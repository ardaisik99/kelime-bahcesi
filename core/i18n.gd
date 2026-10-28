extends Node
## Localization + language-aware text normalization.
##
## Autoload name: I18n (res://core/i18n.gd)
## Public API:
##   I18n.language -> String ("tr" or "en"); setter persists to SaveStore.
##   I18n.set_language(lang: String, persist: bool = true) -> void
##   I18n.t(key: String, args: Dictionary = {}) -> String
##   I18n.has_key(key: String) -> bool
##   I18n.normalize(text: String, lang: String = "") -> String  (uppercase)
##   I18n.lower(text: String, lang: String = "") -> String
##   I18n.upper_letter(ch: String, lang: String = "") -> String
##   I18n.alphabet(lang: String = "") -> String   (uppercase letters)
##   I18n.is_supported(lang: String) -> bool
##   I18n.category_name(category_id: String) -> String
##   I18n.emote_name(emote_id: String) -> String
## Signal: language_changed(language: String)

signal language_changed(language: String)

const SUPPORTED_LANGUAGES: Array = ["tr", "en"]
const DEFAULT_LANGUAGE: String = "tr"
const TR_ALPHABET: String = "ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ"
const EN_ALPHABET: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

const UI_TR: Dictionary = {
	"app.title": "Kelime Bahçesi",
	"app.tagline": "Kelimeler zincir olsun",
	"app.loading": "Yükleniyor…",
	"common.ok": "Tamam",
	"common.cancel": "Vazgeç",
	"common.yes": "Evet",
	"common.no": "Hayır",
	"common.on": "Açık",
	"common.off": "Kapalı",
	"common.back": "Geri",
	"common.close": "Kapat",
	"common.retry": "Tekrar dene",
	"common.continue": "Devam",
	"common.done": "Bitti",
	"common.copy": "Kopyala",
	"common.copied": "Kopyalandı",
	"common.error": "Hata",
	"common.coins": "Altın",
	"common.coin_count": "{coins} altın",
	"common.level": "Bölüm",
	"common.category": "Kategori",
	"common.coming_soon": "Yakında",
	"nav.play": "Oyna",
	"nav.levels": "Bölümler",
	"nav.party": "Parti",
	"nav.settings": "Ayarlar",
	"home.subtitle": "Bir kelimeden diğerine uzanan zinciri tamamla.",
	"home.continue": "Devam et",
	"home.daily": "Günün zinciri",
	"home.last_played": "Son oynanan",
	"home.coins": "Altın: {coins}",
	"home.completed": "{done}/{total} bölüm tamam",
	"category.all": "Tümü",
	"category.kitchen": "Mutfak",
	"category.nature": "Doğa",
	"category.daily": "Günlük",
	"level.chain_length": "{count} kelime",
	"level.completed": "Tamamlandı",
	"level.new": "Yeni",
	"level.replay": "Tekrar oyna",
	"level.play": "Bölümü aç",
	"level.empty": "Bu kategoride henüz bölüm yok.",
	"level.id": "Bölüm {id}",
	"game.hint": "İpucu ({cost})",
	"game.reveal": "Harf göster ({cost})",
	"game.submit": "Gönder",
	"game.backspace": "Sil",
	"game.clear": "Temizle",
	"game.active_word": "Etkin kelime: {word}",
	"game.word_of": "{current}/{total}. kelime",
	"game.chain_complete": "Zincir tamamlandı!",
	"game.submit_ready": "Hazır olduğunda gönder.",
	"game.incorrect": "Kelime yanlış. Harfleri kontrol et.",
	"game.incomplete": "Önce tüm harfleri doldur.",
	"game.correct": "Doğru!",
	"game.won": "Bölümü tamamladın!",
	"game.first_clear": "İlk tamamlama ödülü: {coins} altın",
	"game.replay_reward": "Bu bölümü daha önce tamamladın; tekrar ödül yok.",
	"game.reward": "+{coins} altın",
	"game.coins_total": "Toplam: {coins} altın",
	"game.hint_unavailable": "Bu kelime için ipucu zaten açık.",
	"game.reveal_unavailable": "Gösterilecek gizli harf kalmadı.",
	"game.not_enough_coins": "Yeterli altının yok.",
	"game.hint_bought": "İpucu açıldı.",
	"game.reveal_bought": "Bir harf gösterildi.",
	"game.mask_hint": "Alt çizgiler boş harfleri gösterir.",
	"game.type_hint": "Harflere dokun veya klavyeden yaz.",
	"game.leave_confirm": "Bölümden çıkmak istiyor musun?",
	"game.back_to_levels": "Bölümlere dön",
	"result.title": "Bölüm sonucu",
	"result.win": "Harika iş!",
	"result.replay": "Bölüm tamamlandı",
	"result.coins": "Kazanılan altın: {coins}",
	"result.total": "Toplam altın: {coins}",
	"result.next": "Sonraki bölüm",
	"result.menu": "Menüye dön",
	"result.first_clear": "İlk tamamlama",
	"result.no_reward": "Tekrar oynama ödülü yok",
	"settings.title": "Ayarlar",
	"settings.language": "Dil",
	"settings.language_tr": "Türkçe",
	"settings.language_en": "English",
	"settings.sound": "Ses",
	"settings.reset_progress": "İlerlemeyi sıfırla",
	"settings.reset_confirm": "Bu dildeki tüm ilerleme ve altınlar silinsin mi?",
	"settings.about": "Hakkında",
	"settings.version": "Sürüm {version}",
	"toast.saved": "Kaydedildi",
	"toast.save_failed": "Kayıt yapılamadı: {error}",
	"toast.progress_reset": "İlerleme sıfırlandı",
	"toast.language_changed": "Dil değiştirildi",
	"party.title": "1'e 1 Yarışma",
	"party.create": "Oda oluştur",
	"party.join": "Odaya katıl",
	"party.name": "Adın",
	"party.name_placeholder": "Adını yaz",
	"party.code": "Oda kodu",
	"party.code_placeholder": "6 haneli kod",
	"party.enter_code": "Oda kodunu gir",
	"party.waiting": "Oyuncular bekleniyor…",
	"party.players": "Oyuncular",
	"party.starting": "Oyun başlıyor…",
	"party.score": "Puan",
	"party.time_left": "Kalan süre: {seconds} sn",
	"party.emote": "Duygu",
	"party.leave": "Odadan ayrıl",
	"party.leave_confirm": "Odadan ayrılmak istiyor musun?",
	"party.connecting": "Bağlanıyor…",
	"party.connected": "Bağlandı",
	"party.disconnected": "Bağlantı kesildi",
	"party.reconnecting": "Yeniden bağlanıyor…",
	"party.host": "Kurucu",
	"party.you": "Sen",
	"party.finished": "Oyun bitti",
	"party.copy_code": "Kodu kopyala",
	"party.invalid_code": "Oda kodu geçersiz.",
	"party.join_failed": "Odaya katılamadın.",
	"party.create_failed": "Oda oluşturulamadı.",
	"party.connection_failed": "Sunucuya bağlanılamadı.",
	"party.connection_lost": "Sunucu bağlantısı koptu.",
	"party.waiting_host": "İkinci oyuncu bekleniyor…",
	"party.answer_correct": "Doğru!",
	"party.answer_wrong": "Yanlış.",
	"party.results": "Sonuçlar",
	"party.rank": "{rank}. sıra",
	"party.no_players": "Henüz oyuncu yok.",
	"party.default_name": "Oyuncu",
	"party.not_connected": "Önce sunucuya bağlan.",
	"party.ready": "Hazır",
	"emote.hello": "Merhaba",
	"emote.nice": "Güzel!",
	"emote.wow": "Vay!",
	"emote.gg": "İyi oyun",
	"error.timeout": "İstek zaman aşımına uğradı.",
	"error.network": "Ağ hatası oluştu.",
	"error.connection_closed": "Bağlantı kapandı.",
	"error.invalid_message": "Sunucudan geçersiz yanıt geldi.",
	"error.invalid_code": "Oda kodu geçersiz.",
	"error.room_full": "Oda dolu.",
	"error.game_started": "Oyun çoktan başladı.",
	"error.name_required": "Bir ad gir.",
	"error.not_connected": "Bağlı değilsin.",
	"error.unknown": "Bilinmeyen bir hata oluştu.",
	"error.save": "Kayıt hatası.",
}

const UI_EN: Dictionary = {
	"app.title": "Word Garden",
	"app.tagline": "Link the words together",
	"app.loading": "Loading…",
	"common.ok": "OK",
	"common.cancel": "Cancel",
	"common.yes": "Yes",
	"common.no": "No",
	"common.on": "On",
	"common.off": "Off",
	"common.back": "Back",
	"common.close": "Close",
	"common.retry": "Try again",
	"common.continue": "Continue",
	"common.done": "Done",
	"common.copy": "Copy",
	"common.copied": "Copied",
	"common.error": "Error",
	"common.coins": "Coins",
	"common.coin_count": "{coins} coins",
	"common.level": "Level",
	"common.category": "Category",
	"common.coming_soon": "Coming soon",
	"nav.play": "Play",
	"nav.levels": "Levels",
	"nav.party": "Party",
	"nav.settings": "Settings",
	"home.subtitle": "Complete the chain from one word to the next.",
	"home.continue": "Continue",
	"home.daily": "Daily chain",
	"home.last_played": "Last played",
	"home.coins": "Coins: {coins}",
	"home.completed": "{done}/{total} levels complete",
	"category.all": "All",
	"category.kitchen": "Kitchen",
	"category.nature": "Nature",
	"category.daily": "Everyday",
	"level.chain_length": "{count} words",
	"level.completed": "Completed",
	"level.new": "New",
	"level.replay": "Play again",
	"level.play": "Open level",
	"level.empty": "No levels in this category yet.",
	"level.id": "Level {id}",
	"game.hint": "Hint ({cost})",
	"game.reveal": "Reveal ({cost})",
	"game.submit": "Submit",
	"game.backspace": "Delete",
	"game.clear": "Clear",
	"game.active_word": "Active word: {word}",
	"game.word_of": "Word {current}/{total}",
	"game.chain_complete": "Chain complete!",
	"game.submit_ready": "Submit when you are ready.",
	"game.incorrect": "That word is not correct. Check the letters.",
	"game.incomplete": "Fill in every letter first.",
	"game.correct": "Correct!",
	"game.won": "Level complete!",
	"game.first_clear": "First-clear reward: {coins} coins",
	"game.replay_reward": "You already cleared this level; replays give no reward.",
	"game.reward": "+{coins} coins",
	"game.coins_total": "Total: {coins} coins",
	"game.hint_unavailable": "The hint for this word is already open.",
	"game.reveal_unavailable": "No hidden letters left to reveal.",
	"game.not_enough_coins": "You do not have enough coins.",
	"game.hint_bought": "Hint unlocked.",
	"game.reveal_bought": "One letter revealed.",
	"game.mask_hint": "Underscores mark empty letters.",
	"game.type_hint": "Tap the letters or use your keyboard.",
	"game.leave_confirm": "Leave this level?",
	"game.back_to_levels": "Back to levels",
	"result.title": "Level result",
	"result.win": "Great job!",
	"result.replay": "Level cleared",
	"result.coins": "Coins earned: {coins}",
	"result.total": "Total coins: {coins}",
	"result.next": "Next level",
	"result.menu": "Back to menu",
	"result.first_clear": "First clear",
	"result.no_reward": "No reward on replay",
	"settings.title": "Settings",
	"settings.language": "Language",
	"settings.language_tr": "Türkçe",
	"settings.language_en": "English",
	"settings.sound": "Sound",
	"settings.reset_progress": "Reset progress",
	"settings.reset_confirm": "Delete all progress and coins for this language?",
	"settings.about": "About",
	"settings.version": "Version {version}",
	"toast.saved": "Saved",
	"toast.save_failed": "Could not save: {error}",
	"toast.progress_reset": "Progress reset",
	"toast.language_changed": "Language changed",
	"party.title": "1v1 Race",
	"party.create": "Create room",
	"party.join": "Join room",
	"party.name": "Your name",
	"party.name_placeholder": "Enter your name",
	"party.code": "Room code",
	"party.code_placeholder": "6-character code",
	"party.enter_code": "Enter the room code",
	"party.waiting": "Waiting for players…",
	"party.players": "Players",
	"party.starting": "Game starting…",
	"party.score": "Score",
	"party.time_left": "Time left: {seconds}s",
	"party.emote": "Emote",
	"party.leave": "Leave room",
	"party.leave_confirm": "Leave the room?",
	"party.connecting": "Connecting…",
	"party.connected": "Connected",
	"party.disconnected": "Disconnected",
	"party.reconnecting": "Reconnecting…",
	"party.host": "Host",
	"party.you": "You",
	"party.finished": "Game over",
	"party.copy_code": "Copy code",
	"party.invalid_code": "That room code is invalid.",
	"party.join_failed": "Could not join the room.",
	"party.create_failed": "Could not create the room.",
	"party.connection_failed": "Could not connect to the server.",
	"party.connection_lost": "Lost connection to the server.",
	"party.waiting_host": "Waiting for a second player…",
	"party.answer_correct": "Correct!",
	"party.answer_wrong": "Wrong.",
	"party.results": "Results",
	"party.rank": "Rank {rank}",
	"party.no_players": "No players yet.",
	"party.default_name": "Player",
	"party.not_connected": "Connect to the server first.",
	"party.ready": "Ready",
	"emote.hello": "Hello",
	"emote.nice": "Nice!",
	"emote.wow": "Wow!",
	"emote.gg": "Good game",
	"error.timeout": "The request timed out.",
	"error.network": "A network error occurred.",
	"error.connection_closed": "The connection closed.",
	"error.invalid_message": "The server sent an invalid response.",
	"error.invalid_code": "That room code is invalid.",
	"error.room_full": "The room is full.",
	"error.game_started": "The game has already started.",
	"error.name_required": "Enter a name.",
	"error.not_connected": "You are not connected.",
	"error.unknown": "An unknown error occurred.",
	"error.save": "Save error.",
}

var _language: String = DEFAULT_LANGUAGE

var language: String:
	get:
		return _language
	set(value):
		set_language(value)


func _ready() -> void:
	var stored: String = DEFAULT_LANGUAGE
	var store: Node = get_node_or_null("/root/SaveStore")
	if store != null and store.has_method("get_setting"):
		stored = str(store.call("get_setting", "language", DEFAULT_LANGUAGE))
	_language = _validate(stored)


func is_supported(lang: String) -> bool:
	return SUPPORTED_LANGUAGES.has(lang)


func _validate(lang: String) -> String:
	var clean: String = lang.strip_edges().to_lower()
	if clean.begins_with("tr"):
		return "tr"
	if clean.begins_with("en"):
		return "en"
	return DEFAULT_LANGUAGE


func set_language(lang: String, persist: bool = true) -> void:
	var clean: String = _validate(lang)
	var changed: bool = clean != _language
	_language = clean
	if persist:
		var store: Node = get_node_or_null("/root/SaveStore")
		if store != null and store.has_method("set_setting"):
			store.call("set_setting", "language", clean)
	if changed:
		language_changed.emit(clean)


func get_language() -> String:
	return _language


func t(key: String, args: Dictionary = {}) -> String:
	var table: Dictionary = UI_TR if _language == "tr" else UI_EN
	var text: String = str(table.get(key, key))
	if not args.is_empty():
		for k: Variant in args.keys():
			text = text.replace("{" + str(k) + "}", str(args[k]))
	return text


func has_key(key: String) -> bool:
	return UI_TR.has(key) or UI_EN.has(key)


func upper_letter(ch: String, lang: String = "") -> String:
	if ch.is_empty():
		return ""
	var use_lang: String = _language if lang.is_empty() else _validate(lang)
	if use_lang == "tr":
		match ch:
			"i":
				return "İ"
			"ı":
				return "I"
			"I":
				return "I"
			"İ":
				return "İ"
			"î":
				return "İ"
			_:
				return ch.to_upper()
	return ch.to_upper()


func lower_letter(ch: String, lang: String = "") -> String:
	if ch.is_empty():
		return ""
	var use_lang: String = _language if lang.is_empty() else _validate(lang)
	if use_lang == "tr":
		match ch:
			"I":
				return "ı"
			"İ":
				return "i"
			"i":
				return "i"
			"ı":
				return "ı"
			_:
				return ch.to_lower()
	return ch.to_lower()


func upper(text: String, lang: String = "") -> String:
	return normalize(text, lang)


func normalize(text: String, lang: String = "") -> String:
	var use_lang: String = _language if lang.is_empty() else _validate(lang)
	var out: String = ""
	var previous_space: bool = false
	for i: int in text.length():
		var ch: String = text.substr(i, 1)
		if ch == "\n" or ch == "\t" or ch == "\r" or ch == " ":
			if not previous_space and not out.is_empty():
				out += " "
				previous_space = true
			continue
		previous_space = false
		out += upper_letter(ch, use_lang)
	return out.strip_edges()


func lower(text: String, lang: String = "") -> String:
	var use_lang: String = _language if lang.is_empty() else _validate(lang)
	var out: String = ""
	for i: int in text.length():
		out += lower_letter(text.substr(i, 1), use_lang)
	return out


func alphabet(lang: String = "") -> String:
	var use_lang: String = _language if lang.is_empty() else _validate(lang)
	return TR_ALPHABET if use_lang == "tr" else EN_ALPHABET


func is_alphabet_letter(ch: String, lang: String = "") -> bool:
	if ch.length() != 1:
		return false
	return alphabet(lang).contains(ch)


func category_name(category_id: String) -> String:
	return t("category." + category_id)


func emote_name(emote_id: String) -> String:
	return t("emote." + emote_id)


func ui_dictionary(lang: String = "") -> Dictionary:
	var use_lang: String = _language if lang.is_empty() else _validate(lang)
	return (UI_TR if use_lang == "tr" else UI_EN).duplicate(true)

