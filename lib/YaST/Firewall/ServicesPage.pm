# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for YaST module
# Services Settings Page.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::Firewall::ServicesPage;
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
    $self->{tbl_known_trusted} = $self->{app}->table({id => "\"known:trusted\""});
    $self->{btn_add} = $self->{app}->button({id => "add"});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    my $is_shown = $self->{tbl_known_trusted}->exist();
    save_screenshot if $is_shown;
    return $is_shown;
}

sub select_service {
    my ($self, $zone, $service) = @_;
    $self->{"tbl_known_$zone"}->select(value => $service);
    save_screenshot;
}

sub add_service {
    my ($self) = @_;
    $self->{btn_add}->click();
    save_screenshot;
}

1;
