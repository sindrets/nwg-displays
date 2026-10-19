#!/usr/bin/env bash
set -euo pipefail

PROGRAM_NAME="nwg-displays"
MODULE_NAME="nwg_displays"
PYTHON="${PYTHON:-python3}"

# Uninstall from the system when running as root, from the user dir
# (~/.local) otherwise.
if [ "$(id -u)" -eq 0 ]; then
    PREFIX=/usr
    SHARE=/usr/share
    SITE_PACKAGES="$("$PYTHON" -c "import sysconfig; print(sysconfig.get_paths()['purelib'])")"
else
    PREFIX="$HOME/.local"
    SHARE="${XDG_DATA_HOME:-$PREFIX/share}"
    SITE_PACKAGES="$("$PYTHON" -c "import site; print(site.getusersitepackages())")"
fi
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
    if [ -f "$PREFIX/bin/$filename" ]; then
        rm -f "$PREFIX/bin/$filename"
        echo "Removing $PREFIX/bin/$filename"
    fi
done

# Remove desktop entry, icon and documentation.
rm -f "$SHARE/applications/$PROGRAM_NAME.desktop"
rm -f "$SHARE/pixmaps/$PROGRAM_NAME.svg"
rm -rf "$SHARE/licenses/$PROGRAM_NAME"
rm -rf "$SHARE/doc/$PROGRAM_NAME"

echo "Uninstalled $PROGRAM_NAME from $PREFIX"
