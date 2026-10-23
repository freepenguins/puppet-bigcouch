#!/bin/bash
# Runs in the builder container (see build.sh): builds the packages named
# on the command line, in order, into /out.
#
#   inside.sh mozjs bigcouch
. /pkg/lib.sh

# couch-libmozjs185-1.0 and -dev: SpiderMonkey 1.8.5, which BigCouch's
# couchjs runs views and validation functions with. Apache's
# packaging (couchdb-pkg js/), rebuilt for this Debian release.
build_mozjs() {
  ensure_python2
  log "couch-libmozjs185 1.8.5"
  local version="1.8.5-1.0.0+couch-1+fp1~${DIST}"
  rm -rf /build/mozjs && mkdir -p /build/mozjs
  cp /cache/js185-1.0.0.tar.gz /build/mozjs/couch-libmozjs185_1.8.5-1.0.0+couch.orig.tar.gz
  unpack js185-1.0.0.tar.gz /build/mozjs/js-1.8.5
  cp -a /cache/couchdb-pkg/js/debian /build/mozjs/js-1.8.5/debian
  cd /build/mozjs/js-1.8.5
  rm debian/couch-libmozjs185-1.0.symbols
  patch -p1 --batch < /pkg/mozjs/debian.patch
  changelog couch-libmozjs185 "$version" \
    "Rebuild for Debian ${DIST} (freepenguins packaging): Python 2 as a build tool only, compiler flags for current GCC, shlibs instead of a symbols file."
  PATH=/tools/bin:$PATH logged mozjs-dpkg-buildpackage dpkg-buildpackage -us -uc -b
  cp ../couch-libmozjs185-1.0_"${version}"_*.deb ../couch-libmozjs185-dev_"${version}"_*.deb /out/
}

# bigcouch 0.4.2b with Erlang/OTP R16B03-1 (crypto linked against a static
# OpenSSL 1.0.2u, the newest OpenSSL R16 supports) bundled in /opt/bigcouch.
build_bigcouch() {
  ensure_python2
  ensure_otp_r16
  install_mozjs
  log "bigcouch 0.4.2b"
  local version="0.4.2b-1+fp1~${DIST}"
  local src=/build/bigcouch/bigcouch-0.4.2b
  rm -rf /build/bigcouch && mkdir -p /build/bigcouch
  unpack bigcouch "$src"
  # The dependencies rebar would fetch, at the tags rebar.config names.
  # Their app files take the version from `git describe`; without git
  # history it is written in, as rebar would have (the tag name).
  local dep app tag
  for dep in oauth:BigCouch-0.4.0 ibrowse:CouchDB-1.1.0 mochiweb:CouchDB-1.1.0 rexi:1.5.5 \
             fabric:2.0.7 mem3:2.0.0 chttpd:1.4.3 twig:0.2.1 meck:0.7.2; do
    app=${dep%%:*} tag=${dep#*:}
    unpack "bigcouch-dep-${app}" "$src/deps/${app}"
    sed -i "s/{vsn, *git}/{vsn, \"${tag}\"}/" "$src/deps/${app}/src/${app}.app.src"
  done
  # mochiweb's parameterized modules compile on R16 with pmod_transform's
  # parse transform (patches/0003). It goes into the build toolchain's own
  # lib/, which stays on the code path (this rebar resets it, so ERL_LIBS
  # doesn't work); nothing uses it at run time, so the release leaves it out.
  local pmod=/tools/otp-R16B03-1/lib/erlang/lib/pmod_transform-1.1
  if [ ! -f "$pmod/ebin/pmod_pt.beam" ]; then
    mkdir -p "$pmod/ebin"
    /tools/otp-R16B03-1/bin/erlc -o "$pmod/ebin" /cache/pmod_transform/src/pmod_pt.erl
  fi
  cd "$src"
  for p in /pkg/bigcouch/patches/*.patch; do [ -e "$p" ] && patch -p1 --batch < "$p"; done
  rsync -a /pkg/bigcouch/debian/ debian/
  changelog bigcouch "$version" \
    "Build for Debian ${DIST} (freepenguins packaging), with Erlang/OTP R16B03-1 and a static OpenSSL 1.0.2u bundled."
  PATH=/tools/otp-R16B03-1/bin:/tools/bin:$PATH logged bigcouch-dpkg-buildpackage dpkg-buildpackage -us -uc -b -d
  cp ../bigcouch_"${version}"_*.deb /out/
}

for target in "$@"; do
  case $target in
    mozjs|bigcouch) "build_${target}" ;;
    *) echo "unknown package: $target (mozjs or bigcouch)" >&2; exit 2 ;;
  esac
done

log "done"
ls -l /out
