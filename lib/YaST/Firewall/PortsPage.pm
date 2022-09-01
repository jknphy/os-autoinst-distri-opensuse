# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for YaST module
# Services Settings Page.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::Firewall::PortsPage;
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
    $self->{tb_tcp} = $self->{app}->textbox({id => "tcp"});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    my $is_shown = $self->{tb_tcp}->exist();
    save_screenshot if $is_shown;
    return $is_shown;
}

sub set_tcp_port {
    my ($self, $tcp_port) = @_;
    $self->{tb_tcp}->set($tcp_port);
    save_screenshot;
}

1;
