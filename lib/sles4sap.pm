## no critic (RequireFilenameMatchesPackage);
package sles4sap;
use base "opensusebasetest";

use strict;
use warnings;
use testapi;
use utils;
use hacluster 'pre_run_hook';
use isotovideo;
use x11utils 'ensure_unlocked_desktop';

our @EXPORT = qw (
  fix_path
  set_ps_cmd
  set_sap_info
  become_sapadm
  test_version_info
  test_instance_properties
  test_stop
  test_start_service
  test_start_instance
);

our $prev_console;
our $sapadmin;
our $sid;
our $instance;
our $ps_cmd;

sub fix_path {
    my ($self, $var) = @_;
    my ($proto, $path) = split m|://|, $var;
    my @aux = split '/', $path;

    $proto = 'cifs' if ($proto eq 'smb' or $proto eq 'smbfs');
    die 'Currently only supported protocols are nfs and smb/smbfs/cifs'
      unless ($proto eq 'nfs' or $proto eq 'cifs');

    $aux[0] .= ':' if ($proto eq 'nfs');
    $aux[0] = '//' . $aux[0] if ($proto eq 'cifs');
    $path = join '/', @aux;
    return ($proto, $path);
}

sub set_ps_cmd {
    my ($self, $procname) = @_;
    $ps_cmd = 'ps auxw | grep ' . $procname . ' | grep -vw grep';
    return $ps_cmd;
}

sub set_sap_info {
    my ($self, $sid_env, $instance_env) = @_;
    $sid      = uc($sid_env);
    $instance = $instance_env;
    $sapadmin = lc($sid_env) . 'adm';
    return ($sapadmin);
}

sub become_sapadm {
    # Allow SAP Admin user to inform status via $testapi::serialdev
    assert_script_run "chown $sapadmin /dev/$testapi::serialdev";

    type_string "su - $sapadmin\n";

    # Change the working shell to bash as SAP's installer sets the admin
    # user's shell to /bin/csh and csh has problems with strings that start
    # with ~ which can be generated by testapi::hashed_string() leading to
    # unexpected failures of script_output() or assert_script_run()
    type_string "exec bash\n";
}

sub test_version_info {
    my $output = script_output "sapcontrol -nr $instance -function GetVersionInfo";
    die "sapcontrol: GetVersionInfo API failed\n\n$output" unless ($output =~ /GetVersionInfo[\r\n]+OK/);
}

sub test_instance_properties {
    my $output = script_output "sapcontrol -nr $instance -function GetInstanceProperties | grep ^SAP";
    die "sapcontrol: GetInstanceProperties API failed\n\n$output" unless ($output =~ /SAPSYSTEM.+SAPSYSTEMNAME.+SAPLOCALHOST/s);

    $output =~ /SAPSYSTEMNAME, Attribute, ([A-Z][A-Z0-9]{2})/m;
    die "sapcontrol: SAP administrator [$sapadmin] does not match with System SID [$1]" if ($1 ne $sid);
}

sub test_stop {
    my $output = script_output "sapcontrol -nr $instance -function Stop";
    die "sapcontrol: Stop API failed\n\n$output" unless ($output =~ /Stop[\r\n]+OK/);

    $output = script_output "sapcontrol -nr $instance -function StopService";
    die "sapcontrol: StopService API failed\n\n$output" unless ($output =~ /StopService[\r\n]+OK/);
}

sub test_start_service {
    my $output = script_output "sapcontrol -nr $instance -function StartService $sid";
    die "sapcontrol: StartService API failed\n\n$output" unless ($output =~ /StartService[\r\n]+OK/);

    $output = script_output $ps_cmd;
    my @olines = split(/\n/, $output);
    die "sapcontrol: wrong number of processes running after an StartService\n\n" . @olines unless (@olines == 1);
    die "sapcontrol failed to start the service" unless ($output =~ /^$sapadmin.+sapstartsrv/);
}

sub test_start_instance {
    my $output = script_output "sapcontrol -nr $instance -function Start";
    die "sapcontrol: Start API failed\n\n$output" unless ($output =~ /Start[\r\n]+OK/);

    $output = script_output $ps_cmd;
    my @olines = split(/\n/, $output);
    die "sapcontrol: failed to start the instance" unless (@olines > 1);
}

sub post_run_hook {
    my ($self) = @_;

    return unless ($prev_console);
    select_console($prev_console, await_console => 0);
    ensure_unlocked_desktop if ($prev_console eq 'x11');
}

1;
