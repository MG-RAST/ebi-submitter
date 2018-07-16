#!/usr/bin/env perl

use strict;
use warnings;
no warnings('once');

use Net::FTP;
use Getopt::Long;
use File::Basename;
umask 000;

# options
my $input  = "";
my $output = "";
my $mgid   = "";
my $format = "fastq";
my $updir  = "";
my $furl   = "webin.ebi.ac.uk";
my $user   = $ENV{'EBI_USER'} || undef;
my $pswd   = $ENV{'EBI_PASSWORD'} || undef;
my $tmpdir = ".";
my $help   = 0;
my $options = GetOptions (
        "input=s"  => \$input,
        "output=s" => \$output,
        "mgid=s"   => \$mgid,
        "format=s" => \$format,
        "updir=s"  => \$updir,
        "furl=s"   => \$furl,
        "user=s"   => \$user,
        "pswd=s"   => \$pswd,
        "tmpdir=s" => \$tmpdir,
		"help!"    => \$help
);

if ($help) {
    print get_usage();
    exit 0;
} elsif (! -s $input) {
    print STDERR "input sequence file is missing\n";
    exit 1;
} elsif (length($output)==0) {
    print STDERR "output was not specified\n";
    exit 1;
} elsif (! $updir) {
    print STDERR "upload ftp dir is missing\n";
    exit 1;
}

unless ($format =~ /^fastq|fasta$/) {
    print STDERR "format must be one of: fastq or fasta\n";
    exit 1;
}

# compress / md5
my $gzfile = $tmpdir."/".basename($input).".gz";
my $md5 = `gzip -c $input | tee $gzfile | md5sum | cut -f1 -d' '`;
chomp $md5;

my $retry = 3;
foreach ((1..$retry)) {
    my $error = put_file($furl, $user, $pswd, $updir, $gzfile);
    if (! $error) {
        last;
    }
}
if ($error) {
    print STDERR $error."\n";
    exit 1;
}

# print output
my @data = (
    $mgid || 'null',
    $updir."/".basename($gzfile),
    $md5,
    $format
);
open(OUTF, ">$output");
print OUTF join("\t", @data)."\n";
close(OUTF);

exit 0;

sub put_file {
    my ($url, $user, $pswd, $dir, $file) = @_;
    
    # set ftp connection
    my $ftp = Net::FTP->new($url, Passive => 1, Timeout => 3600) || return "Cannot connect to $url: $!";
    $ftp->login($user, $pswd) || return "Cannot login using $user and $pswd: ".$ftp->message;
    $ftp->mkdir($dir); # skip errors as dir may already exist
    $ftp->cwd($dir) || return "Cannot change working directory: ".$ftp->message;
    $ftp->binary();

    # ftp
    $ftp->put($file, basename($file)) || return "Put of $file failed: ".$ftp->message;
    
    $ftp->quit();
    return "";
}

sub get_usage {
    return "USAGE: upload_read.pl -input=<sequence file> -output=<output info file> -updir=<ftp upload dir> -furl=<ebi ftp url> -user=<ebi ftp user> -pswd=<ebi ftp password> -tmpdir=<dir for temp files, default CWD>\n";
}

