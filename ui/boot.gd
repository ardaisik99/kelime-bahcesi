extends Control
## Real scene-load progress. The web shell covers WASM/PCK download before this scene.
const MAIN := "res://scenes/main.tscn"
var _progress: ProgressBar
var _status: Label
var _started := 0

func _ready() -> void:
	theme = GardenTheme.build_theme()
	var bg := ColorRect.new()
	bg.color = GardenTheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var v := VBoxContainer.new()
	v.custom_minimum_size.x = 280
	v.add_theme_constant_override("separation", 18)
	center.add_child(v)
	var brand := GardenPaint.brand(92)
	brand.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(brand)
	v.add_child(GardenWidgets.title("Kelime Zinciri", 34, GardenTheme.INK, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(GardenWidgets.label("HER KELİME BİR BAĞLANTI", 12, GardenTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(GardenWidgets.vspace(22))
	_progress = GardenWidgets.progress_bar(0, 1, GardenTheme.LAVENDER, 5)
	v.add_child(_progress)
	_status = GardenWidgets.label("Kelimeler hazırlanıyor…", 13, GardenTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_status)
	_started = Time.get_ticks_msec()
	var err := ResourceLoader.load_threaded_request(MAIN)
	if err != OK:
		_status.text = "Yükleme başlatılamadı. Oyunu yeniden aç."
		set_process(false)

func _process(_delta: float) -> void:
	var values: Array = []
	var status := ResourceLoader.load_threaded_get_status(MAIN, values)
	if not values.is_empty():
		_progress.value = float(values[0])
	if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_status.text = "Oyun yüklenemedi. Lütfen yeniden aç."
		set_process(false)
	elif status == ResourceLoader.THREAD_LOAD_LOADED:
		_progress.value = 1
		_status.text = "Hazır"
		if Time.get_ticks_msec() - _started >= 650:
			set_process(false)
			var scene := ResourceLoader.load_threaded_get(MAIN) as PackedScene
			get_tree().change_scene_to_packed.call_deferred(scene)
