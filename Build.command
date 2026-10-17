#!/bin/zsh
set -eu
cd "$(dirname "$0")"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
python_bin=""
for candidate in python3.13 python3.12 python3.11 python3.10 python3; do
  if command -v "$candidate" >/dev/null && "$candidate" -c 'import sys;raise SystemExit(sys.version_info < (3,10))' 2>/dev/null; then
    python_bin="$candidate"
    break
  fi
done
if [[ -z "$python_bin" ]]; then
  print 'Install an ARM64 Python 3.10+ from python.org, then run this again.'
  read '?Press Return to close.'
  exit 1
fi
choice=$(osascript -e 'choose from list {"GOG Mac .pkg", "Complete Mac game folder"} with prompt "Choose your own game input" default items {"GOG Mac .pkg"}')
[[ "$choice" == false ]] && exit 0
if [[ "$choice" == 'GOG Mac .pkg' ]]; then
  game_input=$(osascript -e 'POSIX path of (choose file with prompt "Select the GOG Mac .pkg")')
else
  game_input=$(osascript -e 'POSIX path of (choose folder with prompt "Select a folder containing one complete game .app")')
fi
destination=$(osascript -e 'POSIX path of (choose folder with prompt "Choose a location for a NEW dedicated build folder")')
build_work="${destination%/}/Hollow-iOS-Build-$(date +%Y%m%d-%H%M%S)"
"$python_bin" -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python build.py build --input "$game_input" --work "$build_work"
print "Build complete. Output is in: $build_work"
read '?Press Return to close.'
