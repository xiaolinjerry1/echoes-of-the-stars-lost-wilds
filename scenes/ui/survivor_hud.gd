class_name SurvivorHUD
extends CanvasLayer
## 飞镖师HUD与暂停/升级界面；暂停时保持可操作，升级选择不能跳过。
var controller: DartMasterController
var root: Control
var status: Label
var health: ProgressBar
var exp_bar: ProgressBar
var echo_bar: ProgressBar
var echo_text: Label
var feedback: Label
var modal: PanelContainer
var modal_box: VBoxContainer
var mode := ""
var feedback_left := 0.0
var map_panel: MapPanel
var dialogue_box: DialogueBox
var settings: Control
var hint: Label
var threat: Label
const TITLES := {"count":"飞刃扩阵","speed":"疾风连射","damage":"锋芒淬炼","move":"踏影疾行","duration":"影身延续"}
const COLORS := {"count":Color(0.45,0.75,1),"speed":Color(0.45,0.9,0.75),"damage":Color(1,0.65,0.45),"move":Color(0.9,0.8,0.4),"duration":Color(0.75,0.55,1)}

func setup(growth: DartMasterController) -> void:
	controller = growth
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var cross := label("·",26)
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.position = Vector2(-7,-17)
	root.add_child(cross)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.position = Vector2(24,-185)
	panel.custom_minimum_size = Vector2(410,160)
	panel.add_theme_stylebox_override("panel",style(Color(0.035,0.045,0.07,0.94),Color(0.3,0.4,0.65)))
	root.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	status = label("",18)
	box.add_child(status)
	health = bar(Color(0.85,0.25,0.32)); box.add_child(health)
	exp_bar = bar(Color(0.5,0.8,0.9)); box.add_child(exp_bar)
	echo_bar = bar(Color(0.6,0.45,1)); box.add_child(echo_bar)
	echo_text = label("",15); box.add_child(echo_text)
	var controls := label("左键  飞镖连投归航  ·  右键  奥义影分身\nWASD 移动  ·  空格 跳跃  ·  E 交互  ·  M 地图  ·  Esc 暂停",15)
	controls.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	controls.position = Vector2(-540,-88)
	controls.size = Vector2(510,65)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(controls)
	hint=label("",18)
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM);hint.position=Vector2(-250,-125);hint.size=Vector2(500,30);hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;root.add_child(hint)
	threat=label("",16);threat.set_anchors_preset(Control.PRESET_TOP_RIGHT);threat.position=Vector2(-310,25);threat.size=Vector2(280,55);threat.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;root.add_child(threat)
	feedback = label("离开营地，击杀敌人收集经验 · 升级选择强化",22)
	feedback.set_anchors_preset(Control.PRESET_CENTER_TOP)
	feedback.position = Vector2(-400,45)
	feedback.size = Vector2(800,60)
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(feedback)
	feedback_left = 8.0
	modal = PanelContainer.new()
	modal.set_anchors_preset(Control.PRESET_CENTER)
	modal.position = Vector2(-455,-235)
	modal.custom_minimum_size = Vector2(910,470)
	modal.add_theme_stylebox_override("panel",style(Color(0.025,0.035,0.065,0.99),Color(0.65,0.55,0.9)))
	modal_box = VBoxContainer.new()
	modal_box.add_theme_constant_override("separation",18)
	modal.add_child(modal_box)
	root.add_child(modal)
	modal.hide()
	map_panel = (load("res://scenes/ui/map_panel.tscn") as PackedScene).instantiate()
	add_child(map_panel)
	map_panel.setup(controller.player)
	dialogue_box = (load("res://scenes/ui/dialogue_box.tscn") as PackedScene).instantiate()
	add_child(dialogue_box)
	settings = (load("res://scenes/ui/settings_panel.tscn") as PackedScene).instantiate()
	add_child(settings)

static func style(bg: Color, edge: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color=bg; s.border_color=edge
	s.set_border_width_all(2);s.set_corner_radius_all(12)
	s.content_margin_left=20;s.content_margin_right=20;s.content_margin_top=16;s.content_margin_bottom=16
	return s

static func label(text: String, size: int) -> Label:
	var l := Label.new();l.text=text;l.add_theme_font_size_override("font_size",size)
	l.add_theme_constant_override("outline_size",3);l.add_theme_color_override("font_outline_color",Color(0.02,0.025,0.04))
	return l

static func bar(color: Color) -> ProgressBar:
	var b := ProgressBar.new();b.custom_minimum_size=Vector2(350,16)
	var bg := style(Color(0.06,0.075,0.11),Color.TRANSPARENT)
	var fill := style(color,Color.TRANSPARENT)
	for s in [bg,fill]:
		s.content_margin_top=0;s.content_margin_bottom=0;s.content_margin_left=0;s.content_margin_right=0
	b.add_theme_stylebox_override("background",bg)
	b.add_theme_stylebox_override("fill",fill)
	b.show_percentage=false
	return b

func _process(delta: float) -> void:
	if controller == null: return
	refresh()
	if not get_tree().paused:
		feedback_left=maxf(0.0,feedback_left-delta)
		feedback.visible=feedback_left>0.0
		var target := controller.nearest_interactable()
		hint.text="E  ·  "+target.interact_text if target!=null and not panel_open() else ""
		threat.text="原野侵袭  ·  敌人 %d\n飞刃 %d 枚  ·  攻击 %.0f" % [get_tree().get_nodes_in_group("enemy").size(),controller.dart_count(),controller.attack_damage()]

func refresh() -> void:
	if controller == null: return
	var stats := controller.player.stats
	status.text="飞镖师 Lv.%d  ·  生命 %d/%d  ·  击杀 %d" % [stats.level,stats.current_health,stats.max_health,controller.kills]
	health.max_value=stats.max_health;health.value=stats.current_health
	exp_bar.max_value=stats.get_exp_to_next_level();exp_bar.value=stats.exp
	exp_bar.tooltip_text="经验 %d/%d" % [stats.exp,stats.get_exp_to_next_level()]
	echo_bar.value=controller.echo_value
	if controller.ultimate_left>0.0: echo_text.text="影分身之术 · %.1f 秒" % controller.ultimate_left
	elif controller.windup>0.0: echo_text.text="结印中…"
	else: echo_text.text="经验 %d/%d · 回响 %d/100%s" % [stats.exp,stats.get_exp_to_next_level(),controller.echo_value," · 右键释放" if controller.echo_value>=100 else " · 命中充能"]

func show_feedback(text: String, color: Color) -> void:
	feedback.text=text;feedback.modulate=color;feedback_left=3.0;feedback.show()

func panel_open() -> bool:
	return not mode.is_empty() or map_panel.visible or settings.visible or controller.player.dialogue_active

func _clear_modal() -> void:
	for child in modal_box.get_children(): modal_box.remove_child(child);child.queue_free()

func show_choices() -> void:
	mode="upgrade"
	_clear_modal()
	modal_box.add_child(label("升级 · 选择你的强化",30))
	modal_box.add_child(label("五种能力随机抽三种，每级选择一项  ·  尚有 %d 次选择" % controller.pending_choices,17))
	var row := HBoxContainer.new();row.add_theme_constant_override("separation",14);modal_box.add_child(row)
	for i in controller.offered.size():
		var id: String=controller.offered[i]
		var b := Button.new()
		b.custom_minimum_size=Vector2(270,285)
		b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		b.text="%d  ·  %s\n\n%s\n\n强化等级 %d → %d" % [i+1,TITLES[id],upgrade_description(id),int(controller.ranks[id]),int(controller.ranks[id])+1]
		b.add_theme_font_size_override("font_size",20)
		b.add_theme_stylebox_override("normal",style(Color(0.07,0.085,0.14),COLORS[id]))
		b.add_theme_stylebox_override("hover",style(Color(0.12,0.15,0.23),Color.WHITE))
		b.pressed.connect(func():controller.choose_upgrade(id))
		row.add_child(b)
	modal.show();get_tree().paused=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func upgrade_description(id: String) -> String:
	match id:
		"count":return "飞镖 %d → %d 枚\n环绕半径 %.2f → %.2f 米" % [controller.dart_count(),controller.dart_count()+2,controller.orbit_radius(),controller.orbit_radius()+0.35]
		"speed":return "连投速度与接触间隔\n%.2f → %.2f 秒" % [controller.attack_interval(),0.12+(controller.attack_interval()-0.12)*0.86]
		"damage":return "每枚飞镖攻击力\n%.1f → %.1f" % [controller.attack_damage(),controller.attack_damage()+(18+(controller.player.stats.level-1)*2)*0.25]
		"move":return "移动速度\n%.2f → %.2f 米/秒" % [controller.move_speed(),controller.move_speed()+0.52]
		_:return "影分身持续时间\n%.0f → %.0f 秒" % [controller.ultimate_duration(),controller.ultimate_duration()+2]

func close_panel() -> void:
	if controller.pending_choices>0:
		show_choices();return
	mode="";modal.hide();get_tree().paused=false;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func toggle_pause() -> void:
	if controller.pending_choices>0: return
	if mode=="pause":close_panel();return
	mode="pause";_clear_modal()
	modal_box.add_child(label("暂歇 · 群星回响",28))
	button("继续冒险",close_panel)
	for slot in [1,2,3]:
		button("保存至档位 %d" % slot,func():
			if AppFlow.game_session.is_in_combat():show_feedback("战斗中不能保存",Color(1,0.6,0.4));return
			SaveService.save_game(slot)
			show_feedback("已保存至档位 %d" % slot,Color(0.6,1,0.8)))
		if SaveService.has_save(slot):button("读取档位 %d" % slot,func():get_tree().paused=false;AppFlow.continue_game(slot))
	button("设置",func():settings.open())
	button("返回主菜单",func():get_tree().paused=false;AppFlow.return_to_title())
	modal.show();get_tree().paused=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func button(text: String, action: Callable) -> void:
	var b := Button.new();b.text=text;b.custom_minimum_size.y=36;b.pressed.connect(action);modal_box.add_child(b)

func _unhandled_input(event: InputEvent) -> void:
	if controller==null:return
	if settings.visible or controller.player.dialogue_active:return
	if mode=="upgrade" and event is InputEventKey and event.pressed and not event.echo:
		var index: int = event.physical_keycode-KEY_1
		if index>=0 and index<controller.offered.size():controller.choose_upgrade(controller.offered[index]);get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		if map_panel.visible:map_panel.close_panel();get_tree().paused=false;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		else:toggle_pause()
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and event.physical_keycode==KEY_M and mode.is_empty():
		if map_panel.visible:map_panel.close_panel();get_tree().paused=false;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		else:map_panel.open_panel();get_tree().paused=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
