class_name DialogueBox
extends Control
## DialogueBox（NPC 对话框）
## 职责：底部对话框（名称 + 文本 + 继续提示）；按 空格/E 或点击继续；
## 对话结束后触发回调（用于接取/交付任务等），单次对话控制在 3-6 句。

var _lines: Array = []
var _index := 0
var _on_finished := Callable()

@onready var name_label: Label = $Panel/NameLabel
@onready var text_label: Label = $Panel/TextLabel


## 由 PlayerController.start_dialogue 调用。
func start(speaker: String, lines: Array, on_finished := Callable()) -> void:
	_lines = lines.duplicate()
	_index = 0
	_on_finished = on_finished
	name_label.text = speaker
	if _lines.is_empty():
		visible = false
		_finish()
		return
	visible = true
	_show_line()


func is_active() -> bool:
	return visible


## 推进到下一句（外部/测试可直接调用）。
func advance() -> void:
	if not visible:
		return
	_index += 1
	if _index >= _lines.size():
		visible = false
		_finish()
	else:
		_show_line()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("jump") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		advance()


func _show_line() -> void:
	text_label.text = str(_lines[_index])


func _finish() -> void:
	var callback := _on_finished
	_on_finished = Callable()
	if callback.is_valid():
		callback.call()
