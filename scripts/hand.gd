extends Control
## Tangan POV dengan animasi: napas, goyang jalan, ayun, siram, lempar, panen.

const W := 230.0
const H := 348.0

var base_pos: Vector2 = Vector2.ZERO
var walk: float = 0.0
var look: Vector2 = Vector2.ZERO
var tool_id: int = 0

var act_rot: float = 0.0
var act_off: Vector2 = Vector2.ZERO
var act_scale: float = 1.0

var _t: float = 0.0
var _sway: Vector2 = Vector2.ZERO
var _tw: Tween
var _tex: TextureRect
var _poses: Dictionary = {}
var _pose: String = "open"


func _ready() -> void:
	size = Vector2(W, H)
	pivot_offset = Vector2(W * 0.5, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_poses = {
		"open": load("res://assets/hand_buka.png"),
		"loose": load("res://assets/hand_longgar.png"),
		"grip": load("res://assets/hand_genggam.png"),
		"pinch": load("res://assets/hand_jepit.png"),
		"palm": load("res://assets/hand_telapak.png"),
		"reach": load("res://assets/hand_jangkau.png"),
	}
	_tex = TextureRect.new()
	_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex.stretch_mode = TextureRect.STRETCH_SCALE
	_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tex)
	_show_pose(_pose_for_tool())


func _pose_for_tool() -> String:
	match tool_id:
		1:
			return "loose"
		2:
			return "pinch"
		3:
			return "loose"
	return "grip"


func _show_pose(name: String) -> void:
	_pose = name
	var t: Texture2D = _poses[name]
	_tex.texture = t
	var w := H * float(t.get_width()) / float(t.get_height())
	_tex.size = Vector2(w, H)
	_tex.position = Vector2((W - w) * 0.5, 0.0)


func set_tool(i: int) -> void:
	tool_id = i
	if _tex:
		_show_pose(_pose_for_tool())


func _process(delta: float) -> void:
	_t += delta
	var bob := sin(_t * 9.0) * walk * 6.0
	var bobx := sin(_t * 4.5) * walk * 4.0
	var idle := sin(_t * 1.7) * 1.6
	_sway = _sway.lerp(-look * 900.0, 0.18)
	_sway = _sway.limit_length(28.0)
	position = base_pos + Vector2(bobx + idle + _sway.x + act_off.x, bob + absf(idle) + _sway.y * 0.5 + act_off.y)
	rotation = sin(_t * 1.3) * 0.015 + act_rot + _sway.x * 0.004
	scale = Vector2.ONE * act_scale


func _tween_to(rot: float, off: Vector2, sc: float, dur: float, ease_type: Tween.EaseType = Tween.EASE_OUT) -> void:
	_tw.tween_property(self, "act_rot", rot, dur).set_ease(ease_type).set_trans(Tween.TRANS_SINE)
	_tw.parallel().tween_property(self, "act_off", off, dur).set_ease(ease_type).set_trans(Tween.TRANS_SINE)
	_tw.parallel().tween_property(self, "act_scale", sc, dur).set_ease(ease_type).set_trans(Tween.TRANS_SINE)


func play(kind: String) -> void:
	if _tw and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	match kind:
		"swing":
			_tween_to(-0.35, Vector2(14, -30), 1.0, 0.16)
			_tween_to(0.42, Vector2(-14, 46), 1.05, 0.09, Tween.EASE_IN)
			_tween_to(0.0, Vector2.ZERO, 1.0, 0.26)
		"water":
			_tween_to(0.62, Vector2(-34, 4), 1.0, 0.2)
			_tw.tween_interval(0.35)
			_tween_to(0.0, Vector2.ZERO, 1.0, 0.22)
		"plant":
			_tween_to(0.12, Vector2(0, 54), 0.94, 0.16)
			_tw.tween_interval(0.12)
			_tween_to(0.0, Vector2.ZERO, 1.0, 0.2)
		"cast":
			_tween_to(-0.55, Vector2(34, 66), 1.0, 0.26)
			_tween_to(0.38, Vector2(-24, -36), 1.04, 0.12, Tween.EASE_IN)
			_tween_to(0.0, Vector2(0, 8), 1.0, 0.3)
		"reach":
			_show_pose("reach")
			_tween_to(-0.05, Vector2(0, -36), 1.13, 0.12)
			_tween_to(0.0, Vector2.ZERO, 1.0, 0.2)
			_tw.tween_callback(func() -> void: _show_pose(_pose_for_tool()))
		"bite":
			for i in 3:
				_tween_to(0.08, Vector2(0, 10), 1.0, 0.05)
				_tween_to(-0.08, Vector2(0, -6), 1.0, 0.05)
			_tween_to(0.0, Vector2(0, 6), 1.0, 0.08)
		"reel":
			_tween_to(0.3, Vector2(-10, 40), 1.0, 0.12)
			_tween_to(-0.3, Vector2(10, -34), 1.06, 0.14, Tween.EASE_IN)
			_tween_to(0.0, Vector2.ZERO, 1.0, 0.2)
		_:
			_tween_to(0.0, Vector2.ZERO, 1.0, 0.1)
