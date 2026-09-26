#!/usr/bin/env bash
# Package startup resources for a standalone Realm of Kings Android install.
set -euo pipefail
ASSETS=src/main/assets/defaults
UPDATES=src/main/assets/update
DIST_REF=54a6e2395c532648ff762540e9615319fac4f51b
DIST_DIR=$(mktemp -d)
git -C "$DIST_DIR" init -q
git -C "$DIST_DIR" remote add origin https://github.com/ProjectIgnis/Distribution.git
git -C "$DIST_DIR" fetch --depth 1 origin "$DIST_REF"
git -C "$DIST_DIR" checkout --detach FETCH_HEAD
mkdir -p "$ASSETS" "$UPDATES"
python3 - "$DIST_DIR" "$ASSETS" <<'PYASSETS'
from pathlib import Path
import shutil, sys
source, target = map(Path, sys.argv[1:])
# Repository contents update in-app; do not package Git histories or player data.
for item in source.iterdir():
    if item.name.startswith('.') or item.name in {'repositories', 'deck', 'replay', 'replays', 'puzzles'}:
        continue
    if item.is_dir():
        shutil.copytree(item, target / item.name, dirs_exist_ok=True,
                        ignore=shutil.ignore_patterns('.git', '.github'))
    elif item.is_file() and item.suffix != '.sh':
        shutil.copy2(item, target / item.name)
PYASSETS
# Preserve license texts from the engine in the shipped assets.
cp deps/edopro/COPYING "$ASSETS/COPYING.txt"
cp deps/edopro/LICENSE "$ASSETS/LICENSE.txt"
lua ci/bin2c.lua "$ASSETS/fonts/NotoSansJP-Regular.otf" deps/edopro/gframe/CGUITTFont/bundled_font.cpp
curl --fail --retry 5 --connect-timeout 30 --location     "$LIBWINDBOT_RESOURCES" --output "$DIST_DIR/windbot.7z"
7z x -y "$DIST_DIR/windbot.7z" -o"$ASSETS"
mkdir -p "$ASSETS/config"
cat > "$ASSETS/config/user_configs.json" <<'REALM_CONFIG'
{
  "repos": [
    {
      "url": "https://github.com/Hacato/Realm-Of-Kings.git",
      "repo_name": "Realm-Of-Kings",
      "repo_path": "./repositories/Realm-Of-Kings",
      "has_core": false,
      "data_path": "",
      "script_path": "script",
      "pics_path": "pics",
      "lflist_path": "lflists",
      "expansions_path": "expansions",
      "should_update": true,
      "should_read": true
    }
  ],
  "urls": [
    {
      "url": "default",
      "type": "pic"
    },
    {
      "type": "field",
      "url": "https://raw.githubusercontent.com/Hacato/Realm-Of-Kings/main/pics/field/{}.png"
    },
    {
      "type": "field",
      "url": "https://raw.githubusercontent.com/Hacato/Realm-Of-Kings/main/pics/field/{}.jpg"
    },
    {
      "url": "default",
      "type": "cover"
    }
  ],
  "servers": [
    {
      "name": "Realm of Kings",
      "address": "interchange.proxy.rlwy.net",
      "duelport": 24564,
      "roomaddress": "appealing-joy-production-bc20.up.railway.app",
      "roomlistprotocol": "https",
      "roomlistport": 443
    }
  ]
}
REALM_CONFIG
python3 - "$ASSETS" "$UPDATES" <<'PYINDEX'
from pathlib import Path
import json, sys
assets, updates = map(Path, sys.argv[1:])
for name in ('configs.json', 'user_configs.json'):
    json.loads((assets / 'config' / name).read_text())
# Android upgrades leave existing user settings, decks and repositories intact.
# Fresh installations receive defaults; the update list contains only .nomedia.
for root, suffix in ((assets, ''), (updates, 'u')):
    (root / '.nomedia').touch()
    paths = sorted(root.rglob('*'))
    for filename, selected in (
        ('index', [p for p in paths if p.is_dir()]),
        ('filelist', paths),
    ):
        (root.parent / (filename + suffix + '.txt')).write_text(
            ''.join(p.relative_to(root).as_posix() + '\n' for p in selected))
PYINDEX
