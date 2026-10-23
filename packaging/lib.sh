# Helpers for inside.sh, which runs in the builder container with:
#   /pkg    this directory (read-only)
#   /cache  sources from fetch.sh (read-only)
#   /tools  toolchains built here: Python 2, OpenSSL, Erlang (kept between runs)
#   /build  scratch
#   /out    the finished .deb files
set -euo pipefail

DIST=$(. /etc/os-release && echo "$VERSION_CODENAME")
JOBS=$(nproc)
export DEBEMAIL='2281089+freepenguins@users.noreply.github.com'
export DEBFULLNAME='freepenguins'
export DEB_BUILD_OPTIONS="parallel=${JOBS} nocheck"
export LC_ALL=C.UTF-8
mkdir -p /tools /build /out

# Old C code on GCC 12 (Debian 12) and GCC 14 (Debian 13): common symbols,
# GNU89 inline semantics, and errors GCC 14 made of old warnings.
OLD_CFLAGS='-O2 -g -fno-strict-aliasing -fcommon -fgnu89-inline -Wno-error -Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=incompatible-pointer-types -Wno-error=int-conversion'

log() { printf '\n==> [%s] %s\n' "$DIST" "$*"; }

# Runs a command with its output in /build/<name>.log, showing the tail if
# it fails.
logged() {
  local name=$1; shift
  if ! "$@" >"/build/$name.log" 2>&1; then
    echo "FAILED: $* (last lines of /build/$name.log):" >&2
    tail -40 "/build/$name.log" >&2
    return 1
  fi
}

# A fresh copy of a cached source tree or tarball in /build.
unpack() { # <tarball or directory in /cache> <destination>
  rm -rf "$2"
  mkdir -p "$2"
  if [ -d "/cache/$1" ]; then
    rsync -a --exclude .git "/cache/$1/" "$2/"
  else
    tar -xzf "/cache/$1" -C "$2" --strip-components=1 --no-same-owner
  fi
}

# Python 2.7, only as a build tool: SpiderMonkey 1.8.5's configure and
# BigCouch's SCons need it. Never packaged.
ensure_python2() {
  if [ ! -x /tools/py27/bin/python2.7 ]; then
    log "Python 2.7.18 (build tool only)"
    unpack cpython-2.7.18 /build/py27
    cd /build/py27
    logged py27-configure ./configure --prefix=/tools/py27 --without-ensurepip
    logged py27-make make -j"$JOBS"
    logged py27-install make install
  fi
  mkdir -p /tools/bin
  ln -sf /tools/py27/bin/python2.7 /tools/bin/python2
  ln -sf /tools/py27/bin/python2.7 /tools/bin/python
}

# OpenSSL as a static, position-independent library, linked into Erlang's
# crypto so the package doesn't need libssl1.0, which Debian 12 and 13
# don't have.
ensure_openssl() { # <version>
  local v=$1 prefix=/tools/openssl-$1
  if [ ! -f "$prefix/lib/libcrypto.a" ]; then
    log "OpenSSL $v (static)"
    unpack "openssl-$v.tar.gz" "/build/openssl-$v"
    cd "/build/openssl-$v"
    logged "openssl-$v-config" ./config --prefix="$prefix" --openssldir="$prefix/ssl" no-shared -fPIC
    case $v in
      1.0.*) logged "openssl-$v-depend" make depend
             logged "openssl-$v-make" make -j1 ;;
      *)     logged "openssl-$v-make" make -j"$JOBS" ;;
    esac
    logged "openssl-$v-install" make install_sw
  fi
}

# Erlang/OTP R16B03-1 for BigCouch. Only what BigCouch uses:
# no Java, ODBC, wx or the GUI tools that need it, and no HiPE.
OTP_CONFIGURE=(--disable-hipe --enable-threads --enable-smp-support --enable-kernel-poll
  --disable-dynamic-ssl-lib --without-javac --without-odbc --without-wx
  --without-debugger --without-observer --without-et --without-megaco --without-diameter)

ensure_otp_r16() {
  local prefix=/tools/otp-R16B03-1
  if [ ! -x "$prefix/bin/erl" ]; then
    ensure_openssl 1.0.2u
    log "Erlang/OTP R16B03-1"
    unpack otp-R16B03-1 /build/otp16
    cd /build/otp16
    export ERL_TOP=/build/otp16
    # The git tag has no generated configure scripts; R16 needs autoconf 2.69
    # or older.
    mkdir -p /build/ac269
    ln -sf /usr/bin/autoconf2.69 /build/ac269/autoconf
    ln -sf /usr/bin/autoheader2.69 /build/ac269/autoheader
    PATH=/build/ac269:$PATH logged otp16-autoconf ./otp_build autoconf
    logged otp16-configure ./configure --prefix="$prefix" --with-ssl=/tools/openssl-1.0.2u \
      "${OTP_CONFIGURE[@]}" CFLAGS="$OLD_CFLAGS" LDFLAGS='-Wl,-z,noexecstack'
    logged otp16-make make -j"$JOBS"
    logged otp16-install make install
    unset ERL_TOP
  fi
  "$prefix/bin/erl" -noshell -eval 'ok = crypto:start(), halt().'
}

# couch-libmozjs185 from this run's /out, which couchjs builds against.
install_mozjs() {
  if ! dpkg -s couch-libmozjs185-dev >/dev/null 2>&1; then
    dpkg -i /out/couch-libmozjs185-1.0_*~"${DIST}"_*.deb /out/couch-libmozjs185-dev_*~"${DIST}"_*.deb
  fi
}

# Adds a changelog entry for this build to the package in the current
# directory.
changelog() { # <package> <version> <message>
  dch --create --package "$1" --newversion "$2" --distribution "$DIST" --force-distribution "$3" 2>/dev/null ||
    dch --package "$1" --newversion "$2" --distribution "$DIST" --force-distribution "$3"
}
