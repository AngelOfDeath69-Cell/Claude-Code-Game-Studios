extends RefCounted
## Procedural dragon drawing — every dragon is built from its `art` data, no image assets.


## Draws a dragon facing right, centred on [param c]; [param s] is half its width in pixels.
## [param silhouette] draws it as an undiscovered shadow.
static func draw(ci: CanvasItem, c: Vector2, s: float, art: Dictionary, silhouette: bool = false) -> void:
	var body := Color(str(art["body"]))
	var belly := Color(str(art["belly"]))
	var wing := Color(str(art["wing"]))
	var dark := body.darkened(0.35)
	var white := Color.WHITE
	var black := Color(0.1, 0.1, 0.1)
	if silhouette:
		body = Color(0, 0, 0, 0.35)
		belly = Color(0, 0, 0, 0)
		wing = Color(0, 0, 0, 0.25)
		dark = body
		white = Color(0, 0, 0, 0)
		black = white

	# Tail
	_poly(ci, c, s, [[-0.6, 0.0], [-1.5, -0.35], [-1.25, 0.0], [-1.45, 0.3], [-0.6, 0.45]], dark)
	# Wing
	var w: Array = [[-0.1, -0.2], [-0.9, -1.2], [-0.55, -0.6], [-1.0, -0.55], [-0.5, -0.1]]
	match str(art["wing_style"]):
		"fin":
			w = [[-0.5, -0.2], [-0.3, -1.05], [0.05, -0.75], [0.2, -1.0], [0.35, -0.25]]
		"leaf":
			w = [[0.0, -0.2], [-0.5, -0.7], [-0.75, -1.25], [-0.15, -1.0], [0.2, -0.5]]
	_poly(ci, c, s, w, wing)
	# Legs, body, belly
	_ellipse(ci, c + Vector2(-0.35, 0.6) * s, Vector2(0.18, 0.2) * s, dark)
	_ellipse(ci, c + Vector2(0.35, 0.6) * s, Vector2(0.18, 0.2) * s, dark)
	_ellipse(ci, c + Vector2(0.0, 0.1) * s, Vector2(0.75, 0.55) * s, body)
	_ellipse(ci, c + Vector2(0.1, 0.3) * s, Vector2(0.48, 0.3) * s, belly)
	# Back spikes
	if art["spikes"]:
		for i in 3:
			var x: float = -0.45 + 0.3 * i
			_poly(ci, c, s, [[x - 0.12, -0.38], [x, -0.72], [x + 0.12, -0.38]], dark)
	# Horns
	var horns: int = int(art["horns"])
	for i in horns:
		var hx: float = 0.55 + 0.2 * i
		_poly(ci, c, s, [[hx - 0.08, -0.75], [hx - 0.05, -1.15], [hx + 0.1, -0.75]], belly if not silhouette else body)
	# Head, snout, eye
	_ellipse(ci, c + Vector2(0.75, -0.45) * s, Vector2(0.38, 0.36) * s, body)
	_ellipse(ci, c + Vector2(1.05, -0.35) * s, Vector2(0.26, 0.2) * s, body)
	_ellipse(ci, c + Vector2(0.85, -0.55) * s, Vector2(0.11, 0.12) * s, white)
	_ellipse(ci, c + Vector2(0.88, -0.55) * s, Vector2(0.05, 0.07) * s, black)
	_ellipse(ci, c + Vector2(1.2, -0.4) * s, Vector2(0.03, 0.03) * s, black)


static func _poly(ci: CanvasItem, c: Vector2, s: float, pts: Array, color: Color) -> void:
	var out := PackedVector2Array()
	for p: Array in pts:
		out.append(c + Vector2(p[0], p[1]) * s)
	ci.draw_colored_polygon(out, color)


static func _ellipse(ci: CanvasItem, c: Vector2, r: Vector2, color: Color) -> void:
	var out := PackedVector2Array()
	for i in 24:
		var a: float = TAU * i / 24.0
		out.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	ci.draw_colored_polygon(out, color)
