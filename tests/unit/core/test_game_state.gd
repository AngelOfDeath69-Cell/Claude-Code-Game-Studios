extends SceneTree
## Unit tests for src/core/game_state.gd.
## Run: godot --headless -s res://tests/unit/core/test_game_state.gd

const GameData := preload("res://src/core/game_data.gd")
const GameState := preload("res://src/core/game_state.gd")

const T0 := 1000.0

var _failed := 0


func _init() -> void:
	for m: Dictionary in get_script().get_script_method_list():
		if str(m["name"]).begins_with("test_"):
			call(m["name"])
	print("FAILED: %d" % _failed if _failed > 0 else "ALL TESTS PASSED")
	quit(1 if _failed > 0 else 0)


func _check(cond: bool, what: String) -> void:
	if not cond:
		_failed += 1
		printerr("FAIL: " + what)


## In-memory fixture — no file I/O.
func _state() -> RefCounted:
	var d := GameData.new()
	d.balance = {
		"start_gold": 1000, "start_food": 100, "grid": {"cols": 2, "rows": 2},
		"habitat": {"cost": 100, "capacity": 2, "gold_cap": 50},
		"farm": {"cost": 100, "crop_cost": 10, "crop_food": 5, "crop_seconds": 20},
		"feed": {"base_cost": 4, "growth": 2.0, "max_level": 3},
		"level_gold_bonus": 0.5, "breeding": {"min_level": 2, "seconds": 30},
	}
	d.elements = {"a": {}, "b": {}}
	d.dragons = {
		"da": {"id": "da", "elements": ["a"], "egg_cost": 50, "hatch_seconds": 10, "gold_per_min": 60},
		"db": {"id": "db", "elements": ["b"], "egg_cost": 50, "hatch_seconds": 10, "gold_per_min": 60},
		"dab": {"id": "dab", "elements": ["a", "b"], "egg_cost": 0, "hatch_seconds": 10, "gold_per_min": 120},
	}
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	return GameState.new(d, rng, T0)


func _hatch(s: RefCounted, id: String) -> void:
	s.buy_egg(id, T0)
	s.tick(T0 + 10.0)
	s.hatch(T0 + 10.0)


func test_build_spends_gold_and_blocks_occupied_tile() -> void:
	var s := _state()
	_check(s.build_habitat(0, "a") == "", "build ok")
	_check(s.gold == 900.0, "gold spent")
	_check(s.build_farm(0) != "", "occupied tile rejected")
	s.gold = 0.0
	_check(s.build_farm(1) != "", "no gold rejected")


func test_egg_hatches_only_when_ready_and_habitat_matches() -> void:
	var s := _state()
	s.build_habitat(0, "b")
	_check(s.buy_egg("dab", T0) != "", "hybrid egg not for sale")
	_check(s.buy_egg("da", T0) == "", "buy egg")
	_check(s.hatch(T0 + 9.0) != "", "not ready yet")
	_check(s.hatch(T0 + 10.0) != "", "no matching habitat")
	s.build_habitat(1, "a")
	_check(s.hatch(T0 + 10.0) == "", "hatch")
	_check(s.dragons["1"]["tile"] == 1 and s.discovered == ["da"], "dragon placed and discovered")


func test_habitat_gold_accrues_and_caps() -> void:
	var s := _state()
	s.build_habitat(0, "a")
	_hatch(s, "da")
	s.tick(T0 + 30.0)
	_check(is_equal_approx(s.tiles[0]["stored"], 20.0), "1 gold/s for 20 s")
	s.tick(T0 + 9999.0)
	_check(s.tiles[0]["stored"] == 50.0, "capped")
	var before: float = s.gold
	s.collect_gold(0)
	_check(s.gold == before + 50.0 and s.tiles[0]["stored"] == 0.0, "collected")


func test_feed_levels_up_and_raises_rate() -> void:
	var s := _state()
	s.build_habitat(0, "a")
	_hatch(s, "da")
	_check(s.feed("1") == "" and s.food == 96, "level 1->2 costs 4")
	_check(s.feed("1") == "" and s.food == 88, "level 2->3 costs 8")
	_check(s.feed("1") != "", "max level")
	_check(is_equal_approx(s.gold_rate("1"), 2.0), "rate doubles at level 3")


func test_farm_cycle() -> void:
	var s := _state()
	s.build_farm(0)
	_check(s.plant(0, T0) == "", "plant")
	_check(s.harvest(0, T0 + 19.0) != "", "not ripe")
	_check(s.harvest(0, T0 + 20.0) == "" and s.food == 105, "harvest gives food")


func test_breeding_needs_level_and_yields_pool_member() -> void:
	var s := _state()
	s.build_habitat(0, "a")
	s.build_habitat(1, "b")
	_hatch(s, "da")
	_hatch(s, "db")
	_check(s.breed("1", "2", T0) != "", "level too low")
	s.feed("1")
	s.feed("2")
	_check(s.breed_pool("1", "2") == ["da", "dab", "db"], "pool = subsets of parents' elements")
	_check(s.breed("1", "1", T0) != "", "same dragon rejected")
	_check(s.breed("1", "2", T0) == "", "breed")
	_check(s.collect_breeding(T0 + 29.0) != "", "not ready")
	_check(s.collect_breeding(T0 + 30.0) == "", "egg to hatchery")
	_check(s.breed_pool("1", "2").has(s.hatchery["id"]) and s.breeding.is_empty(), "egg from pool")


func test_save_roundtrip_through_json() -> void:
	var s := _state()
	s.build_habitat(0, "a")
	_hatch(s, "da")
	s.tick(T0 + 15.0)
	var s2 := _state()
	s2.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	_check(s2.gold == s.gold and s2.dragons_in(0) == ["1"], "state restored")
	s2.tick(T0 + 25.0)
	_check(is_equal_approx(s2.tiles[0]["stored"], 15.0), "keeps accruing after load")
