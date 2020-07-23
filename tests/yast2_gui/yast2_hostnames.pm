# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: yast2_hostnames check hostnames and add/delete hostsnames
#    Make sure those yast2 modules can opened properly. We can add more
#    feature test against each module later, it is ensure it will not crashed
#    while launching atm.
# Maintainer: Zaoliang Luo <zluo@suse.com>

use base "y2_module_guitest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $self = shift;

    select_console 'root-console';
    # zypper_call("ar https://download.opensuse.org/repositories/YaST:/Head/openSUSE_Leap_15.2/YaST:Head.repo");
    # zypper_call("--gpg-auto-import-keys ref");
    # zypper_call("in libyui-rest-api");
    # zypper_call("up --allow-vendor-change -r YaST_Head");
    
    my $ip = script_output("ip -4 addr show eth0 | grep -oP '(?<=inet\\s)\\d+(\\.\\d+){3}'");
    systemctl 'stop firewalld';

    # select_console 'x11';
    # $self->launch_yast2_module_x11('host', match_timeout => 30);
    # sleep;


    # print qx{ip a};
    # print qx{ping -I br1 -c 4 $ip};
    # print qx{id};
    # print qx{cat /etc/os-release};
    # print qx{ruby --version};    
    # print qx{git clone -b poc_ruby_integration --single-branch https://github.com/jknphy/libyui_client.git};
    # print qx{sudo zypper --non-interactive in ruby2.5-rubygem-bundler};
    
    # print qx{echo "\$HOME"};
    # print qx{echo "\$PWD"};

    # print qx{HOME=\$PWD bundle install --path \$PWD/libyui_client/.vendor/bundler --gemfile \$PWD/libyui_client/Gemfile};
    # print qx{ls -lah \$PWD/libyui_client};
    # # print qx{cd libyui_client ; HOME=\$PWD bundle exec rspec};
    # print qx{cd libyui_client ; HOME=\$PWD GUEST_IP=$ip bundle exec ruby lib/libyui_client/sample.rb};

}

1;
