# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for YaST module
# System Settings Page.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::Firewall::ZonesPage;
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
    $self->{tbl_zones} = $self->{app}->table({id => "\"zones_table\""});
    $self->{btn_set_as_default} = $self->{app}->button({id => "\"Y2Firewall::Widgets::DefaultZoneButton\""});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    my $is_shown = $self->{tbl_zones}->exist();
    save_screenshot if $is_shown;
    return $is_shown;
}

sub get_items {
    my ($self) = @_;
    return $self->{tbl_zones}->items();
}

sub get_items_ref {
    my ($self) = @_;
    return $self->{tbl_zones}->items_ref();
}

sub set_default_zone {
    my ($self, $zone) = @_;
    $self->{tbl_zones}->select(value => $zone);
    save_screenshot;
    record_info("set button exist value", "$self->{btn_set_as_default}->exist()");
    $self->{btn_set_as_default}->click();
    save_screenshot;
}
1;
