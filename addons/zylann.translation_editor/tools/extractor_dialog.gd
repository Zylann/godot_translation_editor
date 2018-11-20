tool
extends WindowDialog

const Extractor = preload("extractor.gd")

signal import_selected(strings)

onready var _root_path_edit = get_node("VBoxContainer/HBoxContainer/RootPathEdit")
onready var _summary_label = get_node("VBoxContainer/SummaryLabel")
onready var _results_list = get_node("VBoxContainer/Results")
onready var _progress_bar = get_node("VBoxContainer/ProgressBar")
onready var _extract_button = get_node("VBoxContainer/Buttons/ExtractButton")
onready var _import_button = get_node("VBoxContainer/Buttons/ImportButton")

var _extractor = null
var _results = {}
var _registered_string_filter = null


func _ready():
	_import_button.disabled = true


func set_registered_string_filter(registered_string_filter):
	assert(registered_string_filter is FuncRef)
	_registered_string_filter = registered_string_filter


func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if visible:
			_summary_label.text = ""
			_results.clear()
			_update_import_button()


func _update_import_button():
	_import_button.disabled = (_results == null or len(_results) == 0)


func _on_ExtractButton_pressed():
	if _extractor != null:
		return
	
	var root = _root_path_edit.text.strip_edges()
	var d = Directory.new()
	if not d.dir_exists(root):
		printerr("Directory `", root, "` does not exist")
		return
	
	_extractor = Extractor.new()
	_extractor.connect("finished", self, "_on_Extractor_finished")
	#_extractor.extract("res://", ["addons"])
	_extractor.extract("res://", [])
	
	# TODO Progress reporting
	_progress_bar.value = 50
	
	_extract_button.disabled = true
	_import_button.disabled = true
	
	_summary_label.text = "Extracting..."


func _on_ImportButton_pressed():
	emit_signal("import_selected", _results)
	_results.clear()
	hide()


func _on_CancelButton_pressed():
	# TODO Cancel extraction?
	hide()


func _on_Extractor_finished(results):
	print("Extractor finished")
	_progress_bar.value = 100
	
	_results_list.clear()
	
	var registered_set = {}
	var new_set = {}
	
	# TODO We might actually want to not filter, in order to update location comments
	# Filter results
	if _registered_string_filter != null:
		
		var fpaths = results.keys()
		for fpath in fpaths:
			var strings_dict = results[fpath]
			
			var strings = strings_dict.keys()
			for text in strings:
				if _registered_string_filter.call_func(text):
					strings_dict.erase(text)
					registered_set[text] = true
			
			if len(strings_dict) == 0:
				results.erase(fpath)
	
	# Root
	_results_list.create_item()
	
	for fpath in results:
		#print(fpath)
		var strings = results[fpath]
		
		for text in strings:
			var line_number = strings[text]
			#print("    ", line_number, ": `", text, "`")
			
			var item = _results_list.create_item()
			item.set_text(0, text)
			item.set_text(1, str(fpath, ": ", line_number))
			#item.set_tooltip(
			item.set_metadata(1, fpath)
			
			new_set[text] = true
	
	_results = results
	_extractor = null

	_update_import_button()
	_extract_button.disabled = false
	
	_summary_label.text = "{0} new, {1} registered".format([len(new_set), len(registered_set)])
