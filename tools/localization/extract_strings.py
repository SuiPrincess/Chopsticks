#!/usr/bin/env python3
"""Extract user-facing string literals from Swift sources.

Finds double-quoted literals (handling \\( interpolation by normalizing to
format placeholders the way SwiftUI/Foundation do:
  \\(intExpr)    -> %lld   (can't infer type — we mark as %@|%lld AMBIG)
Actually: we keep the raw literal and a normalized "key form" where every
interpolation becomes the placeholder given by a manual type map lookup;
unresolved ones are flagged for human review.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2] / "Chopsticks"
JP = re.compile(r"[぀-ヿ㐀-鿿！-｠]")

# string literal with escapes; Swift interpolation \( ... ) needs bracket matching
def extract_literals(text):
    literals = []
    i = 0
    n = len(text)
    while i < n:
        c = text[i]
        if c == '"':
            # check for triple quote (none in this codebase)
            j = i + 1
            buf = []
            while j < n:
                ch = text[j]
                if ch == "\\":
                    nxt = text[j + 1] if j + 1 < n else ""
                    if nxt == "(":
                        # interpolation: find matching paren
                        depth = 1
                        k = j + 2
                        while k < n and depth > 0:
                            if text[k] == "(":
                                depth += 1
                            elif text[k] == ")":
                                depth -= 1
                            k += 1
                        expr = text[j + 2:k - 1]
                        buf.append(("INTERP", expr))
                        j = k
                        continue
                    else:
                        buf.append(("CHAR", ch + nxt))
                        j += 2
                        continue
                elif ch == '"':
                    literals.append((i, buf))
                    j += 1
                    break
                else:
                    buf.append(("CHAR", ch))
                    j += 1
            i = j
        elif c == "/" and i + 1 < n and text[i + 1] == "/":
            # line comment
            while i < n and text[i] != "\n":
                i += 1
        else:
            i += 1
    return literals


def render(buf):
    out = []
    for kind, val in buf:
        if kind == "CHAR":
            out.append(val)
        else:
            out.append("\\(" + val + ")")
    return "".join(out)


def main():
    results = {}
    for f in sorted(ROOT.rglob("*.swift")):
        if "ChopsticksTests" in str(f) or ".xcodeproj" in str(f):
            continue
        text = f.read_text()
        lines = text.split("\n")
        for pos, buf in extract_literals(text):
            s = render(buf)
            if not JP.search(s) and not any(
                s.startswith(k) for k in ("WIN!", "LOSE", "DRAW", "Play Again", "Menu", "Split", "CHOPSTICKS", "waribashi", "CPU", "Player ")
            ):
                continue
            line_no = text[:pos].count("\n") + 1
            rel = str(f.relative_to(ROOT))
            results.setdefault(rel, []).append({"line": line_no, "s": s})
    print(json.dumps(results, ensure_ascii=False, indent=1))
    total = sum(len(v) for v in results.values())
    print(f"// total: {total} strings in {len(results)} files", file=sys.stderr)


if __name__ == "__main__":
    main()
