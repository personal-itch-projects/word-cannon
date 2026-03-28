extends Node

const MIN_WORD_LENGTH := 3

var anagram_table: Dictionary = {}   # sorted_key -> Array[{word, frequency}]
var language: String = "en"           # "en" or "ru"

signal language_changed(lang: String)

func _ready() -> void:
	load_dictionary(language)

func load_dictionary(lang: String) -> void:
	language = lang
	anagram_table.clear()
	if lang == "en":
		_load_english()
	else:
		_load_russian()
	language_changed.emit(lang)

func _load_english() -> void:
	var file := FileAccess.open("res://assets/data/SUBTLEXfreqPoS-sorted.csv", FileAccess.READ)
	if file == null:
		push_error("Failed to open English dictionary")
		return
	file.get_line()  # skip header
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty():
			continue
		var parts := line.split(",")
		if parts.size() < 2:
			continue
		var word := parts[0].to_lower()
		var freq := int(parts[1])
		if word.length() < MIN_WORD_LENGTH:
			continue
		if not _is_alpha(word):
			continue
		var key := _sort_letters(word)
		if not anagram_table.has(key):
			anagram_table[key] = []
		anagram_table[key].append({"word": word, "frequency": freq})

func _load_russian() -> void:
	var file := FileAccess.open("res://assets/data/lemma.num", FileAccess.READ)
	if file == null:
		push_error("Failed to open Russian dictionary")
		return
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty():
			continue
		var parts := line.replace("\t", " ").split(" ", false)
		if parts.size() < 3:
			continue
		var word := parts[2]
		var freq := int(float(parts[1]))
		if word.length() < MIN_WORD_LENGTH:
			continue
		if not _is_cyrillic(word):
			continue
		var key := _sort_letters(word)
		if not anagram_table.has(key):
			anagram_table[key] = []
		anagram_table[key].append({"word": word, "frequency": freq})

func _is_alpha(text: String) -> bool:
	for i in text.length():
		var c := text.unicode_at(i)
		if c < 97 or c > 122:  # a-z
			return false
	return true

func _is_cyrillic(text: String) -> bool:
	for i in text.length():
		var c := text.unicode_at(i)
		# а-я (0x0430-0x044F), ё (0x0451), А-Я (0x0410-0x042F), Ё (0x0401)
		if not ((c >= 0x0430 and c <= 0x044F) or c == 0x0451 or (c >= 0x0410 and c <= 0x042F) or c == 0x0401):
			return false
	return true

func _sort_letters(text: String) -> String:
	var chars: Array = []
	for i in text.length():
		chars.append(text[i])
	chars.sort()
	return "".join(chars)

func find_word(letters: Array[String]) -> Variant:
	var combined := "".join(letters).to_lower()
	var key := _sort_letters(combined)
	if not anagram_table.has(key):
		return null
	var matches: Array = anagram_table[key]
	var best: Dictionary = matches[0]
	for i in range(1, matches.size()):
		if matches[i]["frequency"] > best["frequency"]:
			best = matches[i]
	return best

func get_alphabet() -> String:
	if language == "en":
		return "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	else:
		return "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ"
