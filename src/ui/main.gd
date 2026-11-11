extends Control
## Main screen of Dragon Legends: island grid, tile panel, hatchery, breeding cave, collection.

const GameData := preload("res://src/core/game_data.gd")
const GameState := preload("res://src/core/game_state.gd")
const DragonArt := preload("res://src/ui/dragon_art.gd")
const TileView := preload("res://src/ui/tile_view.gd")
const SAVE_PATH := "user://save.json"

var data: RefCounted
var state: RefCounted
var selected: int = -1

var _breed_a := ""
var _breed_b := ""
var _dirty := true
var _signature := ""
var _live: Array[Callable] = []
var _shot_path := ""
var _frames := 0
var _toast_until := 0.0
var _gold: Label
var _food: Label
var _toast: Label
var _side: VBoxContainer
var _hatch: VBoxContainer
var _breed: VBoxContainer
var _book: VBoxContainer


func _ready() -> void:
	data = GameData.load_from("res://data")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	state = GameState.new(data, rng, now())
	var args := OS.get_cmdline_user_args()
	var i := args.find("--shot")
	if i >= 0 and i + 1 < args.size():
		_shot_path = args[i + 1]
		_demo()
	else:
		_load()
	_build_ui()


## Current time in seconds; the single clock the UI passes to the game state.
func now() -> float:
	return Time.get_unix_time_from_system()


## Selects an island tile and shows its actions in the side panel.
func select_tile(index: int) -> void:
	selected = index
	_dirty = true


func _process(_delta: float) -> void:
	var t := now()
	state.tick(t)
	_gold.text = "Emas: %d" % int(state.gold)
	_food.text = "Makanan: %d" % state.food
	if t > _toast_until:
		_toast.text = ""
	var sig := str(state.is_ready(state.hatchery, t)) + str(state.is_ready(state.breeding, t))
	for tile in state.tiles:
		if tile != null:
			sig += str(state.is_ready(tile, t))
	if sig != _signature:
		_signature = sig
		_dirty = true
	if _dirty:
		_dirty = false
		_rebuild()
	for cb in _live:
		cb.call()
	_frames += 1
	if _shot_path != "" and _frames == 20:
		get_viewport().get_texture().get_image().save_png(_shot_path)
		get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#7ec8f2"))
	draw_rect(Rect2(0, size.y * 0.55, size.x, size.y * 0.45), Color("#3f9bd6"))
	for c: Array in [[0.12, 0.16, 46], [0.17, 0.14, 60], [0.55, 0.1, 50], [0.6, 0.12, 38]]:
		draw_circle(Vector2(size.x * c[0], size.y * c[1]), c[2], Color(1, 1, 1, 0.8))


# --- UI construction -------------------------------------------------------

func _build_ui() -> void:
	resized.connect(queue_redraw)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 24)
	root.add_child(top)
	_label(top, "DRAGON LEGENDS", 30)
	_toast = _label(top, "", 18)
	_toast.size_flags_horizontal = SIZE_EXPAND_FILL
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold = _label(top, "", 22)
	_food = _label(top, "", 22)

	var mid := HBoxContainer.new()
	mid.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(mid)
	var center := CenterContainer.new()
	center.size_flags_horizontal = SIZE_EXPAND_FILL
	mid.add_child(center)
	var grid := GridContainer.new()
	grid.columns = int(data.balance["grid"]["cols"])
	center.add_child(grid)
	for i in state.tiles.size():
		var tv := TileView.new()
		tv.setup(self, i)
		grid.add_child(tv)
	_side = _panel(mid, 300)

	var bottom := HBoxContainer.new()
	bottom.custom_minimum_size.y = 190
	root.add_child(bottom)
	_hatch = _panel(bottom, 330)
	_breed = _panel(bottom, 330)
	_book = _panel(bottom, 0)


func _panel(parent: Control, width: float) -> VBoxContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.12, 0.2, 0.82)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", sb)
	if width > 0:
		p.custom_minimum_size.x = width
	else:
		p.size_flags_horizontal = SIZE_EXPAND_FILL
	parent.add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	return v


func _label(parent: Control, text: String, font_size: int = 16) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	parent.add_child(l)
	return l


func _button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func() -> void: _act(action.call()))
	parent.add_child(b)
	return b


## Shows the result of a game action and refreshes the panels.
func _act(err: String) -> void:
	if err != "":
		_toast.text = err
		_toast_until = now() + 2.5
	_dirty = true
	_save()


func _rebuild() -> void:
	_live.clear()
	for p: VBoxContainer in [_side, _hatch, _breed, _book]:
		for c in p.get_children():
			p.remove_child(c)
			c.queue_free()
	_build_side()
	_build_hatchery()
	_build_breeding()
	_build_book()


func _countdown(parent: Control, prefix: String, slot: Dictionary) -> void:
	var l := _label(parent, "")
	_live.append(func() -> void:
		l.text = "%s %d dtk" % [prefix, ceili(maxf(0.0, float(slot["ready_at"]) - now()))])


func _build_side() -> void:
	if selected < 0:
		_label(_side, "Pilih petak di pulau.")
		return
	var t = state.tiles[selected]
	if t == null:
		_label(_side, "Petak kosong", 20)
		for el: String in data.elements:
			_button(_side, "Habitat %s — %d emas" % [data.elements[el]["name"], int(data.balance["habitat"]["cost"])],
					func() -> String: return state.build_habitat(selected, el))
		_button(_side, "Ladang — %d emas" % int(data.balance["farm"]["cost"]),
				func() -> String: return state.build_farm(selected))
	elif t["type"] == "habitat":
		_label(_side, "Habitat %s" % data.elements[t["element"]]["name"], 20)
		var stored := _label(_side, "")
		_live.append(func() -> void:
			stored.text = "Emas tersimpan: %d / %d" % [int(t["stored"]), int(data.balance["habitat"]["gold_cap"])])
		_button(_side, "Panen emas", func() -> String: return state.collect_gold(selected))
		var uids: Array = state.dragons_in(selected)
		if uids.is_empty():
			_label(_side, "Belum ada naga.\nTetaskan telur berelemen cocok.")
		for uid: String in uids:
			var level: int = int(state.dragons[uid]["level"])
			_label(_side, "%s  Lv %d  (+%d emas/mnt)" % [state.def_of(uid)["name"], level, int(state.gold_rate(uid) * 60.0)])
			if level >= int(data.balance["feed"]["max_level"]):
				_label(_side, "Level maksimal")
			else:
				_button(_side, "Beri makan (%d makanan)" % state.feed_cost(level),
						func() -> String: return state.feed(uid))
	else:
		_label(_side, "Ladang", 20)
		var f: Dictionary = data.balance["farm"]
		if float(t["ready_at"]) <= 0.0:
			_button(_side, "Tanam: %d emas → %d makanan" % [int(f["crop_cost"]), int(f["crop_food"])],
					func() -> String: return state.plant(selected, now()))
		elif state.is_ready(t, now()):
			_button(_side, "Panen makanan", func() -> String: return state.harvest(selected, now()))
		else:
			_countdown(_side, "Tumbuh:", t)


func _build_hatchery() -> void:
	_label(_hatch, "Penetasan", 20)
	var egg: Dictionary = state.hatchery
	if egg.is_empty():
		var g := GridContainer.new()
		g.columns = 2
		_hatch.add_child(g)
		for id: String in data.dragons:
			var def: Dictionary = data.dragons[id]
			if float(def["egg_cost"]) > 0.0:
				_button(g, "Telur %s — %d" % [def["name"], int(def["egg_cost"])],
						func() -> String: return state.buy_egg(id, now()))
		return
	var dname: String = data.dragons[egg["id"]]["name"]
	if state.is_ready(egg, now()):
		_button(_hatch, "Tetaskan %s" % dname, func() -> String: return state.hatch(now()))
	else:
		_countdown(_hatch, "Telur %s menetas:" % dname, egg)


func _build_breeding() -> void:
	_label(_breed, "Gua Kawin", 20)
	var slot: Dictionary = state.breeding
	if not slot.is_empty():
		if state.is_ready(slot, now()):
			_button(_breed, "Ambil telur → penetasan", func() -> String: return state.collect_breeding(now()))
		else:
			_countdown(_breed, "Telur misteri:", slot)
		return
	var uids: Array = []
	for uid: String in state.dragons:
		if state.can_breed(uid):
			uids.append(uid)
	if uids.size() < 2:
		_label(_breed, "Butuh 2 naga Lv %d+.\nBeri makan nagamu!" % int(data.balance["breeding"]["min_level"]))
		return
	if not uids.has(_breed_a):
		_breed_a = uids[0]
	if not uids.has(_breed_b) or _breed_b == _breed_a:
		_breed_b = uids[1] if uids[0] == _breed_a else uids[0]
	for slot_a: bool in [true, false]:
		var ob := OptionButton.new()
		for uid: String in uids:
			ob.add_item("%s Lv %d" % [state.def_of(uid)["name"], int(state.dragons[uid]["level"])])
		ob.select(uids.find(_breed_a if slot_a else _breed_b))
		ob.item_selected.connect(func(i: int) -> void:
			if slot_a:
				_breed_a = uids[i]
			else:
				_breed_b = uids[i])
		_breed.add_child(ob)
	_button(_breed, "Kawinkan (%d dtk)" % int(data.balance["breeding"]["seconds"]),
			func() -> String: return state.breed(_breed_a, _breed_b, now()))


func _build_book() -> void:
	_label(_book, "Koleksi %d/%d" % [state.discovered.size(), data.dragons.size()], 20)
	var c := Control.new()
	c.size_flags_vertical = SIZE_EXPAND_FILL
	_book.add_child(c)
	var ids: Array = data.dragons.keys()
	c.draw.connect(func() -> void:
		var cols: int = ceili(ids.size() / 2.0)
		for i in ids.size():
			var pos := Vector2(c.size.x * (i % cols + 0.5) / cols, c.size.y * (0.3 if i < cols else 0.8))
			DragonArt.draw(c, pos, 20, data.dragons[ids[i]]["art"], not state.discovered.has(ids[i])))


# --- Persistence -----------------------------------------------------------

func _save() -> void:
	if _shot_path != "":
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(state.to_dict()))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if d is Dictionary:
		state.from_dict(d)


## Fills the island with a sample mid-game state for evidence screenshots (`-- --shot <png>`).
func _demo() -> void:
	var t := now()
	state.gold = 5000.0
	state.food = 500
	state.build_habitat(0, "bara")
	state.build_habitat(1, "arus")
	state.build_habitat(5, "petir")
	state.build_farm(2)
	state.plant(2, t)
	for id: String in ["baraka", "tirtana", "kilatra", "uapra"]:
		state.hatchery = {"id": id, "ready_at": t - 1.0}
		state.hatch(t)
	for uid: String in ["1", "2"]:
		for n in 4:
			state.feed(uid)
	state.last_tick = t - 120.0
	state.buy_egg("wanara", t)
	selected = 0
