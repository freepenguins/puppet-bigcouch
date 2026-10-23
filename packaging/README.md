# BigCouch packages for the bigcouch class

BigCouch has no packages for Debian 12 (bookworm) or 13 (trixie): its last
were Cloudant's, for Ubuntu releases long out of support. These scripts
build them.

| Package | Version | What's in it |
|---|---|---|
| `couch-libmozjs185-1.0`, `-dev` | 1.8.5-1.0.0+couch-1+fp1~&lt;release&gt; | SpiderMonkey 1.8.5, which BigCouch's couchjs needs. Apache's packaging (`couchdb-pkg` `js/`) with flags for GCC 12 and 14. |
| `bigcouch` | 0.4.2b-1+fp1~&lt;release&gt; | BigCouch 0.4.2b in `/opt/bigcouch`, with Erlang/OTP R16B03-1 bundled; configuration in `/etc/bigcouch`. |

The bundled Erlang's crypto is linked against a static OpenSSL 1.0.2u (the
newest R16 supports), because Debian 12 and 13 have neither R16 nor OpenSSL
1.0. Both are end-of-life: keep BigCouch on 127.0.0.1 or a trusted network
(the module's default).

## Building

Needs Docker and network access to the source hosts in `sources.lock`
(ftp.mozilla.org and github.com).

```bash
packaging/build.sh bookworm             # both, into packaging/out/bookworm/
packaging/build.sh trixie bigcouch      # or one of them
```

`fetch.sh` downloads the sources into `packaging/.cache/` and checks each
tarball's SHA-256 and each git checkout's commit against `sources.lock`.
The build then runs in a Debian container without network access.
Toolchains built along the way (Python 2.7 for SpiderMonkey's configure and
BigCouch's SCons, the OpenSSL and Erlang builds) are kept in
`packaging/.work/<release>/tools`, so later builds skip them. A first build
takes about half an hour on two cores.

The package is BigCouch 0.4.2b with the applications its `rebar.config`
pins (couch 1.1.1-788-gf0f5a10, chttpd 1.4.3, fabric 2.0.7, mem3 2.0.0,
rexi 1.5.5 and so on), released with Erlang/OTP R16B03-1 (erts 5.10.4)
and without OTP's GUI applications
(appmon, gs, wx, observer, et). It reads `/etc/bigcouch/vm.args`, logs to
`/var/log/bigcouch`, keeps data in `/var/lib/bigcouch` and runs in the
foreground under its own systemd unit. It conflicts with
`bigcouch-unofficial`, an older package of BigCouch for CentOS.

Patches applied to upstream sources:

* `bigcouch/patches/0001-couchjs-version-without-git.patch`: couchjs takes
  its version string from the build rather than `git describe`.
* `bigcouch/patches/0002-couchjs-link-shared-mozjs185.patch`: link the
  shared SpiderMonkey library, not the static archive.
* `bigcouch/patches/0003-mochiweb-pmod-transform.patch`: R16 dropped
  parameterized modules, which four of mochiweb's modules are; they compile
  with the parse transform from
  [pmod_transform](https://github.com/erlang/pmod_transform) (a build tool,
  pinned in `sources.lock`, not shipped).
* `mozjs/debian.patch`: compiler flags for GCC 12 and 14, Python 2 as a
  build tool, shlibs instead of the symbols file.

freepenguins-couchdb's packaging builds the same `couch-libmozjs185`
packages, at the same version and from the same sources, for CouchDB 2.3.1.
If both go into one APT repository, `repo.sh` keeps the copy already there:
a package already in the pool under the same file name is never replaced.

## Publishing

```bash
packaging/repo.sh /srv/apt/bigcouch <GPG key ID>
```

makes an APT repository with one suite per release built (`bookworm`,
`trixie`, component `main`), signed with the key, and exports the key as
`key.asc`. Serve the directory and give it to the class as `repository`:

```yaml
bigcouch::repository:
  location: 'https://apt.example.com/bigcouch/'
  release: '%{facts.os.distro.codename}'
  repos: 'main'
  key:
    name: 'bigcouch.asc'
    source: 'https://apt.example.com/bigcouch/key.asc'
```

Without a key, `repo.sh` makes an unsigned repository, which needs
`allow_unsigned: true` instead of `key`.
