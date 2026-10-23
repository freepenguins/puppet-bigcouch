#!/bin/bash
# Downloads the sources in sources.lock into the cache directory and checks
# each one: tarballs by SHA-256, git checkouts by commit.
#
#   fetch.sh [cache directory]     (default: packaging/.cache)
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
cache=${1:-$here/.cache}
mkdir -p "$cache"

fail=0
while read -r kind name url ref_or_sum commit; do
  case $kind in
    tar)
      sum=$ref_or_sum
      if [ ! -f "$cache/$name" ] || ! echo "$sum  $cache/$name" | sha256sum -c --quiet - 2>/dev/null; then
        echo "==> downloading $name"
        curl -fsSL --retry 3 -o "$cache/$name.part" "$url"
        mv "$cache/$name.part" "$cache/$name"
      fi
      if echo "$sum  $cache/$name" | sha256sum -c --quiet -; then
        echo "ok  $name"
      else
        echo "BAD $name: SHA-256 is not $sum" >&2
        fail=1
      fi
      ;;
    git)
      ref=$ref_or_sum
      dir=$cache/$name
      if [ "$(git -C "$dir" rev-parse HEAD 2>/dev/null || true)" != "$commit" ]; then
        echo "==> fetching $name ($ref)"
        rm -rf "$dir"
        git init -q "$dir"
        git -C "$dir" remote add origin "$url"
        # Fetch the commit itself where the server allows it, else the ref.
        git -C "$dir" fetch -q --depth 1 origin "$commit" 2>/dev/null ||
          git -C "$dir" fetch -q --depth 50 origin "$ref"
        git -C "$dir" -c advice.detachedHead=false checkout -q "$commit"
      fi
      if [ "$(git -C "$dir" rev-parse HEAD)" = "$commit" ]; then
        echo "ok  $name @ ${commit:0:12}"
      else
        echo "BAD $name: not at $commit" >&2
        fail=1
      fi
      ;;
  esac
done < <(grep -E '^(tar|git) ' "$here/sources.lock")

exit $fail
