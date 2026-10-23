# @summary Runs BigCouch with the package's own systemd unit.
#
# @api private
class bigcouch::service {
  assert_private()

  service { $bigcouch::service_name:
    ensure => running,
    enable => true,
  }
}
