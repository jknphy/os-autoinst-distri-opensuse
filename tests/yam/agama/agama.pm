## Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Run interactive installation with Agama,
# using a web automation tool to test directly from the Live ISO.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base Yam::Agama::agama_base;
use strict;
use warnings;
use Carp qw(croak);
use testapi qw(
  diag
  get_required_var
  script_run
  script_output
  assert_script_run
  record_info
  record_soft_failure
  parse_extra_log
  upload_logs
  console
  select_console
);
use utils qw(reconnect_mgmt_console);

sub run {
    my $self = shift;
    my $test = get_required_var('AGAMA_TEST');
    my $test_options = get_required_var('AGAMA_TEST_OPTIONS');
    my $reboot_page = $testapi::distri->get_reboot();
    my $spec = "spec.txt";
    my $tap = "tap.txt";
    my $reporters = "--test-reporter=spec --test-reporter=tap --test-reporter-destination=/tmp/$spec --test-reporter-destination=/tmp/$tap";
    my $node_cmd = "node --enable-source-maps $reporters /usr/share/agama/system-tests/${test}.js $test_options";
    record_info("node cmd", $node_cmd);

    script_run("dmesg --console-off");
    my $ret = script_run($node_cmd, timeout => 2400);
    script_run("dmesg --console-on");

    # see https://github.com/os-autoinst/openQA/blob/master/lib/OpenQA/Parser/Format/TAP.pm#L36
    assert_script_run("sed -i 's/TAP version 13/$tap ../' /tmp/$tap");
    parse_extra_log(TAP => "/tmp/$tap");
    upload_logs("/tmp/$spec", failok => 1);
    my $content = script_output("cat /tmp/$spec /tmp/$tap");
    diag($content);
    croak("command \n'$node_cmd'\n failed") unless $ret == 0;
    $self->upload_agama_logs();
    my $svirt = console('svirt');
    $svirt->change_domain_element(os => boot => {dev => 'hd'});
    select_console 'root-console';
    $reboot_page->reboot();
    reconnect_mgmt_console(timeout => 1400, grub_timeout => 360);
}

1;
