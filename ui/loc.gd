class_name GardenLoc
extends RefCounted

## Localisation facade.
## First tries the project I18n autoload (if it exposes a translate-style method),
## then falls back to the bundled TR/EN strings below. This keeps the UI usable
## even if a content/localisation key is missing from the core layer.

static var _i18n_checked := false
static var _i18n: Node = null

const STRINGS := {
	"tr": {
		"brand": "Kelime Bahçesi",
		"brand_sub": "Word Garden",
		"tagline": "Kelimeleri büyüt, bahçeni tamamla.",
		"back": "Geri",
		"close": "Kapat",
		"cancel": "Vazgeç",
		"ok": "Tamam",
		"retry": "Tekrar dene",
		"loading": "Yükleniyor…",
		"settings": "Ayarlar",
		"language": "Dil",
		"turkish": "Türkçe",
		"english": "English",
		"coins": "altın",
		"sound": "Ses",
		"on": "Açık",
		"off": "Kapalı",
		"reduced_motion": "Az hareket",
		"home": "Ana sayfa",

		"home_continue": "Kaldığın yerden",
		"home_continue_hint": "Sıradaki seviye seni bekliyor",
		"home_play": "Oyna",
		"home_categories": "Kategoriler",
		"home_category_count": "%d kategori",
		"home_modes": "Modlar",
		"home_party": "Parti",
		"home_party_desc": "Rahat tempo, rastgele zincirler",
		"home_online": "Çevrimiçi",
		"home_online_desc": "Bir arkadaşınla yarış",
		"home_how": "Nasıl oynanır?",
		"how_1": "İlk harf verilir; kelimenin kalanını yaz.",
		"how_2": "Doğru kelime, zincirdeki sonraki kartı açar.",
		"how_3": "İpucu veya harf alabilirsin. İlk bitirişte 25 altın kazanırsın.",
		"how_example": "Örnek: BAL → LALE → EV",
		"home_progress": "%d / %d seviye",
		"start_here": "Buradan başla",
		"all_done_title": "Bahçen tamamlandı!",
		"all_done_body": "Tüm seviyeleri bitirdin. Parti ve çevrimiçi modda yeni zincirler seni bekliyor.",
		"tap_category": "Bir kategori seç",

		"categories_title": "Kategoriler",
		"categories_sub": "Her kategori kendi kelime zincirlerini saklar. Seviyeler sırayla açılır.",
		"category_levels_count": "%d seviye",
		"category_done": "%d / %d tamamlandı",
		"level_n": "Seviye %d",
		"locked": "Kilitli",
		"locked_prev": "Önce bir önceki seviyeyi bitir.",
		"completed": "Tamamlandı",
		"play": "Başla",
		"replay": "Tekrar oyna",
		"word_count": "%d kelime",
		"level_preview": "İlk kelime",
		"language_levels_note": "Bu dildeki ilerleme ayrı tutulur.",

		"chain_title": "Kelime zinciri",
		"chain_progress": "%d / %d",
		"hint_btn": "İpucu",
		"reveal_btn": "Harf",
		"hint_cost": "İpucu · %d",
		"reveal_cost": "Harf · %d",
		"hint_prefix": "İpucu",
		"no_hint": "Bu kelime için ipucu yok.",
		"correct": "Doğru!",
		"wrong": "Tekrar dene",
		"incomplete": "Önce kelimeyi tamamla.",
		"not_enough_coins": "Yeterli altın yok.",
		"lang_locked_play": "Dil, bir seviye sürerken değiştirilemez. Önce seviyeden çık.",
		"content_missing": "İçerik yüklenemedi",
		"content_missing_body": "Kelime verileri henüz hazır değil. Tekrar denemek için aşağıdaki düğmeye dokun.",
		"solve_word": "Kelimeyi yaz",
		"submit": "Tamam",
		"backspace": "Sil",
		"victory_title": "Harika!",
		"victory_sub": "Zinciri tamamladın.",
		"first_clear_reward": "İlk tamamlama ödülü +%d altın",
		"already_cleared": "Bu seviyeyi daha önce tamamladın.",
		"next_level": "Sonraki seviye",
		"back_to_map": "Haritaya dön",
		"expression_label": "İfade örneği",
		"expression_none": "Bu kelime için ifade örneği yok.",
		"chain_complete": "Zincir tamamlandı",
		"quit_title": "Ayrılmak istiyor musun?",
		"quit_body": "Bölüm yeniden başlayacak; bu denemedeki harfler ve ipuçları sıfırlanır. Harcanan altınlar iade edilmez.",
		"quit_confirm": "Ayrıl",
		"party_badge": "PARTİ",
		"party_title": "Parti modu",
		"party_sub": "Rahat oyna, ifade örneklerini keşfet.",
		"party_tip": "Tüm cevaplar açık. Yeni zincir için bir karta dokun!",
		"save_failed": "Kayıt yazılamadı. Lütfen cihaz depolamasını kontrol et.",
		"party_next": "Yeni zincir",
		"party_links": "İfade bağlantıları",
		"party_finished": "Zincir bitti",
		"party_tap_next": "Yeni zincir için dokun",

		"settings_title": "Ayarlar",
		"settings_sub": "Oyunu kendine göre ayarla.",
		"sound_effects": "Ses efektleri",
		"sound_desc": "Doğru cevap, hata ve buton sesleri.",
		"reduced_motion_desc": "Animasyonları ve konfetiyi azaltır.",
		"language_desc": "Arayüz ve bulmacalar seçili dilde açılır.",
		"about_title": "Kelime Bahçesi hakkında",
		"about_body": "Türkçe ve İngilizce kelime zincirleriyle oynanan, reklamsız ve girişsiz bir kelime oyunu. İlerlemen bu cihazda saklanır.",
		"progress_note": "İlerleme ve altınlar bu cihazda saklanır.",
		"licenses": "Lisanslar",
		"licenses_title": "Açık kaynak lisansları",
		"licenses_body": "Kelime Bahçesi Godot Engine ile geliştirildi. Motor ve bağımlılıklarının lisans metinleri aşağıdadır.",
		"licenses_missing": "Lisans dosyası bulunamadı.",
		"licenses_engine": "Godot Engine lisansı",
		"licenses_copyright": "Godot Engine telif bildirimi",

		"online_title": "Çevrimiçi",
		"online_sub": "Aynı anda 3 zinciri çöz; en çok kelimeyi önce bitiren kazanır.",
		"online_no_login": "Giriş yok. Sadece bir takma ad yeter.",
		"or": "veya",
		"online_time_up": "Süre bitti!",
		"emote_hello": "Selam!",
		"emote_nice": "Harika!",
		"emote_wow": "Ooo!",
		"emote_gg": "İyi oyun!",
		"online_name": "Takma ad",
		"online_name_ph": "Adın",
		"online_create": "Oda kur",
		"online_join": "Odaya katıl",
		"online_code": "Oda kodu",
		"online_code_ph": "Örn. 4821",
		"online_connecting": "Bağlanıyor…",
		"online_connected": "Bağlı",
		"online_disconnected": "Bağlantı kesildi",
		"online_offline_title": "Sunucuya ulaşılamadı",
		"online_offline_body": "Çevrimiçi mod için bir WebSocket sunucusu gerekir. config/network.example.json dosyasını config/network.json olarak kopyala, adresi düzenle ve sunucuyu başlat. Ardından tekrar dene.",
		"online_retry": "Yeniden bağlan",
		"online_leave": "Odadan ayrıl",
		"online_room": "Oda",
		"online_waiting": "Arkadaşın bekleniyor…",
		"online_players": "%d oyuncu",
		"online_you": "Sen",
		"online_opponent": "Rakip",
		"online_wait_start": "Oda hazır. Sunucu başlatınca geri sayım başlayacak.",
		"online_ready": "Hazır",
		"online_match": "Maç",
		"online_countdown": "Hazırlan",
		"online_go": "Başla!",
		"online_remaining": "Kalan",
		"online_emote": "Tepki",
		"online_room_lang": "Oda dili",
		"online_room_code": "Oda kodu",
		"online_need_name": "Önce bir takma ad yaz.",
		"online_need_code": "Oda kodunu yaz.",
		"online_config_title": "Yerel sunucu",
		"online_config_body": "config/network.json içindeki \"url\" alanı varsayılan olarak ws://127.0.0.1:8787. Aynı ağdaki cihazlar için bilgisayarının yerel IP'sini kullan.",
		"online_leave_confirm": "Odadan ayrılmak istiyor musun?",
		"online_leave_match": "Maçtan ayrılırsan rakibin hükmen kazanır.",
		"online_lang_locked": "Maç sırasında dil değiştirilemez. Önce odadan ayrıl.",
		"online_lang_locked_room": "Odadayken dil sabittir. Değiştirmek için önce ayrıl.",
		"online_you_win": "Kazandın!",
		"online_you_lose": "Bu sefer olmadı",
		"online_draw": "Berabere",
		"online_final": "Maç sonucu",
		"online_score": "Skor",
		"online_return": "Ana sayfaya dön",
		"online_wait_finish": "Rakibin bitirmesi bekleniyor…",
		"online_opponent_left": "Rakip ayrıldı.",
		"online_connecting_hint": "Sunucuya bağlanılıyor. Bu birkaç saniye sürebilir.",
		"online_no_client": "Ağ istemcisi bulunamadı.",
		"online_copy_hint": "Kodu arkadaşınla paylaş.",
		"online_round": "Tur %d / %d",
		"online_word": "Kelime %d / %d",
		"online_waiting_room": "Oda koduyla arkadaşını davet et.",

		"err_generic": "Bir şeyler ters gitti.",
		"err_offline": "Sunucuya bağlanılamadı.",
		"err_timeout": "Sunucu yanıt vermedi. Tekrar dene.",
		"err_room_not_found": "Oda bulunamadı. Kodu kontrol et.",
		"err_room_full": "Oda dolu.",
		"err_invalid_code": "Geçersiz oda kodu.",
		"err_name_taken": "Bu takma ad kullanılıyor.",
		"err_started": "Maç çoktan başladı.",
		"err_invalid_answer": "Cevap kabul edilmedi.",
		"err_server_busy": "Sunucu şu anda meşgul.",
		"err_unknown": "Bilinmeyen bir hata oluştu.",
		"err_room_unavailable": "Bu oda çoktan başladı.",
		"err_invalid_language": "Geçersiz dil seçimi.",
		"err_invalid_name": "Takma ad 1-16 yazdırılabilir karakter olmalı.",
		"err_content_unavailable": "Bu dil için yeterli seviye yok.",
		"err_not_started": "Geri sayım bitmedi. Biraz bekle.",
		"err_game_over": "Oyun süresi doldu.",
		"err_already_finished": "Tüm kelimeleri zaten bitirdin.",
		"err_invalid_coordinates": "Kelime konumu geçersiz.",
		"err_invalid_emote": "Geçersiz tepki.",
		"err_no_room": "Önce bir odaya katıl.",
		"err_already_in_room": "Zaten bir odadasın.",
		"err_internal_error": "Sunucuda bir sorun oluştu.",
		"err_invalid_json": "Sunucudan geçersiz yanıt geldi.",
		"err_invalid_message": "Sunucudan geçersiz yanıt geldi.",
		"err_missing_type": "Sunucudan geçersiz yanıt geldi.",
		"err_not_connected": "Sunucu bağlantısı yok.",
		"err_connect_error": "Sunucuya bağlanılamadı."
	},
	"en": {
		"brand": "Word Garden",
		"brand_sub": "Kelime Bahçesi",
		"tagline": "Grow words, complete your garden.",
		"back": "Back",
		"close": "Close",
		"cancel": "Cancel",
		"ok": "OK",
		"retry": "Try again",
		"loading": "Loading…",
		"settings": "Settings",
		"language": "Language",
		"turkish": "Türkçe",
		"english": "English",
		"coins": "coins",
		"sound": "Sound",
		"on": "On",
		"off": "Off",
		"reduced_motion": "Reduced motion",
		"home": "Home",

		"home_continue": "Pick up where you left off",
		"home_continue_hint": "Your next level is waiting",
		"home_play": "Play",
		"home_categories": "Categories",
		"home_category_count": "%d categories",
		"home_modes": "Modes",
		"home_party": "Party",
		"home_party_desc": "Relaxed pace, random chains",
		"home_online": "Online",
		"home_online_desc": "Race a friend",
		"home_how": "How to play",
		"how_1": "The first letter is given; type the rest of the word.",
		"how_2": "A correct word unlocks the next card in the chain.",
		"how_3": "Buy hints or letters. Your first clear earns 25 coins.",
		"how_example": "Example: BAL → LALE → EV",
		"home_progress": "%d / %d levels",
		"start_here": "Start here",
		"all_done_title": "Your garden is complete!",
		"all_done_body": "You finished every level. Party and online modes have fresh chains waiting.",
		"tap_category": "Pick a category",

		"categories_title": "Categories",
		"categories_sub": "Each category holds its own word chains. Levels unlock in order.",
		"category_levels_count": "%d levels",
		"category_done": "%d / %d complete",
		"level_n": "Level %d",
		"locked": "Locked",
		"locked_prev": "Finish the previous level first.",
		"completed": "Completed",
		"play": "Start",
		"replay": "Play again",
		"word_count": "%d words",
		"level_preview": "First word",
		"language_levels_note": "Progress is tracked separately for this language.",

		"chain_title": "Word chain",
		"chain_progress": "%d / %d",
		"hint_btn": "Hint",
		"reveal_btn": "Letter",
		"hint_cost": "Hint · %d",
		"reveal_cost": "Letter · %d",
		"hint_prefix": "Hint",
		"no_hint": "No hint for this word.",
		"correct": "Correct!",
		"wrong": "Try again",
		"incomplete": "Finish the word first.",
		"not_enough_coins": "Not enough coins.",
		"lang_locked_play": "Language can't change during a level. Leave the level first.",
		"content_missing": "Content couldn't load",
		"content_missing_body": "The word data isn't ready yet. Tap retry below.",
		"solve_word": "Type the word",
		"submit": "Enter",
		"backspace": "Del",
		"victory_title": "Wonderful!",
		"victory_sub": "You completed the chain.",
		"first_clear_reward": "First clear reward +%d coins",
		"already_cleared": "You cleared this level before.",
		"next_level": "Next level",
		"back_to_map": "Back to map",
		"expression_label": "Expression example",
		"expression_none": "No expression example for this word.",
		"chain_complete": "Chain complete",
		"quit_title": "Leave now?",
		"quit_body": "The level will restart; letters and hints from this attempt are cleared. Spent coins are not refunded.",
		"quit_confirm": "Leave",
		"party_badge": "PARTY",
		"party_title": "Party mode",
		"party_sub": "Play relaxed and discover expression examples.",
		"party_tip": "All answers are open. Tap a card for a new chain!",
		"save_failed": "Could not save. Please check your device storage.",
		"party_next": "New chain",
		"party_links": "Expression links",
		"party_finished": "Chain finished",
		"party_tap_next": "Tap for a new chain",

		"settings_title": "Settings",
		"settings_sub": "Make the garden yours.",
		"sound_effects": "Sound effects",
		"sound_desc": "Correct, wrong and button sounds.",
		"reduced_motion_desc": "Tones down animation and confetti.",
		"language_desc": "Interface and puzzles open in the selected language.",
		"about_title": "About Word Garden",
		"about_body": "A login-free, ad-free word chain game in Turkish and English. Your progress is stored on this device.",
		"progress_note": "Progress and coins are stored on this device.",
		"licenses": "Licenses",
		"licenses_title": "Open source licenses",
		"licenses_body": "Word Garden is built with Godot Engine. The license texts of the engine and its dependencies are shown below.",
		"licenses_missing": "License file not found.",
		"licenses_engine": "Godot Engine license",
		"licenses_copyright": "Godot Engine copyright notice",

		"online_title": "Online",
		"online_sub": "Solve 3 shared chains; whoever finishes the most words first wins.",
		"online_no_login": "No login. A nickname is all you need.",
		"or": "or",
		"online_time_up": "Time's up!",
		"emote_hello": "Hi!",
		"emote_nice": "Nice!",
		"emote_wow": "Wow!",
		"emote_gg": "Good game!",
		"online_name": "Nickname",
		"online_name_ph": "Your name",
		"online_create": "Create room",
		"online_join": "Join room",
		"online_code": "Room code",
		"online_code_ph": "e.g. 4821",
		"online_connecting": "Connecting…",
		"online_connected": "Connected",
		"online_disconnected": "Disconnected",
		"online_offline_title": "Can't reach the server",
		"online_offline_body": "Online mode needs a WebSocket server. Copy config/network.example.json to config/network.json, edit the address, start the server, then retry.",
		"online_retry": "Reconnect",
		"online_leave": "Leave room",
		"online_room": "Room",
		"online_waiting": "Waiting for your friend…",
		"online_players": "%d players",
		"online_you": "You",
		"online_opponent": "Opponent",
		"online_wait_start": "Room ready. The countdown starts when the server begins.",
		"online_ready": "Ready",
		"online_match": "Match",
		"online_countdown": "Get ready",
		"online_go": "Go!",
		"online_remaining": "Left",
		"online_emote": "Reactions",
		"online_room_lang": "Room language",
		"online_room_code": "Room code",
		"online_need_name": "Enter a nickname first.",
		"online_need_code": "Enter a room code.",
		"online_config_title": "Local server",
		"online_config_body": "The \"url\" in config/network.json defaults to ws://127.0.0.1:8787. For devices on the same network, use your computer's local IP.",
		"online_leave_confirm": "Leave the room?",
		"online_leave_match": "Leaving a match forfeits it to your opponent.",
		"online_lang_locked": "Language can't change during a match. Leave the room first.",
		"online_lang_locked_room": "The room language is fixed. Leave to change it.",
		"online_you_win": "You win!",
		"online_you_lose": "Not this time",
		"online_draw": "It's a draw",
		"online_final": "Match result",
		"online_score": "Score",
		"online_return": "Back home",
		"online_wait_finish": "Waiting for your opponent to finish…",
		"online_opponent_left": "Your opponent left.",
		"online_connecting_hint": "Connecting to the server. This can take a moment.",
		"online_no_client": "Network client unavailable.",
		"online_copy_hint": "Share this code with a friend.",
		"online_round": "Round %d / %d",
		"online_word": "Word %d / %d",
		"online_waiting_room": "Invite a friend with the room code.",

		"err_generic": "Something went wrong.",
		"err_offline": "Could not connect to the server.",
		"err_timeout": "The server didn't respond. Try again.",
		"err_room_not_found": "Room not found. Check the code.",
		"err_room_full": "This room is full.",
		"err_invalid_code": "Invalid room code.",
		"err_name_taken": "That nickname is taken.",
		"err_started": "The match already started.",
		"err_invalid_answer": "Answer was rejected.",
		"err_server_busy": "The server is busy.",
		"err_unknown": "An unknown error occurred.",
		"err_room_unavailable": "This room has already started.",
		"err_invalid_language": "Invalid language selection.",
		"err_invalid_name": "Nickname must be 1-16 printable characters.",
		"err_content_unavailable": "Not enough levels for this language.",
		"err_not_started": "The countdown has not finished yet. Wait a moment.",
		"err_game_over": "The play window has ended.",
		"err_already_finished": "You have already finished all words.",
		"err_invalid_coordinates": "Invalid word position.",
		"err_invalid_emote": "Invalid reaction.",
		"err_no_room": "Join a room first.",
		"err_already_in_room": "You are already in a room.",
		"err_internal_error": "The server hit a problem.",
		"err_invalid_json": "The server sent an invalid reply.",
		"err_invalid_message": "The server sent an invalid reply.",
		"err_missing_type": "The server sent an invalid reply.",
		"err_not_connected": "No server connection.",
		"err_connect_error": "Could not connect to the server."
	}
}

## Content data only ships category ids / name keys, so the display names are
## resolved here (TR/EN) instead of leaking raw ids into the UI.
const CATEGORY_NAMES := {
	"tr": {"kitchen": "Mutfak", "nature": "Doğa", "daily": "Günlük"},
	"en": {"kitchen": "Kitchen", "nature": "Nature", "daily": "Everyday"}
}


static func _i18n_node() -> Node:
	if not _i18n_checked:
		_i18n_checked = true
		var tree := Engine.get_main_loop()
		if tree is SceneTree:
			_i18n = (tree as SceneTree).root.get_node_or_null("I18n")
	return _i18n


static func has(key: String) -> bool:
	return STRINGS["tr"].has(key) or STRINGS["en"].has(key)


static func t(key: String, lang: String = "") -> String:
	var language := lang if lang in ["tr", "en"] else ""
	# Bundled UI strings are authoritative and already language-explicit.
	var table: Dictionary = STRINGS.get(language, STRINGS["tr"]) if not language.is_empty() else STRINGS["tr"]
	if table.has(key):
		return str(table[key])
	# Only consult I18n when it is actually showing the requested language,
	# otherwise an explicit-language lookup would return mixed results.
	var node := _i18n_node()
	if node != null:
		var i18n_lang := ""
		if node.has_method("get_language"):
			i18n_lang = str(node.call("get_language"))
		if language.is_empty() or i18n_lang.is_empty() or i18n_lang == language:
			for method in ["t", "tr", "translate", "get_text", "text"]:
				if node.has_method(method):
					var result: Variant = node.call(method, key)
					if typeof(result) == TYPE_STRING and not (result as String).is_empty() and result != key:
						return result
	# Short graceful fallback for unknown keys instead of raw snake_case.
	var alt: Dictionary = STRINGS["en"] if language == "tr" else STRINGS["tr"]
	if alt.has(key):
		return str(alt[key])
	return key.replace("_", " ").capitalize()


static func f(key: String, values: Array, lang: String = "") -> String:
	var text := t(key, lang)
	if values.is_empty():
		return text
	if "%" in text:
		return text % values
	return text


static func category_name(category: Variant, lang: String) -> String:
	var language := lang if lang in ["tr", "en"] else "tr"
	var id := ""
	var explicit := ""
	if typeof(category) == TYPE_DICTIONARY:
		var d: Dictionary = category
		id = str(d.get("id", ""))
		if id.is_empty():
			id = str(d.get("name_key", d.get("key", "")).to_lower())
		for key in ["name_" + language, "name", "title_" + language, "title", "label"]:
			if not d.has(key):
				continue
			var v: Variant = d[key]
			if typeof(v) == TYPE_DICTIONARY:
				var inner: Dictionary = v
				if inner.has(language):
					explicit = str(inner[language])
					break
				if inner.has("text"):
					explicit = str(inner["text"])
					break
			elif typeof(v) == TYPE_STRING and not (v as String).is_empty():
				explicit = str(v)
				break
	else:
		id = str(category)
	if id.begins_with("category."):
		id = id.substr("category.".length())
	id = id.strip_edges()
	var mapped: Dictionary = CATEGORY_NAMES.get(language, {})
	if mapped.has(id):
		return str(mapped[id])
	if not explicit.is_empty():
		return explicit
	if not id.is_empty():
		return id.replace("_", " ").capitalize()
	if not explicit.is_empty():
		return explicit
	return ""


static func status_label(code: String, lang: String = "") -> String:
	var clean := code.to_lower().replace("-", "_").strip_edges()
	if clean.is_empty():
		return t("err_generic", lang)
	if clean.begins_with("connect_error"):
		return t("err_connect_error", lang)
	if clean.begins_with("close_"):
		return t("err_offline", lang)
	if clean == "timeout":
		return t("err_timeout", lang)
	var key := "err_" + clean
	if has(key):
		return t(key, lang)
	return t("err_generic", lang)
