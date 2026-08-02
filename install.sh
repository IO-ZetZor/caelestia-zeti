#!/usr/bin/env bash
#
# Install per-monitor wallpapers and colours into an existing Caelestia setup.
#
#   ./install.sh                 install (auto-detects paths)
#   ./install.sh --dry-run       show what would change, write nothing
#   ./install.sh --uninstall     restore the most recent backup
#
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia-zeti/backups"

DRY_RUN=0
UNINSTALL=0
SHELL_DIR=""
CLI_DIR=""

die() { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }
info() { printf '\033[36m::\033[0m %s\n' "$*"; }
ok() { printf '\033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!\033[0m %s\n' "$*"; }

usage() {
    sed -n '2,8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    cat <<'EOF'

Options:
  --shell-dir DIR   Caelestia shell root (the directory holding shell.qml)
  --cli-dir DIR     caelestia Python package root
  -n, --dry-run     Report intended changes without writing
  -u, --uninstall   Restore the most recent backup
  -h, --help        Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --shell-dir) SHELL_DIR="${2:?--shell-dir needs a path}"; shift 2 ;;
        --cli-dir) CLI_DIR="${2:?--cli-dir needs a path}"; shift 2 ;;
        -n|--dry-run) DRY_RUN=1; shift ;;
        -u|--uninstall) UNINSTALL=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "unknown option: $1 (try --help)" ;;
    esac
done

# ── Dependency checks ────────────────────────────────────────────────────────

command -v python3 >/dev/null || die "python3 is required"

# ── Locate the shell ─────────────────────────────────────────────────────────

detect_shell_dir() {
    local c
    for c in \
        "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/caelestia" \
        "/etc/xdg/quickshell/caelestia" \
        "$HOME/.local/share/caelestia/shell"
    do
        [[ -f "$c/shell.qml" ]] && { printf '%s' "$c"; return 0; }
    done
    return 1
}

detect_cli_dir() {
    local d
    d=$(python3 - <<'PY' 2>/dev/null || true
import importlib.util as u
s = u.find_spec("caelestia")
print(s.submodule_search_locations[0] if s and s.submodule_search_locations else "")
PY
)
    [[ -n "$d" && -d "$d" ]] && { printf '%s' "$d"; return 0; }
    return 1
}

[[ -n "$SHELL_DIR" ]] || SHELL_DIR=$(detect_shell_dir) \
    || die "could not find the Caelestia shell; pass --shell-dir"
[[ -f "$SHELL_DIR/shell.qml" ]] \
    || die "$SHELL_DIR does not contain shell.qml"

[[ -n "$CLI_DIR" ]] || CLI_DIR=$(detect_cli_dir) \
    || warn "caelestia CLI not found; skipping CLI patch (pass --cli-dir to include it)"

# Writing into a root-owned tree (a packaged install) needs sudo.
SUDO=""
if [[ ! -w "$SHELL_DIR" ]]; then
    command -v sudo >/dev/null || die "$SHELL_DIR is not writable and sudo is unavailable"
    SUDO="sudo"
    warn "$SHELL_DIR is not writable; using sudo"
fi

CLI_SUDO=""
if [[ -n "$CLI_DIR" && ! -w "$CLI_DIR" ]]; then
    command -v sudo >/dev/null || die "$CLI_DIR is not writable and sudo is unavailable"
    CLI_SUDO="sudo"
fi

# ── Uninstall ────────────────────────────────────────────────────────────────

if [[ $UNINSTALL -eq 1 ]]; then
    [[ -d "$BACKUP_ROOT" ]] || die "no backups found under $BACKUP_ROOT"
    latest=$(find "$BACKUP_ROOT" -maxdepth 1 -mindepth 1 -type d | sort | tail -1)
    [[ -n "$latest" ]] || die "no backups found under $BACKUP_ROOT"

    info "restoring from $latest"
    if [[ $DRY_RUN -eq 1 ]]; then
        ok "dry run: would restore shell/ and cli/ from that backup"
        exit 0
    fi
    # Replace the tree wholesale rather than copying over it: the rewrite
    # touched files this repo never ships, and files added since the backup
    # (LockScreenPanel.qml and friends) must not survive an uninstall.
    if [[ -d "$latest/shell" ]]; then
        $SUDO rm -rf "${SHELL_DIR:?}"/*
        $SUDO cp -a "$latest/shell/." "$SHELL_DIR/"
    fi
    if [[ -d "$latest/cli" && -n "$CLI_DIR" ]]; then
        $CLI_SUDO rm -rf "${CLI_DIR:?}"/*
        $CLI_SUDO cp -a "$latest/cli/." "$CLI_DIR/"
        $CLI_SUDO find "$CLI_DIR" -name __pycache__ -type d -exec rm -rf {} + 2>/dev/null || true
    fi
    ok "restored. Restart the shell:  qs -c caelestia kill && caelestia shell &"
    exit 0
fi

# ── Preflight ────────────────────────────────────────────────────────────────

info "shell : $SHELL_DIR"
[[ -n "$CLI_DIR" ]] && info "cli   : $CLI_DIR"

# The rewrite assumes stock call sites. If p(/tp( are already present the tree
# has been patched before, and re-running is harmless but worth announcing.
if grep -rqs "Colours\.p(Tokens\.screen)" "$SHELL_DIR" 2>/dev/null; then
    warn "this shell already looks patched; re-running is safe (idempotent)"
fi

if [[ $DRY_RUN -eq 1 ]]; then
    info "dry run: no files will be written"
    python3 "$REPO/scripts/rewrite_colours.py" "$SHELL_DIR" --dry-run
    echo
    info "would overlay $(find "$REPO/shell" -name '*.qml' | wc -l) shell file(s)"
    [[ -n "$CLI_DIR" ]] && info "would overlay $(find "$REPO/cli" -name '*.py' | wc -l) CLI file(s)"
    exit 0
fi

# ── Backup ───────────────────────────────────────────────────────────────────

STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP="$BACKUP_ROOT/$STAMP"
mkdir -p "$BACKUP/shell"
info "backing up to $BACKUP"
cp -a "$SHELL_DIR/." "$BACKUP/shell/"
if [[ -n "$CLI_DIR" ]]; then
    mkdir -p "$BACKUP/cli"
    cp -a "$CLI_DIR/." "$BACKUP/cli/"
fi
ok "backup complete"

# ── Overlay the changed files ────────────────────────────────────────────────

info "installing shell files"
while IFS= read -r rel; do
    dest="$SHELL_DIR/$rel"
    $SUDO mkdir -p "$(dirname "$dest")"
    $SUDO cp "$REPO/shell/$rel" "$dest"
done < <(cd "$REPO/shell" && find . -type f -name '*.qml' | sed 's|^\./||')
ok "shell files installed"

if [[ -n "$CLI_DIR" ]]; then
    info "installing CLI files"
    while IFS= read -r rel; do
        dest="$CLI_DIR/$rel"
        $CLI_SUDO mkdir -p "$(dirname "$dest")"
        $CLI_SUDO cp "$REPO/cli/$rel" "$dest"
    done < <(cd "$REPO/cli" && find . -type f -name '*.py' | sed 's|^\./||')
    # Stale bytecode would shadow the new sources.
    $CLI_SUDO find "$CLI_DIR" -name __pycache__ -type d -exec rm -rf {} + 2>/dev/null || true
    ok "CLI files installed"
fi

# ── Rewrite the remaining call sites ─────────────────────────────────────────

info "rewriting Colours call sites for per-screen palettes"
if [[ -n "$SUDO" ]]; then
    $SUDO python3 "$REPO/scripts/rewrite_colours.py" "$SHELL_DIR"
else
    python3 "$REPO/scripts/rewrite_colours.py" "$SHELL_DIR"
fi

# ── Done ─────────────────────────────────────────────────────────────────────

echo
ok "installed"
cat <<EOF

Restart the shell to pick up the changes:

    qs -c caelestia kill && caelestia shell &

To revert:

    $0 --uninstall

EOF
