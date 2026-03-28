extends Node

const MIN_WORD_LENGTH := 3

var anagram_table: Dictionary = {}   # sorted_key -> Array[{word, frequency}]
var word_table: Dictionary = {}      # word -> frequency (exact match)
var language: String = "en"           # "en" or "ru"
var letter_weights: Dictionary = {}   # letter -> float weight
var _weight_total: float = 0.0
var _alphabet: String = ""

signal language_changed(lang: String)

func _ready() -> void:
	load_dictionary(language)

func load_dictionary(lang: String) -> void:
	language = lang
	anagram_table.clear()
	word_table.clear()
	var path := "res://assets/data/%s.%s.csv" % [GameManager.datasource, lang]
	var check_fn: Callable = _is_alpha if lang == "en" else _is_cyrillic
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open dictionary: " + path)
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
		if not check_fn.call(word):
			continue
		var key := _sort_letters(word)
		if not anagram_table.has(key):
			anagram_table[key] = []
		anagram_table[key].append({"word": word, "frequency": freq})
		word_table[word] = freq
	_compute_letter_weights()
	language_changed.emit(lang)

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
	if not word_table.has(combined):
		return null
	return {"word": combined, "frequency": word_table[combined]}

func get_alphabet() -> String:
	return _alphabet

func pick_weighted_letter(allowed: String) -> String:
	if allowed.is_empty():
		return ""
	var total := 0.0
	for i in allowed.length():
		total += letter_weights.get(allowed[i].to_lower(), 1.0)
	var roll := randf() * total
	var acc := 0.0
	for i in allowed.length():
		acc += letter_weights.get(allowed[i].to_lower(), 1.0)
		if roll <= acc:
			return allowed[i]
	return allowed[allowed.length() - 1]

func _compute_letter_weights() -> void:
	letter_weights.clear()
	_weight_total = 0.0
	for key in anagram_table:
		for entry in anagram_table[key]:
			var word: String = entry["word"]
			var freq: int = entry["frequency"]
			var w: float = log(maxf(float(freq), 1.0)) + 1.0
			for i in word.length():
				var c: String = word[i]
				letter_weights[c] = letter_weights.get(c, 0.0) + w
	for c in letter_weights:
		_weight_total += letter_weights[c]
	# Build alphabet from letters found in the dictionary
	var chars: Array = letter_weights.keys()
	chars.sort()
	_alphabet = "".join(chars).to_upper()
