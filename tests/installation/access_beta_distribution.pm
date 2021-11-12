# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Confirm access to Beta Distribution
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use base 'y2_installbase';
use strict;
use warnings;

sub run {
    # $testapi::distri->get_ok_popup_controller()->accept();
    my $actual_beta_text = $testapi::distri->get_ok_popup_controller()->get_text();
}

1;
