tool
extends WindowDialog

const Extractor = preload("./extractor.gd")
const Logger = preload("./util/logger.gd")

signal import_selected(strings)

onready var _root_path_edit : LineEdit = $VB/HB/RootPathEdit
onready var _excluded_dirs_edit : LineEdit = $VB/HB2/ExcludedDirsEdit
onready var _prefix_edit : LineEdit = $VB/HB3/PrefixLineEdit
onready var _summary_label : Label = $VB/StatusBar/SummaryLabel
onready var _results_list : Tree = $VB/Results
onready var _progress_bar : ProgressBar = $VB/StatusBar/ProgressBar
onready var _extract_button : Button = $VB/Buttons/ExtractButton
onready var _import_button : Button = $VB/Buttons/ImportButton

var _extractor : Extractor = null
# { string => { fpath => line number } }
var _results := {}
var _registered_string_filter : FuncRef = null
var _logger = Logger.get_for(self)


func _ready():
	_import_button.disabled = true


func set_registered_string_filter(registered_string_filter: FuncRef):
	_registered_string_filter = registered_string_filter


func _notification(what: int):
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if visible:
			_summary_label.text = ""
			_results.clear()
			_results_list.clear()
			_update_import_button()
			
			if ProjectSettings.has_setting("translation_editor/string_prefix"):
				_prefix_edit.text = ProjectSettings.get_setting("translation_editor/string_prefix")

			if ProjectSettings.has_setting("translation_editor/search_root"):
				_root_path_edit.text = ProjectSettings.get_setting("translation_editor/search_root")

			if ProjectSettings.has_setting("translation_editor/ignored_folders"):
				_excluded_dirs_edit.text = \
					ProjectSettings.get_setting("translation_editor/ignored_folders")


func _update_import_button():
	# Can only import if there are results to import
	_import_button.disabled = (len(_results) == 0)


func _on_ExtractButton_pressed():
	if _extractor != null:
		return
	
	var root := _root_path_edit.text.strip_edges()
	var d := Directory.new()
	if not d.dir_exists(root):
		_logger.error("Directory {0} does not exist".format([root]))
		return
	
	var excluded_dirs := _excluded_dirs_edit.text.split(";", false)
	for i in len(excluded_dirs):
		excluded_dirs[i] = excluded_dirs[i].strip_edges()
	
	var prefix := _prefix_edit.text.strip_edges()
	
	_extractor = Extractor.new()
	_extractor.connect("progress_reported", self, "_on_Extractor_progress_reported")
	_extractor.connect("finished", self, "_on_Extractor_finished")
	_extractor.extract_async(root, excluded_dirs, prefix)
	
	_progress_bar.value = 0
	_progress_bar.show()
	_summary_label.text = ""
	
	_extract_button.disabled = true
	_import_button.disabled = true


func _on_ImportButton_pressed():
	emit_signal("import_selected", _results)
	_results.clear()
	hide()


func _on_CancelButton_pressed():
	# TODO Cancel extraction?
	hide()


func _on_Extractor_progress_reported(ratio):
	_progress_bar.value = 100.0 * ratio


func _on_Extractor_finished(results: Dictionary):
	_logger.debug("Extractor finished")
	
	_progress_bar.value = 100
	_progress_bar.hide()
	
	_results_list.clear()
	
	var registered_set := {}
	var new_set := {}
	
	# TODO We might actually want to not filter, in order to update location comments
	# Filter results
	if _registered_string_filter != null:
		var texts := results.keys()
		for text in texts:
			if _registered_string_filter.call_func(text):
				results.erase(text)
				registered_set[text] = true
	
	# Root
	_results_list.create_item()
	
	for text in results:
		var item : TreeItem = _results_list.create_item()
		item.set_text(0, text)
		item.collapsed = true
		new_set[text] = true
		
		var files = results[text]
		for file in files:
			var line_number : int = files[file]
			
			var file_item : TreeItem = _results_list.create_item(item)
			file_item.set_text(0, str(file, ": ", line_number))
	
	_results = results
	_extractor = null

	_update_import_button()
	_extract_button.disabled = false
	
	_summary_label.text = "{0} new, {1} registered".format([len(new_set), len(registered_set)])
