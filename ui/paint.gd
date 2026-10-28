class_name GardenPaint
extends RefCounted

## Procedural art. No image assets are required anywhere in the project.


class Background:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _ready() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w <= 1.0 or h <= 1.0:
			return
		draw_rect(Rect2(Vector2.ZERO, size), GardenTheme.BG)
		# Soft oversized blobs.
		draw_circle(Vector2(w * 0.08, h * 0.06), w * 0.42, Color(0.80, 0.72, 0.96, 0.42))
		draw_circle(Vector2(w * 0.96, h * 0.20), w * 0.34, Color(1.0, 0.79, 0.86, 0.34))
		draw_circle(Vector2(w * 0.90, h * 0.74), w * 0.38, Color(1.0, 0.91, 0.61, 0.22))
		draw_circle(Vector2(w * 0.12, h * 0.92), w * 0.33, Color(0.75, 0.91, 0.82, 0.25))
		draw_circle(Vector2(w * 0.55, h * 0.48), w * 0.30, Color(1, 1, 1, 0.24))
		# Paper dots.
		for i in 34:
			var x := fposmod(float(i) * 137.51, 100.0) / 100.0 * w
			var y := fposmod(float(i) * 71.31 + 11.0, 100.0) / 100.0 * h
			var r := 1.2 + float(i % 3) * 0.6
			draw_circle(Vector2(x, y), r, Color(0.55, 0.45, 0.68, 0.10))
		# Corner flowers.
		flower(Vector2(w * 0.94, h * 0.09), w * 0.035, Color(1, 1, 1, 0.72), Color(1.0, 0.86, 0.35, 0.75))
		flower(Vector2(w * 0.06, h * 0.46), w * 0.024, Color(1, 1, 1, 0.55), Color(0.96, 0.68, 0.77, 0.7))
		flower(Vector2(w * 0.88, h * 0.88), w * 0.028, Color(1, 1, 1, 0.45), Color(0.96, 0.68, 0.77, 0.6))

	func flower(center: Vector2, radius: float, petal: Color, middle: Color) -> void:
		for i in 5:
			var a := TAU * float(i) / 5.0 - PI / 2.0
			draw_circle(center + Vector2(cos(a), sin(a)) * radius, radius * 0.62, petal)
		draw_circle(center, radius * 0.44, middle)


class FlowerMark:
	extends Control
	var petal_color := GardenTheme.LAVENDER
	var center_color := GardenTheme.YELLOW
	var leaf_color := GardenTheme.MINT_DEEP

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(34, 34)

	func _ready() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		var s := minf(size.x, size.y)
		if s <= 1.0:
			return
		var c := Vector2(size.x * 0.5, size.y * 0.46)
		draw_line(Vector2(size.x * 0.5, size.y * 0.55), Vector2(size.x * 0.5, size.y * 0.9), leaf_color, maxf(2.0, s * 0.055), true)
		_draw_leaf(Vector2(size.x * 0.5, size.y * 0.73), -1.0, s, leaf_color)
		_draw_leaf(Vector2(size.x * 0.5, size.y * 0.80), 1.0, s, leaf_color.lightened(0.12))
		var r := s * 0.155
		for i in 5:
			var a := TAU * float(i) / 5.0 - PI / 2.0
			draw_circle(c + Vector2(cos(a), sin(a)) * r * 1.02, r * 0.78, petal_color)
		draw_circle(c, r * 0.65, center_color)
		draw_circle(c + Vector2(-r * 0.2, -r * 0.15), r * 0.15, Color(1, 1, 1, 0.6))

	func _draw_leaf(at: Vector2, dir: float, s: float, col: Color) -> void:
		var points := PackedVector2Array([
			at,
			at + Vector2(s * 0.15 * dir, -s * 0.05),
			at + Vector2(s * 0.19 * dir, s * 0.04),
			at + Vector2(s * 0.02 * dir, s * 0.06)
		])
		draw_colored_polygon(points, col)


class Mascot:
	extends Control
	var blink := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(110, 110)
		blink = true

	func _ready() -> void:
		resized.connect(queue_redraw)
		if not GardenApi.reduced_motion():
			var timer := Timer.new()
			timer.wait_time = 4.2
			timer.autostart = true
			timer.timeout.connect(_blink)
			add_child(timer)

	func _blink() -> void:
		blink = true
		queue_redraw()

	func _draw() -> void:
		var s := minf(size.x, size.y)
		if s <= 2.0:
			return
		var c := Vector2(size.x * 0.5, size.y * 0.42)
		var ground := Vector2(size.x * 0.5, size.y * 0.91)
		# Shadow and pot.
		draw_circle(ground + Vector2(0, 2), s * 0.24, Color(0.35, 0.25, 0.5, 0.10))
		var pot := PackedVector2Array([
			Vector2(c.x - s * 0.17, size.y * 0.78),
			Vector2(c.x + s * 0.17, size.y * 0.78),
			Vector2(c.x + s * 0.13, size.y * 0.91),
			Vector2(c.x - s * 0.13, size.y * 0.91)
		])
		draw_colored_polygon(pot, GardenTheme.PINK)
		draw_rect(Rect2(c.x - s * 0.19, size.y * 0.755, s * 0.38, s * 0.055), GardenTheme.PINK_DEEP, true)
		# Stem and leaves.
		draw_line(Vector2(c.x, size.y * 0.76), Vector2(c.x, c.y + s * 0.08), GardenTheme.MINT_DEEP, maxf(3.0, s * 0.06), true)
		_draw_leaf(Vector2(c.x, size.y * 0.64), -1, s, GardenTheme.MINT)
		_draw_leaf(Vector2(c.x, size.y * 0.69), 1, s, GardenTheme.MINT)
		# Flower head.
		var petal := GardenTheme.LAVENDER
		for i in 6:
			var a := TAU * float(i) / 6.0 - PI / 2.0
			draw_circle(c + Vector2(cos(a), sin(a)) * s * 0.19, s * 0.135, petal)
		draw_circle(c, s * 0.17, GardenTheme.YELLOW)
		# Cute face.
		var eye_y := c.y - s * 0.025
		if blink:
			draw_line(Vector2(c.x - s * 0.075, eye_y), Vector2(c.x - s * 0.035, eye_y), GardenTheme.INK, maxf(2.0, s * 0.018), true)
			draw_line(Vector2(c.x + s * 0.035, eye_y), Vector2(c.x + s * 0.075, eye_y), GardenTheme.INK, maxf(2.0, s * 0.018), true)
		else:
			draw_circle(Vector2(c.x - s * 0.052, eye_y), s * 0.021, GardenTheme.INK)
			draw_circle(Vector2(c.x + s * 0.052, eye_y), s * 0.021, GardenTheme.INK)
		draw_arc(Vector2(c.x, c.y + s * 0.045), s * 0.045, 0.25, PI - 0.25, 14, GardenTheme.INK, maxf(2.0, s * 0.013), true)
		draw_circle(Vector2(c.x - s * 0.11, c.y + s * 0.045), s * 0.022, Color(1, 0.72, 0.78, 0.75))
		draw_circle(Vector2(c.x + s * 0.11, c.y + s * 0.045), s * 0.022, Color(1, 0.72, 0.78, 0.75))

	func _draw_leaf(at: Vector2, dir: float, s: float, col: Color) -> void:
		var points := PackedVector2Array([
			at,
			at + Vector2(s * 0.185 * dir, -s * 0.075),
			at + Vector2(s * 0.22 * dir, s * 0.015),
			at + Vector2(s * 0.02 * dir, s * 0.055)
		])
		draw_colored_polygon(points, col)


class CoinIcon:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(22, 22)

	func _ready() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		var s := minf(size.x, size.y)
		if s <= 1:
			return
		var c := size * 0.5
		draw_circle(c + Vector2(0, s * 0.05), s * 0.46, Color(0.72, 0.52, 0.12, 0.28))
		draw_circle(c, s * 0.45, GardenTheme.YELLOW_DEEP)
		draw_circle(c, s * 0.36, GardenTheme.YELLOW)
		# Sparkle.
		var r := s * 0.17
		var pts := PackedVector2Array([
			c + Vector2(0, -r), c + Vector2(r * 0.33, -r * 0.33), c + Vector2(r, 0),
			c + Vector2(r * 0.33, r * 0.33), c + Vector2(0, r), c + Vector2(-r * 0.33, r * 0.33),
			c + Vector2(-r, 0), c + Vector2(-r * 0.33, -r * 0.33)
		])
		draw_colored_polygon(pts, Color(1, 1, 1, 0.75))


class LockIcon:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(22, 22)

	func _ready() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		var s := minf(size.x, size.y)
		if s <= 1:
			return
		var col := GardenTheme.LOCKED_INK
		var c := size * 0.5
		draw_arc(c + Vector2(0, -s * 0.08), s * 0.18, PI, TAU, 18, col, maxf(2.0, s * 0.09), true)
		draw_rect(Rect2(c.x - s * 0.27, c.y - s * 0.04, s * 0.54, s * 0.40), col, true)
		draw_circle(c + Vector2(0, s * 0.12), s * 0.055, GardenTheme.LOCKED)
		draw_rect(Rect2(c.x - s * 0.02, c.y + s * 0.12, s * 0.04, s * 0.10), GardenTheme.LOCKED, true)


class CheckIcon:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(22, 22)

	func _ready() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		var s := minf(size.x, size.y)
		if s <= 1:
			return
		draw_circle(size * 0.5, s * 0.46, GardenTheme.MINT)
		var pts := PackedVector2Array([
			Vector2(s * 0.27, s * 0.52),
			Vector2(s * 0.43, s * 0.68),
			Vector2(s * 0.75, s * 0.34)
		])
		draw_polyline(pts, GardenTheme.MINT_DEEP.darkened(0.18), maxf(2.0, s * 0.09), true)


class Confetti:
	extends Control

	var particles: Array = []
	var running := false
	var _rng := RandomNumberGenerator.new()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		set_process(false)

	func start(amount: int = 90, origin: Vector2 = Vector2(-1, -1)) -> void:
		if GardenApi.reduced_motion():
			return
		_rng.randomize()
		var w := maxf(size.x, 200.0)
		var start_at := origin
		if start_at.x < 0:
			start_at = Vector2(w * 0.5, size.y * 0.36)
		var colors := [
			GardenTheme.LAVENDER, GardenTheme.PINK, GardenTheme.YELLOW,
			GardenTheme.MINT, Color("ffffff"), GardenTheme.PINK_DEEP
		]
		for i in amount:
			particles.append({
				"pos": start_at + Vector2(_rng.randf_range(-w * 0.34, w * 0.34), _rng.randf_range(-30, 40)),
				"vel": Vector2(_rng.randf_range(-190, 190), _rng.randf_range(-420, -120)),
				"rot": _rng.randf_range(0, TAU),
				"spin": _rng.randf_range(-7, 7),
				"size": Vector2(_rng.randf_range(5, 11), _rng.randf_range(8, 15)),
				"color": colors[_rng.randi_range(0, colors.size() - 1)],
				"life": _rng.randf_range(1.3, 2.6),
				"age": 0.0
			})
		running = true
		set_process(true)

	func _process(delta: float) -> void:
		if not running:
			return
		var alive: Array = []
		for p_v in particles:
			var p: Dictionary = p_v
			p["age"] = float(p["age"]) + delta
			p["vel"] = (p["vel"] as Vector2) + Vector2(0, 520.0 * delta)
			p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta
			p["rot"] = float(p["rot"]) + float(p["spin"]) * delta
			if float(p["age"]) < float(p["life"]):
				alive.append(p)
		particles = alive
		if particles.is_empty():
			running = false
			set_process(false)
		queue_redraw()

	func _draw() -> void:
		for p_v in particles:
			var p: Dictionary = p_v
			var t := float(p["age"]) / float(p["life"])
			var alpha := clampf(1.0 - pow(t, 3.0), 0.0, 1.0)
			var col: Color = p["color"]
			col.a = alpha
			draw_set_transform(p["pos"], p["rot"], Vector2.ONE)
			var sz: Vector2 = p["size"]
			draw_rect(Rect2(-sz * 0.5, sz), col, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
