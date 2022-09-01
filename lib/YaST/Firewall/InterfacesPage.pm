# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for YaST module
# System Settings Page.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::Firewall::InterfacesPage;
use strict;
use warnings;
use testapi;
use YaST::Firewall::ChangeZonePage;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        app => $args->{app}
    }, $class;
    return $self->init();
}

sub init {
    my $self = shift;
    $self->{tbl_interfaces} = $self->{app}->table({id => "\"interfaces_table\""});
    $self->{btn_change_zone} = $self->{app}->button({id => "\"Y2Firewall::Widgets::ChangeZoneButton\""});
    $self->{cmb_zone_options} = $self->{app}->combobox({id => "\"Y2Firewall::Widgets::ZoneOptions\""});
    $self->{ChangeZonePage} = YaST::Firewall::ChangeZonePage->new({app => YuiRestClient::get_app()});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    my $is_shown = $self->{tbl_interfaces}->exist();
    save_screenshot if $is_shown;
    return $is_shown;
}

sub get_items {
    my ($self) = @_;
    return $self->{tbl_interfaces}->items();
}

sub set_interface_zone {
    my ($self, $device, $zone) = @_;
    $self->{tbl_interfaces}->select(value => $device);
    $self->{btn_change_zone}->click();
    $self->{ChangeZonePage}->is_shown();
    $self->{ChangeZonePage}->set_interface_zone($device, $zone);
}
1;
