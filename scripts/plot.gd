extends StaticBody3D
## Satu petak lahan: kosong -> digemburkan -> ditanam -> siap panen.

var kind: String = "plot"
var state: int = 0
var crop: String = ""
var age: int = 0
var watered: bool = false

const TEX_GRASS := preload("res://assets/tex/grass_fresh.png")
const TEX_TILLED := preload("res://assets/tex/soil_tilled.png")
const TEX_WET := preload("res://assets/tex/soil_wet.png")

var _soil_mat: StandardMaterial3D
var _plant_mat: StandardMaterial3D
var _plants: Node3D
var _sprite: Sprite3D
var _spr_tex := {}
var _soil: MeshInstance3D
var _pegs: Node3D


func setup() -> void:
	collision_layer = 2
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.9, 0.6, 1.9)
	cs.shape = box
	cs.position.y = 0.2
	add_child(cs)

	_soil_mat = StandardMaterial3D.new()
	_soil_mat.roughness = 1.0
	var soil := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.9, 0.14, 1.9)
	soil.mesh = bm
	soil.material_override = _soil_mat
	soil.position.y = 0.05
	add_child(soil)
	_soil = soil

	# Petak kosong: hanya patok sudut, tanpa kotak gelap di atas rumput.
	_pegs = Node3D.new()
	add_child(_pegs)
	var peg_mat := StandardMaterial3D.new()
	peg_mat.albedo_color = Color(0.45, 0.32, 0.2)
	peg_mat.roughness = 1.0
	for cx in [-0.9, 0.9]:
		for cz in [-0.9, 0.9]:
			var pg := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(0.1, 0.3, 0.1)
			pg.mesh = pm
			pg.material_override = peg_mat
			pg.position = Vector3(cx, 0.12, cz)
			_pegs.add_child(pg)

	_plant_mat = StandardMaterial3D.new()
	_plant_mat.roughness = 0.9
	_plants = Node3D.new()
	add_child(_plants)
	for off in [Vector2(-0.5, -0.45), Vector2(0.45, -0.1), Vector2(-0.1, 0.5), Vector2(0.55, 0.55), Vector2(-0.55, 0.3)]:
		var m := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.04
		cm.bottom_radius = 0.22
		cm.height = 1.0
		cm.radial_segments = 6
		m.mesh = cm
		m.material_override = _plant_mat
		m.position = Vector3(off.x, 0.1, off.y)
		_plants.add_child(m)

	_sprite = Sprite3D.new()
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_sprite.pixel_size = 0.0034
	_sprite.double_sided = true
	add_child(_sprite)
	refresh()


func _sprite_tex(name: String, stage: String) -> Texture2D:
	var key := name + "_" + stage
	if not _spr_tex.has(key):
		_spr_tex[key] = load("res://assets/spr/%s.png" % key)
	return _spr_tex[key]


func crop_data() -> Dictionary:
	return Game.CROPS.get(crop, {})


func is_ready() -> bool:
	return state == 2 and age >= int(crop_data().get("days", 99))


func refresh() -> void:
	var tex: Texture2D = TEX_GRASS
	if state > 0:
		tex = TEX_WET if watered else TEX_TILLED
	_soil_mat.albedo_texture = tex
	_soil_mat.albedo_color = Color(0.8, 0.85, 0.8) if state == 0 else Color.WHITE
	_soil.visible = state > 0
	_pegs.visible = state == 0
	var spr_name: String = str(crop_data().get("sprite", ""))
	var use_sprite: bool = state == 2 and spr_name != ""
	_sprite.visible = use_sprite
	_plants.visible = state == 2 and not use_sprite
	if use_sprite:
		var d: int = maxi(1, int(crop_data().get("days", 1)))
		var st: float = clampf(float(age) / float(d), 0.0, 1.0)
		var stage := "tunas" if st < 0.5 else ("dewasa" if st < 1.0 else "buah")
		var t := _sprite_tex(spr_name, stage)
		_sprite.texture = t
		_sprite.position = Vector3(0, 0.1 + t.get_height() * _sprite.pixel_size * 0.5, 0)
	if state == 2 and not use_sprite:
		var days: int = maxi(1, int(crop_data().get("days", 1)))
		var stage: float = clampf(float(age) / float(days), 0.0, 1.0)
		var h: float = lerpf(0.25, 1.0, stage)
		for m in _plants.get_children():
			var n: Node3D = m
			n.scale = Vector3(1.0, h, 1.0)
			n.position.y = 0.12 + h * 0.5
		var ripe: Color = crop_data().get("color", Color.WHITE)
		_plant_mat.albedo_color = Color(0.3, 0.65, 0.25).lerp(ripe, stage if stage >= 1.0 else stage * 0.4)


func grow_day() -> void:
	if state == 2 and watered and not is_ready():
		age += 1
	watered = false
	refresh()


func hint(tool: int) -> String:
	if is_ready():
		return "Panen %s" % crop_data().get("name", "")
	match state:
		0:
			return "Cangkul tanah" if tool == 0 else "Tanah kosong (pakai Cangkul)"
		1:
			if tool == 2:
				return "Tanam %s" % Game.CROPS[Game.selected_seed]["name"]
			return "Tanah siap tanam (pakai Benih)"
		_:
			if watered:
				return "%s (sudah disiram, tumbuh %d/%d)" % [crop_data().get("name", ""), age, int(crop_data().get("days", 0))]
			return "Siram %s (pakai Gembor)" % crop_data().get("name", "")


## Mengembalikan {"ok": bool, "msg": String}.
func interact(tool: int) -> Dictionary:
	if is_ready():
		var id := crop
		Game.add_produce(id, 1)
		Game.register_harvest()
		var nm: String = crop_data().get("name", "")
		state = 1
		crop = ""
		age = 0
		watered = false
		refresh()
		return {"ok": true, "msg": "Panen %s!" % nm, "anim": "reach"}
	match tool:
		0:
			if state == 0:
				state = 1
				refresh()
				return {"ok": true, "msg": "Tanah digemburkan", "anim": "swing"}
			if state == 1:
				return {"ok": false, "msg": "Sudah digemburkan", "anim": ""}
			return {"ok": false, "msg": "Ada tanaman di sini", "anim": ""}
		1:
			if state == 0:
				return {"ok": false, "msg": "Cangkul dulu tanahnya", "anim": ""}
			if watered:
				return {"ok": false, "msg": "Sudah disiram hari ini", "anim": ""}
			watered = true
			refresh()
			return {"ok": true, "msg": "Disiram", "anim": "water"}
		2:
			if state != 1:
				return {"ok": false, "msg": "Tanam di tanah yang sudah digemburkan", "anim": ""}
			var sid := Game.selected_seed
			if int(Game.seeds.get(sid, 0)) <= 0:
				return {"ok": false, "msg": "Benih %s habis, beli di Kios" % Game.CROPS[sid]["name"], "anim": ""}
			Game.seeds[sid] = int(Game.seeds[sid]) - 1
			state = 2
			crop = sid
			age = 0
			refresh()
			Game.changed.emit()
			return {"ok": true, "msg": "Menanam %s" % Game.CROPS[sid]["name"], "anim": "plant"}
	return {"ok": false, "msg": "Alat ini tidak cocok", "anim": ""}


func to_dict() -> Dictionary:
	return {"state": state, "crop": crop, "age": age, "watered": watered}


func from_dict(d: Dictionary) -> void:
	state = int(d.get("state", 0))
	crop = str(d.get("crop", ""))
	age = int(d.get("age", 0))
	watered = bool(d.get("watered", false))
	refresh()
