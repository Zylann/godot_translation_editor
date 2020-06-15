tool
extends EditorPlugin

const TranslationEditor = preload("./translation_editor.gd")
const TranslationEditorScene = preload("./translation_editor.tscn")
const Logger = preload("./util/logger.gd")

const _default_settings = {
	"translation_editor/string_prefix": "",
	"translation_editor/search_root": "res://",
	"translation_editor/ignored_folders": "addons"
}

var _main_control : TranslationEditor = null
var _logger = Logger.get_for(self)


func _enter_tree():
	_logger.debug("Translation editor plugin Enter tree")
	
	var editor_interface := get_editor_interface()
	var base_control := editor_interface.get_base_control()
	
	_main_control = TranslationEditorScene.instance()
	_main_control.configure_for_godot_integration(base_control)
	_main_control.hide()
	editor_interface.get_editor_viewport().add_child(_main_control)
	
	for key in _default_settings:
		if not ProjectSettings.has_setting(key):
			var v = _default_settings[key]
			ProjectSettings.set_setting(key, v)
			ProjectSettings.set_initial_value(key, v)


func _exit_tree():
	_logger.debug("Translation editor plugin Exit tree")
	# The main control is not freed when the plugin is disabled
	_main_control.queue_free()
	_main_control = null


func has_main_screen() -> bool:
	return true


func get_plugin_name() -> String:
	return "Localization"


func get_plugin_icon() -> Texture:
	return preload("icons/icon_translation_editor.svg")


func make_visible(visible: bool):
	_main_control.visible = visible


