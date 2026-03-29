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

var word_table: Dictionary = {}      # word -> frequency (exact match)
var letter_count_table: Dictionary = {} # word -> {letter -> count}
var language: String = "en"           # "en" or "ru"
var letter_weights: Dictionary = {}   # letter -> float weight
var _weight_total: float = 0.0
var _alphabet: String = ""

# Trie: each node is { "c": { char -> node }, "w": "" or word_string }
var _trie_root: Dictionary = {}

# DFS state for find_longest_word
var _best_length: int = 0
var _best_word: String = ""
var _best_freq: int = 0
var _weight_sum: float = 0.0

# DFS state for count_reachable_words
var _count_result: int = 0

signal language_changed(lang: String)

func _ready() -> void:
	load_dictionary(language)

func load_dictionary(lang: String) -> void:
	language = lang
	word_table.clear()
	letter_count_table.clear()
	_trie_root = {"c": {}, "w": ""}
	var path := "res://assets/data/words.%s.csv" % lang
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
		word_table[word] = freq
		letter_count_table[word] = _count_letters(word)
		_trie_insert(word)
	_compute_letter_weights()
	language_changed.emit(lang)

func _trie_insert(word: String) -> void:
	var node := _trie_root
	for i in word.length():
		var ch := word[i]
		if not node["c"].has(ch):
			node["c"][ch] = {"c": {}, "w": ""}
		node = node["c"][ch]
	node["w"] = word

func find_exact_word(letters: Array[String]) -> Dictionary:
	if letters.size() < MIN_WORD_LENGTH:
		return {}
	var budget: Dictionary = {}
	for l in letters:
		var ch := l.to_lower()
		budget[ch] = budget.get(ch, 0) + 1
	_best_word = ""
	_best_freq = 0
	_weight_sum = 0.0
	_trie_dfs_exact(_trie_root, budget, 0, letters.size())
	if _best_word.is_empty():
		return {}
	return {"word": _best_word, "frequency": _best_freq}

func _trie_dfs_exact(node: Dictionary, budget: Dictionary, depth: int, target_len: int) -> void:
	if depth == target_len:
		if not node["w"].is_empty():
			var freq: int = word_table[node["w"]]
			var weight: float = float(freq)
			_weight_sum += weight
			if randf() < weight / _weight_sum:
				_best_word = node["w"]
				_best_freq = freq
		return
	for ch in node["c"]:
		if budget.get(ch, 0) > 0:
			budget[ch] -= 1
			_trie_dfs_exact(node["c"][ch], budget, depth + 1, target_len)
			budget[ch] += 1

func find_longest_word(letters: Array[String]) -> Dictionary:
	# Build letter budget: char -> count
	var budget: Dictionary = {}
	for l in letters:
		var ch := l.to_lower()
		budget[ch] = budget.get(ch, 0) + 1
	_best_length = 0
	_best_word = ""
	_best_freq = 0
	_weight_sum = 0.0
	_trie_dfs(_trie_root, budget, 0)
	if _best_word.is_empty():
		return {}
	return {"word": _best_word, "frequency": _best_freq}

func _trie_dfs(node: Dictionary, budget: Dictionary, depth: int) -> void:
	if not node["w"].is_empty() and depth >= MIN_WORD_LENGTH:
		var freq: int = word_table[node["w"]]
		var weight: float = float(freq)
		if depth > _best_length:
			_best_length = depth
			_best_word = node["w"]
			_best_freq = freq
			_weight_sum = weight
		elif depth == _best_length:
			_weight_sum += weight
			if randf() < weight / _weight_sum:
				_best_word = node["w"]
				_best_freq = freq
	for ch in node["c"]:
		if budget.get(ch, 0) > 0:
			budget[ch] -= 1
			_trie_dfs(node["c"][ch], budget, depth + 1)
			budget[ch] += 1

func can_form_any_word(letters: Array[String]) -> bool:
	var budget: Dictionary = {}
	for l in letters:
		var ch := l.to_lower()
		budget[ch] = budget.get(ch, 0) + 1
	return _trie_any(_trie_root, budget, 0)

func _trie_any(node: Dictionary, budget: Dictionary, depth: int) -> bool:
	if not node["w"].is_empty() and depth >= MIN_WORD_LENGTH:
		return true
	for ch in node["c"]:
		if budget.get(ch, 0) > 0:
			budget[ch] -= 1
			if _trie_any(node["c"][ch], budget, depth + 1):
				budget[ch] += 1
				return true
			budget[ch] += 1
	return false

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

func count_reachable_words(budget: Dictionary) -> int:
	_count_result = 0
	_trie_count_dfs(_trie_root, budget, 0)
	return _count_result

func _trie_count_dfs(node: Dictionary, budget: Dictionary, depth: int) -> void:
	if not node["w"].is_empty() and depth >= MIN_WORD_LENGTH:
		_count_result += 1
	for ch in node["c"]:
		if budget.get(ch, 0) > 0:
			budget[ch] -= 1
			_trie_count_dfs(node["c"][ch], budget, depth + 1)
			budget[ch] += 1

# Slot-aware letter selection: scores each candidate letter by how many
# flocks it helps, weighted by slot urgency, then samples proportionally.
# Falls back to frequency-based weights when no flocks exist or scores are low.
const SLOT_SCORE_THRESHOLD := 5.0

func pick_slot_aware_letter(flock_letter_arrays: Array, allowed: String) -> String:
	if allowed.is_empty():
		return ""

	var scores: Dictionary = {}
	var total_slot_score := 0.0

	for flock_letters in flock_letter_arrays:
		# Build budget from flock's current letters
		var budget: Dictionary = {}
		for l in flock_letters:
			var ch: String = l.to_lower()
			budget[ch] = budget.get(ch, 0) + 1

		var baseline := count_reachable_words(budget)
		var empty_spaces := maxi(MIN_WORD_LENGTH - flock_letters.size(), 1)
		var urgency := 1.0 / float(empty_spaces)

		# Score each candidate letter by marginal value for this flock
		for i in allowed.length():
			var ch := allowed[i].to_lower()
			budget[ch] = budget.get(ch, 0) + 1
			var reachable_with := count_reachable_words(budget)
			budget[ch] -= 1
			if budget[ch] == 0:
				budget.erase(ch)

			var marginal := reachable_with - baseline
			if marginal > 0:
				var contribution := float(marginal) * urgency
				scores[ch] = scores.get(ch, 0.0) + contribution
				total_slot_score += contribution

	# Blend slot scores with frequency weights (smooth transition)
	var alpha := minf(1.0, total_slot_score / SLOT_SCORE_THRESHOLD) if total_slot_score > 0.0 else 0.0

	var total := 0.0
	for i in allowed.length():
		var ch := allowed[i].to_lower()
		var w: float = alpha * scores.get(ch, 0.0) + (1.0 - alpha) * letter_weights.get(ch, 1.0)
		total += w

	if total <= 0.0:
		return pick_weighted_letter(allowed)

	var roll := randf() * total
	var acc := 0.0
	for i in allowed.length():
		var ch := allowed[i].to_lower()
		var w: float = alpha * scores.get(ch, 0.0) + (1.0 - alpha) * letter_weights.get(ch, 1.0)
		acc += w
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
