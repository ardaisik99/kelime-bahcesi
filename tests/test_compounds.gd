extends SceneTree
## Every shipped chain: full native input, Turkish inflections and unchanged roots.
var checks := 0
var failures := 0

class MemoryStore:
	extends RefCounted
	func get_coins(_lang: String) -> int: return 100
	func is_completed(_lang: String, _id: String) -> bool: return true
	func mark_level_completed(_lang: String, _id: String, _reward: int) -> Dictionary:
		return {"success": true, "first_clear": false, "coins_awarded": 0, "coins": 100}

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	await process_frame
	for lang in ["tr", "en"]:
		var previous := 0
		for level in GardenApi.all_levels(lang):
			check(int(level.difficulty) >= previous, "difficulty must increase")
			previous = int(level.difficulty)
			var session := GameSession.new(MemoryStore.new())
			check(session.start(level, lang), "start " + str(level.id))
			var raw: Dictionary = level.raw
			check(session.roots == raw.words, "immutable roots " + str(level.id))
			for i in range(1, session.words.size()):
				var expected := GardenApi.upper(str(raw.links[i - 1]).get_slice(" ", 1), lang) if lang == "tr" else str(raw.words[i])
				check(session.current == expected, "answer must match compound " + str(level.id))
				check(session.word_length(i) == expected.length(), "mask must use inflected length")
				session.set_active_input(expected.left(1))
				check(not session.submit(), "incomplete native answer must fail")
				session.set_active_input(expected + "X")
				check(not session.submit(), "extra letters must fail")
				session.set_active_input("X" + expected.substr(1))
				check(not session.submit(), "wrong fixed letter must fail")
				var root_word := str(raw.words[i])
				if root_word != expected:
					session.set_active_input(root_word)
					check(not session.submit(), "bare Turkish root must fail")
				session.set_active_input(GardenApi.lower_tr(expected) if lang == "tr" else expected.to_lower())
				check(session.submit(), "full lowercase native answer must solve " + expected)
			check(session.won, "chain completed " + str(level.id))
			check(session.coins_awarded == 0, "isolated test store gives no reward")
	print("[compounds] RESULT: %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)
