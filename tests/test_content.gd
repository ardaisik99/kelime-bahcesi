extends SceneTree
## Content data quality tests.
## Run:
##   godot --headless --path . --script tests/test_content.gd
##
## Verifies both language files, category distribution, unique ids, 4-5 word
## chains, uppercase roots, hint/link counts, link prefixes, and random picks.

var _checks: int = 0
var _failures: Array[String] = []
var _i18n: Node = null
var _content: Node = null


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _ensure_services()
	if _i18n == null or _content == null:
		_fail("Content/I18n could not be created")
		_finish()
		return
	await _frames(2)

	var errors: Variant = _content.call("errors")
	_check(errors is Array and (errors as Array).is_empty(), "Content loads without validation errors: %s" % [str(errors)])

	var global_ids: Dictionary = {}
	for lang: String in ["tr", "en"]:
		_check(bool(_content.call("is_loaded", lang)), "%s content is loaded" % lang)
		var categories: Array = _content.call("categories", lang)
		_check(categories.size() == 3, "%s exposes 3 categories" % lang)
		var category_ids: Dictionary = {}
		for category_value: Variant in categories:
			var category: Dictionary = category_value
			var category_id: String = str(category.get("id", ""))
			_check(category_id in ["kitchen", "nature", "daily"], "%s category id is valid (%s)" % [lang, category_id])
			_check(not category_ids.has(category_id), "%s category ids are unique" % lang)
			category_ids[category_id] = true
			_check(int(category.get("count", -1)) == 6, "%s/%s count is 6" % [lang, category_id])
			_check(str(category.get("name_key", "")).begins_with("category."), "%s category has a translation key" % lang)

		var levels: Array = _content.call("get_levels", lang)
		_check(levels.size() == 18, "%s has exactly 18 levels" % lang)
		_check((_content.call("level_ids", lang) as PackedStringArray).size() == 18, "%s level_ids agrees" % lang)
		var chains: Dictionary = {}
		for level_value: Variant in levels:
			var level: Dictionary = level_value
			var id: String = str(level.get("id", ""))
			var category: String = str(level.get("category", ""))
			var words: Array = level.get("words", [])
			var hints: Array = level.get("hints", [])
			var links: Array = level.get("links", [])
			_check(not id.is_empty(), "%s has an id" % lang)
			_check(not global_ids.has(id), "id is globally unique: %s" % id)
			global_ids[id] = true
			_check(category_ids.has(category), "%s belongs to a real category" % id)
			_check(words.size() == 4 or words.size() == 5, "%s has 4 or 5 words" % id)
			_check(hints.size() == words.size(), "%s hints match word count" % id)
			_check(links.size() == words.size() - 1, "%s links match gaps" % id)
			var parts: PackedStringArray = PackedStringArray()
			for word_value: Variant in words:
				var word: String = str(word_value)
				parts.append(word)
				_check(word == str(_i18n.call("normalize", word, lang)), "%s word is uppercase: %s" % [id, word])
				_check(not word.contains(" "), "%s word is a single root: %s" % [id, word])
				var alphabet: String = str(_content.call("alphabet", lang))
				var clean: bool = true
				for i: int in range(word.length()):
					if not alphabet.contains(word.substr(i, 1)):
						clean = false
				_check(clean, "%s word uses only %s letters: %s" % [id, lang, word])
			var chain_key: String = "|".join(parts)
			_check(not chains.has(chain_key), "%s chain is not repeated" % id)
			chains[chain_key] = true
			for hint_value: Variant in hints:
				_check(not str(hint_value).strip_edges().is_empty(), "%s has no empty hint" % id)
			for link_index: int in range(links.size()):
				var link: String = str(links[link_index])
				var root: String = str(words[link_index])
				_check(not link.strip_edges().is_empty(), "%s has no empty link" % id)
				_check(str(_i18n.call("lower", link, lang)).begins_with(str(_i18n.call("lower", root, lang))), "%s link starts with root '%s'" % [id, root])
				_check(str(_i18n.call("lower", link, lang)) != str(_i18n.call("lower", root, lang)), "%s link is a full expression, not just the root" % id)

		_check(int(_content.call("count", lang)) == 18, "%s count() is 18" % lang)
		_check((_content.call("get_levels", lang, "missing") as Array).is_empty(), "%s unknown category is empty" % lang)
		var first: Dictionary = _content.call("get_levels", lang)[0]
		_check(not bool((_content.call("get_level", lang, str(first["id"])) as Dictionary).is_empty()), "%s get_level works" % lang)
		_check(bool((_content.call("get_level", lang, "does_not_exist") as Dictionary).is_empty()), "%s get_level unknown is empty" % lang)

	_check(bool((_content.call("has_level", "tr", "tr_kitchen_tea_time"))), "required Turkish chain id exists")
	_check(bool((_content.call("has_level", "en", "en_daily_book_club"))), "required English chain id exists")
	var tea: Dictionary = _content.call("get_level", "tr", "tr_kitchen_tea_time")
	_check(tea.get("words", []) == ["ÇAY", "KAŞIK", "OYUN", "HAVA"], "ÇAY KAŞIK OYUN HAVA is preserved")
	_check(tea.get("links", []) == ["çay kaşığı", "kaşık oyunu", "oyun havası"], "Turkish possessive suffixes are grammatical")

	var avoided: int = 0
	for i: int in range(60):
		var picked: Dictionary = _content.call("random_level", "en", "daily", "en_daily_book_club")
		if str(picked.get("id", "")) == "en_daily_book_club":
			avoided += 1
	_check(avoided == 0, "random_level never returns avoid_id when alternatives exist")
	var avoided_recent: int = 0
	for i: int in range(60):
		var picked: Dictionary = _content.call("random_level_avoiding", "tr", "nature", ["tr_nature_bee_hive", "tr_nature_rain_drop"], 1)
		if str(picked.get("id", "")) == "tr_nature_rain_drop":
			avoided_recent += 1
	_check(avoided_recent == 0, "random_level_avoiding skips the most recent id")

	_finish()


func _ensure_services() -> void:
	_i18n = root.get_node_or_null("I18n")
	if _i18n == null:
		_i18n = Node.new()
		_i18n.name = "I18n"
		_i18n.set_script(load("res://core/i18n.gd"))
		root.add_child(_i18n)
	_content = root.get_node_or_null("Content")
	if _content == null:
		_content = Node.new()
		_content.name = "Content"
		_content.set_script(load("res://core/content.gd"))
		root.add_child(_content)
	await _frames(2)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error("[content] FAIL: " + message)
	print("[content] FAIL: ", message)


func _frames(count: int) -> void:
	for i: int in range(count):
		await process_frame


func _finish() -> void:
	if _failures.is_empty():
		print("[content] RESULT: PASS (%d checks)" % _checks)
		quit(0)
	else:
		print("[content] RESULT: FAIL (%d checks, %d failures)" % [_checks, _failures.size()])
		for failure: String in _failures:
			print("[content]   - ", failure)
		quit(1)
