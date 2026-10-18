#!/usr/bin/env bash
# Build a release archive with sources + tests + checksums.
# Files are placed at the archive root (no enclosing folder).
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(grep -m1 '| Project |' VERSIONS.md | awk -F'|' '{gsub(/ /,"",$3); print $3}')"
VERSION="${VERSION:-0.0.0}"
DIST="dist"
OUT="${DIST}/stornado-${VERSION}.zip"

mkdir -p "$DIST"
rm -f "$OUT"

# tracked files only, if git is available; otherwise a curated find
if git rev-parse --git-dir >/dev/null 2>&1; then
  mapfile -t FILES < <(git ls-files)
else
  mapfile -t FILES < <(find . -type f \
    -not -path './.git/*' -not -path './build/*' -not -path './obj_dir/*' \
    -not -path './dist/*' -not -path '*/__pycache__/*' | sed 's#^\./##')
fi

# checksums over the file set
: > SHA256SUMS
for f in "${FILES[@]}"; do sha256sum "$f" >> SHA256SUMS; done

zip -q "$OUT" "${FILES[@]}" SHA256SUMS
rm -f SHA256SUMS
echo "packaged $OUT ($(unzip -l "$OUT" | tail -1 | awk '{print $2}') files)"
