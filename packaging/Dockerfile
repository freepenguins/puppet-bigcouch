# Builder for the packages in this directory: Debian 12 or 13 with the
# toolchain. Erlang, OpenSSL and Python 2 are built from source by the
# scripts, not installed from Debian.
ARG DIST=bookworm
FROM debian:${DIST}
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential debhelper dh-exec devscripts dpkg-dev fakeroot lintian equivs \
      autoconf autoconf2.69 automake autotools-dev libtool pkg-config pkg-kde-tools \
      perl python3 git ca-certificates curl rsync xz-utils zip unzip help2man po-debconf \
      libncurses-dev libicu-dev libcurl4-openssl-dev zlib1g-dev libnspr4-dev libffi-dev libedit-dev \
    && rm -rf /var/lib/apt/lists/*
