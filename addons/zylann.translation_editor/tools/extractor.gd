
const Logger = preload("./util/logger.gd")

const STATE_SEARCHING = 0
const STATE_READING_TEXT = 1

# results: { string => { fpath => line number } }
signal finished(results)
signal progress_reported(ratio)

# TODO Do we want to know if a text is found multiple times in the same file?
# text => { file => line number }
var _strings := {}
var _thread : Thread = null
var _time_before := 0.0
var _ignored_paths := {}
var _paths := []
var _logger = Logger.get_for(self)
var _prefix := ""
const _prefix_exclusive := true


func extract_async(root: String, ignored_paths := [], prefix := ""):
	_prepare(root, ignored_paths, prefix)
	_thread = Thread.new()
	_thread.start(self, "_extract_thread_func", root)


func extract(root: String, ignored_paths := [], prefix := "") -> Dictionary:
	_prepare(root, ignored_paths, prefix)
	_extract(root)
	return _strings


func _prepare(root: String, ignored_paths: Array, prefix: String):
	_time_before = OS.get_ticks_msec()
	assert(_thread == null)
	
	_ignored_paths.clear()
	for p in ignored_paths:
		_ignored_paths[root.plus_file(p)] = true

	_prefix = prefix
	
	_strings.clear()


func _extract(root: String):
	_walk(root, funcref(self, "_index_file"), funcref(self, "_filter"), _logger)
	
	for i in len(_paths):
		var fpath : String = _paths[i]
		var f := File.new()
		var err := f.open(fpath, File.READ)
		if err != OK:
			_logger.error("Could not open {0} for read, error {1}".format([fpath, err]))
			continue
		var ext := fpath.get_extension()
		match ext:
			"tscn":
				_process_tscn(f, fpath)
			"gd":
				_process_gd(f, fpath)
			"json":
				_process_quoted_text_generic(f, fpath)
			"cs":
				_process_quoted_text_generic(f, fpath)
		f.close()
		call_deferred("_report_progress", float(i) / float(len(_paths)))
	
	
func _extract_thread_func(root: String):
	_extract(root)
	call_deferred("_finished")


func _report_progress(ratio: float):
	emit_signal("progress_reported", ratio)


func _finished():
	_thread.wait_to_finish()
	_thread = null
	var elapsed := float(OS.get_ticks_msec() - _time_before) / 1000.0
	_logger.debug(str("Extraction took ", elapsed, " seconds"))
	emit_signal("finished", _strings)


func _filter(path: String) -> bool:
	if path in _ignored_paths:
		return false
	if path[0] == ".":
		return false
	return true


func _index_file(fpath: String):
	var ext := fpath.get_extension()
	#print("File ", fpath)
	if ext != "tscn" and ext != "gd":
		return
	_paths.append(fpath)


func _process_tscn(f: File, fpath: String):
	var patterns := [
		"text =",
		"window_title =",
		"dialog_text =",
	]
	
	if _prefix != "":
		var p = str("\"", _prefix)
		if _prefix_exclusive:
			patterns = [p]
		else:
			patterns.append(p)

	var text := ""
	var state := STATE_SEARCHING
	var line_number := 0
	
	while not f.eof_reached():
		var line := f.get_line()
		line_number += 1
		
		if line == "":
			continue
		
		match state:
			STATE_SEARCHING:
				var pattern : String
				var pattern_begin_index : int = -1

				for p in patterns:
					var i := line.find(p)
					if i != -1 and (i < pattern_begin_index or pattern_begin_index == -1):
						pattern_begin_index = i
						pattern = p
				
				if pattern_begin_index == -1:
					continue

				var begin_quote_index := -1
			
				if pattern[0] == "\"":
					begin_quote_index = pattern_begin_index

				else:
					begin_quote_index = line.find('"', pattern_begin_index + len(pattern))
					if begin_quote_index == -1:
						_logger.error(
							"Could not find begin quote after text property, in {0}, line {1}" \
							.format([fpath, line_number]))
						continue
					
				var end_quote_index := line.rfind('"')
				
				if end_quote_index != -1 and end_quote_index > begin_quote_index \
				and line[end_quote_index - 1] != '\\':
					text = line.substr(begin_quote_index + 1, 
						end_quote_index - begin_quote_index - 1)
						
					if text != "" and text != _prefix:
						_add_string(fpath, line_number, text)
					text = ""
					
				else:
					# The text may be multiline
					text = str(line.right(begin_quote_index + 1), "\n")
					state = STATE_READING_TEXT
			
			STATE_READING_TEXT:
				var end_quote_index = line.rfind('"')
				if end_quote_index != -1 and line[end_quote_index - 1] != '\\':
					text = str(text, line.left(end_quote_index))
					_add_string(fpath, line_number, text)
					text = ""
					state = STATE_SEARCHING
				else:
					text = str(text, line, "\n")


func _process_gd(f: File, fpath: String):
	var text := ""
	var line_number := 0
	
	var patterns := [
		"tr(",
		"TranslationServer.translate("
	]
	
	if _prefix != "":
		var p = str("\"", _prefix)
		if _prefix_exclusive:
			patterns = [p]
		else:
			patterns.append(p)
	
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		line_number += 1

		if line == "" or line[0] == "#":
			continue
		
		# Search for one or multiple tr("...") in the same line
		var search_index := 0
		var counter := 0
		while search_index < len(line):
			# Find closest pattern
			var pattern : String
			var pattern_start_index := -1
			for p in patterns:
				var i = line.find(p, search_index)
				if i != -1 and (i < pattern_start_index or pattern_start_index == -1):
					pattern_start_index = i
					pattern = p
			
			if pattern_start_index == -1:
				# No pattern found in entire line
				break
			
			var begin_quote_index = -1
			if pattern[0] == "\"":
				# Detected by prefix
				begin_quote_index = pattern_start_index
				
			else:
				# Detect by call to TranslationServer
				if line.substr(pattern_start_index - 1, 3).is_valid_identifier() \
				or line[pattern_start_index - 1] == '"':
					# not a tr( call, or inside a string. skip
					search_index = pattern_start_index + len(pattern)
					continue
				# TODO There may be more cases to handle
				# They may need regexes or a simplified GDScript parser to extract properly
			
				begin_quote_index = line.find('"', pattern_start_index)
				if begin_quote_index == -1:
					# Multiline or procedural strings not supported
					_logger.error("Begin quote not found in {0}, line {1}" \
						.format([fpath, line_number]))
					# No quote found in entire line, skip
					break
			
			var end_quote_index := find_unescaped_quote(line, begin_quote_index + 1)
			if end_quote_index == -1:
				# Multiline or procedural strings not supported
				_logger.error("End quote not found in {0}, line {1}".format([fpath, line_number]))
				break
			
			text = line.substr(begin_quote_index + 1, end_quote_index - begin_quote_index - 1)
#			var end_bracket_index := line.find(')', end_quote_index)
#			if end_bracket_index == -1:
#				# Multiline or procedural strings not supported
#				_logger.error("End bracket not found in {0}, line {1}".format([fpath, line_number]))
#				break
			
			if text != "" and text != _prefix:
				_add_string(fpath, line_number, text)
#			search_index = end_bracket_index
			search_index = end_quote_index + 1
			
			counter += 1
			# If that fails it means we spent 100 iterations in the same line, that's suspicious
			assert(counter < 100)


func _process_quoted_text_generic(f: File, fpath: String):
	var pattern := str("\"", _prefix)
	var line_number := 0
	
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		line_number += 1
	
		var search_index := 0
		while search_index < len(line):
			var i := line.find(pattern, search_index)
			if i == -1:
				break
			
			var begin_quote_index := i
			var end_quote_index := find_unescaped_quote(line, begin_quote_index + 1)
			if end_quote_index == -1:
				break
			
			var text := line.substr(begin_quote_index + 1, end_quote_index - begin_quote_index - 1)
			if text != "" and text != _prefix:
				_add_string(fpath, line_number, text)
			
			search_index = end_quote_index + 1


static func find_unescaped_quote(s, from) -> int:
	while true:
		var i = s.find('"', from)
		if i <= 0:
			return i
		if s[i - 1] != '\\':
			return i
		from = i + 1
	return -1


func _add_string(file: String, line_number: int, text: String):
	if not _strings.has(text):
		_strings[text] = {}
	_strings[text][file] = line_number


static func _walk(folder_path: String, file_action: FuncRef, filter: FuncRef, logger):
	#print("Walking dir ", folder_path)
	var d := Directory.new()
	var err := d.open(folder_path)
	if err != OK:
		logger.error("Could not open directory {0}, error {1}".format([folder_path, err]))
		return
	d.list_dir_begin(true, true)
	var fname := d.get_next()
	while fname != "":
		var fullpath := folder_path.plus_file(fname)
		if filter == null or filter.call_func(fullpath) == true:
			if d.current_is_dir():
				_walk(fullpath, file_action, filter, logger)
			else:
				file_action.call_func(fullpath)
		fname = d.get_next()
	return

