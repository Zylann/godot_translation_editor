tool
extends Panel

const CsvLoader = preload("csv_loader.gd")
const PoLoader = preload("po_loader.gd")
const StringEditionDialog = preload("string_edition_dialog.tscn")

const MENU_FILE_OPEN = 0
const MENU_FILE_SAVE = 1
const MENU_FILE_SAVE_AS = 2

onready var _file_menu = get_node("VBoxContainer/MenuBar/FileMenu")
onready var _edit_menu = get_node("VBoxContainer/MenuBar/EditMenu")
onready var _string_list = get_node("VBoxContainer/Main/LeftPane/StringList")
onready var _translation_tab_container = \
	get_node("VBoxContainer/Main/RightPane/VSplitContainer/TranslationTabContainer")
onready var _notes_edit = get_node("VBoxContainer/Main/RightPane/VSplitContainer/VBoxContainer/NotesEdit")

var _string_edit_dialog = null
var _open_dialog = null
var _save_dialog = null

# This is set when integrated as a Godot plugin
var _base_control = null

var _data = null
# TODO Make this a config of some sort
var _languages = ["en", "fr"]
var _current_file = null

var _translation_edits = {}


func _ready():
	# I don't want any of this to run in the edited scene (because `tool`)...
	if Engine.editor_hint and get_parent() is Viewport:
		return
	
	_file_menu.get_popup().add_item("Open...", MENU_FILE_OPEN)
	_file_menu.get_popup().add_item("Save", MENU_FILE_SAVE)
	_file_menu.get_popup().add_item("Save as...", MENU_FILE_SAVE_AS)
	_file_menu.get_popup().connect("id_pressed", self, "_on_FileMenu_id_pressed")
	
	_edit_menu.get_popup().connect("id_pressed", self, "_on_EditMenu_id_pressed")
	
	var dialogs_parent = self
	if _base_control != null:
		dialogs_parent = _base_control
		self_modulate = Color(0,0,0,0)
	
	_open_dialog = FileDialog.new()
	_open_dialog.window_title = "Open translations"
	_open_dialog.add_filter("*.csv ; CSV files")
	_open_dialog.add_filter("*.po ; Gettext files")
	_open_dialog.mode = FileDialog.MODE_OPEN_FILE
	_open_dialog.connect("file_selected", self, "_on_OpenDialog_file_selected")
	dialogs_parent.add_child(_open_dialog)

	_save_dialog = FileDialog.new()
	_save_dialog.window_title = "Save translations"
	_save_dialog.add_filter("*.csv ; CSV files")
	_save_dialog.add_filter("*.po ; Gettext files")
	_save_dialog.mode = FileDialog.MODE_SAVE_FILE
	_save_dialog.connect("file_selected", self, "_on_SaveDialog_file_selected")
	dialogs_parent.add_child(_save_dialog)
	
	_string_edit_dialog = StringEditionDialog.instance()
	_string_edit_dialog.set_validator(funcref(self, "_validate_new_string_id"))
	dialogs_parent.add_child(_string_edit_dialog)


func configure_for_godot_integration(base_control):
	# You have to call this before adding to the tree
	assert(not is_inside_tree())
	_base_control = base_control


func _on_FileMenu_id_pressed(id):
	match id:
		MENU_FILE_OPEN:
			_open_dialog.popup_centered_ratio()
		MENU_FILE_SAVE:
			if _current_file == null:
				_save_dialog.popup_centered_ratio()
			else:
				save_file(_current_file)
		MENU_FILE_SAVE_AS:
			_save_dialog.popup_centered_ratio()


func _on_EditMenu_id_pressed(id):
	pass


func _on_OpenDialog_file_selected(filepath):
	load_file(filepath)


func _on_SaveDialog_file_selected(filepath):
	save_file(filepath)


func load_file(filepath):
	var ext = filepath.get_extension()
	if ext == "po":
		_data = PoLoader.load_po_translation(filepath)
	elif ext == "csv":
		_data = CsvLoader.load_csv_translation(filepath)
	else:
		printerr("Unknown file format, cannot load ", filepath)
		return
	
	_translation_edits.clear()
	
	for i in _translation_tab_container.get_child_count():
		var child = _translation_tab_container.get_child(i)
		if child is TextEdit:
			child.queue_free()
	
	for language in _languages:
		var edit = TextEdit.new()
		var tab_index = _translation_tab_container.get_tab_count()
		_translation_tab_container.add_child(edit)
		_translation_tab_container.set_tab_title(tab_index, language)
		_translation_edits[language] = edit
		
	refresh_list()
	_current_file = filepath


func save_file(filepath):
	var ext = filepath.get_extension()
	if ext == "po":
		PoLoader.save_po_translations(filepath.get_base_dir(), _data, _languages)
	elif ext == "csv":
		CsvLoader.save_csv_translation(_data)
	else:
		printerr("Unknown file format, cannot save ", filepath)


func refresh_list():
	_string_list.clear()
	var ordered_ids = _data.keys()
	ordered_ids.sort()
	for id in ordered_ids:
		#var i = _string_list.get_item_count()
		_string_list.add_item(id)


func _on_StringList_item_selected(index):
	var str_id = _string_list.get_item_text(index)
	var s = _data[str_id]
	for language in _languages:
		var e = _translation_edits[language]
		if s.translations.has(language):
			e.text = s.translations[language]
		else:
			e.text = ""
	_notes_edit.text = s.comments


func _on_AddButton_pressed():
	_string_edit_dialog.set_replaced_str_id(null)
	_string_edit_dialog.popup_centered()


func _on_RemoveButton_pressed():
	# TODO Remove string with confirmation
	pass


func _on_RenameButton_pressed():
	var selected_items = _string_list.get_selected_items()
	if len(selected_items) == 0:
		return
	var str_id = _string_list.get_item_text(selected_items[0])
	_string_edit_dialog.set_replaced_str_id(str_id)
	_string_edit_dialog.popup_centered()


func _on_StringEditionDialog_submitted(str_id, prev_str_id):
	if prev_str_id == null:
		add_new_string(str_id)
	else:
		rename_string(prev_str_id, str_id)


func _validate_new_string_id(str_id):
	if _data.has(str_id):
		return "Already existing"
	return true


func add_new_string(strid):
	assert(not _data.has(strid))
	var s = {
		"translations": {},
		"comments": ""
	}
	_data[strid] = s
	_string_list.add_item(strid)


func rename_string(old_strid, new_strid):
	assert(_data.has(old_strid))
	var s = _data[old_strid]
	_data.erase(old_strid)
	_data[new_strid] = s
	for i in _string_list.get_item_count():
		if _string_list.get_item_text(i) == old_strid:
			_string_list.set_item_text(i, new_strid)
			break

