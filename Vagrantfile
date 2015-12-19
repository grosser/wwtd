Vagrant.configure(2) do |config|
  config.vm.box = 'minimal/trusty64'
  # config.vm.box = 'ubuntu/trusty64-juju'

  config.vm.provider "virtualbox" do |vb|
    vb.customize ["modifyvm", :id, "--usb", "off"]
    vb.customize ["modifyvm", :id, "--usbehci", "off"]
  end

  # I tried to install rvm using chef and travis cookbooks but it was total pain,
  # so I switched to this solution http://stackoverflow.com/questions/27961797/vagrantfile-inline-script-and-rvm-provisioning
  config.vm.provision "shell", inline: <<-SHELL
    RUBY_VERSION="2.0.0"
    sudo apt-get -y update
    sudo apt-get -y install curl
    # Install ruby environment
    if ! type rvm >/dev/null 2>&1; then
      curl -sSL https://rvm.io/mpapis.asc | gpg --import -
      curl -L https://get.rvm.io | bash -s stable
      source /etc/profile.d/rvm.sh
    fi

    if ! rvm list rubies ruby | grep ruby-${RUBY_VERSION}; then
      rvm install ${RUBY_VERSION}
    fi

    RUBY_V="2.1.5"
    if ! rvm list rubies ruby | grep ruby-${RUBY_V}; then
      rvm install ${RUBY_V}
    fi

    RUBY_V="2.2.1"
    if ! rvm list rubies ruby | grep ruby-${RUBY_V}; then
      rvm install ${RUBY_V}
    fi

    RUBY_V="jruby-1.7.19"
    if ! rvm list rubies ruby | grep ruby-${RUBY_V}; then
      rvm install ${RUBY_V}
    fi

    rvm --default use ${RUBY_VERSION}
    rvm all do gem install bundler
 SHELL
end
