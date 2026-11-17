# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-11-17

Settings to take over an existing 2600Hz BigCouch (Kazoo on CentOS 7)
without changing its files' owners or modes.

### Added

- `view_index_dir`: view indexes apart from `data_dir` (default: in it).
- `dir_mode` (default `0750`) and `config_mode` (default `0640`).
- `runtime_ini` (default true): false leaves `runtime.ini` out of the
  configuration chain and doesn't create it.
- `user_shell` and `user_comment`.

### Changed

- The user's shell is `/sbin/nologin` and its comment `BigCouch user`, as
  on 2600Hz's servers (`/sbin/nologin` exists on Debian 12 and 13 too).
- The configuration directory is group `root` (was `group`); it's `0755`,
  so its group gave nothing.
- `vm.args` is owned by `user` (was `root`), as `local.ini` is.

## [1.1.0] - 2026-11-13

### Added

- `manage_user` and `manage_group` (default true): leave the user or group
  to something else.
- `uid` and `gid` for the user and group the module creates.

## [1.0.0] - 2026-10-23

### Added

- The `bigcouch` class: BigCouch 0.4 as one node (q = n = 1) on 127.0.0.1
  on Debian 12 and 13, from a given APT repository or the server's existing
  sources. Configuration, node name and cookie are in place before the
  package first starts BigCouch; the admin password is stored hashed.
- `vm_args`, extra lines for `vm.args`.
- `bigcouch::admin_hash`, which makes BigCouch's `-hashed-` admin hashes.

[1.2.0]: https://github.com/freepenguins/puppet-bigcouch/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/freepenguins/puppet-bigcouch/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/freepenguins/puppet-bigcouch/releases/tag/v1.0.0
