extends Control
## 新局职业选择；当前开放第三人称飞镖师，开始按钮直接创建割草会话。
func _ready() -> void:
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var bg := ColorRect.new();bg.color=Color(0.025,0.035,0.065);bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(bg)
	var panel := HBoxContainer.new();panel.set_anchors_preset(Control.PRESET_CENTER);panel.position=Vector2(-470,-275);panel.custom_minimum_size=Vector2(940,550);panel.add_theme_constant_override("separation",45);add_child(panel)
	var portrait := TextureRect.new();portrait.texture=load("res://art/previews/player/dart_master.png");portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.custom_minimum_size=Vector2(420,550);panel.add_child(portrait)
	var box := VBoxContainer.new();box.custom_minimum_size=Vector2(465,0);box.add_theme_constant_override("separation",22);panel.add_child(box)
	box.add_child(SurvivorHUD.label("选择职业",18))
	box.add_child(SurvivorHUD.label("飞镖师",46))
	box.add_child(SurvivorHUD.label("环刃护身 · 飞刃破阵 · 影身同行",20))
	box.add_child(SurvivorHUD.label("第三人称视角\n\n六枚飞镖持续环绕，接触敌人自动伤害。\n左键齐射，环绕飞镖始终保留。\n命中充满回响，右键发动影分身之术。\n\n击杀收集经验，升级随机三选一强化。\n每一级都提升基础攻击，越战越强。",18))
	var start := Button.new();start.text="以飞镖师开始冒险";start.custom_minimum_size.y=60;start.add_theme_font_size_override("font_size",23);start.pressed.connect(func():start.disabled=true;AppFlow.start_new_game("dart_master"));box.add_child(start)
	var back := Button.new();back.text="返回主菜单";back.pressed.connect(func():get_tree().change_scene_to_file("res://scenes/app/main_menu.tscn"));box.add_child(back)
