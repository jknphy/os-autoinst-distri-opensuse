## Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Run the Playwright web UI tests from the Agama Live ISO.
# The tests are downloaded as a CI artifact. There is no installation and no
# reboot, the module only runs the tests and uploads their results.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use Mojo::Base 'Yam::Agama::agama_base';
use Carp qw(croak);
use testapi qw(
  get_var
  script_run
  script_output
  assert_script_run
  record_info
  parse_extra_log
  upload_logs
  select_console
);

my $dir = '/root/agama-playwright';
my $junit = "$dir/test-results/junit.xml";

sub check_iso_versions {
    # The tests were validated with the browser and Node versions of the ISO
    record_info('Versions', script_output('firefox --version; node --version'));
    # The pinned Playwright was tested against Firefox 153, other versions can fail with
    # BiDi errors that look like UI regressions
    assert_script_run("firefox --version | grep -q 'Firefox 153\\.'",
        fail_message => 'The ISO does not ship Firefox 153, the pinned Playwright may not work with it');
}

sub download_tests {
    my $project = get_var('PLAYWRIGHT_PROJECT', 'JERiveraMoya/agama-playwright');
    my $ref = get_var('PLAYWRIGHT_REF', 'main');
    my $url = "https://gitlab.suse.de/$project/-/jobs/artifacts/$ref/raw/agama-playwright-tests.tar.gz?job=package";

    assert_script_run("rm -rf $dir && mkdir -p $dir", fail_message => 'preparing the test directory failed');
    # The Live ISO does not trust the SUSE CA that signs gitlab.suse.de and has no
    # repositories to install it from, so the certificate check is skipped
    assert_script_run("curl -ksSfL '$url' | tar -xz -C $dir",
        fail_message => "No CI artifact at $url. Has the 'package' job passed on $ref?");
    record_info('SHA', script_output("cat $dir/dist/BUILD_SHA"));
}

sub disable_kiosk_firefox {
    my $kiosk_script = '/root/.local/bin/gnome-kiosk-script';

    # The kiosk script starts a Firefox that stays open and uses RAM on the Live ISO.
    # Replace its launch with a sleep, so the script and the kiosk session stay up but
    # empty. The original is kept as .orig. sed -i writes a new file, the running script
    # keeps reading the old one: when Firefox is killed it re-executes the edited script.
    assert_script_run(
        "cp -n $kiosk_script $kiosk_script.orig"
          . q{ && sed -i 's/^firefox --profile.*/sleep infinity/' } . $kiosk_script,
        fail_message => 'disabling the kiosk Firefox failed');
    # Not an assertion: pkill fails when there is no Firefox running
    script_run("pkill -f 'firefox --profile'");
}

# Returns the exit code of the tests
sub run_playwright {
    my $env = 'FIREFOX_PATH=$(command -v firefox) AGAMA_URL=https://localhost'
      . ' PLAYWRIGHT_JUNIT_OUTPUT_FILE=test-results/junit.xml';
    $env .= " AGAMA_PASSWORD='" . get_var('AGAMA_PASSWORD') . "'" if get_var('AGAMA_PASSWORD');
    # Enables the planning scenarios, which register with SCC. Without it they are not defined.
    $env .= " REGCODE='" . get_var('SCC_REGCODE') . "'" if get_var('SCC_REGCODE');
    $env .= ' TIMEOUT_FACTOR=' . get_var('PLAYWRIGHT_TIMEOUT_FACTOR') if get_var('PLAYWRIGHT_TIMEOUT_FACTOR');

    # timeout kills a hanging run before the module timeout, so the results can still be uploaded
    my $cmd = "cd $dir && $env timeout 840 node node_modules/\@playwright/test/cli.js test --workers=1 --reporter=line,junit";
    # Secrets must not end up in the job log
    (my $shown = $cmd) =~ s/(REGCODE|AGAMA_PASSWORD)='[^']*'/$1=[masked]/g;
    record_info('playwright cmd', $shown);
    return script_run($cmd, timeout => 900);
}

sub upload_playwright_results {
    script_run("tar -czf /tmp/playwright-results.tar.gz -C $dir test-results");
    upload_logs('/tmp/playwright-results.tar.gz', failok => 1);
}

sub parse_junit_results {
    # Playwright writes no report when the run is killed by the timeout
    return record_info('No JUnit', "$junit was not written", result => 'fail') if script_run("test -f $junit");
    # openQA's JUnit parser rejects a document with a single root element and no XML
    # declaration, and it names suites after their "package" attribute, which Playwright
    # does not write. Add both before parsing.
    assert_script_run(
        q{sed -i -e '1i <?xml version="1.0" encoding="UTF-8"?>'}
          . q{ -e 's|<testsuite name="\([^"]*\)"|<testsuite package="playwright.\1" name="\1"|' }
          . $junit,
        fail_message => 'preparing the JUnit file for openQA failed');
    parse_extra_log(JUnit => $junit);
}

sub run {
    select_console 'install-shell';
    check_iso_versions();
    download_tests();
    disable_kiosk_firefox();
    my $ret = run_playwright();
    upload_playwright_results();
    parse_junit_results();
    croak("Playwright tests failed, see the uploaded test-results") unless $ret == 0;
}

sub post_fail_hook {
    my ($self) = @_;
    select_console 'install-shell';
    upload_playwright_results();
    # Not SUPER::post_fail_hook, it also uploads the Puppeteer dumps, which this module does not use
    $self->upload_agama_logs();
}

1;
