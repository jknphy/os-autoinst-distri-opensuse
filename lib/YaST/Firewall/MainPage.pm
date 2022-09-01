# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for YaST module
# System Settings Page.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::Firewall::MainPage;
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
    $self->{overview_tree} = $self->{app}->tree({id => "\"Y2Firewall::Widgets::OverviewTree\""});
    $self->{btn_accept} = $self->{app}->button({id => 'next'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    my $is_shown = $self->{overview_tree}->exist();
    save_screenshot if $is_shown;
    return $is_shown;

}

sub select_start_up_page {
    my ($self) = @_;
    $self->{overview_tree}->select("Start-Up");
    save_screenshot;
}

sub select_interfaces_page {
    my ($self) = @_;
    $self->{overview_tree}->select("Interfaces");
    save_screenshot;
}

sub select_zones_page {
    my ($self) = @_;
    $self->{overview_tree}->select("Zones");
    save_screenshot;
}

sub press_accept {
    my ($self) = @_;
    $self->{btn_accept}->click();
    save_screenshot;
}

sub select_zone_page {
    my ($self, $zone) = @_;
    $self->{overview_tree}->select("Zones|$zone");
    save_screenshot;
}

1;
