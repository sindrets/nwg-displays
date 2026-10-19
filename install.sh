#!/usr/bin/env bash
set -euo pipefail

# Before running this script, make sure you have python-build, python-installer
# and python-wheel installed (Debian/Ubuntu: python3-build python3-installer
# python3-wheel).

PROGRAM_NAME="nwg-displays"
MODULE_NAME="nwg_displays"
PYTHON="${PYTHON:-python3}"

# Install system-wide when running as root, to the user dir (~/.local)
# otherwise.
if [ "$(id -u)" -eq 0 ]; then
    PREFIX=/usr
    SHARE=/usr/share
    INSTALL_ARGS=()
else
    PREFIX="$HOME/.local"
    SHARE="${XDG_DATA_HOME:-$PREFIX/share}"
    INSTALL_ARGS=(--prefix "$PREFIX")
fi

# Pure-python site-packages the wheel will be installed to.
if [ "${#INSTALL_ARGS[@]}" -gt 0 ]; then
    SITE_PACKAGES="$("$PYTHON" -c "import site; print(site.getusersitepackages())")"
else
    SITE_PACKAGES="$("$PYTHON" -c "import sysconfig; print(sysconfig.get_paths()['purelib'])")"
fi
PATTERN="$SITE_PACKAGES/$MODULE_NAME*"

# Remove old package files.
for path in $PATTERN; do
    if [ -e "$path" ]; then
        echo "Removing $path"
        rm -r "$path"
    fi
done

# Remove launcher scripts (may be left over from a pip install).
filenames=("$PROGRAM_NAME" "$PROGRAM_NAME-apply" "$PROGRAM_NAME-toggle-wallpapers")
for filename in "${filenames[@]}"; do
    if [ -f "$PREFIX/bin/$filename" ]; then
        rm -f "$PREFIX/bin/$filename"
        echo "Removing $PREFIX/bin/$filename"
    fi
done

# Rebuild the wheel.
rm -rf ./dist
"$PYTHON" -m build --wheel --no-isolation

# Install the wheel (into $PREFIX, i.e. ~/.local, when not root).
"$PYTHON" -m installer "${INSTALL_ARGS[@]}" dist/*.whl

# Create launcher scripts for the entry points.
mkdir -p "$PREFIX/bin"
while IFS=':' read -r name module; do
    install -Dm 755 /dev/null "$PREFIX/bin/$name"
    {
        printf '%s\n' \
            "#!/usr/bin/env $PYTHON" \
            "import sys" \
            "from $module import main" \
            "if __name__ == '__main__':" \
            "    sys.exit(main())"
    } > "$PREFIX/bin/$name"
    echo "Installing $PREFIX/bin/$name"
done <<EOF
$PROGRAM_NAME:nwg_displays.main
$PROGRAM_NAME-apply:nwg_displays.scripts.apply_profile_json
$PROGRAM_NAME-toggle-wallpapers:nwg_displays.scripts.toggle_profile_wallpapers
EOF

# Install desktop entry, icon and documentation.
install -Dm 644 -t "$SHARE/applications" "$PROGRAM_NAME.desktop"
install -Dm 644 -t "$SHARE/pixmaps" "$PROGRAM_NAME.svg"
install -Dm 644 -t "$SHARE/licenses/$PROGRAM_NAME" LICENSE
install -Dm 644 -t "$SHARE/doc/$PROGRAM_NAME" README.md

echo "Installed $PROGRAM_NAME to $PREFIX"
