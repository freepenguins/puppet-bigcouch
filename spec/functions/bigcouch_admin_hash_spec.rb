# frozen_string_literal: true

require 'spec_helper'

describe 'bigcouch::admin_hash' do
  subject(:admin_hash) { find_function }

  it { is_expected.not_to be_nil }

  # Expected value computed independently with Python's hashlib:
  #   hashlib.sha1(b'secret' + b'0123456789abcdef').hexdigest()
  it 'returns -hashed-<sha1(password + salt)>,<salt>, as Sensitive' do
    result = admin_hash.execute('secret', '0123456789abcdef')
    expect(result).to be_a(Puppet::Pops::Types::PSensitiveType::Sensitive)
    expect(result.unwrap).to eq('-hashed-153b4bcb8507185e8213aacad286ec7be94862e6,0123456789abcdef')
  end

  it 'hashes the value of a Sensitive password' do
    expect(admin_hash.execute(sensitive('secret'), '0123456789abcdef').unwrap)
      .to eq(admin_hash.execute('secret', '0123456789abcdef').unwrap)
  end

  it { is_expected.to run.with_params('secret', 'not-a-salt!').and_raise_error(ArgumentError, %r{salt}) }
  it { is_expected.to run.with_params('', 'abcdef').and_raise_error(ArgumentError, %r{password}) }
end
