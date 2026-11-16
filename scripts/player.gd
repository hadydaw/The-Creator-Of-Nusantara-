extends CharacterBody3D
## Pemain sudut pandang orang pertama.

const SPEED := 4.2
const GRAVITY := 20.0
const REACH := 4.5
const MAX_RADIUS := 43.5

var hud: Node = null
var cam: Camera3D
var yaw: float = 0.0
var pitch: float = 0.0
var target: Node = null
var water_ref: Node = null
var speed_ratio: float = 0.0
var _bob_t: float = 0.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	add_child(cs)
	cam = Camera3D.new()
	cam.position.y = 1.6
	cam.fov = 75.0
	cam.near = 0.05
	cam.far = 160.0
	add_child(cam)
	cam.current = true


func _physics_process(delta: float) -> void:
	var look := Vector2.ZERO
	var move := Vector2.ZERO
	if hud:
		look = hud.consume_look()
		move = hud.move
	look += Input.get_vector("lk_l", "lk_r", "lk_u", "lk_d") * 2.2 * delta
	move += Input.get_vector("mv_l", "mv_r", "mv_f", "mv_b")
	yaw -= look.x
	pitch = clampf(pitch - look.y, -1.35, 1.35)
	rotation.y = yaw
	cam.rotation.x = pitch

	var dir := transform.basis * Vector3(move.x, 0.0, move.y)
	dir = dir.limit_length(1.0)
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()

	var flat := Vector2(global_position.x, global_position.z)
	if flat.length() > MAX_RADIUS:
		flat = flat.normalized() * MAX_RADIUS
		global_position.x = flat.x
		global_position.z = flat.y

	speed_ratio = Vector2(velocity.x, velocity.z).length() / SPEED
	_bob_t += delta * 9.0 * speed_ratio
	cam.position.y = 1.6 + sin(_bob_t) * 0.035 * speed_ratio
	_update_target()


func _update_target() -> void:
	var space := get_world_3d().direct_space_state
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * REACH
	var q := PhysicsRayQueryParameters3D.create(from, to, 3)
	q.exclude = [get_rid()]
	var r := space.intersect_ray(q)
	target = null
	if r.is_empty():
		_shore_target()
		return
	var col: Object = r["collider"]
	if col != null and col.get("kind") != null and str(col.get("kind")) != "":
		target = col as Node
	if target == null:
		_shore_target()


## Di tepi pantai, melihat ke arah laut dan ke bawah dianggap mengarah ke air.
func _shore_target() -> void:
	if water_ref == null:
		return
	var flat := Vector2(global_position.x, global_position.z)
	if flat.length() < 41.0 or pitch > -0.2:
		return
	var fwd := -global_transform.basis.z
	var f2 := Vector2(fwd.x, fwd.z).normalized()
	if f2.dot(flat.normalized()) > 0.5:
		target = water_ref
