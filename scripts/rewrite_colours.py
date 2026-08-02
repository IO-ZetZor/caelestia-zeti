#!/usr/bin/env python3
"""Rewrite Colours.* call sites in a Caelestia shell tree to be screen-aware.

    Colours.palette.X   ->  Colours.p(Tokens.screen).X
    Colours.tPalette.X  ->  Colours.tp(Tokens.screen).X
    Colours.light       ->  Colours.isLight(Tokens.screen)
    Colours.layer(c, n) ->  Colours.layerOn(Tokens.screen, c, n)

`Tokens.screen` is an attached property that Caelestia already propagates down
each window's item tree, so it resolves to the connector name of the screen a
component is rendering on. An empty value falls back to the global palette,
which makes the rewrite safe even where no screen is resolvable.

Files shipped by this repo are skipped: they are already correct, and several
resolve the screen by a different route because their root type is not an Item
(a QObject/ShapePath/LazyLoader has no attached properties).

Idempotent: running twice is a no-op.
"""

import argparse
import re
import sys
from pathlib import Path

# Root type is not a QQuickItem, so `Tokens.screen` cannot resolve. Each of
# these is handled explicitly in the shipped copy.
SKIP = {
    "services/Colours.qml",
    "components/filedialog/FileDialog.qml",
    "modules/lock/LockSurface.qml",
    "modules/utilities/Background.qml",
    "modules/nexus/PageCompRegistry.qml",
    "modules/drawers/ContentWindow.qml",
    "modules/nexus/WindowFactory.qml",
}

SUBS = (
    (re.compile(r"\bColours\.palette\.(\w+)"), r"Colours.p(Tokens.screen).\1"),
    (re.compile(r"\bColours\.palette\["), r"Colours.p(Tokens.screen)["),
    (re.compile(r"\bColours\.tPalette\.(\w+)"), r"Colours.tp(Tokens.screen).\1"),
    (re.compile(r"\bColours\.tPalette\["), r"Colours.tp(Tokens.screen)["),
    (re.compile(r"\bColours\.light\b"), r"Colours.isLight(Tokens.screen)"),
    (re.compile(r"\bColours\.layer\(([^)]+)\)"), r"Colours.layerOn(Tokens.screen, \1)"),
)

IMPORT = "import Caelestia.Config"


def add_import(text: str) -> str:
    """Ensure `Caelestia.Config` is imported, for `Tokens`."""
    if IMPORT in text:
        return text
    lines = text.split("\n")
    last = max((i for i, l in enumerate(lines) if re.match(r"^import\s", l)), default=None)
    if last is None:
        return text
    lines.insert(last + 1, IMPORT)
    return "\n".join(lines)


def rewrite(path: Path, dry: bool) -> int:
    original = text = path.read_text()
    for pattern, repl in SUBS:
        text = pattern.sub(repl, text)
    if text == original:
        return 0
    if "Tokens.screen" in text:
        text = add_import(text)
    if not dry:
        path.write_text(text)
    return sum(text.count(f"Colours.{fn}(") for fn in ("p", "tp", "isLight", "layerOn"))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("shell_dir", type=Path, help="Caelestia shell root (contains shell.qml)")
    ap.add_argument("-n", "--dry-run", action="store_true", help="report without writing")
    args = ap.parse_args()

    root = args.shell_dir
    if not (root / "shell.qml").is_file():
        print(f"error: {root} does not look like a Caelestia shell "
              "(no shell.qml)", file=sys.stderr)
        return 1

    files = changed = total = 0
    for qml in sorted(root.rglob("*.qml")):
        rel = qml.relative_to(root).as_posix()
        if rel in SKIP:
            continue
        files += 1
        n = rewrite(qml, args.dry_run)
        if n:
            changed += 1
            total += n

    verb = "would rewrite" if args.dry_run else "rewrote"
    print(f"{verb} {changed} of {files} file(s), {total} call site(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
