# @summary Writes local.ini and vm.args, and creates the user and directories.
#
# Runs before the package is installed (see the bigcouch class), so the
# package's postinst finds the user and configuration already in place and
# only adds what is missing.
#
# @api private
class bigcouch::config {
  assert_private()

  $dir = $bigcouch::config_dir

  group { $bigcouch::group:
    ensure => present,
    system => true,
  }

  user { $bigcouch::user:
    ensure     => present,
    system     => true,
    gid        => $bigcouch::group,
    home       => $bigcouch::data_dir,
    managehome => false,
    shell      => '/usr/sbin/nologin',
    comment    => 'BigCouch',
    require    => Group[$bigcouch::group],
  }

  file { $dir:
    ensure => directory,
    owner  => 'root',
    group  => $bigcouch::group,
    mode   => '0755',
  }

  file { [$bigcouch::data_dir, $bigcouch::log_file.dirname]:
    ensure => directory,
    owner  => $bigcouch::user,
    group  => $bigcouch::group,
    mode   => '0750',
  }

  # The admin, hashed with a salt that stays the same for this node.
  if $bigcouch::admin_username =~ NotUndef {
    $_salt = stdlib::fqdn_rand_string(32, 'abcdef0123456789', 'bigcouch salt')
    $_hash = bigcouch::admin_hash($bigcouch::admin_password, $_salt)
    $_admins = { 'admins' => { $bigcouch::admin_username => $_hash.unwrap } }
  } else {
    $_admins = {}
  }

  $_module_settings = {
    'chttpd'  => {
      'bind_address'       => $bigcouch::bind_address,
      'port'               => $bigcouch::port,
      'require_valid_user' => false,
    },
    'httpd'   => {
      'bind_address'       => $bigcouch::bind_address,
      'port'               => $bigcouch::node_local_port,
      'require_valid_user' => false,
    },
    'couchdb' => {
      'database_dir'   => $bigcouch::data_dir,
      'view_index_dir' => $bigcouch::data_dir,
    },
    # One node: one copy of each document, in one shard per database.
    'cluster' => { 'q' => 1, 'n' => 1, 'r' => 1, 'w' => 1 },
    'log'     => { 'file' => $bigcouch::log_file },
  } + $_admins

  # Two-level merge: yours over the module's, key by key.
  $_sections = ($_module_settings + $bigcouch::settings).map |$section, $values| {
    [$section, pick($_module_settings[$section], {}) + $values]
  }.convert_to(Hash)

  file { "${dir}/local.ini":
    ensure    => file,
    owner     => $bigcouch::user,
    group     => $bigcouch::group,
    mode      => '0640',
    content   => Sensitive(epp("${module_name}/local.ini.epp", { 'sections' => $_sections })),
    show_diff => false,
  }

  # BigCouch saves settings changed through its _config API to the last ini
  # file, which Puppet only creates.
  file { "${dir}/runtime.ini":
    ensure  => file,
    owner   => $bigcouch::user,
    group   => $bigcouch::group,
    mode    => '0640',
    replace => false,
    content => "; Settings changed through BigCouch's _config API. Read last, so they win.\n",
  }

  $_vm_args = epp("${module_name}/vm.args.epp", {
      'node_name' => $bigcouch::node_name,
      'cookie'    => $bigcouch::cookie.unwrap,
      'ini_files' => ['/opt/bigcouch/etc/default.ini', "${dir}/local.ini", "${dir}/runtime.ini"],
  })

  file { "${dir}/vm.args":
    ensure    => file,
    owner     => 'root',
    group     => $bigcouch::group,
    mode      => '0640',
    content   => Sensitive($_vm_args),
    show_diff => false,
  }
}
