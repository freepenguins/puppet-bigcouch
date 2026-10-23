# BigCouch listening on every address, with its own node name, data
# directory and log level. Set node_name before the first run: a node keeps
# the name it first started with in its shard maps.
class { 'bigcouch':
  admin_username => 'admin',
  admin_password => Sensitive('change-me'),
  bind_address   => '0.0.0.0',
  node_name      => 'bigcouch@db1.example.com',
  data_dir       => '/srv/bigcouch',
  settings       => {
    'log' => { 'level' => 'warning' },
  },
}
