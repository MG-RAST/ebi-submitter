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

# set ftp connection
my $ftp = Net::FTP->new($furl, Passive => 1) or die "Cannot connect to $furl: $!";
$ftp->login($user, $pswd) or die "Cannot login using $user and $pswd. ", $ftp->message;
$ftp->mkdir($updir);
$ftp->cwd($updir);
$ftp->binary();

# compress / md5
my $gzfile = $tmpdir."/".basename($input).".gz";
my $md5 = `gzip -c $input | tee $gzfile | md5sum | cut -f1 -d' '`;
chomp $md5;
# ftp
$ftp->put($gzfile, basename($gzfile));

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

sub get_usage {
    return "USAGE: upload_read.pl -input=<sequence file> -output=<output info file> -updir=<ftp upload dir> -furl=<ebi ftp url> -user=<ebi ftp user> -pswd=<ebi ftp password> -tmpdir=<dir for temp files, default CWD> -trim <boolean: run adapter trimmer>\n";
}

