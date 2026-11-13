# bigcouch

Installs and configures [BigCouch](https://github.com/cloudant/bigcouch)
0.4, Cloudant's clustered CouchDB, as one node on Debian 12 and 13, from an
APT repository. The packages are built by
[puppet-bigcouch-packaging](https://github.com/freepenguins/puppet-bigcouch-packaging).

## Table of contents

1. [Description](#description)
1. [Setup](#setup)
    * [What bigcouch affects](#what-bigcouch-affects)
    * [Requirements](#requirements)
    * [Beginning with bigcouch](#beginning-with-bigcouch)
1. [Usage](#usage)
1. [Reference](#reference)
1. [Limitations](#limitations)
1. [Development](#development)

## Description

BigCouch 0.4 is CouchDB 1.1 with Dynamo-style clustering; its features went
into Apache CouchDB 2.0, and it has been unmaintained since 2013. Nothing
publishes it for current Debian: its last packages were Cloudant's, for
Ubuntu releases long out of support.
[puppet-bigcouch-packaging](https://github.com/freepenguins/puppet-bigcouch-packaging) builds `bigcouch` 0.4.2b, its last
release, with Erlang/OTP R16B03-1 bundled, plus `couch-libmozjs185-1.0`
(SpiderMonkey 1.8.5, for couchjs), for bookworm and trixie, and an APT
repository of them. See [The packages](#the-packages).

The class:

* adds your APT repository with those packages (`repository`), or leaves
  the server's APT sources alone and installs `bigcouch` from them;
* writes `/etc/bigcouch/local.ini` and `vm.args` before installing the
  package, since the package starts BigCouch, and a node renamed after its
  first start keeps the old name in its shard maps;
* runs one node with q = n = r = w = 1, listening on 127.0.0.1;
* optionally creates an admin, with the password stored already hashed in
  BigCouch's format, so BigCouch doesn't rewrite it.

## Setup

### What bigcouch affects

* The `bigcouch` package (and `couch-libmozjs185-1.0`), its service and
  its `/opt/bigcouch`, and with `repository` an APT source.
* The `bigcouch` user and group (unless `manage_user`/`manage_group` are
  false), `/var/lib/bigcouch` (databases and view
  indexes) and `/var/log/bigcouch`.
* `/etc/bigcouch`: `local.ini` (managed), `runtime.ini` (created once;
  changes made through BigCouch's `_config` API are saved there) and
  `vm.args`.

### Requirements

* Debian 12 or 13 (amd64), Puppet 7 or 8.
* [puppetlabs/stdlib](https://forge.puppet.com/modules/puppetlabs/stdlib)
  and [puppetlabs/apt](https://forge.puppet.com/modules/puppetlabs/apt).
* The `bigcouch` and `couch-libmozjs185-1.0` packages in an APT repository:
  build and publish them with
  [puppet-bigcouch-packaging](https://github.com/freepenguins/puppet-bigcouch-packaging) (`build.sh`, `repo.sh`).

### Beginning with bigcouch

```puppet
class { 'bigcouch':
  admin_username => 'admin',
  admin_password => Sensitive('change-me'),
  repository     => {
    'location' => 'https://apt.example.com/bigcouch/',   # where you serve repo.sh's output
    'release'  => $facts['os']['distro']['codename'],
    'repos'    => 'main',
    'key'      => {
      'name'   => 'bigcouch.asc',
      'source' => 'https://apt.example.com/bigcouch/key.asc',
    },
  },
}
```

BigCouch then answers on `http://127.0.0.1:5984/` (the clustered API) and
`:5986` (the node-local API).

## Usage

### The packages' source

`repository` takes `apt::source` parameters. Without it, nothing is added,
and `package_name` is installed from the server's existing sources, such
as a repository your control repository already manages. For an unsigned
repository, give `'allow_unsigned' => true` instead of `key`.

### Admin

Without `admin_username` BigCouch runs in "admin party" mode: anyone who
reaches the port is an admin. With one, BigCouch still lets anyone read and
write documents in existing databases (`require_valid_user` is false), but
creating and deleting databases, design documents and configuration need
the admin. Set `require_valid_user` to true in `settings` (both `chttpd`
and `httpd`) to require a login for everything.

### Settings

`settings` adds to or overrides `local.ini`, section by section:

```puppet
class { 'bigcouch':
  bind_address => '0.0.0.0',
  settings     => {
    'log'    => { 'level' => 'warning' },
    'chttpd' => { 'require_valid_user' => true },
  },
}
```

### Erlang VM arguments

`vm_args` adds lines to `/etc/bigcouch/vm.args`, after the module's own;
a change restarts BigCouch:

```puppet
class { 'bigcouch':
  vm_args => ['+P 1048576', '-kernel net_ticktime 30'],
}
```

For an emulator flag the module already sets (`+A 16`, `+K true`), the
later line wins. `-name`, `-setcookie` and `-couch_ini` come from
`node_name`, `cookie` and the ini files; don't repeat them here.

### The user and group

By default the module creates the `bigcouch` system user and group before
the package is installed. To fix their ids, or to leave them to another
class or a directory service:

```puppet
class { 'bigcouch':
  uid => 990,
  gid => 990,
}

class { 'bigcouch':
  manage_user  => false,
  manage_group => false,
}
```

With `manage_user` or `manage_group` false, the user or group must exist
before the class runs, because the module's files are owned by them. A
changed `uid` or `gid` changes the account but not the ownership of files
already on disk.

### Node name and cookie

`node_name` defaults to `bigcouch@<fqdn>`, what the package's own
`-name bigcouch` becomes. Set it before the first run. `cookie` defaults to a random string
that stays the same for the node; nodes of one cluster must share it.

### The packages

The `bigcouch` and `couch-libmozjs185-1.0` packages are built and
published by [puppet-bigcouch-packaging](https://github.com/freepenguins/puppet-bigcouch-packaging), on a machine with Docker:

```bash
./build.sh bookworm                         # or trixie; into out/<release>/
./repo.sh /srv/apt/bigcouch <GPG key ID>    # an APT repository to give as `repository`
```

Its README lists what the packages contain and the patches.

### Moving from another server

Replicate the databases rather than copying their files: shard maps name
the node they were made on. From the new server:

```bash
OLD=http://old-server:5984 NEW=http://admin:change-me@127.0.0.1:5984
for db in $(curl -s "$OLD/_all_dbs" | python3 -c 'import json,sys; print("\n".join(d for d in json.load(sys.stdin) if not d.startswith("_")))'); do
  curl -s -X POST "$NEW/_replicate" -H 'Content-Type: application/json' \
    -d "{\"source\": \"$OLD/${db//\//%2F}\", \"target\": \"$NEW/${db//\//%2F}\", \"create_target\": true}"
done
```

## Reference

See [REFERENCE.md](REFERENCE.md).

## Limitations

* One node only; joining nodes into a cluster isn't managed.
* Debian 12 and 13 on amd64; the packages are built for amd64.
* BigCouch 0.4.2b, Erlang/OTP R16B03-1 and the OpenSSL 1.0.2u its crypto is
  linked against are all unmaintained. Keep BigCouch on 127.0.0.1, as by
  default, or on a trusted network.
* The package's systemd unit runs BigCouch as `bigcouch` and its postinst
  creates and chowns `bigcouch`, so keep `user` and `group` at
  `bigcouch` unless you also override the unit.
* No TLS; put a proxy in front if BigCouch must be reached over a network.

## Development

```bash
bundle install
bundle exec rake spec     # rspec-puppet, Debian 12 and 13
bundle exec rake lint syntax metadata_lint rubocop
```

## Credits

BigCouch is by Cloudant (Apache-2.0); Apache CouchDB is by the Apache
Software Foundation.
