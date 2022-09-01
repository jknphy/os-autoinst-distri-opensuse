# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for YaST module
# System Settings Page.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::Firewall::ChangeZonePage;
use strict;
use warnings;
use testapi;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        app => $args->{app}
    }, $class;
    return $self->init();
}

sub init {
    my $self = shift;
    $self->{cmb_zone_options} = $self->{app}->combobox({id => "\"Y2Firewall::Widgets::ZoneOptions\""});
    $self->{btn_ok} = $self->{app}->button({id => "ok"});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    my $is_shown = $self->{cmb_zone_options}->exist();
    save_screenshot if $is_shown;
    return $is_shown;
}

sub set_interface_zone {
    my ($self, $device, $zone) = @_;
    $self->{cmb_zone_options}->select($zone);
    $self->{btn_ok}->click();
}
1;
