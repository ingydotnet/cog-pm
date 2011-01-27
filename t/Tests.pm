package t::Tests;
use strict;
use Test::More ();
use File::Path ();
use Capture::Tiny ();
use Cwd ();
use lib Cwd::cwd . '/lib';

use base 'Exporter';
our @EXPORT = qw(
    XXX
    WWW
    rmpath
    mkpath
    cd
    run_pass
    files_exist
    $PERL
    $CWD
    $STDOUT
    $STDERR
    $SYSTEM_PASS
    $SYSTEM_FAIL
    $COMMAND
);

our $PERL = $^X;
our $CWD = Cwd::cwd();
our $STDOUT;
our $STDERR;
our $SYSTEM_PASS;
our $SYSTEM_FAIL;
our $COMMAND;

sub XXX {
    require XXX;
    XXX::XXX(@_);
}

sub WWW {
    require XXX;
    XXX::WWW(@_);
}

sub rmpath {
    my $path = shift;
    if (not -e $path) {
        Test::More::pass("rmpath $path - path did not exist");
    }
    else {
        my $success = File::Path::rmtree($path);
        die "rmpath $path - failed"
            if not $success or -e $path;
        Test::More::pass("rmpath $path");
    }
}

sub mkpath {
    my $path = shift;
    die "mkpath $path - path already exists"
        if -e $path;
    my $success = File::Path::mkpath($path);
    die "mkpath $path - failed"
        if not $success or not -e $path;
    Test::More::pass("mkpath $path");
}

sub cd {
    my $dir = shift || $CWD;
    chdir($dir)
        or die "chdir $dir - failed";
    Test::More::pass("chdir $dir");
}

sub run_pass {
    my $cmd = shift;
    _run($cmd);
    if ($SYSTEM_PASS) {
        Test::More::pass("$cmd - ran successfully");
    }
    else {
        die $STDERR;
    }
}

sub _run {
    my $COMMAND = shift;
    my $rc;
    ($STDOUT, $STDERR) = Capture::Tiny::capture {
        $rc = system $COMMAND;
    };
    $SYSTEM_PASS = $rc ? 0 : 1;
    $SYSTEM_FAIL = $rc ? 1 : 0;
}

sub files_exist {
    for my $file (@_) {
        Test::More::ok -e $file, "$file exists";
    }
}

1;
