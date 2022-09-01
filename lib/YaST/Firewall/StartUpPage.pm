# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for YaST module
# System Settings Page.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::Firewall::StartUpPage;
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
    $self->{status} = $self->{app}->label({id => 'service_widget_status'});
    $self->{cmb_set_firewall_state} = $self->{app}->combobox({id => 'service_widget_action'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    my $is_shown = $self->{status}->exist();
    save_screenshot if $is_shown;
    return $is_shown;
}

sub start_firewall {
    my ($self) = @_;
    $self->{cmb_set_firewall_state}->select("Start");
}

sub stop_firewall {
    my ($self) = @_;
    $self->{cmb_set_firewall_state}->select("Stop");
}

1;
