## Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Run interactive installation with Agama,
# using a web automation tool to test directly from the Live ISO.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base Yam::Agama::agama_base;
use strict;
use warnings;

use testapi qw(
  get_required_var
  script_run
  assert_script_run
  record_soft_failure
  parse_extra_log
  upload_logs
);

sub run {
    my $self = shift;
    my $test = get_required_var('AGAMA_TEST');
    my $test_options = get_required_var('AGAMA_TEST_OPTIONS');
    my $reboot_page = $testapi::distri->get_reboot();
    my $spec_reporter = "/tmp/$test.txt";
    my $tap_reporter = "/tmp/$test.tap";

    script_run("dmesg --console-off");
    assert_script_run("node --enable-source-maps --test-reporter=spec --test-reporter=tap --test-reporter-destination=$spec_reporter --test-reporter-destination=$tap_reporter /usr/share/agama/system-tests/$test.js $test_options", timeout => 2400);
    script_run("dmesg --console-on");

    # see https://github.com/os-autoinst/openQA/blob/master/lib/OpenQA/Parser/Format/TAP.pm#L36
    assert_script_run("sed -i 's/TAP version 13/$tap_reporter ../' /tmp/$tap_reporter");
    parse_extra_log(TAP => $tap_reporter);
    upload_logs($spec_reporter, failok => 1);
    $self->upload_agama_logs();
    $reboot_page->reboot();
}

1;
