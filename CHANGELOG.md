# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[1.1.0]: https://github.com/freepenguins/puppet-bigcouch/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/freepenguins/puppet-bigcouch/releases/tag/v1.0.0
