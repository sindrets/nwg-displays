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
#
# The scheme name is pinned explicitly: `python -m installer --prefix` derives
# its paths from sysconfig's *default* scheme, which on some distros (Debian,
# Ubuntu: "posix_local") already contains a "local/" component. Prefixing that
# with --prefix ~/.local yields ~/.local/local/bin and ~/.local/local/lib.
if [ "$(id -u)" -eq 0 ]; then
    SCHEME=posix_prefix
    PREFIX=/usr
    SHARE=/usr/share
else
    SCHEME=posix_user
    PREFIX="$HOME/.local"
    SHARE="${XDG_DATA_HOME:-$PREFIX/share}"
fi

# Resolve that scheme's paths once, so the cleanup below, the wheel install and
# the launcher scripts all agree on a single location.
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
    if [ -f "$BIN_DIR/$filename" ]; then
        rm -f "$BIN_DIR/$filename"
        echo "Removing $BIN_DIR/$filename"
    fi
done

# Rebuild the wheel.
rm -rf ./dist
"$PYTHON" -m build --wheel --no-isolation

# Install the wheel into the scheme chosen above. `python -m installer` offers
# no way to pick a scheme, so drive its API directly instead of using --prefix.
"$PYTHON" - "$SCHEME" dist/*.whl <<'PY'
import sys
import sysconfig

from installer import install
from installer.destinations import SchemeDictionaryDestination
from installer.sources import WheelFile

scheme, wheel_path = sys.argv[1], sys.argv[2]
scheme_dict = sysconfig.get_paths(scheme)
# 'headers' is not part of sysconfig's schemes; installer adds it itself.
scheme_dict["headers"] = sysconfig.get_path(
    "include", vars={"installed_base": scheme_dict["data"]}
)

with WheelFile.open(wheel_path) as source:
    destination = SchemeDictionaryDestination(
        scheme_dict=scheme_dict,
        interpreter=sys.executable,
        script_kind="posix",
        bytecode_optimization_levels=[0, 1],
    )
    install(source, destination, {})
PY

# Create launcher scripts for the entry points.
mkdir -p "$BIN_DIR"
while IFS=':' read -r name module; do
    install -Dm 755 /dev/null "$BIN_DIR/$name"
    {
        printf '%s\n' \
            "#!/usr/bin/env $PYTHON" \
            "import sys" \
            "from $module import main" \
            "if __name__ == '__main__':" \
            "    sys.exit(main())"
    } > "$BIN_DIR/$name"
    echo "Installing $BIN_DIR/$name"
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
