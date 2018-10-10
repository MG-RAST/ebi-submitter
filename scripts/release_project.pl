#!/usr/bin/env perl

use strict;
use warnings;
no warnings('once');

use LWP::UserAgent;
use JSON;
use Getopt::Long;

# inputs
my $project_id = undef;

# mgrast base api url
my $mgrast_url = "http://api-internal.metagenomics.anl.gov";

# ENA URL
my $submit_url = "https://www.ebi.ac.uk/ena/submit/drop-box/submit/";
my $user       = $ENV{'EBI_USER'} || undef;
my $password   = $ENV{'EBI_PASSWORD'} || undef;
my $help       = 0;
my $debug      = 0;

GetOptions(
    'project_id=s' => \$project_id,
    'mgrast_url=s' => \$mgrast_url,
    'submit_url=s' => \$submit_url,
    'user=s'       => \$user,
    'password=s'   => \$password,
    'help!'        => \$help,
    'debug!'       => \$debug
);

sub usage {
    print "release_project.pl -project_id <project id>\n";
    print "OPTIONS\n";
    print "\t-user          - EBI submitter login; if provided overrides environment variable EBI_USER\n";
    print "\t-password      - password for login; if provided overrides environment variable EBI_PASSWORD\n"; 
    print "\t-mgrast_url    - MG-RAST API URL to retrieve the project from\n";
    print "\t-submit_url    - EBI submission URL\n";
    print "\t-debug         - debug mode, files created but not submitted\n";
}

if ($help) {
    &usage();
    exit 0;
}

unless ($user && $password && $project_id) {
    print STDERR "Missing required input paramater\n";
    &usage();
    exit 1;
}

if ($debug) {
    $mgrast_url = "http://api-dev.metagenomics.anl.gov";
    $submit_url = "https://www-test.ebi.ac.uk/ena/submit/drop-box/submit/";
    print "Running in DEBUG mode:\nMG-RAST API:\t$mgrast_url\nEBI URL:\t$submit_url\n";
}

# add auth in a bad way
$submit_url .= '?auth=ENA%20'.$user.'%20'.$password;

# initialise handels
my $json  = new JSON;
my $agent = LWP::UserAgent->new;

# get previous submission
my $submission = get_json_from_url($mgrast_url."/submission/".$project_id);
unless (exists($submission->{receipt}) && ref($submission->{receipt}) && ($submission->{receipt}{success} eq 'true')) {
    print STDERR $json->encode($submission)."\n";
    print STDERR "Project $project_id has no existing ENA submission\n";
    exit 1;
}

my $submit_alias = $submission->{receipt}{submission}{mgrast_accession};
my $submit_id    = $submission->{receipt}{submission}{ena_accession};
my $study_id     = $submission->{receipt}{study}{ena_accession};

my $release = <<"EOF";
<?xml version="1.0" encoding="UTF-8"?>
<SUBMISSION_SET xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
xsi:noNamespaceSchemaLocation="ftp://ftp.sra.ebi.ac.uk/meta/xsd/sra_1_5/SRA.submission.xsd">
    <SUBMISSION alias="$submit_alias" accession="$submit_id" center_name="MG-RAST">
        <CONTACTS>
            <CONTACT name="Andreas Wilke" inform_on_error="wilke\@mcs.anl.gov"/>
        </CONTACTS>
        <ACTIONS>
            <ACTION>
                <RELEASE target="$study_id"/>
            </ACTION>
        </ACTIONS>
    </SUBMISSION>
</SUBMISSION_SET>
EOF

if ($debug) {
    print $release;
}

open(OUT, ">submission.xml");
print OUT $release;
close(OUT);

my $cmd = 'curl -s -k -F "SUBMISSION=@submission.xml" '.$submit_url;
if ($debug) {
    print $cmd;
}
my $receipt = `$cmd`;

if ($receipt =~ /success="true"/) {
    print STDOUT "release of $project_id / $study_id was successful\n";
} elsif ($receipt =~ /success="false"/) {
    print STDERR "release of $project_id / $study_id failed\n";
    my @lines = split(/\n/, $receipt);
    foreach my $line (@lines) {
        if ($line =~ /<ERROR>(.*)<\/ERROR>/) {
            print STDERR $1."\n";
        }
    }
    exit 1;
} else {
    print STDERR "error on submission:\n".$receipt."\n";
    exit 1;
}

exit 0;

sub get_json_from_url {
    my ($url) = @_;
    my $response = $agent->get($url);
    
    unless ($response->is_success) {
        print STDERR "Error retrieving data from $url\n";
        print STDERR $response->status_line."\n";
        my $tmp = undef;
        eval {
            $tmp = $json->decode($response->content);
        };
        if ($tmp && $tmp->{ERROR}) {
            print STDERR "ERROR: ".$tmp->{ERROR}."\n";
        } else {
            print STDERR "ERROR: ".$response->content."\n";
        }
        exit 1;
    }
    
    my $data = undef;
    # error handling if not json
    eval {
        $data = $json->decode($response->content);
    };
    if ($@) {
        print STDERR "Error: $@\n";
        exit 1;
    }
    return $data;
}

