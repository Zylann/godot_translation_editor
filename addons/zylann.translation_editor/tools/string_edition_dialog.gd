tool
extends WindowDialog

signal submitted(str_id, prev_str_id)

onready var _line_edit : LineEdit = $VBoxContainer/LineEdit
onready var _ok_button : Button = $VBoxContainer/Buttons/OkButton
onready var _hint_label : Label = $VBoxContainer/HintLabel

var _validator_func : FuncRef = null
var _prev_str_id := ""


func set_replaced_str_id(str_id: String):
	_prev_str_id = str_id
	_line_edit.text = str_id


func set_validator(f: FuncRef):
	_validator_func = f


func _notification(what: int):
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if visible:
			if _prev_str_id == "":
				window_title = "New string ID"
			else:
				window_title = str("Replace `", _prev_str_id, "`")
			_line_edit.grab_focus()
			_validate()


func _on_LineEdit_text_changed(new_text: String):
	_validate()


func _validate():
	var new_text := _line_edit.text.strip_edges()
	var valid := not new_text.empty()
	var hint_message := ""

	if _validator_func != null:
		var res = _validator_func.call_func(new_text)
		assert(typeof(res) == TYPE_BOOL or typeof(res) == TYPE_STRING)
		if typeof(res) != TYPE_BOOL or res == false:
			hint_message = res
			valid = false

	_ok_button.disabled = not valid
	_hint_label.text = hint_message
	# Note: hiding the label would shift up other controls in the container


func _on_LineEdit_text_entered(new_text: String):
	submit()


func _on_OkButton_pressed():
	submit()


func _on_CancelButton_pressed():
	hide()


func submit():
	var s := _line_edit.text.strip_edges()
	emit_signal("submitted", s, _prev_str_id)
	hide()

