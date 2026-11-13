# @summary Adds the APT repository with the BigCouch packages, if one is given.
#
# @api private
class bigcouch::repo {
  assert_private()

  if $bigcouch::repository =~ NotUndef {
    # With only `name` and `source` in `key`, apt writes a keyring and
    # signed-by instead of using apt-key.
    apt::source { 'bigcouch':
      *             => { 'comment' => 'BigCouch packages' } + $bigcouch::repository,
      notify_update => true,
    }
    Apt::Source['bigcouch'] -> Class['apt::update']
  }
}
