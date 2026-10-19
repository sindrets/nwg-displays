#!/usr/bin/env bash
set -euo pipefail

PROGRAM_NAME="nwg-displays"
MODULE_NAME="nwg_displays"
PYTHON="${PYTHON:-python3}"

# Uninstall from the system when running as root, from the user dir
# (~/.local) otherwise.
# The scheme names mirror install.sh: sysconfig's *default* scheme differs
# between distributions (Debian/Ubuntu use 'posix_local', whose paths already
# contain a 'local' component), so pin it instead of relying on the default.
if [ "$(id -u)" -eq 0 ]; then
    SCHEME=posix_prefix
    PREFIX=/usr
    SHARE=/usr/share
else
    SCHEME=posix_user
    PREFIX="$HOME/.local"
    SHARE="${XDG_DATA_HOME:-$PREFIX/share}"
fi

mapfile -t SCHEME_PATHS < <("$PYTHON" - "$SCHEME" <<'PY'
import sys
import sysconfig

paths = sysconfig.get_paths(sys.argv[1])
print(paths["scripts"])
print(paths["purelib"])
PY
)
if [ "${#SCHEME_PATHS[@]}" -ne 2 ]; then
    echo "Failed to resolve the '$SCHEME' install scheme" >&2
    exit 1
fi
BIN_DIR="${SCHEME_PATHS[0]}"
SITE_PACKAGES="${SCHEME_PATHS[1]}"
PATTERN="$SITE_PACKAGES/$MODULE_NAME*"

# Remove from site-packages.
for path in $PATTERN; do
    if [ -e "$path" ]; then
        echo "Removing $path"
        rm -r "$path"
    fi
done

# Remove launcher scripts.
filenames=("$PROGRAM_NAME" "$PROGRAM_NAME-apply" "$PROGRAM_NAME-toggle-wallpapers")
for filename in "${filenames[@]}"; do
    if [ -f "$BIN_DIR/$filename" ]; then
        rm -f "$BIN_DIR/$filename"
        echo "Removing $BIN_DIR/$filename"
    fi
done

# Remove desktop entry, icon and documentation.
rm -f "$SHARE/applications/$PROGRAM_NAME.desktop"
rm -f "$SHARE/pixmaps/$PROGRAM_NAME.svg"
rm -rf "$SHARE/licenses/$PROGRAM_NAME"
rm -rf "$SHARE/doc/$PROGRAM_NAME"

echo "Uninstalled $PROGRAM_NAME from $PREFIX"
