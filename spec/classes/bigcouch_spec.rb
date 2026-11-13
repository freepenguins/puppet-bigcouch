# frozen_string_literal: true

require 'spec_helper'

describe 'bigcouch' do
  def file_content(path)
    content = catalogue.resource('File', path)[:content]
    content.respond_to?(:unwrap) ? content.unwrap : content
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:fqdn) { os_facts[:networking]['fqdn'] }

      context 'with defaults' do
        it { is_expected.to compile.with_all_deps }

        it 'writes the configuration before installing the package, which starts BigCouch' do
          is_expected.to contain_class('bigcouch::repo').that_comes_before('Class[bigcouch::config]')
          is_expected.to contain_class('bigcouch::config').that_comes_before('Class[bigcouch::install]')
          is_expected.to contain_class('bigcouch::install').that_comes_before('Class[bigcouch::service]')
          is_expected.to contain_class('bigcouch::config').that_notifies('Class[bigcouch::service]')
        end

        it { is_expected.not_to contain_apt__source('bigcouch') }
        it { is_expected.to contain_package('bigcouch').with_ensure('installed') }
        it { is_expected.to contain_service('bigcouch').with(ensure: 'running', enable: true) }
        it { is_expected.to contain_group('bigcouch').with(system: true) }
        it { is_expected.to contain_user('bigcouch').with(system: true, gid: 'bigcouch', home: '/var/lib/bigcouch', shell: '/usr/sbin/nologin') }
        it { is_expected.to contain_file('/etc/bigcouch').with(ensure: 'directory', owner: 'root', group: 'bigcouch', mode: '0755') }
        it { is_expected.to contain_file('/var/lib/bigcouch').with(ensure: 'directory', owner: 'bigcouch', mode: '0750') }
        it { is_expected.to contain_file('/var/log/bigcouch').with(ensure: 'directory', owner: 'bigcouch', mode: '0750') }

        it 'configures one node on 127.0.0.1 with q = n = 1 and no admin' do
          is_expected.to contain_file('/etc/bigcouch/local.ini').with(owner: 'bigcouch', group: 'bigcouch', mode: '0640', show_diff: false)
          content = file_content('/etc/bigcouch/local.ini')
          expect(content).to match(%r{^\[chttpd\]\nbind_address = 127\.0\.0\.1\nport = 5984\nrequire_valid_user = false$})
          expect(content).to match(%r{^\[httpd\]\nbind_address = 127\.0\.0\.1\nport = 5986\nrequire_valid_user = false$})
          expect(content).to match(%r{^\[cluster\]\nn = 1\nq = 1\nr = 1\nw = 1$})
          expect(content).to match(%r{^\[couchdb\]\ndatabase_dir = /var/lib/bigcouch\nview_index_dir = /var/lib/bigcouch$})
          expect(content).to match(%r{^\[log\]\nfile = /var/log/bigcouch/bigcouch\.log$})
          expect(content).not_to include('[admins]')
        end

        it { is_expected.to contain_file('/etc/bigcouch/runtime.ini').with(replace: false, owner: 'bigcouch', mode: '0640') }

        it 'writes vm.args with the node name, a stable cookie and the ini chain' do
          is_expected.to contain_file('/etc/bigcouch/vm.args').with(owner: 'root', group: 'bigcouch', mode: '0640', show_diff: false)
          content = file_content('/etc/bigcouch/vm.args')
          expect(content).to match(%r{^-name bigcouch@#{Regexp.escape(fqdn)}$})
          expect(content).to match(%r{^-setcookie [A-Za-z0-9]{32}$})
          expect(content).to match(%r{^\+Bd -noinput$})
          expect(content).to match(%r{^-couch_ini /opt/bigcouch/etc/default\.ini /etc/bigcouch/local\.ini /etc/bigcouch/runtime\.ini$})
          expect(content).not_to include('vm_args')
        end
      end

      context 'with vm_args' do
        let(:params) { { vm_args: ['+P 1048576', '-kernel net_ticktime 30'] } }

        it 'appends them after the module\'s lines' do
          content = file_content('/etc/bigcouch/vm.args')
          expect(content).to match(%r{^-couch_ini [^\n]+\n\n# From the bigcouch class's vm_args\.\n\+P 1048576\n-kernel net_ticktime 30\n\z})
        end

        it { is_expected.to contain_file('/etc/bigcouch/vm.args').that_notifies('Class[bigcouch::service]') }
      end

      context 'with a vm_args line containing a newline' do
        let(:params) { { vm_args: ["+P 1\n-setcookie x"] } }

        it { is_expected.to compile.and_raise_error(%r{vm_args}) }
      end

      context 'with an admin' do
        let(:params) { { admin_username: 'admin', admin_password: sensitive('s3cret') } }

        it 'stores the password hashed in BigCouch\'s format' do
          content = file_content('/etc/bigcouch/local.ini')
          expect(content).to match(%r{^\[admins\]\nadmin = -hashed-[0-9a-f]{40},[0-9a-f]{32}$})
          expect(content).not_to include('s3cret')
        end
      end

      context 'with only an admin username' do
        let(:params) { { admin_username: 'admin' } }

        it { is_expected.to compile.and_raise_error(%r{set both admin_username and admin_password}) }
      end

      context 'with a repository' do
        let(:params) do
          {
            repository: {
              'location' => 'https://apt.example.test/bigcouch/',
              'release' => os_facts[:os]['distro']['codename'],
              'repos' => 'main',
              'key' => { 'name' => 'bigcouch.asc', 'source' => 'https://apt.example.test/bigcouch/key.asc' },
            },
          }
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_apt__source('bigcouch').with(
            location: 'https://apt.example.test/bigcouch/',
            release: os_facts[:os]['distro']['codename'],
            repos: 'main',
            key: { 'name' => 'bigcouch.asc', 'source' => 'https://apt.example.test/bigcouch/key.asc' },
            notify_update: true,
          ).that_comes_before('Class[apt::update]')
        end

        it { is_expected.to contain_class('apt::update').that_comes_before('Package[bigcouch]') }
      end

      context 'with other addresses, names and settings' do
        let(:params) do
          {
            bind_address: '0.0.0.0',
            port: 15_984,
            node_local_port: 15_986,
            node_name: 'bc1@db.example.test',
            cookie: sensitive('Secr3tCookie'),
            data_dir: '/srv/bigcouch',
            log_file: '/srv/log/bigcouch.log',
            settings: { 'log' => { 'level' => 'debug' }, 'cluster' => { 'n' => 3 } },
          }
        end

        it 'passes them on, with your settings over the module\'s' do
          content = file_content('/etc/bigcouch/local.ini')
          expect(content).to match(%r{^\[chttpd\]\nbind_address = 0\.0\.0\.0\nport = 15984})
          expect(content).to match(%r{^\[httpd\]\nbind_address = 0\.0\.0\.0\nport = 15986})
          expect(content).to match(%r{^\[cluster\]\nn = 3\nq = 1$})
          expect(content).to match(%r{^\[log\]\nfile = /srv/log/bigcouch\.log\nlevel = debug$})
          expect(content).to match(%r{^database_dir = /srv/bigcouch$})
          vm_args = file_content('/etc/bigcouch/vm.args')
          expect(vm_args).to match(%r{^-name bc1@db\.example\.test$})
          expect(vm_args).to match(%r{^-setcookie Secr3tCookie$})
          is_expected.to contain_file('/srv/bigcouch').with_owner('bigcouch')
          is_expected.to contain_file('/srv/log').with_owner('bigcouch')
        end
      end
    end
  end
end
