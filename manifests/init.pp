# @summary Installs and configures BigCouch 0.4 as one node.
#
# BigCouch is Cloudant's clustered CouchDB 1.1, whose features went into
# CouchDB 2. Nothing publishes BigCouch packages for Debian 12 or 13;
# [puppet-bigcouch-packaging](https://github.com/freepenguins/puppet-bigcouch-packaging) builds `bigcouch` 0.4.2b (with
# Erlang/OTP R16B03-1) and the `couch-libmozjs185-1.0` it needs. Publish
# them in an APT repository and give it as `repository`, or leave
# `repository` unset to install `package_name` from whatever APT sources the
# server already has.
#
# Puppet writes `local.ini` and `vm.args` before installing the package,
# because the package starts BigCouch, and a node renamed after its first
# start keeps the old name in its shard maps. The admin password is written
# already hashed in BigCouch's own format, so BigCouch leaves it alone.
#
# @example One node on 127.0.0.1 with an admin
#   class { 'bigcouch':
#     admin_username => 'admin',
#     admin_password => Sensitive('change-me'),
#     repository     => {
#       'location' => 'https://apt.example.com/bigcouch/',
#       'release'  => $facts['os']['distro']['codename'],
#       'repos'    => 'main',
#       'key'      => {
#         'name'   => 'bigcouch.asc',
#         'source' => 'https://apt.example.com/bigcouch/key.asc',
#       },
#     },
#   }
#
# @example Listening on every address, with more logging
#   class { 'bigcouch':
#     admin_username => 'admin',
#     admin_password => Sensitive('change-me'),
#     bind_address   => '0.0.0.0',
#     settings       => {
#       'log' => { 'level' => 'debug' },
#     },
#   }
#
# @example More Erlang VM arguments
#   class { 'bigcouch':
#     vm_args => ['+P 1048576', '-kernel net_ticktime 30'],
#   }
#
# @param admin_username
#   The admin to create. Without one BigCouch runs in "admin party" mode,
#   where anyone who reaches the port is an admin.
# @param admin_password
#   The admin's password.
# @param repository
#   `apt::source` parameters for the repository with the `bigcouch` and
#   `couch-libmozjs185-1.0` packages, such as `location`, `release`, `repos`
#   and `key` (`{ name, source }`) or `allow_unsigned`. Unset, no source is
#   added and the package comes from the APT sources already configured.
# @param package_name
#   The BigCouch package.
# @param package_ensure
#   The package's `ensure`, such as a version.
# @param bind_address
#   Address both HTTP APIs listen on.
# @param port
#   The clustered HTTP API port.
# @param node_local_port
#   The node-local HTTP API port.
# @param node_name
#   Erlang node name. Defaults to `bigcouch@<fqdn>`, what the package's own
#   `-name bigcouch` becomes. Set it before the first run (see above).
# @param cookie
#   Erlang distribution cookie. Nodes of one cluster must share it. Defaults
#   to a random string that stays the same for this node.
# @param config_dir
#   Where `local.ini`, `runtime.ini` and `vm.args` go. The package's
#   `/opt/bigcouch/bin/bigcouch` reads `/etc/bigcouch/vm.args`.
# @param data_dir
#   Databases and view indexes.
# @param log_file
#   BigCouch's log.
# @param user
#   The user BigCouch runs as, which owns `data_dir`.
# @param group
#   The group of `user`.
# @param service_name
#   The service the package installs.
# @param settings
#   More settings for `local.ini`, as `{ section => { key => value } }`,
#   merged over the module's (yours win).
# @param vm_args
#   More lines for `vm.args`, written as given after the module's own, such
#   as `'+P 1048576'` or `'-kernel net_ticktime 30'`. For an emulator flag
#   the module already sets (`+A`, `+K`), the later line wins. Don't set
#   `-name`, `-setcookie` or `-couch_ini` here: use `node_name`, `cookie`
#   and `settings`.
class bigcouch (
  Optional[Pattern[/\A[^\s=:]+\z/]]                  $admin_username  = undef,
  Optional[Variant[String[1], Sensitive[String[1]]]] $admin_password  = undef,
  Optional[Hash[String[1], Any]]                     $repository      = undef,
  String[1]                                          $package_name    = 'bigcouch',
  String[1]                                          $package_ensure  = 'installed',
  Stdlib::IP::Address::Nosubnet                      $bind_address    = '127.0.0.1',
  Stdlib::Port                                       $port            = 5984,
  Stdlib::Port                                       $node_local_port = 5986,
  Pattern[/\A[^@\s]+@[^@\s]+\z/]                     $node_name       = "bigcouch@${facts['networking']['fqdn']}",
  Variant[Pattern[/\A[A-Za-z0-9]+\z/], Sensitive[Pattern[/\A[A-Za-z0-9]+\z/]]] $cookie = Sensitive(stdlib::fqdn_rand_string(32, undef, 'bigcouch cookie')),
  Stdlib::Absolutepath                               $config_dir      = '/etc/bigcouch',
  Stdlib::Absolutepath                               $data_dir        = '/var/lib/bigcouch',
  Stdlib::Absolutepath                               $log_file        = '/var/log/bigcouch/bigcouch.log',
  String[1]                                          $user            = 'bigcouch',
  String[1]                                          $group           = 'bigcouch',
  String[1]                                          $service_name    = 'bigcouch',
  Hash[String[1], Hash[String[1], Scalar]]           $settings        = {},
  Array[Pattern[/\A[^\r\n]+\z/]]                      $vm_args         = [],
) {
  if ($admin_username =~ Undef) != ($admin_password =~ Undef) {
    fail('bigcouch: set both admin_username and admin_password, or neither.')
  }

  contain bigcouch::repo
  contain bigcouch::config
  contain bigcouch::install
  contain bigcouch::service

  # The configuration goes in before the package, which starts BigCouch.
  Class['bigcouch::repo']
  -> Class['bigcouch::config']
  -> Class['bigcouch::install']
  -> Class['bigcouch::service']

  Class['bigcouch::config'] ~> Class['bigcouch::service']
}
