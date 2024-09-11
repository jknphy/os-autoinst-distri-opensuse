## Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Run interactive installation with Agama,
# using a web automation tool to test directly from the Live ISO.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base Yam::Agama::agama_base;
use strict;
use warnings;
use testapi;
use Utils::Architectures;
use Utils::Backends;

use testapi qw(
  assert_script_run
  get_required_var
);

sub run {
    my $self = shift;
    my $test = get_required_var('AGAMA_TEST');
    my $arch = get_required_var('ARCH');
    my $reboot_page = $testapi::distri->get_reboot_page();

    script_run("dmesg --console-off");
    assert_script_run("ARCH=${arch} /usr/share/agama/system-tests/" . $test . ".cjs", timeout => 1200);
    script_run("dmesg --console-on");

    if (is_s390x() && is_backend_s390x()) {
      enter_cmd 'reboot';
    } else{
      select_console('installation');
      $reboot_page->reboot();
    }
}

1;
