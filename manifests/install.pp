# @summary Installs the BigCouch package.
#
# @api private
class bigcouch::install {
  assert_private()

  package { $bigcouch::package_name:
    ensure => $bigcouch::package_ensure,
  }

  if $bigcouch::repository =~ NotUndef {
    Class['apt::update'] -> Package[$bigcouch::package_name]
  }
}
