tool
extends EditorPlugin

const TranslationEditor = preload("./translation_editor.gd")
const TranslationEditorScene = preload("./translation_editor.tscn")

var _main_control : TranslationEditor = null


func _enter_tree():
	print("Translation editor plugin Enter tree")
	
	var editor_interface := get_editor_interface()
	var base_control := editor_interface.get_base_control()
	
	_main_control = TranslationEditorScene.instance()
	_main_control.configure_for_godot_integration(base_control)
	_main_control.hide()
	editor_interface.get_editor_viewport().add_child(_main_control)


func _exit_tree():
	print("Translation editor plugin Exit tree")
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


