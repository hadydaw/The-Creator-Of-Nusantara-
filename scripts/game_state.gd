extends Node
## Data dan aturan inti game (autoload "Game").

signal changed
signal toast(text: String)
signal day_changed

const DAY_SECONDS := 300.0

const CROPS := {
	"padi": {"name": "Padi", "days": 4, "sell": 14, "seed": 4, "color": Color(0.88, 0.8, 0.3)},
	"jagung": {"name": "Jagung", "days": 3, "sell": 11, "seed": 3, "color": Color(0.96, 0.78, 0.15)},
	"cabai": {"name": "Cabai", "days": 2, "sell": 8, "seed": 2, "color": Color(0.85, 0.12, 0.1)},
	"singkong": {"name": "Singkong", "days": 5, "sell": 20, "seed": 6, "color": Color(0.62, 0.45, 0.3)},
	"pisang": {"name": "Pisang", "days": 6, "sell": 28, "seed": 8, "color": Color(0.9, 0.8, 0.2), "sprite": "pisang"},
	"kelapa": {"name": "Kelapa", "days": 8, "sell": 38, "seed": 11, "color": Color(0.6, 0.45, 0.2), "sprite": "kelapa"},
}
const FISH := {
	"teri": {"name": "Ikan Teri", "sell": 6},
	"gabus": {"name": "Ikan Gabus", "sell": 15},
	"kakap": {"name": "Ikan Kakap", "sell": 40},
}
const TOOLS := ["Cangkul", "Ember", "Benih", "Pancing"]

var coins: int = 30
var day: int = 1
var clock: float = 6.5
var fog: float = 1.0
var seeds: Dictionary = {"padi": 3, "jagung": 3, "cabai": 3, "singkong": 0, "pisang": 0, "kelapa": 0}
var produce: Dictionary = {}
var selected_seed: String = "padi"
var tool_index: int = 0
var harvested_total: int = 0
var paused: bool = false
var save_path: String = "user://save.json"


func _process(delta: float) -> void:
	if paused:
		return
	clock += delta * 24.0 / DAY_SECONDS
	if clock >= 24.0:
		new_day()


func total_hours() -> float:
	return float(day - 1) * 24.0 + clock


## Pasang surut 0..1 (0 = surut, 1 = pasang).
func tide() -> float:
	return 0.5 + 0.5 * sin(total_hours() / 12.4 * TAU)


func new_day() -> void:
	day += 1
	clock = 6.5
	day_changed.emit()
	changed.emit()


func item_name(id: String) -> String:
	if CROPS.has(id):
		return CROPS[id]["name"]
	if FISH.has(id):
		return FISH[id]["name"]
	return id


func item_price(id: String) -> int:
	if CROPS.has(id):
		return CROPS[id]["sell"]
	if FISH.has(id):
		return FISH[id]["sell"]
	return 0


func add_produce(id: String, n: int = 1) -> void:
	produce[id] = int(produce.get(id, 0)) + n
	changed.emit()


func produce_value() -> int:
	var total := 0
	for id in produce:
		total += item_price(id) * int(produce[id])
	return total


func sell_all() -> int:
	var total := produce_value()
	produce.clear()
	coins += total
	changed.emit()
	return total


func buy_seeds(id: String, amount: int) -> bool:
	var cost: int = int(CROPS[id]["seed"]) * amount
	if coins < cost:
		return false
	coins -= cost
	seeds[id] = int(seeds.get(id, 0)) + amount
	changed.emit()
	return true


## Setiap panen menipiskan kabut pulau.
func register_harvest() -> void:
	harvested_total += 1
	fog = maxf(0.15, 1.0 - float(harvested_total) * 0.03)
	changed.emit()


func cycle_seed() -> void:
	var ids: Array = CROPS.keys()
	var i: int = ids.find(selected_seed)
	selected_seed = ids[(i + 1) % ids.size()]
	changed.emit()


func save_game(plot_data: Array) -> void:
	var data := {
		"coins": coins, "day": day, "clock": clock, "fog": fog,
		"seeds": seeds, "produce": produce, "selected_seed": selected_seed,
		"harvested_total": harvested_total, "plots": plot_data,
	}
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


## Mengembalikan data petak, atau array kosong bila tidak ada simpanan.
func load_game() -> Array:
	if not FileAccess.file_exists(save_path):
		return []
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return []
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return []
	var d: Dictionary = parsed
	coins = int(d.get("coins", coins))
	day = int(d.get("day", day))
	clock = float(d.get("clock", clock))
	fog = float(d.get("fog", fog))
	seeds = d.get("seeds", seeds)
	produce = d.get("produce", produce)
	selected_seed = str(d.get("selected_seed", selected_seed))
	harvested_total = int(d.get("harvested_total", 0))
	var p: Variant = d.get("plots", [])
	return p if typeof(p) == TYPE_ARRAY else []
