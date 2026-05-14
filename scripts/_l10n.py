#!/usr/bin/env python3
"""
String Catalog (.xcstrings) mutator. Backs add-l10n.sh and remove-l10n.sh.

Locates MyRadio/Localizable.xcstrings relative to the repo root. Creates the
file on the first `add` call. Source language is English; the KEY itself is
used as the en value unless --en is passed explicitly.

Output is Xcode-compatible: UTF-8 (no \\u escapes), 2-space indent,
sorted keys, trailing newline.
"""

import json
import os
import sys
from pathlib import Path
from typing import Optional

CATALOG_REL_PATH = Path("MyRadio/Localizable.xcstrings")
SOURCE_LANGUAGE = "en"
CATALOG_VERSION = "1.0"


def repo_root() -> Path:
    """Walk up from this file looking for the .git directory."""
    here = Path(__file__).resolve()
    for parent in [here.parent, *here.parents]:
        if (parent / ".git").exists():
            return parent
    sys.exit("error: could not locate repo root (no .git/ ancestor of script)")


def catalog_path() -> Path:
    # MYRADIO_CATALOG_PATH lets tests redirect to a tempfile.
    override = os.environ.get("MYRADIO_CATALOG_PATH")
    if override:
        return Path(override)
    return repo_root() / CATALOG_REL_PATH


def load_catalog() -> dict:
    path = catalog_path()
    if not path.exists():
        return {
            "sourceLanguage": SOURCE_LANGUAGE,
            "strings": {},
            "version": CATALOG_VERSION,
        }
    try:
        with path.open("r", encoding="utf-8") as f:
            return json.load(f)
    except json.JSONDecodeError as e:
        sys.exit(f"error: catalog at {path} is not valid JSON: {e}")


def save_catalog(catalog: dict) -> None:
    path = catalog_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    text = json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True)
    with path.open("w", encoding="utf-8") as f:
        f.write(text + "\n")


def make_unit(value: str) -> dict:
    return {"stringUnit": {"state": "translated", "value": value}}


def cmd_add(key: str, comment: Optional[str], locales: list[tuple[str, str]]) -> None:
    catalog = load_catalog()
    strings = catalog.setdefault("strings", {})
    entry = strings.get(key, {})
    entry["extractionState"] = "manual"
    if comment is not None:
        entry["comment"] = comment

    localizations = entry.setdefault("localizations", {})
    explicit_en = next((v for code, v in locales if code == SOURCE_LANGUAGE), None)
    localizations[SOURCE_LANGUAGE] = make_unit(explicit_en if explicit_en is not None else key)

    for code, value in locales:
        if code == SOURCE_LANGUAGE:
            continue
        localizations[code] = make_unit(value)

    strings[key] = entry
    save_catalog(catalog)
    rel = catalog_path()
    try:
        rel = rel.relative_to(repo_root())
    except ValueError:
        pass
    print(f"ok: '{key}' → {rel} ({len(localizations)} locales)")


def cmd_remove(key: str, locale: Optional[str]) -> None:
    catalog = load_catalog()
    strings = catalog.get("strings", {})
    if key not in strings:
        sys.exit(f"error: key '{key}' not found in catalog")

    if locale:
        if locale == SOURCE_LANGUAGE:
            sys.exit(f"error: cannot remove source locale '{SOURCE_LANGUAGE}' — remove the whole key instead")
        localizations = strings[key].get("localizations", {})
        if locale not in localizations:
            sys.exit(f"error: locale '{locale}' not present for key '{key}'")
        del localizations[locale]
        save_catalog(catalog)
        print(f"ok: removed locale '{locale}' from '{key}'")
    else:
        del strings[key]
        save_catalog(catalog)
        print(f"ok: removed key '{key}' from catalog")


def parse_add_argv(argv: list[str]):
    if not argv or argv[0].startswith("-"):
        sys.exit("usage: add-l10n.sh KEY [--comment TEXT] [--LOCALE VALUE]...")
    key = argv[0]
    comment: Optional[str] = None
    locales: list[tuple[str, str]] = []
    i = 1
    while i < len(argv):
        flag = argv[i]
        if not flag.startswith("--"):
            sys.exit(f"error: expected --LOCALE flag, got '{flag}'")
        name = flag[2:]
        if not name:
            sys.exit("error: empty flag '--'")
        if i + 1 >= len(argv):
            sys.exit(f"error: flag '{flag}' has no value")
        value = argv[i + 1]
        if name == "comment":
            comment = value
        else:
            locales.append((name, value))
        i += 2
    return key, comment, locales


def parse_remove_argv(argv: list[str]):
    if not argv or argv[0].startswith("-"):
        sys.exit("usage: remove-l10n.sh KEY [--locale CODE]")
    key = argv[0]
    locale: Optional[str] = None
    i = 1
    while i < len(argv):
        flag = argv[i]
        if flag != "--locale":
            sys.exit(f"error: unknown flag '{flag}' (only --locale supported)")
        if i + 1 >= len(argv):
            sys.exit("error: --locale requires a value")
        locale = argv[i + 1]
        i += 2
    return key, locale


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit("usage: _l10n.py {add|remove} ...")
    mode, *rest = sys.argv[1:]
    if mode == "add":
        key, comment, locales = parse_add_argv(rest)
        cmd_add(key, comment, locales)
    elif mode == "remove":
        key, locale = parse_remove_argv(rest)
        cmd_remove(key, locale)
    else:
        sys.exit(f"error: unknown mode '{mode}' (expected 'add' or 'remove')")


if __name__ == "__main__":
    main()
