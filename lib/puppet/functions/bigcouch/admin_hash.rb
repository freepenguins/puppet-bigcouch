# frozen_string_literal: true

require 'digest'

# @summary Hashes a BigCouch admin password for the `[admins]` ini section.
#
# BigCouch (like CouchDB 1.x) replaces a plain-text admin password with a
# hash when it starts and writes the hash back to its configuration, so a
# plain-text password in a Puppet-managed file would change on every run. A
# hash in BigCouch's own format, `-hashed-<sha1(password + salt)>,<salt>`, is
# left alone. The salt should stay the same for a node (for example from
# `stdlib::fqdn_rand_string`), so the result is the same on every run.
Puppet::Functions.create_function(:'bigcouch::admin_hash') do
  # @param password
  #   The admin password.
  # @param salt
  #   The salt, as a string of letters and digits.
  # @return [Sensitive[String]]
  #   The value for the admin's line in `[admins]`.
  # @example
  #   bigcouch::admin_hash(Sensitive('secret'), 'a1b2c3d4')
  dispatch :admin_hash do
    param 'Variant[String[1], Sensitive[String[1]]]', :password
    param 'Pattern[/\A[A-Za-z0-9]+\z/]', :salt
  end

  def admin_hash(password, salt)
    password = password.unwrap if password.respond_to?(:unwrap)
    Puppet::Pops::Types::PSensitiveType::Sensitive.new("-hashed-#{Digest::SHA1.hexdigest(password + salt)},#{salt}")
  end
end
