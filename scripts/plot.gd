extends StaticBody3D
## Satu petak lahan: kosong -> digemburkan -> ditanam -> siap panen.

var kind: String = "plot"
var state: int = 0
var crop: String = ""
var age: int = 0
var watered: bool = false

var _soil_mat: StandardMaterial3D
var _plant_mat: StandardMaterial3D
var _plants: Node3D


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
	refresh()


func crop_data() -> Dictionary:
	return Game.CROPS.get(crop, {})


func is_ready() -> bool:
	return state == 2 and age >= int(crop_data().get("days", 99))


func refresh() -> void:
	var base := Color(0.3, 0.5, 0.25) if state == 0 else Color(0.4, 0.26, 0.16)
	if watered and state > 0:
		base = base.darkened(0.35)
	_soil_mat.albedo_color = base
	_plants.visible = state == 2
	if state == 2:
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
			return "Siram %s (pakai Ember)" % crop_data().get("name", "")


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
