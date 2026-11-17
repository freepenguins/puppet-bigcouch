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
#   Erlang distribution cookie (letters, digits and `_`). Nodes of one
#   cluster must share it, and anyone who has it and reaches the
#   distribution ports can run code on the node. Defaults to a random string
#   that stays the same for this node.
# @param config_dir
#   Where `local.ini`, `vm.args` and `runtime.ini` (see `runtime_ini`) go. The package's
#   `/opt/bigcouch/bin/bigcouch` reads `/etc/bigcouch/vm.args`.
# @param data_dir
#   Databases (`database_dir`), and view indexes unless `view_index_dir` is
#   set. Puppet manages this directory's owner, group and mode, so don't
#   point it at a shared path such as `/srv`: give a directory of its own,
#   such as `/srv/db`.
# @param view_index_dir
#   View indexes (`view_index_dir`). Unset, they go in `data_dir`.
# @param log_file
#   BigCouch's log. Puppet manages its directory like `data_dir`.
# @param dir_mode
#   Mode of `data_dir`, `view_index_dir` and the log directory.
# @param config_mode
#   Mode of `local.ini`, `runtime.ini` and `vm.args`. They hold the admin's
#   password hash and the Erlang cookie (which gives a shell on the node),
#   so the default keeps them from other users.
# @param runtime_ini
#   Whether to add `runtime.ini` as the last configuration file, where
#   BigCouch saves settings changed through its _config API. With false,
#   BigCouch saves them to `local.ini`, which Puppet then overwrites.
# @param user
#   The user BigCouch runs as, which owns `data_dir`.
# @param group
#   The group of `user`.
# @param manage_user
#   Whether to create `user` (a system user with home `user_home`, shell
#   `user_shell` and comment `user_comment`). With false the user must already exist, from another
#   class or a directory service, before the class runs: the files the
#   module writes are owned by it.
# @param manage_group
#   Whether to create `group` (a system group). With false the group must
#   already exist.
# @param user_home
#   The user's home, when `manage_user` is true. Unset, `data_dir`.
# @param user_shell
#   The user's shell, when `manage_user` is true. `/sbin/nologin` exists on
#   Debian 12 and 13 (merged `/usr`) and on EL.
# @param user_comment
#   The user's comment (GECOS), when `manage_user` is true.
# @param uid
#   The user's uid, when `manage_user` is true. Unset, the system picks one.
# @param gid
#   The group's gid, when `manage_group` is true. Unset, the system picks one.
# @param service_name
#   The service the package installs.
# @param settings
#   More settings for `local.ini`, as `{ section => { key => value } }`,
#   merged over the module's (yours win).
# @param async_threads
#   Erlang's async I/O thread pool (`+A` in `vm.args`).
# @param detached
#   Whether BigCouch detaches from the terminal (`-detached` in `vm.args`).
#   Only for a service whose init script expects BigCouch to fork, such as
#   2600Hz's on CentOS 7; under a systemd unit that runs it in the
#   foreground, as the Debian package's does, it must stay false.
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
  Variant[Pattern[/\A\w+\z/], Sensitive[Pattern[/\A\w+\z/]]] $cookie = Sensitive(stdlib::fqdn_rand_string(32, undef, 'bigcouch cookie')),
  Stdlib::Absolutepath                               $config_dir      = '/etc/bigcouch',
  Stdlib::Absolutepath                               $data_dir        = '/var/lib/bigcouch',
  Optional[Stdlib::Absolutepath]                     $view_index_dir  = undef,
  Stdlib::Absolutepath                               $log_file        = '/var/log/bigcouch/bigcouch.log',
  Stdlib::Filemode                                   $dir_mode        = '0750',
  Stdlib::Filemode                                   $config_mode     = '0640',
  Boolean                                            $runtime_ini     = true,
  String[1]                                          $user            = 'bigcouch',
  String[1]                                          $group           = 'bigcouch',
  Boolean                                            $manage_user     = true,
  Boolean                                            $manage_group    = true,
  Optional[Stdlib::Absolutepath]                     $user_home       = undef,
  Stdlib::Absolutepath                               $user_shell      = '/sbin/nologin',
  String                                             $user_comment    = 'BigCouch user',
  Optional[Integer[0]]                               $uid             = undef,
  Optional[Integer[0]]                               $gid             = undef,
  String[1]                                          $service_name    = 'bigcouch',
  Hash[String[1], Hash[String[1], Scalar]]           $settings        = {},
  Integer[0, 1024]                                   $async_threads   = 16,
  Boolean                                            $detached        = false,
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
