#!/usr/bin/env python3
"""Download and build frequency word lists for English and Russian.

English: FrequencyWords (OpenSubtitles 2018) from hermitdave/FrequencyWords on GitHub.
Russian: Ozhegov dictionary (primary word source) with FrequencyWords for frequency scoring.
"""

import argparse
import re
import subprocess
from pathlib import Path

OUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "data"
MIN_LEN = 3
CUMULATIVE_CUTOFF = 0.95  # keep top 95% of total frequency mass
MIN_FREQ_FOR_UNVETTED = 50  # minimum frequency for words not in curated dictionaries

EN_RE = re.compile(r"^[a-z]+$")
RU_RE = re.compile(r"^[а-яё]+$")

FREQ_EN_URL = "https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018/en/en_full.txt"
ENABLE_URL = "https://raw.githubusercontent.com/dolph/dictionary/master/enable1.txt"
FREQ_RU_URL = "https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018/ru/ru_full.txt"
OZHEGOV_URL = "https://raw.githubusercontent.com/Layerex/ozhegov-dict/master/ozhegov.txt"


def _download(url: str) -> bytes:
    """Download a URL using curl (respects system proxy settings)."""
    result = subprocess.run(
        ["curl", "-sL", url],
        capture_output=True,
        timeout=600,
    )
    if result.returncode != 0:
        raise RuntimeError(f"curl failed for {url}: {result.stderr.decode()}")
    return result.stdout


def _parse_freq_lines(raw: str, pattern: re.Pattern, normalise=None) -> list[tuple[str, int]]:
    """Parse 'word freq' lines, filtering by regex."""
    words: list[tuple[str, int]] = []
    for line in raw.splitlines():
        parts = line.split()
        if len(parts) != 2:
            continue
        word = parts[0].lower()
        if normalise:
            word = normalise(word)
        try:
            count = int(parts[1])
        except ValueError:
            continue
        if len(word) >= MIN_LEN and pattern.match(word):
            words.append((word, count))
    return words


def _apply_cumulative_cutoff(words: list[tuple[str, int]]) -> list[tuple[str, int]]:
    """Sort by frequency desc and keep top CUMULATIVE_CUTOFF of total mass."""
    words.sort(key=lambda x: x[1], reverse=True)
    total = sum(c for _, c in words)
    cumulative = 0
    keep: list[tuple[str, int]] = []
    for word, count in words:
        keep.append((word, count))
        cumulative += count
        if cumulative / total >= CUMULATIVE_CUTOFF:
            break
    return keep


def _write_csv(words: list[tuple[str, int]], path: Path) -> None:
    with open(path, "w", encoding="utf-8") as f:
        f.write("Word,FREQcount\n")
        for word, count in words:
            f.write(f"{word},{count}\n")
    print(f"  Wrote {len(words)} words to {path}")


# --- English ---

def _load_enable_words() -> set[str]:
    """Download ENABLE word list (standard word-game dictionary)."""
    print("[en] Downloading ENABLE word list ...")
    raw = _download(ENABLE_URL).decode("utf-8")
    words = {w.strip().lower() for w in raw.splitlines() if w.strip()}
    print(f"[en] Loaded {len(words)} ENABLE dictionary words")
    return words


def build_english() -> None:
    enable = _load_enable_words()

    print("[en] Downloading FrequencyWords English list ...")
    raw = _download(FREQ_EN_URL).decode("utf-8")
    all_words = _parse_freq_lines(raw, EN_RE)
    freq_map = {w: c for w, c in all_words}

    # Spawn dataset: ENABLE ∩ FrequencyWords, with cumulative cutoff
    words = [(w, c) for w, c in all_words if w in enable]
    print(f"[en] Parsed {len(all_words)} valid words, {len(words)} in ENABLE")
    keep = _apply_cumulative_cutoff(words)
    _write_csv(keep, OUT_DIR / "words.en.csv")

    # Full validation dataset: ENABLE ∪ FrequencyWords (filtered)
    full_words: dict[str, int] = {}
    for w in enable:
        if len(w) >= MIN_LEN and EN_RE.match(w):
            full_words[w] = freq_map.get(w, 1)
    for w, c in all_words:
        if w not in full_words and c >= MIN_FREQ_FOR_UNVETTED:
            full_words[w] = c
    full_list = sorted(full_words.items(), key=lambda x: x[1], reverse=True)
    print(f"[en] Full validation dataset: {len(full_list)} words")
    _write_csv(full_list, OUT_DIR / "words.en.full.csv")


# --- Russian ---

def _load_ozhegov_words() -> set[str]:
    """Download Ozhegov dictionary and extract headwords."""
    print("[ru] Downloading Ozhegov dictionary ...")
    raw = _download(OZHEGOV_URL).decode("utf-8")
    words: set[str] = set()
    for line in raw.splitlines():
        if line.startswith("VOCAB|"):
            continue  # skip header
        parts = line.split("|")
        if parts:
            word = parts[0].strip().lower().replace("ё", "е")
            if word and RU_RE.match(word):
                words.add(word)
    print(f"[ru] Loaded {len(words)} Ozhegov dictionary words")
    return words


def _load_freq_ru() -> dict[str, int]:
    """Download FrequencyWords Russian list and return word->frequency map."""
    print("[ru] Downloading FrequencyWords Russian list ...")
    raw = _download(FREQ_RU_URL).decode("utf-8")
    freq_map: dict[str, int] = {}
    for line in raw.splitlines():
        parts = line.split()
        if len(parts) != 2:
            continue
        word = parts[0].lower().replace("ё", "е")
        try:
            count = int(parts[1])
        except ValueError:
            continue
        if len(word) >= MIN_LEN and RU_RE.match(word):
            freq_map[word] = count
    print(f"[ru] Loaded {len(freq_map)} frequency entries")
    return freq_map


def build_russian(skip_ozhegov: bool = False) -> None:
    if skip_ozhegov:
        # Fallback: frequency-only mode (no Ozhegov)
        print("[ru] Downloading FrequencyWords Russian list ...")
        raw = _download(FREQ_RU_URL).decode("utf-8")
        normalise_ru = lambda w: w.replace("ё", "е")
        words = _parse_freq_lines(raw, RU_RE, normalise=normalise_ru)
        print(f"[ru] Parsed {len(words)} valid words (no Ozhegov filter)")
        keep = _apply_cumulative_cutoff(words)
        _write_csv(keep, OUT_DIR / "words.ru.csv")
        # Full dataset same as spawn when no Ozhegov
        _write_csv(words, OUT_DIR / "words.ru.full.csv")
        return

    # Primary source: Ozhegov dictionary
    try:
        ozhegov_words = _load_ozhegov_words()
    except Exception as e:
        print(f"[ru] ERROR: Ozhegov download failed ({e}), falling back to frequency-only")
        build_russian(skip_ozhegov=True)
        return

    # Frequency data for scoring
    freq_map = _load_freq_ru()

    # Spawn dataset: Ozhegov words with frequency
    DEFAULT_FREQ = 1  # rare/unscored words get minimum frequency (highest score)
    words: list[tuple[str, int]] = []
    for word in sorted(ozhegov_words):
        if len(word) >= MIN_LEN:
            words.append((word, freq_map.get(word, DEFAULT_FREQ)))

    print(f"[ru] {len(words)} Ozhegov words (>={MIN_LEN} chars), "
          f"{sum(1 for _, f in words if f > DEFAULT_FREQ)} with frequency data")
    _write_csv(words, OUT_DIR / "words.ru.csv")

    # Full validation dataset: Ozhegov ∪ FrequencyWords (filtered)
    full_words: dict[str, int] = {}
    for w in ozhegov_words:
        if len(w) >= MIN_LEN:
            full_words[w] = freq_map.get(w, DEFAULT_FREQ)
    for w, c in freq_map.items():
        if w not in full_words and len(w) >= MIN_LEN and RU_RE.match(w) and c >= MIN_FREQ_FOR_UNVETTED:
            full_words[w] = c
    full_list = sorted(full_words.items(), key=lambda x: x[1], reverse=True)
    print(f"[ru] Full validation dataset: {len(full_list)} words")
    _write_csv(full_list, OUT_DIR / "words.ru.full.csv")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Build word frequency lists")
    parser.add_argument("--lang", choices=["en", "ru", "all"], default="all")
    parser.add_argument("--skip-ozhegov", action="store_true",
                        help="Skip Ozhegov cross-reference for Russian")
    args = parser.parse_args()

    OUT_DIR.mkdir(parents=True, exist_ok=True)

    if args.lang in ("en", "all"):
        build_english()
    if args.lang in ("ru", "all"):
        build_russian(skip_ozhegov=args.skip_ozhegov)
