# BigCouch as one node on 127.0.0.1, with an admin, from the APT repository
# built with packaging/ (repo.sh).
class { 'bigcouch':
  admin_username => 'admin',
  admin_password => Sensitive('change-me'),
  repository     => {
    'location' => 'https://apt.example.com/bigcouch/',
    'release'  => $facts['os']['distro']['codename'],
    'repos'    => 'main',
    'key'      => {
      'name'   => 'bigcouch.asc',
      'source' => 'https://apt.example.com/bigcouch/key.asc',
    },
  },
}
