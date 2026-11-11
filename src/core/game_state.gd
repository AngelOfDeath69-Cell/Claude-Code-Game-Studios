extends RefCounted
## Core rules of Dragon Legends: island tiles, dragons, hatchery, breeding.
## Pure logic — time (`now`, seconds) and RNG are injected so it is unit-testable.
## Action methods return "" on success or a player-facing error message.

var data: RefCounted
var rng: RandomNumberGenerator
var gold: float = 0.0
var food: int = 0
## One entry per island tile: null, a habitat {type, element, stored} or a farm {type, ready_at}.
var tiles: Array = []
## uid -> { id, level, tile }.
var dragons: Dictionary = {}
## Empty, or the egg in the hatchery { id, ready_at }.
var hatchery: Dictionary = {}
## Empty, or the egg being bred { id, ready_at }.
var breeding: Dictionary = {}
## Dragon ids hatched at least once.
var discovered: Array = []
var last_tick: float = 0.0
var next_uid: int = 1


func _init(p_data: RefCounted, p_rng: RandomNumberGenerator, now: float) -> void:
	data = p_data
	rng = p_rng
	gold = data.balance["start_gold"]
	food = int(data.balance["start_food"])
	tiles.resize(int(data.balance["grid"]["cols"]) * int(data.balance["grid"]["rows"]))
	last_tick = now


## Accrues habitat gold for the time elapsed since the last tick (also offline time).
func tick(now: float) -> void:
	var dt: float = maxf(0.0, now - last_tick)
	last_tick = now
	var cap: float = data.balance["habitat"]["gold_cap"]
	for i in tiles.size():
		var t = tiles[i]
		if t == null or t["type"] != "habitat":
			continue
		var rate := 0.0
		for uid: String in dragons_in(i):
			rate += gold_rate(uid)
		t["stored"] = minf(cap, float(t["stored"]) + rate * dt)


## Definition of the dragon with instance id [param uid].
func def_of(uid: String) -> Dictionary:
	return data.dragons[dragons[uid]["id"]]


## Uids of the dragons living on [param tile].
func dragons_in(tile: int) -> Array:
	var out: Array = []
	for uid: String in dragons:
		if int(dragons[uid]["tile"]) == tile:
			out.append(uid)
	return out


## Gold per second produced by a dragon at its current level.
func gold_rate(uid: String) -> float:
	var level: int = int(dragons[uid]["level"])
	var bonus: float = data.balance["level_gold_bonus"]
	return float(def_of(uid)["gold_per_min"]) / 60.0 * (1.0 + bonus * (level - 1))


## Food needed to raise a dragon from [param level] to the next one.
func feed_cost(level: int) -> int:
	var f: Dictionary = data.balance["feed"]
	return int(round(float(f["base_cost"]) * pow(float(f["growth"]), level - 1)))


## True when a timed slot (hatchery, breeding, farm) holds something that is done.
func is_ready(slot: Dictionary, now: float) -> bool:
	return float(slot.get("ready_at", 0.0)) > 0.0 and now >= float(slot["ready_at"])


func build_habitat(tile: int, element: String) -> String:
	if tiles[tile] != null:
		return "Petak sudah terisi"
	if not _spend(data.balance["habitat"]["cost"]):
		return "Emas tidak cukup"
	tiles[tile] = {"type": "habitat", "element": element, "stored": 0.0}
	return ""


func build_farm(tile: int) -> String:
	if tiles[tile] != null:
		return "Petak sudah terisi"
	if not _spend(data.balance["farm"]["cost"]):
		return "Emas tidak cukup"
	tiles[tile] = {"type": "farm", "ready_at": 0.0}
	return ""


## Moves a habitat's stored gold to the player.
func collect_gold(tile: int) -> String:
	var t = tiles[tile]
	if t == null or t["type"] != "habitat":
		return "Bukan habitat"
	gold += floorf(float(t["stored"]))
	t["stored"] = 0.0
	return ""


func plant(tile: int, now: float) -> String:
	var t = tiles[tile]
	if t == null or t["type"] != "farm":
		return "Bukan ladang"
	if float(t["ready_at"]) > 0.0:
		return "Ladang sedang dipakai"
	if not _spend(data.balance["farm"]["crop_cost"]):
		return "Emas tidak cukup"
	t["ready_at"] = now + float(data.balance["farm"]["crop_seconds"])
	return ""


func harvest(tile: int, now: float) -> String:
	var t = tiles[tile]
	if t == null or t["type"] != "farm" or not is_ready(t, now):
		return "Belum siap panen"
	food += int(data.balance["farm"]["crop_food"])
	t["ready_at"] = 0.0
	return ""


func feed(uid: String) -> String:
	var d: Dictionary = dragons[uid]
	var level: int = int(d["level"])
	if level >= int(data.balance["feed"]["max_level"]):
		return "Level maksimal"
	var cost := feed_cost(level)
	if food < cost:
		return "Makanan tidak cukup"
	food -= cost
	d["level"] = level + 1
	return ""


func buy_egg(id: String, now: float) -> String:
	if not hatchery.is_empty():
		return "Penetasan sedang dipakai"
	var def: Dictionary = data.dragons[id]
	if float(def["egg_cost"]) <= 0.0:
		return "Naga ini hanya dari kawin silang"
	if not _spend(def["egg_cost"]):
		return "Emas tidak cukup"
	hatchery = {"id": id, "ready_at": now + float(def["hatch_seconds"])}
	return ""


## First habitat with free space that shares an element with dragon [param id], or -1.
func find_habitat_for(id: String) -> int:
	var els: Array = data.dragons[id]["elements"]
	var capacity: int = int(data.balance["habitat"]["capacity"])
	for i in tiles.size():
		var t = tiles[i]
		if t != null and t["type"] == "habitat" and els.has(t["element"]) \
				and dragons_in(i).size() < capacity:
			return i
	return -1


## Hatches the ready egg into the first matching habitat.
func hatch(now: float) -> String:
	if hatchery.is_empty():
		return "Tidak ada telur"
	if not is_ready(hatchery, now):
		return "Telur belum siap"
	var id: String = hatchery["id"]
	var tile := find_habitat_for(id)
	if tile < 0:
		return "Butuh habitat berelemen cocok yang masih kosong"
	dragons[str(next_uid)] = {"id": id, "level": 1, "tile": tile}
	next_uid += 1
	if not discovered.has(id):
		discovered.append(id)
	hatchery = {}
	return ""


## Dragon ids two parents can produce: every dragon whose elements all come from the parents.
func breed_pool(a: String, b: String) -> Array:
	var els: Array = []
	for uid: String in [a, b]:
		for e: String in def_of(uid)["elements"]:
			if not els.has(e):
				els.append(e)
	var pool: Array = []
	for id: String in data.dragons:
		var ok := true
		for e: String in data.dragons[id]["elements"]:
			if not els.has(e):
				ok = false
		if ok:
			pool.append(id)
	pool.sort()
	return pool


func can_breed(uid: String) -> bool:
	return int(dragons[uid]["level"]) >= int(data.balance["breeding"]["min_level"])


func breed(a: String, b: String, now: float) -> String:
	if not breeding.is_empty():
		return "Gua kawin sedang dipakai"
	if a == b or not dragons.has(a) or not dragons.has(b):
		return "Pilih dua naga berbeda"
	if not can_breed(a) or not can_breed(b):
		return "Level naga belum cukup"
	var pool := breed_pool(a, b)
	var id: String = pool[rng.randi_range(0, pool.size() - 1)]
	breeding = {"id": id, "ready_at": now + float(data.balance["breeding"]["seconds"])}
	return ""


## Moves the finished bred egg into the hatchery.
func collect_breeding(now: float) -> String:
	if breeding.is_empty() or not is_ready(breeding, now):
		return "Telur belum siap"
	if not hatchery.is_empty():
		return "Penetasan sedang dipakai"
	var id: String = breeding["id"]
	hatchery = {"id": id, "ready_at": now + float(data.dragons[id]["hatch_seconds"])}
	breeding = {}
	return ""


## Serialises the whole state to a JSON-safe dictionary.
func to_dict() -> Dictionary:
	return {
		"gold": gold, "food": food, "tiles": tiles, "dragons": dragons,
		"hatchery": hatchery, "breeding": breeding, "discovered": discovered,
		"last_tick": last_tick, "next_uid": next_uid,
	}


## Restores a state written by [method to_dict] (JSON turns every number into a float).
func from_dict(d: Dictionary) -> void:
	gold = d["gold"]
	food = int(d["food"])
	tiles = d["tiles"]
	dragons = d["dragons"]
	hatchery = d["hatchery"]
	breeding = d["breeding"]
	discovered = d["discovered"]
	last_tick = d["last_tick"]
	next_uid = int(d["next_uid"])


func _spend(cost: float) -> bool:
	if gold < cost:
		return false
	gold -= cost
	return true
