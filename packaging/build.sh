#!/bin/bash
# Builds the bigcouch and couch-libmozjs185 packages for one Debian
# release, in a Docker container.
#
#   packaging/build.sh <bookworm|trixie> [mozjs] [bigcouch]
#
# With no package names, builds both. The .deb files go to
# packaging/out/<release>/. Sources are downloaded and checked first
# (fetch.sh); the build itself runs without network access.
#
# Environment: CACHE (sources, default packaging/.cache), WORK (toolchains
# and scratch, default packaging/.work/<release>), OUT (default
# packaging/out/<release>), IMAGE (builder image name).
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
dist=${1:-}
case $dist in
  bookworm|trixie) shift ;;
  *) echo "usage: $0 <bookworm|trixie> [mozjs] [bigcouch]" >&2; exit 2 ;;
esac
targets=("$@")
[ ${#targets[@]} -gt 0 ] || targets=(mozjs bigcouch)

cache=${CACHE:-$here/.cache}
work=${WORK:-$here/.work/$dist}
out=${OUT:-$here/out/$dist}
image=${IMAGE:-bigcouch-packaging:$dist}

"$here/fetch.sh" "$cache"

docker build --quiet --network host --build-arg DIST="$dist" -t "$image" -f "$here/Dockerfile" "$here" >/dev/null

mkdir -p "$work/tools" "$work/build" "$out"
docker run --rm --network none \
  -v "$here:/pkg:ro" -v "$cache:/cache:ro" \
  -v "$work/tools:/tools" -v "$work/build:/build" -v "$out:/out" \
  "$image" bash /pkg/inside.sh "${targets[@]}"
