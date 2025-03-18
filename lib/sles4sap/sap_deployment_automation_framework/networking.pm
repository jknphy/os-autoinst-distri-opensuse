# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>

package sles4sap::sap_deployment_automation_framework::networking;

use strict;
use warnings;
use testapi;
use Exporter qw(import);
use Carp qw(croak);
use Regexp::Common qw(net);
use Time::Piece;
use sles4sap::azure_cli
  qw(az_storage_blob_list az_storage_blob_lease_acquire az_storage_blob_upload az_storage_blob_update
  az_network_peering_list az_network_vnet_get);

=head1 SYNOPSIS

Library with common functions for Microsoft SDAF deployment automation related to networking setup.

=cut

our @EXPORT = qw(
  assign_address_space
  calculate_subnets
  calculate_ip_count
);

=head2 calculate_net_addr_space

    calculate_net_addr_space();

Calculate network IP space that will be reserved to contain all underlying subnets used by the deployment.
Each network space will reserve 64 IP addresses. This splits last IP octet into 4 network spaces.
First 64 address spaces are used from third octet, making 256 network spaces available for all OpenQA tests at
any point in time. (256 tests can run at the same time using one control plane.)

Random network space pick is only performance related. If the pick was in orderly manner it would mean that from
for example 5 parallel tests, one test will spend 5 loops to get a free network.

=cut

sub calculate_net_addr_space {
    # map { $_ * 64 IP addresses } (1 .. all 256 addresses within octet/64 IP per network space);
    my @addr_ranges = map { $_ * 64 } (1 .. 4);
    my $network_segment = $addr_ranges[int(rand @addr_ranges - 1)];
    my $network = join('.', '192', '168', int(rand(63)));
    return ("$network.$network_segment/26");
}

=head2 calculate_subnets

    calculate_subnets([network_space=>'192.168.0.0']);

=over

=item B<network_space>: Define network space to calculate subnets for. Will be generated if left undefined.

=back

Calculates 4 subnets required by SDAF within a network space. If network space is not specified,
it will be generated by B<calculate_net_addr_space>. Check mentioned function for details.
Network space is set to reserve 64 IP addresses which will be split into 4 subnets: 'db', 'app', 'web', 'admin'
This leaves 16 IP addresses for each subnet. (only 14 are usable).

=cut

sub calculate_subnets {
    my (%args) = @_;
    $args{network_space} //= calculate_net_addr_space();
    # extract subnet prefix from network addr space and calculate total IPs available for all subnets
    my $network_space_ip_count = calculate_ip_count(subnet_prefix => (split(/\//, $args{network_space}))[1]);

    # Definition of subnet name and subnet prefix
    # Subnet assignment is defined here approximately how many IPs specific subnet might need
    # total count of all subnet IPs must stay within network space boundaries
    my %subnet_definition = (
        admin_subnet_address_prefix => '/29',
        web_subnet_address_prefix => '/29',
        db_subnet_address_prefix => '/28',
        app_subnet_address_prefix => '/28',
        iscsi_subnet_address_prefix => '/28'
    );

    my %network_data = (network_address_space => $args{network_space});
    my @octets = (split(/[.\/]/, $args{network_space}))[0 .. 3];
    my $starting_octet = $octets[3];
    # Sort subnets according to their size in descending order to avoid IP overlap
    my @sorted_keys = sort {
        my ($a_num) = $subnet_definition{$a} =~ m{/(\d+)};
        my ($b_num) = $subnet_definition{$b} =~ m{/(\d+)};
        $a_num <=> $b_num;
    } keys(%subnet_definition);

    my $total_ip_count = 0;

    # This will sort subnets according to network size in descending order
    for my $subnet_name (@sorted_keys) {
        my $subnet_ip_count = calculate_ip_count(subnet_prefix => $subnet_definition{$subnet_name});
        $total_ip_count += $subnet_ip_count;
        my $subnet = join('.', @octets[0 .. 2], $starting_octet) . $subnet_definition{$subnet_name};
        $network_data{$subnet_name} = $subnet;
        $starting_octet = $starting_octet + $subnet_ip_count;
    }
    # Prevent IP leaking into next network space and let the test fail early.
    die "Total number of calculated subnet IPs ($total_ip_count) is outside of address space ($network_space_ip_count)" if
      $total_ip_count > $network_space_ip_count;
    return (\%network_data);
}

=head2 calculate_ip_count

    calculate_ip_count(subnet_prefix=>'/24');

=over

=item B<subnet_prefix>: Subnet prefix to be translated into number of IP addresses

=back

Returns number of usable IPv4 addresses belonging to a subnet prefix

=cut

sub calculate_ip_count {
    my (%args) = @_;
    # IPv4 consists of 32 bits
    # Subnet prefix describes how many bits from left separate network portion from host portion
    # 32bits - $subnet prefix = number of bits for host IPs
    # 2 to the power of $host_bits = number of IP addresses belonging to subnet
    return 2**(32 - int($args{subnet_prefix} =~ s/\///r));
}

=head2 list_expired_files

    list_expired_files($check_older_than_sec);

=over

=item B<$check_older_than_sec>: Check only files with modification time older than parameter value in seconds

=back

Returns names of lease blob files within 'network-spaces' container which are older than retention time.
Test will search network spaces which were reserved more than B<$check_older_than_sec> seconds ago.
Default 7h should be plenty for not triggering race condition between network assignment and actual infrastructure creation.

=cut

sub list_expired_files {
    my ($check_older_than_sec) = @_;
    $check_older_than_sec //= 7 * 3600;    # 7 hours default
    my @free_lease_files;
    # this creates list of network file names and last modification time
    my $all_files = az_storage_blob_list(
        container_name => 'network-spaces',
        storage_account_name => get_required_var('SDAF_TFSTATE_STORAGE_ACCOUNT'),
        query => "[].{network:name , last_modified:properties.lastModified}"
    );

    foreach (@$all_files) {
        # for format explanation check 'man strftime' - az cli returns date in ISO 8601 format
        # Time::Piece does not recognize az cli timezone format `+02:00`, only `+0200`
        # therefore we have to do some colonoscopy and remove `:` from az cli output
        $_->{last_modified} =~ s/(?<=\+\d\d):(?=\d\d$)//;
        # Avoid using `%F` instead of `%F` as it is not supported in older perl versions
        my $time = Time::Piece->strptime($_->{last_modified}, '%Y-%m-%dT%H:%M:%S%z')->epoch();
        push(@free_lease_files, $_->{network}) if $time < time() - $check_older_than_sec;
    }
    return @free_lease_files;
}

=head2 list_network_lease_files

    list_network_lease_files();

Returns names of all lease blob files within 'network-spaces' container.

=cut

sub list_network_lease_files {
    return az_storage_blob_list(
        container_name => 'network-spaces',
        storage_account_name => get_required_var('SDAF_TFSTATE_STORAGE_ACCOUNT'),
        query => "[].name"
    );
}

=head2 acquire_network_file_lease

    acquire_network_file_lease(network_lease_file=>'192.168.1.0' [, storage_account=>'some account']);

=over

=item B<storage_account>: Storage account containing lease file. Default: 'SDAF_TFSTATE_STORAGE_ACCOUNT'

=item B<network_lease_file>: Name of the lease file

=back

Acquire network lease for a blob. Returns blob lease UUID which is later required for getting permission to modify
blob file.

=cut

sub acquire_network_file_lease {
    my (%args) = @_;
    $args{storage_account} //= get_required_var('SDAF_TFSTATE_STORAGE_ACCOUNT');
    foreach ('network_lease_file', 'storage_account') {
        croak "Missing mandatory argument: '$_'" unless $args{$_};
    }
    my %arguments = (
        container_name => 'network-spaces',
        storage_account_name => $args{storage_account},
        blob_name => $args{network_lease_file},
        lease_duration => 60
    );

    # First acquire a file lease to gain exclusive file access - prevents other tests modifying it.
    my $lease_id = az_storage_blob_lease_acquire(%arguments);

    # Return unless the file lease was successful
    return unless $lease_id;
    # Updates modification time for a file - this tells other tests not to try to assign this address in next 7H
    return if az_storage_blob_update(
        container_name => $arguments{container_name},
        account_name => $arguments{storage_account_name},
        name => $arguments{blob_name},
        lease_id => $lease_id
    );

    return ($lease_id);
}


=head2 deployer_peering_exists

    deployer_peering_exists(addr_space=>'192.168.0.0', deployer_vnet_name=>'SHODAN-vnet');

=over

=item B<addr_space>: Address space to check for. Must include subnet prefix.

=item B<deployer_vnet_name>: Deployer virtual network name

=back

Checks if there is already a network peering established between deployer virtual network and address space specified by
B<addr_space>.

=cut

sub deployer_peering_exists {
    my (%args) = @_;
    foreach ('addr_space', 'deployer_vnet_name') {
        croak "Missing mandatory argument: $_" unless $args{$_};
    }
    my $jmespath_query = "length([?contains(remoteVirtualNetworkAddressSpace.addressPrefixes, '$args{addr_space}')])";
    return (az_network_peering_list(
            resource_group => get_required_var('SDAF_DEPLOYER_RESOURCE_GROUP'),
            vnet => $args{deployer_vnet_name},
            query => $jmespath_query));
}

=head2 assign_defined_network

    assign_defined_network(deployer_vnet_name=>'SHODAN-vnet' [, networks_older_than=>3600]);

=over

=item B<networks_older_than>: Check for networks older than parameter value in seconds.

=item B<deployer_vnet_name>: Deployer virtual network name

=back

Assign network that has already lease file present in storage account.
Lists existing network files which were modified more than B<$args{networks_older_than}> seconds in the past and picks
one of the files at random. A check is performed if the network space is already peered to deployer virtual network
B<deployer_vnet_name>. Last step is to attempt to assign a blob lease for the network file associated. Blob file lease
serves as a locking mechanism to prevent multiple tests assign same network space, causing collisions.

For a successful network assignment three criteria must be met:
- there is blob file that represents a network space in storage account (check list_expired_files())
- network peering between network space and deployer virtual network does not exist
- function is able to assign a 60s blob file lease to reserve exclusive network rights

Argument B<networks_older_than> value should be greater than time between the start of this function
and B<lib/sles4sap/sap_deployment_automation_framework sdaf_execute_deployment()> creating network resources.
This serves to prevent a race condition where a test picks network space which another test already assigned but haven't
created network resources yet.

B<There are multiple ways to handle this:>
B<A.> set B<networks_older_than> to larger value than (timeout + retry) arguments set for
sdaf_execute_deployment(timeout=>$timeout, retry=>$retry). This means test won't search for networks which are still
possibly being created by terraform.
Check B<tests/sles4sap/sap_deployment_automation_framework/deploy_workload_zone.pm> for example.

B<B.> Set it to some arbitrarily high but acceptable value like default 7 hours. This should be enough for any terraform deployment
either to finish or fail.

=cut

sub assign_defined_network {
    my (%args) = @_;
    croak 'Missing mandatory argument: deployer_vnet_name' unless $args{deployer_vnet_name};

    my @lease_files;
    my $lease_file;
    record_info('NET assign', "Searching for free networks older than $args{networks_older_than} seconds");
    while (!$lease_file) {
        @lease_files = list_expired_files($args{networks_older_than});
        record_info('Expired files', "Following expired leases found:\n" . join("\n", @lease_files));
        return unless @lease_files;
        # Taking random file from the list decreases the chance of two tests spending time checking same file.
        $lease_file = $lease_files[int(rand(@lease_files - 1))];
        # Check if network resource associated with chosen lease file exists.
        return if deployer_peering_exists(addr_space => $lease_file . '/26', deployer_vnet_name => $args{deployer_vnet_name});

        # Attempt to acquire network file lease (update modification time)
        # This will prevent other tests from spending time checking this file since it is already taken.
        return if !acquire_network_file_lease(network_lease_file => $lease_file);

    }
    return $lease_file . '/26';    # Add /26 suffix
}

=head2 create_lease_file

    create_lease_file(network_space=>'192.168.1.0' [, storage_account=>'SHODAN-storage']);

=over

=item B<storage_account>: Storage account containing lease file

=item B<network_space>: Network space to create the lease file for

=back

Creates an uploads new network lease file

=cut

sub create_lease_file {
    my (%args) = @_;
    $args{storage_account} //= get_var('SDAF_TFSTATE_STORAGE_ACCOUNT');
    foreach ('network_space', 'storage_account') {
        croak "Missing mandatory argument: '$_'" unless $args{$_};
    }
    my $network_lease_filename = $args{network_space};
    my $lease_file = "/tmp/$network_lease_filename";
    assert_script_run("touch $lease_file", quiet => 1);
    az_storage_blob_upload(
        container_name => 'network-spaces',
        storage_account_name => $args{storage_account},
        file => $lease_file
    );
}


=head2 create_new_address_space

    create_new_address_space(deployer_vnet_name=>'SHODAN-vnet' [, timeout=>9001]);

=over

=item B<deployer_vnet_name>: Deployer virtual network

=item B<timeout>: Timeout for creating new lease file

=back

Used to assign network space which does not yet have blob file created in 'SDAF_TFSTATE_STORAGE_ACCOUNT' storage account.
Function generates random address space and checks for an existing lease file in storage account. If file does not exist
it will be created, otherwise function searches again for network space without existing file.
Before assigning network space there is a check for an existing peering between this network and deployer vnet.
This is to avoid assigning network which was created without a lease file.

=cut

sub create_new_address_space {
    my (%args) = @_;
    croak 'Missing mandatory argument: deployer_vnet_name' unless $args{deployer_vnet_name};
    $args{timeout} //= 300;    # Timeout for creating new lease file
    my $address_space;
    my $generated_address_space;
    my $start_time = time();

    record_info('New lease', 'There are no free existing network files: Creating new file');
    while (!$address_space) {
        die('Failed to reserve free address space within timeout') if (time() - $start_time > $args{timeout});
        ($generated_address_space = calculate_net_addr_space()) =~ s/\/26//;
        # Calculate another network if file for this network is already present
        sleep 1;    # one sec delay to prevent command spamming
        next if grep { $_ eq $generated_address_space } @{list_network_lease_files()};

        # Create a file for new addr space
        create_lease_file(network_space => $generated_address_space);

        # Check if there is already a network peering present for this network file.
        # Do not assign this network space if it is already used by something else.
        # No need to delete the lease file. It will tell other tests that this one is already assigned.
        next if deployer_peering_exists(addr_space => $generated_address_space . '/26', deployer_vnet_name => $args{deployer_vnet_name});
        $address_space = $generated_address_space;
    }
    return $address_space . '/26';
}

=head2 assign_address_space

    assign_address_space([networks_older_than=>3600]);

=over

=item B<networks_older_than>: Check for networks older than parameter value in seconds.

=back

Assigns an unused address space either by leasing existing network file inside storage account or creates a new file
in case there are no free existing lease files.
Check functions B<assign_defined_network> and B<create_new_address_space> for details about the process.

=cut

sub assign_address_space {
    my (%args) = @_;
    my $deployer_vnet_code = get_required_var('SDAF_DEPLOYER_VNET_CODE');
    my $deployer_vnet_name = @{az_network_vnet_get(
            resource_group => get_required_var('SDAF_DEPLOYER_RESOURCE_GROUP'),
            query => "[?contains(name, '$deployer_vnet_code')].name")}[0];

    # Check first if there is free network with a lease file already created, create new file otherwise.
    return
      assign_defined_network(deployer_vnet_name => $deployer_vnet_name, networks_older_than => $args{networks_older_than}) //
      create_new_address_space(deployer_vnet_name => $deployer_vnet_name);
}
