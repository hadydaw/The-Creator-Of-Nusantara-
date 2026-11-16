extends CanvasLayer
## Antarmuka sentuh: joystick, geser untuk melihat, tombol alat, AKSI, tangan POV.

signal action_pressed
signal tool_selected(index: int)
signal seed_cycle
signal save_pressed

const HandScript := preload("res://scripts/hand.gd")

var move: Vector2 = Vector2.ZERO
var look_accum: Vector2 = Vector2.ZERO
var hand

var _root: Control
var _joy_index: int = -1
var _look_index: int = -1
var _joy_center: Vector2 = Vector2.ZERO
var _joy_base: Panel
var _joy_knob: Panel
var _joy_radius: float = 64.0
var _buttons: Dictionary = {}
var _tool_panels: Array = []
var _info: Label
var _prompt: Label
var _toast: Label
var _toast_tw: Tween
var _seed_label: Label
var _vp: Vector2 = Vector2(1280, 576)


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	hand = HandScript.new()
	_root.add_child(hand)

	var cross := Panel.new()
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross.size = Vector2(6, 6)
	cross.add_theme_stylebox_override("panel", _circle_style(Color(1, 1, 1, 0.85)))
	cross.name = "Cross"
	_root.add_child(cross)

	_info = Label.new()
	_info.position = Vector2(14, 10)
	_info.add_theme_font_size_override("font_size", 18)
	_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_info.add_theme_constant_override("outline_size", 5)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_info)

	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 20)
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_prompt)

	_toast = Label.new()
	_toast.add_theme_font_size_override("font_size", 22)
	_toast.add_theme_color_override("font_color", Color(1, 0.95, 0.6))
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	_root.add_child(_toast)

	_joy_base = _make_circle(_joy_radius * 2.0, Color(1, 1, 1, 0.14))
	_joy_knob = _make_circle(54.0, Color(1, 1, 1, 0.38))
	_joy_base.visible = false
	_joy_knob.visible = false

	for i in Game.TOOLS.size():
		var p := _make_button(Game.TOOLS[i], Vector2(96, 44))
		_buttons["tool%d" % i] = p
		_tool_panels.append(p)
	_buttons["action"] = _make_button("AKSI", Vector2(104, 104), true)
	_buttons["seed"] = _make_button("Benih", Vector2(150, 40))
	_seed_label = (_buttons["seed"] as Panel).get_child(0)
	_buttons["save"] = _make_button("Simpan", Vector2(84, 36))

	get_viewport().size_changed.connect(_layout)
	Game.changed.connect(refresh)
	Game.toast.connect(show_toast)
	_layout()
	refresh()
	set_tool(Game.tool_index)


func _circle_style(c: Color, radius: int = 999) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(radius)
	return s


func _make_circle(d: float, c: Color) -> Panel:
	var p := Panel.new()
	p.size = Vector2(d, d)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _circle_style(c, int(d * 0.5)))
	_root.add_child(p)
	return p


func _make_button(text: String, sz: Vector2, round_btn: bool = false) -> Panel:
	var p := Panel.new()
	p.size = sz
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.1, 0.12, 0.15, 0.62)
	s.border_color = Color(1, 1, 1, 0.55)
	s.set_border_width_all(2)
	if round_btn:
		s.set_corner_radius_all(int(minf(sz.x, sz.y) * 0.48))
	else:
		s.set_corner_radius_all(10)
	p.add_theme_stylebox_override("panel", s)
	var l := Label.new()
	l.text = text
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 22 if round_btn else 17)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	_root.add_child(p)
	return p


func _layout() -> void:
	_vp = get_viewport().get_visible_rect().size
	var w := _vp.x
	var h := _vp.y
	_root.get_node("Cross").position = Vector2(w * 0.5 - 3, h * 0.5 - 3)
	_prompt.size = Vector2(w * 0.7, 30)
	_prompt.position = Vector2(w * 0.15, h * 0.5 + 22)
	_toast.size = Vector2(w * 0.8, 34)
	_toast.position = Vector2(w * 0.1, h * 0.22)
	var tool_w := 96.0 + 8.0
	var x0 := w * 0.5 - tool_w * Game.TOOLS.size() * 0.5
	for i in _tool_panels.size():
		(_tool_panels[i] as Panel).position = Vector2(x0 + tool_w * i, h - 56)
	(_buttons["seed"] as Panel).position = Vector2(w * 0.5 - 75, h - 104)
	(_buttons["action"] as Panel).position = Vector2(w - 330, h - 150)
	(_buttons["save"] as Panel).position = Vector2(w - 98, 10)
	hand.base_pos = Vector2(w - 235, h - hand.H + 110)
	hand.position = hand.base_pos


func refresh() -> void:
	var tide_pct := int(round(Game.tide() * 100.0))
	var hh := int(Game.clock)
	var mm := int((Game.clock - float(hh)) * 60.0)
	var lines := PackedStringArray()
	lines.append("Hari %d   %02d:%02d" % [Game.day, hh, mm])
	lines.append("Koin: %d" % Game.coins)
	lines.append("Kabut: %d%%   Pasang: %d%%" % [int(round(Game.fog * 100.0)), tide_pct])
	var items := PackedStringArray()
	for id in Game.produce:
		if int(Game.produce[id]) > 0:
			items.append("%s x%d" % [Game.item_name(id), int(Game.produce[id])])
	if items.size() > 0:
		lines.append("Hasil: " + ", ".join(items))
	_info.text = "\n".join(lines)
	var sid := Game.selected_seed
	_seed_label.text = "Benih: %s x%d" % [Game.CROPS[sid]["name"], int(Game.seeds.get(sid, 0))]


func set_tool(i: int) -> void:
	Game.tool_index = i
	for k in _tool_panels.size():
		var s := (_tool_panels[k] as Panel).get_theme_stylebox("panel") as StyleBoxFlat
		s.bg_color = Color(0.85, 0.6, 0.15, 0.85) if k == i else Color(0.1, 0.12, 0.15, 0.62)
	hand.set_tool(i)
	(_buttons["seed"] as Panel).visible = i == 2


func set_prompt(text: String) -> void:
	_prompt.text = text


func show_toast(text: String) -> void:
	_toast.text = text
	if _toast_tw and _toast_tw.is_valid():
		_toast_tw.kill()
	_toast.modulate.a = 1.0
	_toast_tw = create_tween()
	_toast_tw.tween_interval(1.4)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.5)


func consume_look() -> Vector2:
	var v := look_accum
	look_accum = Vector2.ZERO
	hand.look = v
	return v


func _process(_delta: float) -> void:
	_refresh_clock()


var _clock_acc: float = 0.0


func _refresh_clock() -> void:
	_clock_acc += get_process_delta_time()
	if _clock_acc > 0.5:
		_clock_acc = 0.0
		refresh()


func _button_at(pos: Vector2) -> String:
	for key in _buttons:
		var b: Panel = _buttons[key]
		if b.visible and b.get_global_rect().has_point(pos):
			return key
	return ""


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		if t.pressed:
			_press(t.index, t.position)
		else:
			_release(t.index)
	elif event is InputEventScreenDrag:
		var d: InputEventScreenDrag = event
		_drag(d.index, d.position, d.relative)
	elif event.is_action_pressed("do_action"):
		action_pressed.emit()


func _press(index: int, pos: Vector2) -> void:
	var key := _button_at(pos)
	if key != "":
		_activate(key)
		return
	if pos.x < _vp.x * 0.42 and pos.y > _vp.y * 0.25 and _joy_index == -1:
		_joy_index = index
		_joy_center = pos
		_joy_base.position = pos - Vector2(_joy_radius, _joy_radius)
		_joy_knob.position = pos - Vector2(27, 27)
		_joy_base.visible = true
		_joy_knob.visible = true
	elif _look_index == -1 and pos.x >= _vp.x * 0.42:
		_look_index = index


func _activate(key: String) -> void:
	if key == "action":
		action_pressed.emit()
	elif key == "seed":
		seed_cycle.emit()
	elif key == "save":
		save_pressed.emit()
	elif key.begins_with("tool"):
		var i := int(key.substr(4))
		set_tool(i)
		tool_selected.emit(i)


func _release(index: int) -> void:
	if index == _joy_index:
		_joy_index = -1
		move = Vector2.ZERO
		_joy_base.visible = false
		_joy_knob.visible = false
		hand.walk = 0.0
	elif index == _look_index:
		_look_index = -1


func _drag(index: int, pos: Vector2, rel: Vector2) -> void:
	if index == _joy_index:
		var off := (pos - _joy_center).limit_length(_joy_radius)
		_joy_knob.position = _joy_center + off - Vector2(27, 27)
		move = off / _joy_radius
		hand.walk = move.length()
	elif index == _look_index:
		look_accum += rel * 0.0065
