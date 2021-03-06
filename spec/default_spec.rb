require 'spec_helper'

describe 'rabbitmq::default' do
  let(:runner) { ChefSpec::ServerRunner.new(REDHAT_OPTS) }
  let(:node) { runner.node }

  let(:chef_run) do
    runner.converge(described_recipe)
  end

  let(:file_cache_path) { Chef::Config[:file_cache_path] }

  include_context 'rabbitmq-stubs'

  it 'creates a directory for mnesiadir' do
    expect(chef_run).to create_directory('/var/lib/rabbitmq/mnesia')
  end

  describe 'rabbitmq-env.conf' do
    let(:file) { chef_run.template('/etc/rabbitmq/rabbitmq-env.conf') }

    it 'creates a template rabbitmq-env.conf with attributes' do
      expect(chef_run).to create_template(file.name).with(
        :user => 'root',
        :group => 'root',
        :source => 'rabbitmq-env.conf.erb',
        :mode => 00644)
    end

    it 'has no erl args by default' do
      [/^SERVER_ADDITIONAL_ERL_ARGS=/,
       /^CTL_ERL_ARGS=/].each do |line|
        expect(chef_run).not_to render_file(file.name).with_content(line)
      end
    end

    it 'has erl args overridden' do
      node.set['rabbitmq']['server_additional_erl_args'] = 'test123'
      node.set['rabbitmq']['ctl_erl_args'] = 'test123'
      [/^SERVER_ADDITIONAL_ERL_ARGS='test123'/,
       /^CTL_ERL_ARGS='test123'/].each do |line|
        expect(chef_run).to render_file(file.name).with_content(line)
      end
    end

    it 'has no additional_env_settings default' do
      expect(chef_run).not_to render_file(file.name).with_content(/^# Additional ENV settings/)
    end

    it 'has additional_env_settings' do
      node.set['rabbitmq']['additional_env_settings'] = [
        'USE_LONGNAME=true',
        'WHATS_ON_THE_TELLY=penguin']
      [/^WHATS_ON_THE_TELLY=penguin/,
       /^# Additional ENV settings/,
       /^USE_LONGNAME=true/].each do |line|
        expect(chef_run).to render_file(file.name).with_content(line)
      end
    end
  end

  it 'should create the directory /var/lib/rabbitmq/mnesia' do
    expect(chef_run).to create_directory('/var/lib/rabbitmq/mnesia').with(
      :user => 'rabbitmq',
      :group => 'rabbitmq',
      :mode => '775'
   )
  end

  it 'does not enable a rabbitmq service when manage_service is false' do
    node.set['rabbitmq']['manage_service'] = false
    expect(chef_run).not_to enable_service('rabbitmq-server')
  end

  it 'does not start a rabbitmq service when manage_service is false' do
    node.set['rabbitmq']['manage_service'] = false
    expect(chef_run).not_to start_service('rabbitmq-server')
  end

  it 'enables a rabbitmq service when manage_service is true' do
    node.set['rabbitmq']['manage_service'] = true
    expect(chef_run).to enable_service('rabbitmq-server')
  end

  it 'starts a rabbitmq service when manage_service is true' do
    node.set['rabbitmq']['manage_service'] = true
    expect(chef_run).to start_service('rabbitmq-server')
  end

  it 'should have the use_distro_version set to false' do
    expect(chef_run.node['rabbitmq']['use_distro_version']).to eq(false)
  end

  it 'should install the erlang package' do
    expect(chef_run).to install_package('erlang')
  end

  it 'should create the rabbitmq /etc/default file' do
    expect(chef_run).to create_template("/etc/default/#{chef_run.node['rabbitmq']['service_name']}").with(
      :user => 'root',
      :group => 'root',
      :source => 'default.rabbitmq-server.erb',
      :mode => 00644
    )
  end

  it 'creates a template rabbitmq.config with attributes' do
    expect(chef_run).to create_template('/etc/rabbitmq/rabbitmq.config').with(
      :user => 'root',
      :group => 'root',
      :source => 'rabbitmq.config.erb',
      :mode => 00644)
  end

  describe 'ssl ciphers' do
    it 'has no ssl ciphers specified by default' do
      expect(chef_run).not_to render_file('/etc/rabbitmq/rabbitmq.config').with_content(
        /{ciphers,[{.*}]}/)
    end

    it 'allows ssl ciphers' do
      node.set['rabbitmq']['ssl'] = true
      node.set['rabbitmq']['ssl_ciphers'] = ['{ecdhe_ecdsa,aes_128_cbc,sha256}', '{ecdhe_ecdsa,aes_256_cbc,sha}']
      expect(chef_run).to render_file('/etc/rabbitmq/rabbitmq.config').with_content(
                            '{ciphers,[{ecdhe_ecdsa,aes_128_cbc,sha256},{ecdhe_ecdsa,aes_256_cbc,sha}]}')
    end

    it 'allows web console ssl ciphers' do
      node.set['rabbitmq']['web_console_ssl'] = true
      node.set['rabbitmq']['ssl_ciphers'] = ['"ECDHE-ECDSA-AES256-SHA384"', '"ECDH-ECDSA-AES256-SHA384"']
      expect(chef_run).to render_file('/etc/rabbitmq/rabbitmq.config').with_content(
                            "{ciphers,[\"ECDHE-ECDSA-AES256-SHA384\",\"ECDH-ECDSA-AES256-SHA384\"]}")
    end

    it 'should set additional rabbitmq config' do
      node.set['rabbitmq']['additional_rabbit_configs'] = { 'foo' => 'bar' }
      expect(chef_run).to render_file('/etc/rabbitmq/rabbitmq.config').with_content('foo, bar')
    end
  end

  describe 'suse' do
    let(:runner) { ChefSpec::ServerRunner.new(SUSE_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      runner.converge(described_recipe)
    end

    it 'should install the rabbitmq package' do
      expect(chef_run).to install_package('rabbitmq-server')
    end

    it 'should install the rabbitmq plugin package' do
      expect(chef_run).to install_package('rabbitmq-server-plugins')
    end
  end

  describe 'ubuntu' do
    let(:runner) { ChefSpec::ServerRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set['rabbitmq']['version'] = '3.5.6'
      runner.converge(described_recipe)
    end

    it 'creates a template for 90forceyes' do
      expect(chef_run).to create_template('/etc/apt/apt.conf.d/90forceyes')
    end

    include_context 'rabbitmq-stubs'

    # ~FC005 -- we should ignore this during compile time
    it 'should autostart via the exit 101' do
      expect(chef_run).to run_execute('disable auto-start 1/2')
    end

    # ~FC005 -- we should ignore this during compile time
    it 'should disable the autostart 2/2' do
      expect(chef_run).to run_execute('disable auto-start 2/2')
    end

    # ~FC005 -- we should ignore this during compile time
    it 'should install the logrotate package' do
      expect(chef_run).to install_package('logrotate')
    end

    it 'creates a rabbitmq-server deb in the cache path' do
      expect(chef_run).to create_remote_file_if_missing('/tmp/rabbitmq-server_3.5.6-1_all.deb')
    end

    it 'installs the rabbitmq-server deb_package with the default action' do
      expect(chef_run).to install_dpkg_package('/tmp/rabbitmq-server_3.5.6-1_all.deb')
    end

    it 'creates a template rabbitmq-server with attributes' do
      expect(chef_run).to create_template('/etc/default/rabbitmq-server').with(
        :user => 'root',
        :group => 'root',
        :source => 'default.rabbitmq-server.erb',
        :mode => 00644)
    end

    it 'should undo the service disable hack' do
      expect(chef_run).to run_execute('undo service disable hack')
    end

    describe 'uses distro version' do
      before do
        node.set['rabbitmq']['use_distro_version'] = true
      end

      it 'should install rabbitmq-server package' do
        expect(chef_run).to install_package('rabbitmq-server')
      end

      it 'should install the logrotate package' do
        expect(chef_run).to install_package('logrotate')
      end
    end
  end

  describe 'redhat' do
    let(:runner) { ChefSpec::ServerRunner.new(REDHAT_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      runner.converge(described_recipe)
    end

    it 'creates a rabbitmq-server rpm in the cache path' do
      expect(chef_run).to create_remote_file_if_missing('/tmp/rabbitmq-server-3.5.6-1.noarch.rpm')
      expect(chef_run).to_not create_remote_file_if_missing('/tmp/not-rabbitmq-server-3.5.6-1.noarch.rpm')
    end

    it 'installs the rabbitmq-server rpm_package with the default action' do
      expect(chef_run).to install_rpm_package('/tmp/rabbitmq-server-3.5.6-1.noarch.rpm')
      expect(chef_run).to_not install_rpm_package('/tmp/not-rabbitmq-server-3.5.6-1.noarch.rpm')
    end

    describe 'uses distro version' do
      before do
        node.set['rabbitmq']['use_distro_version'] = true
      end

      it 'should install rabbitmq-server package' do
        expect(chef_run).to install_package('rabbitmq-server')
      end
    end

    it 'loopback_users will not show in config file unless attribute is specified' do
      expect(chef_run).not_to render_file('/etc/rabbitmq/rabbitmq.config').with_content('loopback_users')
    end

    it 'loopback_users is empty when attribute is empty array' do
      node.set['rabbitmq']['loopback_users'] = []
      expect(chef_run).to render_file('/etc/rabbitmq/rabbitmq.config').with_content('loopback_users, []')
    end

    it 'loopback_users can list single user' do
      node.set['rabbitmq']['loopback_users'] = ['foo']
      expect(chef_run).to render_file('/etc/rabbitmq/rabbitmq.config').with_content('loopback_users, [<<"foo">>]')
    end

    it 'loopback_users can list multiple users' do
      node.set['rabbitmq']['loopback_users'] = %w(foo bar)
      expect(chef_run).to render_file('/etc/rabbitmq/rabbitmq.config').with_content('loopback_users, [<<"foo">>,<<"bar">>]')
    end
  end

  describe 'centos' do
    let(:runner) { ChefSpec::ServerRunner.new(CENTOS_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      runner.converge(described_recipe)
    end

    it 'creates a rabbitmq-server rpm in the cache path' do
      expect(chef_run).to create_remote_file_if_missing('/tmp/rabbitmq-server-3.5.6-1.noarch.rpm')
      expect(chef_run).to_not create_remote_file_if_missing('/tmp/not-rabbitmq-server-3.5.6-1.noarch.rpm')
    end

    it 'installs the rabbitmq-server rpm_package with the default action' do
      expect(chef_run).to install_rpm_package('/tmp/rabbitmq-server-3.5.6-1.noarch.rpm')
      expect(chef_run).to_not install_rpm_package('/tmp/not-rabbitmq-server-3.5.6-1.noarch.rpm')
    end

    it 'includes the `yum-epel` recipe' do
      expect(chef_run).to include_recipe('yum-epel')
    end

    describe 'uses distro version' do
      before do
        node.set['rabbitmq']['use_distro_version'] = true
      end

      it 'should install rabbitmq-server package' do
        expect(chef_run).to install_package('rabbitmq-server')
      end
    end
  end

  describe 'fedora' do
    let(:runner) { ChefSpec::ServerRunner.new(FEDORA_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set['rabbitmq']['version'] = '3.5.6'
      runner.converge(described_recipe)
    end

    it 'creates a rabbitmq-server rpm in the cache path' do
      expect(chef_run).to create_remote_file_if_missing('/tmp/rabbitmq-server-3.5.6-1.noarch.rpm')
      expect(chef_run).to_not create_remote_file_if_missing('/tmp/not-rabbitmq-server-3.5.6-1.noarch.rpm')
    end

    it 'installs the rabbitmq-server rpm_package with the default action' do
      expect(chef_run).to install_rpm_package('/tmp/rabbitmq-server-3.5.6-1.noarch.rpm')
      expect(chef_run).to_not install_rpm_package('/tmp/not-rabbitmq-server-3.5.6-1.noarch.rpm')
    end

    describe 'uses distro version' do
      before do
        node.set['rabbitmq']['use_distro_version'] = true
      end

      it 'should install rabbitmq-server package' do
        expect(chef_run).to install_package('rabbitmq-server')
      end
    end
  end
end
