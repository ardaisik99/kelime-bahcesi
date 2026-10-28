class_name GardenPaint
extends RefCounted
## Static SVG atlas. No procedural art, particles or idle animation.

class Background:
	extends ColorRect
	func _init() -> void:
		color = GardenTheme.BG
		mouse_filter = Control.MOUSE_FILTER_IGNORE

class Icon:
	extends TextureRect
	func _init(index: int = 0) -> void:
		var atlas := AtlasTexture.new()
		atlas.atlas = preload("res://assets/ui/icons.svg")
		atlas.region = Rect2(index * 64, 0, 64, 64)
		texture = atlas
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		custom_minimum_size = Vector2(28, 28)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

class ChainIcon:
	extends Icon
	var petal_color: Color
	var center_color: Color
	func _init() -> void:
		super(0)

class CoinIcon:
	extends Icon
	func _init() -> void:
		super(4)

class LockIcon:
	extends Icon
	func _init() -> void:
		super(5)

class CheckIcon:
	extends Icon
	func _init() -> void:
		super(6)

class TrophyIcon:
	extends Icon
	func _init() -> void:
		super(8)

static func icon(index: int, side: float = 28) -> TextureRect:
	var node := Icon.new(index)
	node.custom_minimum_size = Vector2(side, side)
	return node

static func brand(side: float = 64) -> TextureRect:
	var node := TextureRect.new()
	node.texture = preload("res://assets/ui/brand.svg")
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.custom_minimum_size = Vector2(side, side)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func texture(index: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = preload("res://assets/ui/icons.svg")
	atlas.region = Rect2(index * 64, 0, 64, 64)
	return atlas
