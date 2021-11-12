# SUSE's openQA tests

package YuiRestClient::Widget::Attribute::Attribute;

use strict;
use warnings;

use parent 'YuiRestClient::Widget::Base';

sub init {
    my ($self, $args) = @_;
    $self->SUPER::init($args);
    $self->{enable_delegate} = $args->{enable_delegate};
    $self->{selectable_delegate} = $args->{selectable_delegate};
    return $self;
}

sub is_enabled {
    my ($self) = @_;
    return $self->{enable_delegate}->is_enabled($self);
}

sub is_selected {
    my ($self) = @_;
    die ref($self) . " does not implement method 'is_selected'" unless $self->{selectable_delegate};
    return $self->{selectable_delegate}->is_selected($self);
}

1;
