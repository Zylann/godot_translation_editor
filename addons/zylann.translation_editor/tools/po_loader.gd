tool

static func load_po_translation(folder_path, valid_locales):
	var all_strings = {}
	
	var languages = get_languages_in_folder(folder_path, valid_locales)
	
	if len(languages) == 0:
		printerr("No .po languages were found in ", folder_path)
		return all_strings
	
	for language in languages:
		var filepath = folder_path.plus_file(str(language, ".po"))
		
		var f = File.new()
		var err = f.open(filepath, File.READ)
		if err != OK:
			printerr("Could not open file ", filepath, " for read, error ", err)
			return null
		
		f.store_line("")
		
		var comment = ""
		var msgid = ""
		var msgstr = ""
		var last_is_msgid = false
		var ids = []
		var translations = []
		var comments = []
		
		while not f.eof_reached():
			var line = f.get_line().strip_edges()
			
			if line != "" and line[0] == "#":
				if comment == "":
					comment = str(comment, line.right(1))
				else:
					comment = str(comment, "\n", line.right(1))
				continue
			
			var space_index = line.find(" ")
			
			if line.begins_with("msgid"):
				msgid = _parse_msg(line.right(space_index))
				last_is_msgid = true
				
			elif line.begins_with("msgstr"):
				msgstr = _parse_msg(line.right(space_index))
				last_is_msgid = false
				
			elif line.begins_with('"'):
				if last_is_msgid:
					msgid = str(msgid, _parse_msg(line))
				else:
					msgstr = str(msgstr, _parse_msg(line))
				
			elif line == "":
				var s = null
				if not all_strings.has(msgid):
					s = {
						"translations": {},
						"comments": ""
					}
					all_strings[msgid] = s
				else:
					s = all_strings[msgid]
				s.translations[language] = msgstr
				if s.comments == "":
					s.comments = comment
				
				comment = ""
				msgid = ""
				msgstr = ""
				
			else:
				print("Unhandled .po line: ", line)
				continue
				
	return all_strings


static func _parse_msg(s):
	s = s.strip_edges()
	assert(s[0] == '"')
	var end = s.rfind('"')
	var msg = s.substr(1, end - 1)
	return msg.c_unescape().replace('\\"', '"')


class _Sorter:
	func sort(a, b):
		return a[0] < b[0]


static func save_po_translations(folder_path, translations, languages_to_save):
	var sorter = _Sorter.new()
	var saved_languages = []
	
	for language in languages_to_save:
		
		var f = File.new()
		var filepath = folder_path.plus_file(str(language, ".po"))
		var err = f.open(filepath, File.WRITE)
		if err != OK:
			printerr("Could not open file ", filepath, " for write, error ", err)
			continue
		
		var items = []
		
		for id in translations:
			var s = translations[id]
			if not s.translations.has(language):
				continue
			items.append([id, s.translations[language], s.comments])
		
		items.sort_custom(sorter, "sort")
		
		for item in items:
			
			var comment = item[2]
			if comment != "":
				var comment_lines = comment.split("\n")
				for line in comment_lines:
					f.store_line(str("# ", line))
			
			_write_msg(f, "msgid", item[0])
			_write_msg(f, "msgstr", item[1])
			
			f.store_line("")
		
		f.close()
		saved_languages.append(language)
	
	return saved_languages


static func _write_msg(f, msgtype, msg):
	var lines = msg.split("\n")
	if len(lines) > 1:
		for i in range(0, len(lines) - 1):
			lines[i] = str(lines[i], "\n")
	
	# This is just to avoid too long lines
#	if len(lines) > 1:
#		var rlines = []
#		for i in len(rlines):
#			var line = rlines[i]
#			var maxlen = 78
#			if i == 0:
#				maxlen -= len(msgtype) + 1
#			while len(line) > maxlen:
#				line = line.substr(0, maxlen)
#				rlines.append(line)
#			rlines.append(line)
#		lines = rlines

	for i in len(lines):
		lines[i] = lines[i].c_escape().replace('"', '\\"')
	
	f.store_line(str(msgtype, " \"", lines[0], "\""))
	for i in range(1, len(lines)):
		f.store_line(str(" \"", lines[i], "\""))


static func get_languages_in_folder(folder_path, valid_locales):
	var result = []
	var d = Directory.new()
	var err = d.open(folder_path)
	if err != OK:
		printerr("Could not open directory ", folder_path, ", error ", err)
		return result
	d.list_dir_begin()
	var fname = d.get_next()
	while fname != "":
		if not d.current_is_dir():
			var ext = fname.get_extension()
			if ext == "po":
				var language = fname.get_basename().get_file()
				if valid_locales.find(language) != -1:
					result.append(language)
		fname = d.get_next()
	return result
