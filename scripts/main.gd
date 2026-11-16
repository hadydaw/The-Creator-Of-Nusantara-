extends Node3D
## Dunia Pulau Kabut: membangun pulau, mengatur siklus hari, aksi pemain.

const PlotScript := preload("res://scripts/plot.gd")
const InteractScript := preload("res://scripts/interactable.gd")
const PlayerScript := preload("res://scripts/player.gd")
const HudScript := preload("res://scripts/hud.gd")

var player: CharacterBody3D
var hud: CanvasLayer
var env: Environment
var sun: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial
var water_mesh: MeshInstance3D
var water_body: StaticBody3D
var plots: Array = []

var fish_state: int = 0   # 0 diam, 1 menunggu, 2 ikan menggigit
var fish_timer: float = 0.0
var _autosave: float = 0.0
var _mats: Dictionary = {}


func _ready() -> void:
	_setup_inputs()
	_build_environment()
	_build_island()
	_build_farm()
	_build_warung()
	_build_kios()
	_build_tent()
	_build_trees()
	_build_grass()

	player = PlayerScript.new()
	add_child(player)
	player.position = Vector3(0, 0.3, 5.0)
	player.water_ref = water_body

	hud = HudScript.new()
	add_child(hud)
	player.hud = hud
	hud.action_pressed.connect(do_action)
	hud.tool_selected.connect(_on_tool_selected)
	hud.seed_cycle.connect(func() -> void: Game.cycle_seed())
	hud.save_pressed.connect(func() -> void:
		save()
		Game.toast.emit("Tersimpan"))

	var selftest: bool = "--selftest" in OS.get_cmdline_user_args()
	if selftest:
		Game.save_path = "user://selftest.json"
		DirAccess.remove_absolute(Game.save_path)
	var saved := Game.load_game()
	for i in mini(saved.size(), plots.size()):
		plots[i].from_dict(saved[i])
	Game.day_changed.connect(_on_day_changed)
	_update_env(1.0)

	if selftest:
		_run_selftest.call_deferred()


func _setup_inputs() -> void:
	var map := {
		"mv_l": KEY_A, "mv_r": KEY_D, "mv_f": KEY_W, "mv_b": KEY_S,
		"lk_l": KEY_LEFT, "lk_r": KEY_RIGHT, "lk_u": KEY_UP, "lk_d": KEY_DOWN,
		"do_action": KEY_E,
	}
	for a in map:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
			var ev := InputEventKey.new()
			ev.physical_keycode = map[a]
			InputMap.action_add_event(a, ev)


func _mat(c: Color, rough: float = 1.0) -> StandardMaterial3D:
	var key := "%s_%s" % [c.to_html(), rough]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	_mats[key] = m
	return m


func _add_mesh(parent: Node, mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _add_body(parent: Node, shape: Shape3D, pos: Vector3, layer: int, kind: String = "") -> StaticBody3D:
	var body: StaticBody3D
	if kind != "":
		body = InteractScript.new()
		body.kind = kind
	else:
		body = StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	body.position = pos
	parent.add_child(body)
	return body


# ---------------------------------------------------------------- dunia

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.8, 0.9)
	env.ambient_light_energy = 0.7
	env.fog_enabled = true
	env.fog_density = 0.05
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = false
	add_child(sun)


func _build_island() -> void:
	var grass := CylinderMesh.new()
	grass.top_radius = 40.0
	grass.bottom_radius = 40.0
	grass.height = 2.0
	grass.radial_segments = 28
	_add_mesh(self, grass, _ground_material(), Vector3(0, -1.0, 0))
	var cyl := CylinderShape3D.new()
	cyl.radius = 40.0
	cyl.height = 2.0
	_add_body(self, cyl, Vector3(0, -1.0, 0), 1)

	var sand := CylinderMesh.new()
	sand.top_radius = 45.0
	sand.bottom_radius = 45.0
	sand.height = 2.0
	sand.radial_segments = 28
	_add_mesh(self, sand, _mat(Color(0.86, 0.79, 0.56)), Vector3(0, -1.3, 0))
	var cyl2 := CylinderShape3D.new()
	cyl2.radius = 45.0
	cyl2.height = 2.0
	_add_body(self, cyl2, Vector3(0, -1.3, 0), 1)

	var pm := PlaneMesh.new()
	pm.size = Vector2(500, 500)
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.16, 0.48, 0.66, 0.82)
	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wmat.roughness = 0.25
	water_mesh = _add_mesh(self, pm, wmat, Vector3(0, -0.6, 0))
	var wbox := BoxShape3D.new()
	wbox.size = Vector3(500, 1.0, 500)
	water_body = _add_body(self, wbox, Vector3(0, -1.1, 0), 2, "water")


func _build_farm() -> void:
	var idx := 0
	for r in 3:
		for c in 3:
			var p: StaticBody3D = PlotScript.new()
			p.position = Vector3((c - 1) * 2.2, 0.0, -4.0 - r * 2.2)
			add_child(p)
			p.setup()
			plots.append(p)
			idx += 1
	# pagar kayu kecil di sekeliling kebun
	var fence := _mat(Color(0.5, 0.35, 0.2))
	for i in range(-4, 5):
		_add_mesh(self, _box(Vector3(0.12, 0.7, 0.12)), fence, Vector3(i * 1.4, 0.35, -2.4))
	_add_mesh(self, _box(Vector3(11.2, 0.1, 0.1)), fence, Vector3(0, 0.55, -2.4))


func _build_hut(pos: Vector3, rot_y: float, roof: Color, title: String, kind: String, counter_label: String) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = rot_y
	add_child(root)
	var wood := _mat(Color(0.55, 0.38, 0.22))
	_add_mesh(root, _box(Vector3(5.0, 0.2, 3.6)), _mat(Color(0.45, 0.32, 0.2)), Vector3(0, 0.1, 0))
	for sx in [-2.3, 2.3]:
		for sz in [-1.6, 1.6]:
			_add_mesh(root, _box(Vector3(0.22, 2.6, 0.22)), wood, Vector3(sx, 1.4, sz))
	_add_mesh(root, _box(Vector3(5.0, 2.2, 0.15)), _mat(Color(0.62, 0.45, 0.28)), Vector3(0, 1.3, -1.75))
	var prism := PrismMesh.new()
	prism.size = Vector3(5.8, 1.3, 4.4)
	_add_mesh(root, prism, _mat(roof), Vector3(0, 3.3, 0))
	_add_mesh(root, _box(Vector3(3.2, 0.9, 0.7)), wood, Vector3(0, 0.55, 1.2))
	var lbl := Label3D.new()
	lbl.text = title
	lbl.font_size = 96
	lbl.pixel_size = 0.006
	lbl.position = Vector3(0, 2.75, 1.9)
	lbl.modulate = Color(1, 0.95, 0.75)
	lbl.outline_size = 16
	root.add_child(lbl)
	_add_body(root, _box_shape(Vector3(3.4, 1.4, 1.2)), Vector3(0, 0.7, 1.2), 1)
	_add_body(root, _box_shape(Vector3(3.8, 2.0, 2.2)), Vector3(0, 1.0, 1.6), 2, kind)
	var sub := Label3D.new()
	sub.text = counter_label
	sub.font_size = 48
	sub.pixel_size = 0.005
	sub.position = Vector3(0, 1.35, 1.58)
	root.add_child(sub)


func _box_shape(size: Vector3) -> BoxShape3D:
	var b := BoxShape3D.new()
	b.size = size
	return b


func _build_warung() -> void:
	_build_hut(Vector3(-11, 0, -2), deg_to_rad(65), Color(0.7, 0.28, 0.2), "WARUNG", "warung", "jual hasil")


func _build_kios() -> void:
	_build_hut(Vector3(11, 0, -2), deg_to_rad(-65), Color(0.25, 0.5, 0.35), "KIOS BENIH", "kios", "beli benih")


func _build_tent() -> void:
	var root := Node3D.new()
	root.position = Vector3(8, 0, 9)
	root.rotation.y = deg_to_rad(-30)
	add_child(root)
	var prism := PrismMesh.new()
	prism.size = Vector3(3.2, 2.2, 3.0)
	_add_mesh(root, prism, _mat(Color(0.88, 0.78, 0.5)), Vector3(0, 1.1, 0))
	_add_mesh(root, _box(Vector3(1.0, 1.4, 0.05)), _mat(Color(0.2, 0.15, 0.12)), Vector3(0, 0.7, 1.52))
	var lbl := Label3D.new()
	lbl.text = "TENDA"
	lbl.font_size = 72
	lbl.pixel_size = 0.005
	lbl.position = Vector3(0, 2.5, 1.0)
	root.add_child(lbl)
	_add_body(root, _box_shape(Vector3(3.2, 2.2, 3.0)), Vector3(0, 1.1, 0), 3, "bed")


func _build_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261116
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.18
	trunk_mesh.bottom_radius = 0.3
	trunk_mesh.height = 3.0
	trunk_mesh.radial_segments = 6
	var leaf_mesh := SphereMesh.new()
	leaf_mesh.radius = 1.7
	leaf_mesh.height = 2.6
	leaf_mesh.radial_segments = 7
	leaf_mesh.rings = 4
	var trunk_mat := _mat(Color(0.45, 0.3, 0.18))
	var leaf_mats := [_mat(Color(0.2, 0.5, 0.22)), _mat(Color(0.25, 0.58, 0.25)), _mat(Color(0.17, 0.44, 0.24))]
	var keep_clear := [Vector2(0, -7), Vector2(-11, -2), Vector2(11, -2), Vector2(8, 9), Vector2(0, 5)]
	var placed := 0
	var tries := 0
	while placed < 46 and tries < 400:
		tries += 1
		var ang := rng.randf() * TAU
		var rad := rng.randf_range(14.0, 37.0)
		var pos := Vector2(cos(ang), sin(ang)) * rad
		var ok := true
		for k in keep_clear:
			if pos.distance_to(k) < 9.0:
				ok = false
		if not ok:
			continue
		var s := rng.randf_range(0.8, 1.3)
		var root := Node3D.new()
		root.position = Vector3(pos.x, 0, pos.y)
		root.scale = Vector3(s, s, s)
		add_child(root)
		_add_mesh(root, trunk_mesh, trunk_mat, Vector3(0, 1.5, 0))
		_add_mesh(root, leaf_mesh, leaf_mats[placed % 3], Vector3(0, 3.7, 0))
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.35
		cyl.height = 3.0
		_add_body(root, cyl, Vector3(0, 1.5, 0), 1)
		placed += 1


# ---------------------------------------------------------------- rumput

func _ground_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://scripts/ground.gdshader")
	m.set_shader_parameter("tex_fresh", load("res://assets/tex/grass_fresh.png"))
	m.set_shader_parameter("tex_dry", load("res://assets/tex/grass_dry.png"))
	m.set_shader_parameter("tex_dark", load("res://assets/tex/grass_dark.png"))
	m.set_shader_parameter("tex_path", load("res://assets/tex/soil_dry.png"))
	return m


func _cross_mesh(aspect: float, mat: Material) -> ArrayMesh:
	var hw := aspect * 0.5
	var verts := PackedVector3Array([
		Vector3(-hw, 0, 0), Vector3(hw, 0, 0), Vector3(hw, 1, 0), Vector3(-hw, 1, 0),
		Vector3(0, 0, -hw), Vector3(0, 0, hw), Vector3(0, 1, hw), Vector3(0, 1, -hw)])
	var quad_uv := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	var uvs := PackedVector2Array(quad_uv + quad_uv)
	var normals := PackedVector3Array()
	for i in 8:
		normals.append(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3, 4, 5, 6, 4, 6, 7])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, mat)
	return mesh


func _grass_ok(p: Vector2) -> bool:
	if absf(p.x) < 6.2 and p.y < -1.8 and p.y > -11.2:
		return false
	for h in [Vector2(-11, -2), Vector2(11, -2)]:
		if p.distance_to(h) < 5.2:
			return false
	if p.distance_to(Vector2(8, 9)) < 3.6:
		return false
	var segs := [
		[Vector2(0, 12), Vector2(0, -1.5)],
		[Vector2(-9, 0.6), Vector2(9, 0.6)],
		[Vector2(0, 6), Vector2(7, 8.5)],
	]
	for sg in segs:
		var c := Geometry2D.get_closest_point_to_segment(p, sg[0], sg[1])
		if p.distance_to(c) < 1.8:
			return false
	return true


func _scatter(tex_path: String, count: int, height: float, min_r: float, rng: RandomNumberGenerator) -> void:
	var tex: Texture2D = load(tex_path)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/grass.gdshader")
	mat.set_shader_parameter("tex", tex)
	var aspect := float(tex.get_width()) / float(tex.get_height())
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _cross_mesh(aspect, mat)
	var xf: Array = []
	var tries := 0
	while xf.size() < count and tries < count * 20:
		tries += 1
		var ang := rng.randf() * TAU
		var rad := sqrt(rng.randf()) * 42.0
		if rad < min_r:
			continue
		var p := Vector2(cos(ang), sin(ang)) * rad
		if not _grass_ok(p):
			continue
		var sc := height * rng.randf_range(0.7, 1.35)
		var b := Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(sc, sc, sc))
		xf.append(Transform3D(b, Vector3(p.x, -0.02, p.y)))
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _build_grass() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7731
	_scatter("res://assets/tex/clump_short.png", 1100, 0.4, 0.0, rng)
	_scatter("res://assets/tex/clump_tall.png", 380, 1.0, 16.0, rng)
	_scatter("res://assets/tex/clump_flower.png", 240, 0.75, 8.0, rng)


# ---------------------------------------------------------------- siklus

func _process(delta: float) -> void:
	_update_env(delta)
	_update_fishing(delta)
	hud.hand.walk = player.speed_ratio
	hud.set_prompt(_hint())
	_autosave += delta
	if _autosave > 45.0:
		_autosave = 0.0
		save()


func _update_env(_delta: float) -> void:
	var clock := Game.clock
	var day_f := clampf(sin((clock - 5.0) / 14.0 * PI) * 2.0, 0.0, 1.0)
	var dusk := clampf(1.0 - absf(day_f - 0.35) * 3.0, 0.0, 1.0) * (1.0 - day_f * 0.5)
	var top := Color(0.03, 0.04, 0.1).lerp(Color(0.3, 0.52, 0.85), day_f)
	var hor := Color(0.05, 0.06, 0.13).lerp(Color(0.72, 0.82, 0.88), day_f)
	hor = hor.lerp(Color(0.95, 0.55, 0.3), dusk * 0.6)
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = hor
	sky_mat.ground_horizon_color = hor
	sky_mat.ground_bottom_color = top.darkened(0.3)
	sun.rotation_degrees = Vector3(-(clock - 5.0) / 14.0 * 180.0, -40.0, 0.0)
	sun.light_energy = 1.1 * day_f
	sun.light_color = Color(1, 0.96, 0.85).lerp(Color(1, 0.6, 0.35), dusk)
	env.ambient_light_color = Color(0.25, 0.3, 0.5).lerp(Color(0.8, 0.85, 0.95), day_f)
	env.ambient_light_energy = lerpf(0.35, 0.8, day_f)
	var mist := Color(0.8, 0.86, 0.9).lerp(hor, 0.5)
	env.fog_light_color = mist.lerp(Color(0.05, 0.06, 0.12), 1.0 - day_f)
	env.fog_density = 0.005 + 0.03 * Game.fog
	var wl: float = lerpf(-0.9, -0.12, Game.tide())
	water_mesh.position.y = wl
	water_body.position.y = wl - 0.5


func _on_day_changed() -> void:
	for p in plots:
		p.grow_day()
	save()
	Game.toast.emit("Hari %d dimulai" % Game.day)


func save() -> void:
	var data: Array = []
	for p in plots:
		data.append(p.to_dict())
	Game.save_game(data)


# ---------------------------------------------------------------- aksi

func _hint() -> String:
	if fish_state == 1:
		return "Menunggu ikan..."
	if fish_state == 2:
		return "IKAN MENGGIGIT! Tekan AKSI!"
	var t: Node = player.target
	if t == null:
		return ""
	var tool := Game.tool_index
	match str(t.get("kind")):
		"plot":
			return t.hint(tool)
		"water":
			return "Pancing di sini" if tool == 3 else "Air (pakai Pancing)"
		"warung":
			var v := Game.produce_value()
			return "Jual semua hasil (+%d koin)" % v if v > 0 else "Warung (belum ada hasil)"
		"kios":
			var sid := Game.selected_seed
			return "Beli 3 benih %s (%d koin)" % [Game.CROPS[sid]["name"], int(Game.CROPS[sid]["seed"]) * 3]
		"bed":
			return "Tidur sampai pagi"
	return ""


func _on_tool_selected(_i: int) -> void:
	fish_state = 0


func do_action() -> void:
	if fish_state == 2:
		_catch_fish()
		return
	if fish_state == 1:
		fish_state = 0
		hud.hand.play("reel")
		Game.toast.emit("Terlalu cepat, ikan kabur")
		return
	var t: Node = player.target
	if t == null:
		Game.toast.emit("Arahkan ke sesuatu")
		return
	match str(t.get("kind")):
		"plot":
			var res: Dictionary = t.interact(Game.tool_index)
			Game.toast.emit(str(res["msg"]))
			if bool(res["ok"]):
				hud.hand.play(str(res["anim"]))
		"water":
			if Game.tool_index == 3:
				fish_state = 1
				fish_timer = randf_range(2.0, 5.0)
				hud.hand.play("cast")
			else:
				Game.toast.emit("Pilih alat Pancing")
		"warung":
			var s := Game.sell_all()
			Game.toast.emit("Terjual: +%d koin" % s if s > 0 else "Belum ada hasil untuk dijual")
			hud.hand.play("reach")
		"kios":
			var sid := Game.selected_seed
			if Game.buy_seeds(sid, 3):
				Game.toast.emit("Beli 3 benih %s" % Game.CROPS[sid]["name"])
				hud.hand.play("reach")
			else:
				Game.toast.emit("Koin tidak cukup")
		"bed":
			Game.new_day()
			hud.hand.play("reach")


func _update_fishing(delta: float) -> void:
	if fish_state == 0:
		return
	fish_timer -= delta
	if fish_timer > 0.0:
		return
	if fish_state == 1:
		fish_state = 2
		fish_timer = 1.4
		hud.hand.play("bite")
	else:
		fish_state = 0
		Game.toast.emit("Ikannya kabur")


func _catch_fish() -> void:
	fish_state = 0
	var tide := Game.tide()
	var w_teri := 60.0
	var w_gabus := 30.0
	var w_kakap := 4.0 + tide * 22.0
	var roll := randf() * (w_teri + w_gabus + w_kakap)
	var id := "teri"
	if roll > w_teri + w_gabus:
		id = "kakap"
	elif roll > w_teri:
		id = "gabus"
	Game.add_produce(id, 1)
	hud.hand.play("reel")
	Game.toast.emit("Dapat %s!" % Game.item_name(id))


# ---------------------------------------------------------------- uji mandiri

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)


func _aim_at(node: Node3D, dist: float = 2.4, yaw_deg: float = 0.0) -> void:
	var rad := deg_to_rad(yaw_deg)
	player.global_position = node.global_position + Vector3(sin(rad), 0.0, cos(rad)) * dist + Vector3(0, 0.1, 0)
	player.yaw = rad
	player.pitch = -atan2(1.5, dist)
	player.rotation.y = rad
	player.cam.rotation.x = player.pitch


func _run_selftest() -> void:
	var out_dir := "/tmp/shots"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			out_dir = a.substr(8)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var fails := 0
	var check := func(name: String, ok: bool) -> void:
		print("[%s] %s" % ["OK " if ok else "GAGAL", name])
	Game.paused = true
	Game.clock = 11.0
	for i in 6:
		await get_tree().physics_frame
	await _shot(out_dir + "/01_awal.png")

	_aim_at(plots[0])
	await get_tree().physics_frame
	await get_tree().physics_frame
	var tgt_ok: bool = player.target == plots[0]
	check.call("raycast mengenai petak 0", tgt_ok)
	if not tgt_ok:
		fails += 1
	hud.set_tool(0)
	do_action()
	await get_tree().create_timer(0.35).timeout
	await _shot(out_dir + "/02_cangkul.png")
	var s1: bool = plots[0].state == 1
	check.call("cangkul -> digemburkan", s1)
	if not s1: fails += 1
	hud.set_tool(2)
	do_action()
	await get_tree().create_timer(0.4).timeout
	await _shot(out_dir + "/02b_tanam.png")
	var s2: bool = plots[0].state == 2 and int(Game.seeds["padi"]) == 2
	check.call("tanam padi (benih 3 -> 2)", s2)
	if not s2: fails += 1
	hud.set_tool(1)
	do_action()
	await get_tree().create_timer(0.3).timeout
	await _shot(out_dir + "/03_siram.png")
	var s3: bool = plots[0].watered
	check.call("siram", s3)
	if not s3: fails += 1
	for d in 4:
		for p in plots:
			p.grow_day()
		if d < 3:
			plots[0].watered = true
	var s4: bool = plots[0].is_ready()
	check.call("tumbuh 4 hari -> siap panen", s4)
	if not s4: fails += 1
	plots[0].refresh()
	await get_tree().physics_frame
	await _shot(out_dir + "/04_siap_panen.png")
	hud.set_tool(0)
	do_action()
	await get_tree().create_timer(0.3).timeout
	var s5: bool = int(Game.produce.get("padi", 0)) == 1 and Game.fog < 1.0
	check.call("panen -> padi 1, kabut menipis (%.2f)" % Game.fog, s5)
	if not s5: fails += 1

	player.global_position = Vector3(-7.7, 0.3, -0.5)
	player.yaw = deg_to_rad(65)
	player.rotation.y = player.yaw
	player.pitch = -0.2
	player.cam.rotation.x = player.pitch
	await get_tree().physics_frame
	await get_tree().physics_frame
	var wk := player.target != null and str(player.target.get("kind")) == "warung"
	check.call("raycast mengenai warung", wk)
	if not wk: fails += 1
	var coins_before := Game.coins
	do_action()
	await get_tree().create_timer(0.3).timeout
	var s6: bool = Game.coins == coins_before + 14
	check.call("jual padi -> +14 koin", s6)
	if not s6: fails += 1
	await _shot(out_dir + "/05_warung.png")

	player.global_position = Vector3(0, 0.3, 43.5)
	player.yaw = deg_to_rad(180)
	player.rotation.y = player.yaw
	player.pitch = -0.5
	player.cam.rotation.x = -0.5
	await get_tree().physics_frame
	await get_tree().physics_frame
	var wt := player.target != null and str(player.target.get("kind")) == "water"
	check.call("target air di tepi pantai", wt)
	if not wt: fails += 1
	hud.set_tool(3)
	do_action()
	var ok_wait: bool = fish_state == 1
	check.call("memancing -> menunggu", ok_wait)
	if not ok_wait: fails += 1
	fish_timer = 0.01
	await get_tree().create_timer(0.3).timeout
	var ok_bite: bool = fish_state == 2
	check.call("ikan menggigit", ok_bite)
	if not ok_bite: fails += 1
	do_action()
	await get_tree().create_timer(0.3).timeout
	var got := 0
	for id in Game.FISH:
		got += int(Game.produce.get(id, 0))
	check.call("dapat ikan (%d)" % got, got == 1)
	if got != 1: fails += 1
	await _shot(out_dir + "/06_pancing.png")

	Game.clock = 20.5
	await get_tree().physics_frame
	await _shot(out_dir + "/07_malam.png")
	Game.clock = 11.0
	var day0 := Game.day
	Game.new_day()
	await get_tree().physics_frame
	check.call("ganti hari", Game.day == day0 + 1)
	save()
	var reloaded := Game.load_game()
	check.call("simpan & muat (%d petak)" % reloaded.size(), reloaded.size() == plots.size())
	if reloaded.size() != plots.size(): fails += 1
	print("SELFTEST SELESAI, gagal=%d" % fails)
	get_tree().quit(fails)
