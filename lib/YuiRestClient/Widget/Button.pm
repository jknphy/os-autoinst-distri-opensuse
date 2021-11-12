# SUSE's openQA tests

package YuiRestClient::Widget::Button;

use strict;
use warnings;

use parent 'YuiRestClient::Widget::Attribute::Attribute';
use YuiRestClient::Action;
use YuiRestClient::Widget::Attribute::Enable;

sub init {
    my ($self, $args) = @_;
    $self->SUPER::init($args);
    $self->{enable_delegate} = YuiRestClient::Widget::Attribute::Enable->new();
    return $self;
}

sub click {
    my ($self) = @_;

    return $self->action(action => YuiRestClient::Action::YUI_PRESS);
}

1;

__END__

=encoding utf8

=head1 NAME

YuiRestClient::Widget::Button - Handle YQWizardButton, YPushButton

=head1 COPYRIGHT

Copyright © 2020 SUSE LLC

SPDX-License-Identifier: FSFAP

=head1 AUTHORS

QE YaST <qa-sle-yast@suse.de>

=head1 SYNOPSIS

$self->{btn_next}->click()

$self->{button}->is_enabled()

=head1 DESCRIPTION

=head2 Overview

This class provides methods to interact with libyui button objects.

=head2 Class and object methods 

B<click()> - Send a press event to a button

The button object receives a press event. 

B<is_enabled()> - Check if button is enabled 

=over 4

=item * If the button object has a property 'enabled' then the value of this property is returned

=item * If the button object has no property 'enabled' then it is considered to be enabled by default

=back

=cut
