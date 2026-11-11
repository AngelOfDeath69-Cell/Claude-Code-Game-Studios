extends Control
## One island tile: empty plot, habitat with its dragons, or farm.

const DragonArt := preload("res://src/ui/dragon_art.gd")

var main: Control
var index: int = 0


## Binds the tile to the main screen and its tile [param i].
func setup(m: Control, i: int) -> void:
	main = m
	index = i
	custom_minimum_size = Vector2(190, 132)


func _process(_delta: float) -> void:
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		main.select_tile(index)


func _draw() -> void:
	var st: RefCounted = main.state
	var t = st.tiles[index]
	var font := get_theme_default_font()
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(14)
	sb.bg_color = Color("#6fbf4a")
	if index == main.selected:
		sb.set_border_width_all(4)
		sb.border_color = Color.WHITE
	var r := Rect2(Vector2(4, 4), size - Vector2(8, 8))
	if t == null:
		sb.draw(get_canvas_item(), r)
		draw_string(font, Vector2(0, size.y / 2 + 12), "+", HORIZONTAL_ALIGNMENT_CENTER, size.x, 36, Color(1, 1, 1, 0.6))
	elif t["type"] == "habitat":
		var el: Dictionary = st.data.elements[t["element"]]
		sb.bg_color = Color(str(el["color"])).lerp(Color("#6fbf4a"), 0.45)
		sb.draw(get_canvas_item(), r)
		var uids: Array = st.dragons_in(index)
		for i in uids.size():
			var x: float = size.x * (i + 1) / (uids.size() + 1)
			DragonArt.draw(self, Vector2(x, size.y * 0.52), 30, st.def_of(uids[i])["art"])
			draw_string(font, Vector2(x - 40, size.y * 0.52 + 40), "Lv %d" % int(st.dragons[uids[i]]["level"]),
					HORIZONTAL_ALIGNMENT_CENTER, 80, 13, Color.WHITE)
		draw_string(font, Vector2(14, 26), str(el["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
		draw_string(font, Vector2(0, 26), "%d emas" % int(t["stored"]), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 14, 15, Color("#fff3a0"))
	else:
		sb.bg_color = Color("#8a5a2b")
		sb.draw(get_canvas_item(), r)
		var growing: bool = float(t["ready_at"]) > 0.0
		for i in 4:
			var y: float = 44 + i * 18
			draw_line(Vector2(20, y), Vector2(size.x - 20, y), Color("#5c3a17"), 6)
			if growing:
				draw_line(Vector2(20, y - 5), Vector2(size.x - 20, y - 5), Color("#9be05a"), 3)
		var label := "Ladang"
		if st.is_ready(t, main.now()):
			label = "Ladang — siap panen!"
		draw_string(font, Vector2(14, 26), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
