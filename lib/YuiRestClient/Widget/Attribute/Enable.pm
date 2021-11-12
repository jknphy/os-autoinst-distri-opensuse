# SUSE's openQA tests

package YuiRestClient::Widget::Attribute::Enable;

use strict;
use warnings;

use parent 'YuiRestClient::Widget::Attribute::EnableDelegate';

sub new {
    my ($class) = @_;
    return bless {}, $class;
}

sub is_enabled {
    my ($self, $base) = @_;
    my $is_enabled = $base->property('enabled');
    return !defined $is_enabled || $is_enabled;
}

1;
