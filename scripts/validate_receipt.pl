#!/usr/bin/env perl

use strict;
use warnings;
no warnings('once');

use XML::Simple;
use Getopt::Long;
umask 000;

# options
my $input   = "";
my $help    = 0;
my $options = GetOptions (
    "input=s" => \$input,
    "help!"   => \$help
);

if ($help) {
    print get_usage();
    exit 0;
} elsif (! -s $input) {
    print STDERR "input receipt file is missing\n";
    exit 1;
}

my $receipt = parse_ebi_receipt($input);

if (! $receipt) {
    print STDERR "submission receipt is not valid XML\n";
    exit 1;
}
if (! $receipt->{'success'}) {
    print STDERR "submission receipt is not correct format\n";
    exit 1;
}
if ($receipt->{'success'} eq 'false') {
    print STDERR "submission was not successful\n";
    if ($receipt->{'MESSAGES'}{'ERROR'} && (scalar(@{$receipt->{'MESSAGES'}{'ERROR'}}) > 0)) {
        print STDERR join("\n", @{$receipt->{'MESSAGES'}{'ERROR'}})."\n";
    }
    exit 1;
}
if (($receipt->{'success'} eq 'true') && ($xml->{'SUBMISSION'}{'accession'})) {
    print STDOUT "submission was successful\naccession ".$xml->{'SUBMISSION'}{'accession'}."\n";
    if ($receipt->{'MESSAGES'}{'INFO'} && (scalar(@{$receipt->{'MESSAGES'}{'INFO'}}) > 0)) {
        print STDOUT join("\n", @{$receipt->{'MESSAGES'}{'INFO'}})."\n";
    }
    exit 0;
} else {
    print STDERR "submission failed, unknown error occured";
    exit 1;
}


sub parse_ebi_receipt {
    my ($file) = @_;
    
    my $xml = undef;
    eval {
        $xml = XMLin($file, ForceArray => ['SAMPLE', 'EXPERIMENT', 'ACTIONS', 'RUN', 'INFO', 'ERROR']);
    };
    if ($@ || (! ref($xml))) {
        return undef;
    }
    return $xml;
    
    my $receipt = {
        success => $xml->{'success'},
        info    => $xml->{'MESSAGES'}{'INFO'},
        error   => $xml->{'MESSAGES'}{'ERROR'} || undef,
        submission => {
            mgrast_accession => $xml->{'SUBMISSION'}{'alias'},
            ena_accession    => $xml->{'SUBMISSION'}{'accession'} || undef,
        },
        study => {
            mgrast_accession  => $xml->{'STUDY'}{'alias'},
            ena_accession     => $xml->{'STUDY'}{'accession'} || undef,
        },
        samples     => [],
        experiments => [],
        runs        => []
    };
    @{$receipt->{samples}}     = map { {mgrast_accession => $_->{alias}, ena_accession => $_->{accession} || undef } } @{$xml->{'SAMPLE'}};
    @{$receipt->{experiments}} = map { {mgrast_accession => $_->{alias}, ena_accession => $_->{accession} || undef } } @{$xml->{'EXPERIMENT'}};
    @{$receipt->{runs}}        = map { {mgrast_accession => $_->{alias}, ena_accession => $_->{accession} || undef } } @{$xml->{'RUN'}};
    
    return $receipt;
}

sub get_usage {
    return "USAGE: validate_receipt.pl --input <receipt xml file>\n";
}