#!/usr/bin/env perl

use strict;
use warnings;
no warnings('once');

use Data::Dumper;
use LWP::UserAgent;
use JSON;
use Getopt::Long;

use Submitter::Project;
use Submitter::Experiments;

# inputs
my $upload_list   = undef;
my $project_id    = undef;
my $submission_id = undef;

# schema/object type
my $sample_type     = "Sample";
my $study_type      = "Study";
my $experiment_type = "Experiment";
my $run_type        = "Run";
my $receipt_file    = "./receipt.xml";
my $temp_dir        = ".";

# mgrast base api url
my $mgrast_url = "http://api.metagenomics.anl.gov";

# ENA URL
my $submit_option = 'ADD';
my $submit_url    = "https://www.ebi.ac.uk/ena/submit/drop-box/submit/";
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
my $study_ref   = $project_data->{id};
my $center_name = $project_data->{data}{PI_organization}{value} || "unknown" ;

my $prj = new Submitter::Project($study_ref, simplify_hash($project_data->{data}));
my $study_xml = $prj->xml2txt;
print Dumper $study_xml if ($verbose && (! $debug));

###### Create Experiments XML ######
my $experiments = new Submitter::Experiments($seq_model_map, $study_ref, $center_name);

###### Create Samples XML ######
my $sample_xml = <<"EOF";
<?xml version="1.0" encoding="UTF-8"?>
<SAMPLE_SET xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
xsi:noNamespaceSchemaLocation="ftp://ftp.sra.ebi.ac.uk/meta/xsd/sra_1_5/SRA.sample.xsd">
EOF

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
            print "read: $mgid, ".join(",", values %{$upload_data->{$mgid}})."\n" if ($verbose);
            push @mg_ids, $mgid;
            $experiments->add($sample_data->{id}, $library_data->{id}, $mgid, simplify_hash($library_data->{data}));
            $run_xml .= get_run_xml($center_name, $mgid, $upload_data->{$mgid});
        }
    }
    if (scalar(@mg_ids) > 0) {
        $sample_xml .= get_sample_xml($sample_data, $center_name, \@mg_ids);
    }
}

# finalize
$run_xml .= "</RUN_SET>";
$sample_xml .= "</SAMPLE_SET>";
my $experiment_xml = $experiments->xml2txt;

my $files = {
    "study" => "study.xml",
    "sample" => "sample.xml",
    "experiment" => "experiment.xml",
    "run" => "run.xml"
};

print "Submitting\n" if ($verbose);
submit($submit_option, $study_xml, $sample_xml, $experiment_xml, $run_xml, $submission_id, $center_name, $files);

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

sub get_sample_xml {
   my ($sample, $center_name, $mg_ids) = @_;

   my $sample_alias = $sample->{id};
   my $sample_name  = $sample->{name};
   my $sdata = simplify_hash($sample->{data});
   my $edata = simplify_hash($sample->{envPackage}{data});

   # get ncbi scientific name and tax id
   my $ncbiTaxName = $sdata->{metagenome_taxonomy};
   my $ncbiTaxId   = $mg_tax_map->{$ncbiTaxName};
   
   # Fill template now
   my $sample_attribute_table = {};
   map { $sample_attribute_table->{$_} = $edata->{$_} } keys %$edata;
   map { $sample_attribute_table->{$_} = $sdata->{$_} } keys %$sdata;

   my $sample_xml = <<"EOF";
    <SAMPLE alias="$sample_alias"
    center_name="$center_name">
        <TITLE>$sample_name Taxonomy ID:$ncbiTaxId</TITLE>
        <SAMPLE_NAME>
            <TAXON_ID>$ncbiTaxId</TAXON_ID>
        </SAMPLE_NAME>
        <DESCRIPTION>$sample_name Taxonomy ID:$ncbiTaxId</DESCRIPTION>
        <SAMPLE_ATTRIBUTES>
EOF

   foreach my $id (@$mg_ids) {
      $sample_xml .= <<"EOF";
          <SAMPLE_ATTRIBUTE>
             <TAG>BROKER_OBJECT_ID</TAG>
             <VALUE>$id</VALUE>
          </SAMPLE_ATTRIBUTE>
EOF
   }

   foreach my $key (keys %$sample_attribute_table) {
      my $value = $sample_attribute_table->{$key};
      $sample_xml .= <<"EOF";
          <SAMPLE_ATTRIBUTE>
             <TAG>$key</TAG>
             <VALUE>$value</VALUE>
          </SAMPLE_ATTRIBUTE>
EOF
   }

   $sample_xml .= <<"EOF";
        </SAMPLE_ATTRIBUTES>
    </SAMPLE>
EOF

   return $sample_xml;
}

sub get_run_xml {
	my ($center_name, $mg_id, $mg_info) = @_;
    
    my $filepath  = $mg_info->{path};
    my $file_md5  = $mg_info->{md5};
    my $file_type = $mg_info->{type};
  
	my $run_xml = <<"EOF";
	    <RUN alias="$mg_id" center_name="$center_name">      
        <EXPERIMENT_REF refname="$mg_id"/>
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
# submit($study_xml, $sample_xml, $experiment_xml, $run_xml, $submission_id, $center_name, $files);
# $files = {"study" => "study.xml", "sample" => "sample.xml", "experiment" => "experiment.xml", "run" => "run.xml"};
sub submit {
   my ($action, $study_xml, $sample_xml, $experiment_xml, $run_xml, $submission_id, $center_name, $files) = @_;
   
   unless($submission_id) {
       print STDERR "No submission id\n";
       exit;
   }
   
   print "Preparing Submission XML\n" if ($verbose);
   my @line_actions;
   if ($files) {
       foreach my $key (keys %$files) {
	       if ($files->{$key}) {
	           push @line_actions, "<ACTION><$action source=\"".$files->{$key}."\" schema=\"".$key."\"/></ACTION>";
	       }
       }
   }
   my $all_actions = join("\n", @line_actions);
   my $submission  = <<"EOF";
<?xml version="1.0" encoding="UTF-8"?>
<SUBMISSION_SET xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
xsi:noNamespaceSchemaLocation="ftp://ftp.sra.ebi.ac.uk/meta/xsd/sra_1_5/SRA.submission.xsd">
<SUBMISSION alias="$submission_id"
 center_name="$center_name">
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

   # dump study_xml
   open(FILE , ">$temp_dir/study.xml") or die "Can't write to study.xml" ;
   print FILE $study_xml;
   close(FILE);
   
   # dump sample_xml
   open(FILE , ">$temp_dir/sample.xml") or die "Can't write sample.xml" ;
   print FILE $sample_xml;
   close(FILE);
   
   # dump experiment_xml
   open(FILE , ">$temp_dir/experiment.xml") or die "Can't write experiment.xml" ;
   print FILE $experiment_xml;
   close(FILE);
   
   # dump run_xml
   open(FILE , ">$temp_dir/run.xml") or die "Can't write run.xml" ;
   print FILE $run_xml;
   close(FILE);

   # dump submission xml
   open(FILE , ">$temp_dir/submission.xml") or die "Can't write submission.xml" ;
   print FILE $submission;
   close FILE;
   
   print "Initiating http transfer of XMLs\n" if ($verbose);
   
   my $cmd = "curl -k -F \"SUBMISSION=\@$temp_dir/submission.xml\" -F \"STUDY=\@$temp_dir/study.xml\" -F \"SAMPLE=\@$temp_dir/sample.xml\" -F \"EXPERIMENT=\@$temp_dir/experiment.xml\" -F \"RUN=\@$temp_dir/run.xml\" \"$submit_url\"";
   print "$cmd\n";
   
   if ($debug) {
       print "######### submission.xml #########\n".$submission."\n";
       print "######### study.xml #########\n".$study_xml."\n";
       print "######### sample.xml #########\n".$sample_xml."\n";
       print "######### experiment.xml #########\n".$experiment_xml."\n";
       print "######### run.xml #########\n".$run_xml."\n";
       exit 0;
   }
   
   my $receipt = `$cmd`;
   print $receipt."\n" if($verbose);

   if ($receipt) {
     open(FILE, ">$receipt_file");
     print FILE $receipt;
     close FILE;
   } else {
     print STDERR "No receipt for submission $submission_id\n";
     exit;
   }
}

