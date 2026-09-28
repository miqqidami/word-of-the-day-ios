#!/usr/bin/env python3
"""Builds Shared/WordData/turkish_words.json from tools/word-source/*.txt.

The JSON array order IS the daily schedule: day N shows entry N. To keep the
"never repeat a shown word" guarantee, this script is append-only:

- words already in the JSON keep their position (their content is refreshed);
- new words are shuffled (fixed seed) and appended to the end;
- removing a word that is already scheduled is refused.

Usage: python3 tools/build_words.py
"""

import json
import random
import re
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE_DIR = ROOT / "tools" / "word-source"
OUTPUT = ROOT / "Shared" / "WordData" / "turkish_words.json"
SHUFFLE_SEED = 20260929
LEVELS = {"A1", "A2", "B1", "B2"}
PARTS_OF_SPEECH = {"noun", "verb", "adjective", "adverb", "expression"}
MIN_EXAMPLES = 3

TURKISH_ASCII = str.maketrans("çğıöşüâîû", "cgiosuaiu")


def slugify(word: str) -> str:
    lowered = word.replace("I", "ı").replace("İ", "i").lower().translate(TURKISH_ASCII)
    lowered = unicodedata.normalize("NFKD", lowered).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "-", lowered).strip("-")


def parse_file(path: Path) -> list[dict]:
    entries: list[dict] = []
    current: dict | None = None

    for number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        where = f"{path.name}:{number}"
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue

        if raw.startswith("  "):
            if current is None:
                sys.exit(f"{where}: example sentence before any word")
            parts = raw.strip().split(" = ")
            if len(parts) != 2 or not all(p.strip() for p in parts):
                sys.exit(f"{where}: expected 'Turkish = English'")
            current["examples"].append({"tr": parts[0].strip(), "en": parts[1].strip()})
            continue

        fields = [f.strip() for f in raw.split(" | ")]
        if len(fields) != 5:
            sys.exit(f"{where}: expected 'word | meaning | pos | level | tip'")
        word, meaning, pos, level, tip = fields
        if pos not in PARTS_OF_SPEECH:
            sys.exit(f"{where}: unknown part of speech '{pos}'")
        if level not in LEVELS:
            sys.exit(f"{where}: unknown level '{level}'")

        current = {
            "id": slugify(word),
            "word": word,
            "meaning": meaning,
            "partOfSpeech": pos,
            "level": level,
            "tip": tip,
            "examples": [],
        }
        entries.append(current)

    return entries


def main() -> None:
    words: dict[str, dict] = {}
    for path in sorted(SOURCE_DIR.glob("*.txt")):
        for entry in parse_file(path):
            if entry["id"] in words:
                sys.exit(f"duplicate word '{entry['word']}' in {path.name}")
            if len(entry["examples"]) < MIN_EXAMPLES:
                sys.exit(f"'{entry['word']}' needs at least {MIN_EXAMPLES} examples")
            words[entry["id"]] = entry

    existing_order: list[str] = []
    if OUTPUT.exists():
        existing_order = [item["id"] for item in json.loads(OUTPUT.read_text(encoding="utf-8"))]

    missing = [word_id for word_id in existing_order if word_id not in words]
    if missing:
        sys.exit(
            "refusing to drop already-scheduled words (it would shift the daily "
            f"schedule and cause repeats): {', '.join(missing)}"
        )

    new_ids = sorted(word_id for word_id in words if word_id not in set(existing_order))
    random.Random(SHUFFLE_SEED + len(existing_order)).shuffle(new_ids)
    order = existing_order + new_ids

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(
        json.dumps([words[word_id] for word_id in order], ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"{len(order)} words ({len(new_ids)} new) -> {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
