#!/bin/bash
# Makes an APT repository from the packages build.sh made, for
# the bigcouch class's `repository`. Serve the directory over HTTP(S).
#
#   packaging/repo.sh <repository directory> [GPG key ID]
#
# Every packaging/out/<release>/ becomes the suite <release>, component
# main. With a GPG key ID the Release files are signed (InRelease and
# Release.gpg) and the public key is written to <directory>/key.asc; give
# that URL as the source's `key`. Without one, the source needs
# `allow_unsigned: true`. Needs apt-utils (apt-ftparchive) and gnupg.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
repo=${1:?usage: $0 <repository directory> [GPG key ID]}
key=${2:-}
out=${OUT_ROOT:-$here/out}

mkdir -p "$repo"
for dir in "$out"/*/; do
  dist=$(basename "$dir")
  compgen -G "$dir/*.deb" >/dev/null || continue
  pool=$repo/pool/main/$dist
  bin=$repo/dists/$dist/main/binary-amd64
  mkdir -p "$pool" "$bin"
  # A package already in the pool under the same file name is kept (the
  # same couch-libmozjs185 build may come from freepenguins-couchdb).
  for deb in "$dir"/*.deb; do
    [ -e "$pool/$(basename "$deb")" ] || cp "$deb" "$pool/"
  done
  (cd "$repo" && apt-ftparchive packages "pool/main/$dist") > "$bin/Packages"
  gzip -9nkf "$bin/Packages"
  apt-ftparchive \
    -o APT::FTPArchive::Release::Origin=freepenguins-bigcouch \
    -o APT::FTPArchive::Release::Label=freepenguins-bigcouch \
    -o APT::FTPArchive::Release::Suite="$dist" \
    -o APT::FTPArchive::Release::Codename="$dist" \
    -o APT::FTPArchive::Release::Architectures=amd64 \
    -o APT::FTPArchive::Release::Components=main \
    release "$repo/dists/$dist" > "$repo/dists/$dist/Release"
  if [ -n "$key" ]; then
    gpg --batch --yes --local-user "$key" --clearsign -o "$repo/dists/$dist/InRelease" "$repo/dists/$dist/Release"
    gpg --batch --yes --local-user "$key" --armor --detach-sign -o "$repo/dists/$dist/Release.gpg" "$repo/dists/$dist/Release"
  fi
  echo "suite $dist: $(grep -c '^Package:' "$bin/Packages") packages"
done

if [ -n "$key" ]; then
  gpg --armor --export "$key" > "$repo/key.asc"
fi
