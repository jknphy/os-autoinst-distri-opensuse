# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-firewall yast2-http-server apache2 apache2-prefork firewalld
# Summary: YaST2 Firewall UI test checks verious configurations and settings of firewall
# Make sure yast2 firewall can opened properly. Configurations can be changed and written correctly.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use base "y2_module_guitest";
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_sle is_leap is_tumbleweed);
use yast2_shortcuts '%fw';
use network_utils 'iface';
use yast2_widget_utils 'change_service_configuration';
use YaST::Module;

sub susefirewall2 {
    # 	enter page interfaces and change zone for network interface
    assert_and_click("yast2_firewall_config_list");
    assert_screen "yast2_firewall_interfaces";
    assert_and_click("yast2_firewall_interface_zone_change");
    wait_still_screen(2);
    assert_and_click("yast2_firewall_interface_no-zone_assigned");
    wait_still_screen 1;
    wait_screen_change {
        send_key "down";
        send_key "ret";
    };
    wait_still_screen 1;
    send_key "alt-o";
    assert_screen "yast2_firewall_interfaces";

    # 	enter page Allowed Services and make  some changes
    assert_and_click("yast2_firewall_allowed-services");
    assert_and_click("yast2_firewall_service-to-allow");
    assert_and_click("yast2_firewall_service_http");
    send_key "alt-a";
    assert_screen "yast2_firewall_service_http_addded";

    #	enter page Broadcast and disable logging broadcast packets
    assert_and_click("yast2_firewall_broadcast");
    wait_still_screen 1;
    wait_screen_change { send_key "alt-l"; };
    send_key "alt-o";
    assert_screen "yast2_firewall_broadcast_no-logging";

    # 	enter page Logging Level and disable logging
    assert_and_click("yast2_firewall_logging-level");
    assert_and_click("yast2_firewall_do-not-log-any_accepted");
    assert_and_click("yast2_firewall_do-not-log-any_not-accepted");

    #	enter page Custom Rules and check ui
    assert_and_click("yast2_firewall_custom-rules");
    # verify Custom Rules page is displayed
    assert_screen("yast2_firewall_custom-rules-loaded");
    send_key "alt-a";
    assert_screen "yast2_firewall_add-new-allowing-rules";
    send_key "alt-c";
    wait_still_screen(2);

    #	Next to finish and exit
    send_key "alt-n";
    assert_screen "yast2_firewall_summary", 30;
    send_key "alt-f";
}

sub verify_service_stopped {

    record_info('Start-Up', "Managing the firewalld service: Stop");
    select_console 'x11', await_console => 0;
    YaST::Module::open(module => 'firewall', ui => 'qt');
    assert_screen 'yast2_firewall_start-up';
    $testapi::distri->get_firewall()->get_main_page();
    save_screenshot;
    $testapi::distri->get_firewall()->get_start_up_page();
    save_screenshot;
    $testapi::distri->get_firewall()->stop_firewall();
    save_screenshot;
    $testapi::distri->get_firewall()->accept_change();
    assert_screen 'generic-desktop';
    select_console 'root-console';
    assert_script_run("! (firewall-cmd --state) | grep 'not running'");
}

sub verify_service_started {

    record_info('Start-Up', "Managing the firewalld service: Start");
    select_console 'x11', await_console => 0;
    YaST::Module::open(module => 'firewall', ui => 'qt');
    assert_screen 'yast2_firewall_start-up';
    $testapi::distri->get_firewall()->get_start_up_page();
    save_screenshot;
    $testapi::distri->get_firewall()->start_firewall();
    save_screenshot;
    $testapi::distri->get_firewall()->accept_change();
    assert_screen 'generic-desktop';
    select_console 'root-console';
    assert_script_run "firewall-cmd --state | grep running";
}

sub verify_interface {
    my (%args) = @_;
    if ($testapi::distri->get_firewall()->verify_interface($args{device} , $args{zone}) != 1) {
        die("Verify interface failed" . $args{device} . " " . $args{zone});
    } else {
        record_info('Verify interface ok', $args{device} . " " . $args{zone});
    }
}

sub change_interface_zone {
    my (%args) = @_;
    $testapi::distri->get_firewall()->get_interfaces_page();
    save_screenshot;
    $testapi::distri->get_firewall()->set_interface_zone($args{device}, $args{zone});
    save_screenshot;
}

sub verify_zone {
    my (%args) = @_;

    my $interfaces = $args{interfaces} //= 'no_interfaces';
    my $default = $args{default} //= 'no_default';
    my $menu_selected = $args{menu_selected} //= 0;
    $testapi::distri->get_firewall()->get_zones_page();
    save_screenshot;
    if ($testapi::distri->get_firewall()->verify_zone($args{name}, $interfaces, $default) != 1) {
        die("Verify zone failed! " . $args{name} . " " . $args{device} . " " . $interfaces . " " . $default);
    } else {
        record_info('verify zone ok! ', $args{name} . " " . $args{device} . " " . $interfaces . " " . $default);
    }
}

sub set_default_zone {
    my $zone = shift;
    $testapi::distri->get_firewall()->get_zones_page();
    save_screenshot;
    $testapi::distri->get_firewall()->set_default_zone($zone);
    save_screenshot;
}

sub configure_zone {
    my (%args) = @_;

    $testapi::distri->get_firewall()->select_zone_page($args{zone});
    save_screenshot;
    #assert_and_click 'yast2_firewall_zones';
    $testapi::distri->get_firewall()->add_service($args{zone}, $args{service});
    $testapi::distri->get_firewall()->add_tcp_port($args{port});
    #if ($args{service}) {
    #    assert_and_click 'yast2_firewall_zone_' . $args{zone} . '_menu';
    #    assert_and_click 'yast2_firewall_zone_service_known_scroll_on_top';    # assuming allowed list empty
    #    send_key_until_needlematch 'yast2_firewall_zone_service_' . $args{service} . '_selected', 'down';
    #    send_key $fw{zones_service_add};
    #    assert_screen 'yast2_firewall_zone_service_' . $args{service} . '_allowed';
    #}
    #if ($args{port}) {
    #    send_key $fw{zones_ports};
    #    assert_screen 'yast2_firewall_zone_ports_tab_selected';
    #    send_key $fw{tcp};
    #    type_string '7777';
    #}
}

sub configure_firewalld {

    record_info('Interface/Zones ', "Verify zone info changing default zone when interface assigned to default zone");
    my $iface = iface;

    select_console 'x11', await_console => 0;
    YaST::Module::open(module => 'firewall', ui => 'qt');
    save_screenshot;
    $testapi::distri->get_firewall()->get_interfaces_page();
    save_screenshot;
    verify_interface(device => $iface, zone => 'default');
    # seems exist bug need sumbit since default libyui will show default flag on block not on public, so SKIP following check firstly
    #verify_zone(name => 'public', interfaces => $iface, default => 'default');
    set_default_zone 'trusted';
    verify_zone(name => 'trusted', interfaces => $iface, default => 'default', menu_selected => 1);

    record_info('Interface/Zones', "Verify zone info assigning interface to different zone");
    change_interface_zone(device => $iface, zone => 'public');
    verify_interface(device => $iface, zone => 'public');
    verify_zone(name => 'public', interfaces => $iface);
    #another bug , libyui show default on block zone
    #verify_zone(name => 'trusted', default => 'default');

    record_info('Zones', "Configure zone adding service and port");
    configure_zone(zone => 'trusted', service => 'bitcoin', port => '7777');
    $testapi::distri->get_firewall()->accept_change();
    return 1;
}

sub verify_firewalld_configuration {
    record_info('Verify firewall', 'Verify firewall configuration');
    select_console 'root-console';
    assert_script_run 'firewall-cmd --state | grep running';
    assert_script_run 'firewall-cmd --list-interfaces --zone=public | grep ' . iface;
    assert_script_run 'firewall-cmd --list-all --zone=trusted | grep -E \'services: bitcoin\'';
    assert_script_run 'firewall-cmd --list-all --zone=trusted | grep -E \'ports: 7777/tcp\'';
}

sub run {
    select_console 'x11';

    if (is_sle('15+') || is_leap('15.0+') || is_tumbleweed) {
        verify_service_stopped;
        verify_service_started;
        configure_firewalld;
        verify_firewalld_configuration;
        select_console 'x11', await_console => 0;
    }
    else {
        die "This firewall libyui test module not support sle version <15 !";
    }
}

1;
