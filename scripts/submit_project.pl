#!/usr/bin/env perl

use strict;
use warnings;
no warnings('once');

use Data::Dumper;
use LWP::UserAgent;
use JSON;
use Getopt::Long;

use Submitter::Project;
use Submitter::Samples;
use Submitter::Experiments;

# inputs
my $upload_list   = undef;
my $project_id    = undef;
my $submission_id = undef;
my $accession_id  = undef;

# schema/object type
my $sample_type     = "Sample";
my $study_type      = "Study";
my $experiment_type = "Experiment";
my $run_type        = "Run";
my $receipt_file    = "./receipt.xml";
my $temp_dir        = ".";

# mgrast base api url
my $mgrast_url = "http://api-dev.metagenomics.anl.gov";

# ENA URL
my $submit_option = 'ADD';
my $submit_url    = "https://www-test.ebi.ac.uk/ena/submit/drop-box/submit/";
my $user          = $ENV{'EBI_USER'} || undef;
my $password      = $ENV{'EBI_PASSWORD'} || undef;

my $verbose = 0;
my $help    = 0;
my $debug   = 0;

my $submit_options = {
    VALIDATE  => 1,
    ADD       => 1,
    MODIFY    => 1,
    HOLD      => 1,
    RELEASE   => 1 
};

my $mixs_term_map = {
    project_name       => ["project name", undef],
    investigation_type => ["investigation type", undef],
    seq_meth           => ["sequencing method", undef],
    collection_date    => ["collection date", undef],
    country            => ["geographic location (country and/or sea)", undef],
    location           => ["geographic location (region and locality)", undef],
    latitude           => ["geographic location (latitude)", "DD"],
    longitude          => ["geographic location (longitude)", "DD"],
    altitude           => ["geographic location (altitude)", "m"],
    depth              => ["geographic location (depth)", "m"],
    elevation          => ["geographic location (elevation)", "m"],
    env_package        => ["environmental package", undef],
    biome              => ["environment (biome)", undef],
    feature            => ["environment (feature)", undef],
    material           => ["environment (material)", undef]
};

GetOptions(
    'upload_list=s'   => \$upload_list,
    'project_id=s'    => \$project_id,
    'output=s'        => \$receipt_file,
    'mgrast_url=s'    => \$mgrast_url,
    'submit_url=s'    => \$submit_url,
    'submit_option=s' => \$submit_option,
    'user=s'          => \$user,
    'password=s'      => \$password,
    'temp_dir=s'      => \$temp_dir,
    'verbose!'        => \$verbose,
    'help!'           => \$help,
    'debug!'          => \$debug,
    'accession_id=s'  => \$accession_id,
    'submission_id=s' => \$submission_id
);

sub usage {
    print "\nsubmit_project.pl >>> create the ENA XML file for an MG-RAST project and submit it to EBI\n";
    print "submit_project.pl -project_id <project id> -upload_list <upload list file>\n";
    print "OPTIONS\n";
    print "\t-user          - EBI submitter login; if provided overrides environment variable EBI_USER\n";
    print "\t-password      - password for login; if provided overrides environment variable EBI_PASSWORD\n"; 
    print "\t-mgrast_url    - MG-RAST API URL to retrieve the project from\n";
    print "\t-submit_url    - EBI submission URL\n";
    print "\t-submit_option - EBI submission option (default ADD): ".join(", ", keys %$submit_options)."\n";
    print "\t-output        - name and path of receipt file, default is receipt.xml\n";
    print "\t-temp_dir      - path of temp dir, default is CWD\n";
    print "\t-verbose       - verbose output\n";
    print "\t-debug         - debug mode, files created but not submitted\n";
    print "upload_list line format:: mg ID \\t filepath \\t md5sum \\t file type\\n\n";
}

if ($help) {
    &usage();
    exit 0;
}

unless ($user && $password && $project_id && $upload_list && (-s $upload_list) && $submit_options->{$submit_option}) {
    print STDERR "Missing required input paramater\n";
    &usage();
    exit 1;
}

if (($submit_option eq 'MODIFY') && (! $accession_id)) {
    print STDERR "Option 'MODIFY' requires an accession ID\n";
    &usage();
    exit 1;
}

if ($debug) {
    $mgrast_url = "http://api-dev.metagenomics.anl.gov";
    $submit_url = "https://www-test.ebi.ac.uk/ena/submit/drop-box/submit/";
    print "Running in DEBUG mode:\nMG-RAST API:\t$mgrast_url\nEBI URL:\t$submit_url\n";
}

# parse upload info
my $upload_data = {};
open(UPLOAD, "<$upload_list");
foreach my $line (<UPLOAD>) {
    chomp $line;
    my @parts = split(/\t/, $line);
    $upload_data->{$parts[0]} = {
        "path" => $parts[1],
        "md5"  => $parts[2],
        "type" => $parts[3]
    };
}
close(UPLOAD);

# add auth in a bad way
$submit_url .= '?auth=ENA%20'.$user.'%20'.$password;

# Project ID will be ID for all submission for the given project - new and updates
print "Checking submission id - create one if not provided\n" if ($verbose);
unless ($submission_id) {
    $submission_id = $project_id.".".time;
}

# initialise handels
my $json  = new JSON;
my $agent = LWP::UserAgent->new;

# get metagenome_taxonomy CV
print "Getting metagenome_taxonomy CV from MG-RAST\n" if ($verbose);
my $mg_tax_map = get_mg_tax_map($mgrast_url);

# get seq_model CV
print "Getting seq_model CV from MG-RAST\n" if ($verbose);
my $seq_model_map = {};
map { $seq_model_map->{$_} = 1 } @{ get_json_from_url($mgrast_url."/metadata/cv?label=seq_model") };

# get project data
print "Getting project metadata from MG-RAST\n" if ($verbose);
my $project_data = get_json_from_url($mgrast_url."/metadata/export/".$project_id);


###### Create Project XML ######
my $study_ref    = $project_data->{id};
my $center_name  = $project_data->{data}{PI_organization}{value} || "unknown";
my $project_name = $project_data->{data}{project_name}{value} || $study_ref;
my $prj = new Submitter::Project($study_ref, simplify_hash($project_data->{data}));

###### Create Samples XML ######
my $samples = new Submitter::Samples($mg_tax_map, $mixs_term_map, $project_name, $center_name);

###### Create Experiments XML ######
my $experiments = new Submitter::Experiments($seq_model_map, $mixs_term_map, $study_ref, $project_name, $center_name);

###### Create RUN XML ######
my $run_xml = <<"EOF";
<?xml version="1.0" encoding="UTF-8"?>
<RUN_SET xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
xsi:noNamespaceSchemaLocation="ftp://ftp.sra.ebi.ac.uk/meta/xsd/sra_1_5/SRA.run.xsd">
EOF

# process project data
foreach my $sample_data (@{$project_data->{samples}}) {
    print "sample: ".$sample_data->{id}."\n" if ($verbose);
    my @mg_ids = ();
    foreach my $library_data (@{$sample_data->{libraries}}) {
        next unless ($library_data->{data}{metagenome_id} && $library_data->{data}{metagenome_id}{value});
        print "library: ".$library_data->{id}."\n" if ($verbose);
        my $mgid = $library_data->{data}{metagenome_id}{value};
        unless ($mgid =~ /^mgm.*/) {
            $mgid = 'mgm'.$mgid;
        }
        if ($upload_data->{$mgid}) {
            print "read: $mgid, ".join(", ", sort values %{$upload_data->{$mgid}})."\n" if ($verbose);
            push @mg_ids, $mgid;
            my $ldata = simplify_hash($library_data->{data});
            $experiments->add($sample_data->{id}, $library_data->{id}, $mgid, $ldata);
            $run_xml .= get_run_xml($center_name, $mgid, $library_data->{id}, $upload_data->{$mgid});
            # add mixs library metadata to sample
            foreach my $key (keys %$ldata) {
                if (exists $mixs_term_map->{$key}) {
                    $sample_data->{data}{$key} = { value => $ldata->{$key} };
                    print "added '$key' : '".$ldata->{$key}."' to sample\n" if ($verbose);
                }
            }
        }
    }
    if (scalar(@mg_ids) > 0) {
        $samples->add($sample_data, \@mg_ids);
    }
}
$run_xml .= "</RUN_SET>";

my $files = {
    study => {
        name => "study.xml",
        text => $prj->xml2txt
    },
    sample => {
        name => "sample.xml",
        text => $samples->xml2txt
    },
    experiment => {
        name => "experiment.xml",
        text => $experiments->xml2txt
    },
    run => {
        name => "run.xml",
        text => $run_xml
    }
};

submit($submit_option, $submission_id, $accession_id, $center_name, $files);

sub simplify_hash {
    my ($old) = @_;
    my $new = {};
    map { $new->{$_} = $old->{$_}{value} } grep { $old->{$_}{value} } keys %$old;
    return $new;
}

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

sub get_mg_tax_map {
    my ($url) = @_;
    
    $url .= "/metadata/cv?label=metagenome_taxonomy";
    my $data = get_json_from_url($url);
    my $mg_tax = {};
    
    foreach my $set (@$data) {
        next unless (scalar(@$set) == 2);
        my @ids = split(/:/, $set->[1]);
        if (scalar(@ids) == 2) {
            $mg_tax->{$set->[0]} = $ids[1];
        } else {
            $mg_tax->{$set->[0]} = $ids[0];
        }
    }
    
    return $mg_tax;
}

sub get_run_xml {
	my ($center_name, $mg_id, $lib_id, $mg_info) = @_;
    
    my $filepath  = $mg_info->{path};
    my $file_md5  = $mg_info->{md5};
    my $file_type = $mg_info->{type};
  
	my $run_xml = <<"EOF";
	    <RUN alias="$mg_id" center_name="$center_name">      
        <EXPERIMENT_REF refname="$lib_id"/>
         <DATA_BLOCK>
            <FILES>
                <FILE filename="$filepath"
                    filetype="$file_type"
                    checksum_method="MD5" checksum="$file_md5"/>
            </FILES>
        </DATA_BLOCK>
    </RUN>
EOF

    return $run_xml;
}

# Submit xml files
sub submit {
   my ($action, $submission_id, $accession_id, $center_name, $files) = @_;
   
   unless ($submission_id) {
       print STDERR "No submission id\n";
       exit;
   }
   
   print "Preparing Submission XML\n" if ($verbose);
   my @line_actions;
   foreach my $key (keys %$files) {
       push @line_actions, "<ACTION><$action source=\"".$files->{$key}{name}."\" schema=\"".$key."\"/></ACTION>";
   }
   my $all_actions = join("\n", @line_actions);
   my $accession   = $accession_id ? 'accession="'.$accession_id.'"' : '';
   my $submission  = <<"EOF";
<?xml version="1.0" encoding="UTF-8"?>
<SUBMISSION_SET xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
xsi:noNamespaceSchemaLocation="ftp://ftp.sra.ebi.ac.uk/meta/xsd/sra_1_5/SRA.submission.xsd">
    <SUBMISSION alias="$submission_id" $accession center_name="$center_name">
        <CONTACTS>
            <CONTACT name="Alex Mira"/>
            <CONTACT name="Andreas Wilke" inform_on_error="wilke\@mcs.anl.gov"/>
        </CONTACTS>
        <ACTIONS>
            $all_actions
        </ACTIONS>
    </SUBMISSION>
</SUBMISSION_SET>
EOF

   $files->{submission} = {
       name => "submission.xml",
       text => $submission
   };

   # output and clean xml files
   my $utf_clean = "iconv -f UTF-8 -t UTF-8 -c";
   foreach my $file (values %$files) {
       open(OUT, ">$temp_dir/".$file->{name}.".tmp");
       print OUT $file->{text};
       close(OUT);
       system("cat $temp_dir/".$file->{name}.".tmp | $utf_clean > $temp_dir/".$file->{name});
       system("rm $temp_dir/".$file->{name}.".tmp");
   }
   
   my $cmd = "curl -s -k -F \"SUBMISSION=\@$temp_dir/submission.xml\" -F \"STUDY=\@$temp_dir/study.xml\" -F \"SAMPLE=\@$temp_dir/sample.xml\" -F \"EXPERIMENT=\@$temp_dir/experiment.xml\" -F \"RUN=\@$temp_dir/run.xml\" \"$submit_url\"";
   
   if ($debug) {
       foreach my $file (values %$files) {
           print "######### ".$file->{name}." #########\n".$file->{text}."\n";
       }
       exit 0;
   }
   
   print "Initiating http transfer of XMLs\n$cmd\n" if ($verbose);
   my $receipt = `$cmd`;
   print $receipt."\n" if ($verbose);

   if ($receipt) {
     open(FILE, ">$receipt_file");
     print FILE $receipt;
     close FILE;
   } else {
     print STDERR "No receipt for submission $submission_id\n";
     exit;
   }
}

