# SUSE's openQA tests
#
# Copyright 2016-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Base module for HPC tests
# Maintainer: Kernel QE <kernel-qa@suse.de>

package hpcbase;
use Mojo::Base 'opensusebasetest';
use testapi;
use utils;
use Utils::Architectures;
use version_utils 'is_sle';

=head2 enable_and_start

Enables and starts given systemd service

=cut
sub enable_and_start {
    my ($self, $arg) = @_;
    systemctl("enable $arg");
    systemctl("start $arg");
}

sub upload_service_log {
    my ($self, $service_name) = @_;
    script_run("journalctl -u $service_name -o short-precise > /tmp/$service_name");
    script_run("cat /tmp/$service_name");
    upload_logs("/tmp/$service_name", failok => 1);
}

sub post_fail_hook {
    my ($self) = @_;
    $self->select_serial_terminal;
    script_run("SUSEConnect --status-text");
    script_run("journalctl -o short-precise > /tmp/journal.log");
    script_run('cat /tmp/journal.log');
    upload_logs('/tmp/journal.log', failok => 1);
    upload_service_log('wickedd-dhcp4.service');
}

sub get_remote_logs {
    my ($self, $machine, $logs) = @_;
    script_run("scp -o StrictHostKeyChecking=no root\@$machine:/var/log/$logs /tmp/$machine\@$logs");
    upload_logs("/tmp/$machine\@$logs", failok => 1);
}

sub switch_user {
    my ($self, $username) = @_;
    enter_cmd("su - $username");
    type_string(qq/PS1="# "\n/);
    wait_serial(qr/PS1="# "/);
    assert_script_run("whoami|grep $username");
}

=head2 master_node_names

Prepare master node names, so those names could be reused, for instance
in config preparation, munge key distribution, etc.
The naming follows general pattern of master-slave

=cut
sub master_node_names {
    my ($self) = @_;
    my $master_nodes = get_required_var("MASTER_NODES");
    my @master_node_names;

    for (my $node = 0; $node < $master_nodes; $node++) {
        my $name = sprintf("master-node%02d", $node);
        push @master_node_names, $name;
    }

    return @master_node_names;
}

=head2 slave_node_names

Prepare compute node names, so those names could be reused, for
instance in config preparation, munge key distribution, etc.
The naming follows general pattern of master-slave

=cut
sub slave_node_names {
    my ($self) = @_;
    my $master_nodes = get_required_var("MASTER_NODES");
    my $nodes = get_required_var("CLUSTER_NODES");
    my @slave_node_names;

    my $slave_nodes = $nodes - $master_nodes;
    for (my $node = 0; $node < $slave_nodes; $node++) {
        my $name = sprintf("slave-node%02d", $node);
        push @slave_node_names, $name;
    }

    return @slave_node_names;
}

=head2 cluster_names

Prepare all node names, so those names could be reused

=cut
sub cluster_names {
    my ($self) = @_;
    my @cluster_names;

    my @master_nodes = master_node_names();
    my @slave_nodes = slave_node_names();

    push(@master_nodes, @slave_nodes);
    @cluster_names = @master_nodes;

    return @cluster_names;
}

=head2 distribute_munge_key

Distributes munge kyes across all cluster nodes

=cut
sub distribute_munge_key {
    my ($self) = @_;
    my @cluster_nodes = cluster_names();
    foreach (@cluster_nodes) {
        script_run("scp -o StrictHostKeyChecking=no /etc/munge/munge.key root\@$_:/etc/munge/munge.key");
    }
}

=head2 distribute_slurm_conf

Distributes slurm config across all cluster nodes

=cut
sub distribute_slurm_conf {
    my ($self) = @_;
    my @cluster_nodes = cluster_names();
    foreach (@cluster_nodes) {
        script_run("scp -o StrictHostKeyChecking=no /etc/slurm/slurm.conf root\@$_:/etc/slurm/slurm.conf");
    }
}

=head2 generate_and_distribute_ssh

     generate_and_distribute_ssh($user)

Generates and distributes ssh keys across compute nodes. C<user> by default is set
to B<root> user unless another value is passed to the parameters.
C<user> is used to determine the user on the remote machine where the ssh_id will
be copied.

=cut
sub generate_and_distribute_ssh {
    my ($self, $user) = @_;
    $user //= 'root';
    my @slave_nodes = slave_node_names();
    assert_script_run('ssh-keygen -b 2048 -t rsa -q -N "" -f ~/.ssh/id_rsa');
    foreach (@slave_nodes) {
        exec_and_insert_password("ssh-copy-id -o StrictHostKeyChecking=no $user\@$_");
    }
}

=head2 check_nodes_availability

Checks if all listed HPC cluster nodes are available (ping)

=cut
sub check_nodes_availability {
    my ($self) = @_;
    my @cluster_nodes = cluster_names();
    foreach (@cluster_nodes) {
        assert_script_run("ping -c 3 $_");
    }
}

=head2 mount_nfs

Ensure correct dir is created, and correct NFS dir is mounted on SUT

=cut
sub mount_nfs {
    my ($self) = @_;
    zypper_call('in nfs-client rpcbind');
    systemctl('start nfs');
    systemctl('start rpcbind');
    record_info('show mounts aviable on the supportserver', script_output('showmount -e 10.0.2.1'));
    assert_script_run('mkdir -p /shared/slurm');
    assert_script_run('chown -Rcv slurm:slurm /shared/slurm');
    assert_script_run('mount -t nfs -o nfsvers=3 10.0.2.1:/nfs/shared /shared/slurm');
}

=head2 get_master_ip

Check the IP of the master node

=cut
sub get_master_ip {
    my ($self) = @_;

    my $master_ip = script_output('hostname -I');

    return $master_ip;
}

=head2 get_slave_ip

Check the IP of the slave node

=cut
sub get_slave_ip {
    my ($self) = @_;

    my $slave_ip = script_output("ssh root\@slave-node00 \'hostname -I\'");
    record_info('DEBUG1', "$slave_ip");
    return $slave_ip;
}

=head2 prepare_user_and_group

Creating slurm user and group with some pre-defined ID

=cut
sub prepare_user_and_group {
    my ($self) = @_;
    assert_script_run('groupadd slurm -g 7777');
    assert_script_run('useradd -u 7777 -g 7777 slurm');
}

=head2 prepare_spack_env

  prepare_spack_env($mpi)

After install spack and HPC C<mpi> required packages, prepares env
variables. The HPC packages (*-gnu-hpc) use an installation path that is separate
from the rest and can be exported via a network file system.

After C<prepare_spack_env> run, C<spack> should be ready to build entire tool stack,
downloading and installing all bits required for whatever package or compiler.
=cut
sub prepare_spack_env {
    my ($self, $mpi) = @_;
    $mpi //= 'mpich';
    zypper_call "in spack $mpi-gnu-hpc $mpi-gnu-hpc-devel";
    type_string('pkill -u root');    # this kills sshd
    $self->select_serial_terminal(0);
    assert_script_run 'module load gnu $mpi';    ## TODO
    assert_script_run 'source /usr/share/spack/setup-env.sh';
    record_info 'spack', script_output 'zypper -q info spack';
    record_info 'boost spec', script_output('spack spec boost', timeout => 360);
    assert_script_run "spack install boost+mpi^$mpi", timeout => 12000;
    assert_script_run 'spack load boost';
}

=head2 uninstall_spack_module

  uninstall_spack_module($module)

Unload and uninstall C<module> from spack stack
=cut
sub uninstall_spack_module {
    my ($self, $module) = @_;
    die 'uninstall_spack_module requires a module name' unless $module;
    assert_script_run("spack unload $module");
    script_run('module av', timeout => 120);
    assert_script_run("spack uninstall -y $module", timeout => 360);
    assert_script_run("spack find $module | grep 'No package matches the query'");
}

=head2 get_compute_nodes_deps

  get_compute_nodes_deps($mpi)

This function is used to select dependencies packages which are required to be installed
on HPC compute nodes in order to run code against particular C<mpi> implementation.
C<get_compute_nodes_deps> returns an array of packages
=cut
sub get_compute_nodes_deps {
    my ($self, $mpi) = @_;
    die "missing C<mpi> parameter" unless $mpi;
    my @deps = ('libucp0');
    if (is_sle('>=15-SP3')) {
        push @deps, 'libhwloc15' if $mpi =~ m/mpich/;
        push @deps, ('libfabric1', 'libpsm2') if $mpi =~ m/openmpi/;
        pop @deps if (is_aarch64 && $mpi =~ m/openmpi/);
    } else {
        push @deps, 'libpciaccess0' if $mpi =~ m/mpich/;
        push @deps, 'libfabric1' if $mpi =~ m/openmpi/;
    }
    push @deps, ('libibmad5') if $mpi =~ m/mvapich2/;
    return @deps;
}

=head2 setup_nfs_server

Prepare a nfs server on the so called management node of the HPC setup.
The management node in a minimal setup should provide the directories
of *-gnu-hpc installed libraries and the directory with the binaries.

C<exports> takes a hash reference with the paths which NFS should make
available to the compute nodes in order to run MPI software.
=cut
sub setup_nfs_server {
    my ($self, $exports) = @_;
    zypper_call 'in nfs-kernel-server';
    foreach my $dir (values %$exports) {
        assert_script_run "echo $dir *(rw,no_root_squash,sync,no_subtree_check) >> /etc/exports";
    }
    assert_script_run 'exportfs -a';
    systemctl 'enable --now nfs-server';
}

=head2 mount_nfs_exports

Make the HPC libraries and the location of the binaries available to the so called
compute nodes, from the management one.
C<exports> takes a hash reference with the paths which the management node share in order to
run the MPI binaries
=cut
sub mount_nfs_exports {
    my ($self, $exports) = @_;
    zypper_call 'in nfs-client';
    foreach my $dir (values %$exports) {
        assert_script_run "mkdir -p $dir" unless script_run("test -f $dir", quiet => 1) == 0;
        assert_script_run "mount master-node00:$dir $dir", timeout => 120;
    }
}

1;
