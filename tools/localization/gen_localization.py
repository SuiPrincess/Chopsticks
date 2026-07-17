#!/usr/bin/env python3
"""Generate .strings files and verify translation coverage.

1. Re-extract every Japanese-containing string literal from app sources.
2. Normalize Swift interpolations to the localization key form
   (\\(IntExpr) -> %lld, \\(StringExpr) -> %@) using an expression type map.
3. Verify every key has an entry in TRANSLATIONS (and report unused entries).
4. Emit en.lproj/Localizable.strings, ja.lproj stub, and InfoPlist.strings.
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from extract_strings import extract_literals  # noqa: E402
from translations import TRANSLATIONS, INFO_PLIST  # noqa: E402

ROOT = Path(__file__).resolve().parents[2] / "Chopsticks"
JP = re.compile(r"[぀-ヿ㐀-鿿！-｠]")

INT_HINTS = ("count", "Count", "level", "Level", "streak", "Streak", "wins",
             "losses", "turn", "Turn", "+ 1", "min(", "$0", "freeHints",
             "fingerCount", "total", "Total", "required", "index", "Wins")
STRING_EXPRS = {
    "text", "name", "mode", "position", "state", "config.aiDifficulty.label",
    "DailyChallenge.title()", "player.name", "appVersion",
    "premium.displayPrice", "product.displayPrice", "rewardTheme.name",
}


def placeholder(expr):
    expr = expr.strip()
    if expr in STRING_EXPRS:
        return "%@"
    if any(h in expr for h in INT_HINTS):
        return "%lld"
    return None  # unknown


def normalize(buf):
    """buf: list of (kind, value) from extract_literals -> key string or (None, expr)."""
    out = []
    for kind, val in buf:
        if kind == "CHAR":
            # unescape swift escapes for the key form
            if val in ("\\n",):
                out.append("\n")
            elif val.startswith("\\"):
                out.append(val[1:])
            else:
                out.append(val)
        else:
            ph = placeholder(val)
            if ph is None:
                return None, val
            out.append(ph)
    return "".join(out), None


def escape_strings(s):
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def main():
    keys = {}
    problems = []
    for f in sorted(ROOT.rglob("*.swift")):
        if "ChopsticksTests" in str(f) or ".xcodeproj" in str(f):
            continue
        text = f.read_text()
        for pos, buf in extract_literals(text):
            raw = "".join(v if k == "CHAR" else "\\(...)" for k, v in buf)
            if not JP.search(raw):
                continue
            key, unknown = normalize(buf)
            if key is None:
                line = text[:pos].count("\n") + 1
                problems.append(f"{f.name}:{line}: unknown interpolation type: {unknown}")
                continue
            keys.setdefault(key, []).append(f.name)

    missing = [k for k in keys if k not in TRANSLATIONS]
    unused = [k for k in TRANSLATIONS if JP.search(k) and k not in keys]

    if problems:
        print("INTERPOLATION PROBLEMS:")
        for p in problems:
            print(" -", p)
    if missing:
        print("MISSING TRANSLATIONS:")
        for k in sorted(missing):
            print(f" - {k!r}  (in {', '.join(sorted(set(keys[k])))})")
    if unused:
        print("UNUSED TRANSLATION KEYS:")
        for k in sorted(unused):
            print(f" - {k!r}")
    if problems or missing:
        sys.exit(1)

    # ---- emit files ----
    en = ROOT / "en.lproj/Localizable.strings"
    ja = ROOT / "ja.lproj/Localizable.strings"
    en.parent.mkdir(exist_ok=True)
    ja.parent.mkdir(exist_ok=True)

    lines = ["/* Chopsticks — English localization.",
             "   Keys are the Japanese source strings (see CLAUDE.md). */", ""]
    for k in sorted(TRANSLATIONS):
        lines.append(f'"{escape_strings(k)}" = "{escape_strings(TRANSLATIONS[k])}";')
    en.write_text("\n".join(lines) + "\n")

    # ja: キー=値の恒等エントリを明示的に出力する。
    # （空ファイル＋キーフォールバック仕様に依存しないための堅牢化）
    ja_lines = ["/* 日本語: キーが日本語原文のため恒等マッピング（自動生成） */", ""]
    for k in sorted(TRANSLATIONS):
        ja_lines.append(f'"{escape_strings(k)}" = "{escape_strings(k)}";')
    ja.write_text("\n".join(ja_lines) + "\n")

    (ROOT / "en.lproj/InfoPlist.strings").write_text(
        "\n".join(f'"{k}" = "{escape_strings(v)}";' for k, v in INFO_PLIST.items()) + "\n"
    )
    (ROOT / "ja.lproj/InfoPlist.strings").write_text(
        "/* 日本語のInfo.plist文字列はビルド設定（INFOPLIST_KEY_*）の値を使う。 */\n"
    )

    print(f"OK: {len(TRANSLATIONS)} translations, {len(keys)} JP keys in code, "
          f"{len(unused)} unused, 0 missing")
    print(f"wrote: {en}")


if __name__ == "__main__":
    main()
