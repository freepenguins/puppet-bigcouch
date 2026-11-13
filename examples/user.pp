# BigCouch with fixed ids for the bigcouch user and group.
class { 'bigcouch':
  uid => 990,
  gid => 990,
}
