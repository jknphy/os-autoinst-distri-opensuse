# SUSE's openQA tests

package YuiRestClient::Widget::Attribute::Enable;

use strict;
use warnings;

use parent 'YuiRestClient::Widget::Attribute::SelectableDelegate';

sub new {
    my ($class) = @_;
    return bless {}, $class;
}

sub is_selected {
    my ($self) = @_;
    $self->property('value');
}

1;
