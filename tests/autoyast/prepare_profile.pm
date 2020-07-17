# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Expand variables in the autoyast profiles and make it accessible for SUT
#
# - Get profile from autoyast template
# - Map version names
# - Get IP address from system variables
# - Get values from SCC_REGCODE SCC_REGCODE_HA SCC_REGCODE_GEO SCC_REGCODE_HPC SCC_URL ARCH LOADER_TYPE
# - Modify profile with obtained values and upload new autoyast profile
# Maintainer: Rodion Iafarov <riafarov@suse.com>

use strict;
use warnings;
use base "opensusebasetest";
use utils;
use testapi;

sub run {
    # print qx{id};
    # print qx{cat /etc/os-release};
    # print qx{ruby --version};    
    # print qx{git clone https://github.com/jknphy/libyui_client.git};
    # print qx{sudo zypper --non-interactive in ruby2.5-rubygem-bundler};
    
    # print qx{echo "\$HOME"};
    # print qx{echo "\$PWD"};

    # print qx{HOME=\$PWD bundle install --path \$PWD/libyui_client/.vendor/bundler --gemfile \$PWD/libyui_client/Gemfile};
    # print qx{ls -lah \$PWD/libyui_client};
    # print qx{cd libyui_client ; HOME=\$PWD bundle exec rspec};
}

1;
