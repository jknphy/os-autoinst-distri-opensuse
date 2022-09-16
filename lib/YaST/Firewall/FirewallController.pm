# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces actions System Settings Dialog.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::Firewall::FirewallController;
use strict;
use warnings;
use testapi;
use YaST::Firewall::MainPage;
use YaST::Firewall::StartUpPage;
use YaST::Firewall::InterfacesPage;
use YaST::Firewall::ZonesPage;
use YaST::Firewall::ZonePage;
use YaST::Firewall::ServicesPage;
use YaST::Firewall::PortsPage;


use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{MainPage} = YaST::Firewall::MainPage->new({app => YuiRestClient::get_app()});
    $self->{StartUpPage} = YaST::Firewall::StartUpPage->new({app => YuiRestClient::get_app()});
    $self->{InterfacesPage} = YaST::Firewall::InterfacesPage->new({app => YuiRestClient::get_app()});
    $self->{ZonesPage} = YaST::Firewall::ZonesPage->new({app => YuiRestClient::get_app()});
    $self->{ZonePage} = YaST::Firewall::ZonePage->new({app => YuiRestClient::get_app()});
    $self->{ServicesPage} = YaST::Firewall::ServicesPage->new({app => YuiRestClient::get_app()});
    $self->{PortsPage} = YaST::Firewall::PortsPage->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_start_up_page {
    my ($self) = @_;
    $self->{MainPage}->select_start_up_page();
    die 'StartUp Pane is not displayed' unless $self->{StartUpPage}->is_shown();
    return $self->{StartUpPage};
}

sub get_interfaces_page {
    my ($self) = @_;
    $self->{MainPage}->select_interfaces_page();
    die 'Interfaces Pane is not displayed' unless $self->{InterfacesPage}->is_shown();
    return $self->{InterfacesPage};
}

sub get_main_page {
    my ($self) = @_;
    die 'Main Firewall Page is not displayed' unless $self->{MainPage}->is_shown();
    return $self->{MainPage};
}

sub get_zones_page {
    my ($self) = @_;
    $self->{MainPage}->select_zones_page();
    die 'Zones Pane is not displayed' unless $self->{ZonesPage}->is_shown();
    return $self->{ZonesPage};
}

sub select_zone_page {
    my ($self, $zone) = @_;
    $self->{MainPage}->select_zone_page($zone);
}

sub start_firewall {
    my ($self) = @_;
    $self->{StartUpPage}->start_firewall;
}

sub stop_firewall {
    my ($self) = @_;
    $self->{StartUpPage}->stop_firewall;
}

sub accept_change {
    my ($self) = @_;
    $self->{MainPage}->press_accept;
}

sub verify_interface {
    my ($self, $device, $zone) = @_;
    my @items = $self->{InterfacesPage}->get_items;
    for my $item (@items) {
       if ($item->[0] eq $device) {
            if ($item->[1] eq $zone) {
                record_info "$item->[0]", "$item->[1]";
                return 1;
            }
       }
    }
    return 0;
}

sub verify_zone {
   my ($self, $zone, $device, $default) = @_;
   my @items = $self->{ZonesPage}->get_items;
   for my $item (@items) {
       #record_info "$item->[0]", "$item->[1]" . " " . "$item->{2}";
       if ($item->[0] eq $zone) {
                #record_info "$item->[0]", "$item->[1]";
                #record_info "$item->[2]", "$item->[2]";
                diag "!!!!!!!!!item0= $item->[0]";
                diag "!!!!!!!!!item1= $item->[1]";
                diag "!!!!!!!!!item2= $item->[2]";
                diag "!!!!!!!!!device= $$device";
	    if ((($device eq "no_interfaces") && ($item->[1] eq "")) || ($item->[1] eq $device)) {
                diag "!!!!!!!!!--level1";
	        #if ((($default eq "no_default") && ($item->[2] eq "" )) || ($item->[2] eq "✔")) {
	        if ((($default eq "no_default") && ($item->[2] eq "" )) || ($item->[2] ne "")) {
                diag "!!!!!!!!!--level2";
                     return 1;
                }
            }
        }
   }
   return 0;
}

sub set_default_zone {
    my ($self, $zone) = @_;
    $self->{ZonesPage}->set_default_zone($zone);
}

sub set_interface_zone {
    my ($self, $device, $zone) = @_;
    $self->{InterfacesPage}->set_interface_zone($device, $zone);
}

sub switch_ports_tab {
    my ($self) = @_;
    $self->{ZonePage}->switch_ports_tab();
}

sub switch_services_tab {
    my ($self) = @_;
    $self->{ZonePage}->switch_services_tab();
}

sub add_service {
    my ($self, $zone, $service) = @_;
    $self->switch_services_tab();
    $self->{ServicesPage}->select_service($zone, $service);
    $self->{ServicesPage}->add_service();
}

sub add_tcp_port {
    my ($self, $port) = @_;
    $self->switch_ports_tab();
    $self->{PortsPage}->set_tcp_port($port);
}

1;
