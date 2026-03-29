extends Node

const MIN_WORD_LENGTH := 3

const ENGLISH_LETTER_FREQ: Dictionary = {
	"e": 12.70, "t": 9.06, "a": 8.17, "o": 7.51, "i": 6.97,
	"n": 6.75, "s": 6.33, "h": 6.09, "r": 5.99, "d": 4.25,
	"l": 4.03, "c": 2.78, "u": 2.76, "m": 2.41, "w": 2.36,
	"f": 2.23, "g": 2.02, "y": 1.97, "p": 1.93, "b": 1.29,
	"v": 0.98, "k": 0.77, "j": 0.15, "x": 0.15, "q": 0.10,
	"z": 0.07,
}

const RUSSIAN_LETTER_FREQ: Dictionary = {
	"о": 10.97, "е": 8.45, "а": 8.01, "и": 7.35, "н": 6.70,
	"т": 6.26, "с": 5.47, "р": 4.73, "в": 4.54, "л": 4.40,
	"к": 3.49, "м": 3.21, "д": 2.98, "п": 2.81, "у": 2.62,
	"я": 2.01, "ы": 1.90, "ь": 1.74, "г": 1.69, "з": 1.64,
	"б": 1.59, "ч": 1.44, "й": 1.21, "х": 0.97, "ж": 0.94,
	"ш": 0.73, "ю": 0.64, "ц": 0.48, "щ": 0.36, "э": 0.32,
	"ф": 0.26, "ъ": 0.04, "ё": 0.04,
}

var anagram_table: Dictionary = {}   # sorted_key -> Array[{word, frequency}]
var word_table: Dictionary = {}      # word -> frequency (exact match)
var letter_count_table: Dictionary = {} # word -> {letter -> count}
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
	letter_count_table.clear()
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
		letter_count_table[word] = _count_letters(word)
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

func _count_letters(text: String) -> Dictionary:
	var counts: Dictionary = {}
	for i in text.length():
		var c := text[i]
		counts[c] = counts.get(c, 0) + 1
	return counts

func _is_multiset_subset(subset: Dictionary, superset: Dictionary) -> bool:
	for c in subset:
		if superset.get(c, 0) < subset[c]:
			return false
	return true

func find_possible_words(letters: Array[String]) -> Array:
	var flock_counts := _count_letters("".join(letters).to_lower())
	var results: Array = []
	for word in word_table:
		if word.length() > letters.size():
			continue
		if _is_multiset_subset(letter_count_table[word], flock_counts):
			results.append({"word": word, "frequency": word_table[word]})
	return results

func filter_possible_words(possible_words: Array, letters: Array[String]) -> Array:
	var flock_counts := _count_letters("".join(letters).to_lower())
	var results: Array = []
	for entry in possible_words:
		if _is_multiset_subset(letter_count_table[entry["word"]], flock_counts):
			results.append(entry)
	return results

func can_form_word_with_additions(letters: Array[String]) -> bool:
	# Check if ANY dictionary word contains the current letters as a subset
	# (i.e. the player could add more letters to eventually form a word)
	var flock_counts := _count_letters("".join(letters).to_lower())
	for word in word_table:
		if word.length() < letters.size():
			continue
		if _is_multiset_subset(flock_counts, letter_count_table[word]):
			return true
	return false

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
	var freq_table: Dictionary = ENGLISH_LETTER_FREQ if language == "en" else RUSSIAN_LETTER_FREQ
	# Collect letters that actually appear in loaded dictionary words
	var dict_letters: Dictionary = {}
	for word in word_table:
		for i in word.length():
			dict_letters[word[i]] = true
	# Assign corpus-based weights, filtered to dictionary letters only
	for c in freq_table:
		if dict_letters.has(c):
			letter_weights[c] = freq_table[c]
			_weight_total += freq_table[c]
	# Build alphabet from letters found in the dictionary
	var chars: Array = letter_weights.keys()
	chars.sort()
	_alphabet = "".join(chars).to_upper()

func pick_partial_word(gaps: int) -> Array[String]:
	var min_len := gaps + MIN_WORD_LENGTH
	var candidates: Array = []
	var total_weight := 0.0
	for word in word_table:
		if word.length() >= min_len:
			var w := log(maxf(float(word_table[word]), 1.0)) + 1.0
			candidates.append({"word": word, "weight": w})
			total_weight += w
	if candidates.is_empty():
		return []
	var roll := randf() * total_weight
	var acc := 0.0
	var chosen_word: String = candidates[0]["word"]
	for c in candidates:
		acc += c["weight"]
		if roll <= acc:
			chosen_word = c["word"]
			break
	var all_indices: Array = []
	for i in chosen_word.length():
		all_indices.append(i)
	all_indices.shuffle()
	var remove_indices: Array = all_indices.slice(0, gaps)
	var kept_letters: Array[String] = []
	for i in chosen_word.length():
		if not remove_indices.has(i):
			kept_letters.append(chosen_word[i].to_upper())
	return kept_letters
