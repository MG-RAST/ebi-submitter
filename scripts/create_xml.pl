#!/usr/bin/perl
use strict;
use warnings;

use Data::Dumper ;
use LWP::UserAgent;
use JSON;
use Getopt::Long;
use Net::FTP;


my $json = new JSON ;

# Example:
# http://api.metagenomics.anl.gov//metagenome/mgm4447943.3?verbosity=full

# metagenome id
my $project_id = undef ;

# metagenome id
my $metagenome_id = undef ;

# mgrast base api url
my $url = "http://api.metagenomics.anl.gov/" ;

# resource name
my $resource = "project" ;
my $sample_resource = "sample";
my $experiment_resource = "metagenome";
my $run_resource = "download";

# api parameter
my $options = "?verbosity=full";

# submit to ena , default is false
my $submit 		= 0 ;

# stage name of file to be uploaded to ENA
my $stage_name  = "upload" || "preprocess.passed" ;


# schema/object type
my $sample_type = "Sample" ;
my $study_type = "Study" ;
my $experiment_type = "Experiment";
my $run_type = "Run";

# submission id
my $submission_id = undef ;

# ENA URL
my $auth = "" ;
my $ena_url = "https://www.ebi.ac.uk/ena/submit/drop-box/submit/";
my $user = undef ;
my $password = undef ;
my $ftp_ena     = "webin.ebi.ac.uk";
my $validate = 0;

my $verbose     = 0;
my $skip_upload = 0 ;
my $skip = 0 ;

GetOptions(
    'project_id=s' => \$project_id ,
    'url=s'  => \$url ,
    'submission_url=s' => \$ena_url,
    'user=s' => \$user,
    'password=s' => \$password,
    'submit' => \$submit,
    'verbose' => \$verbose,
	'auth=s' => \$auth ,
    'no_upload' => \$skip_upload,
    'validate' => \$validate,
    'skip=s' => \$skip,
);


unless($auth){
	$auth = "ENA%20$user%20$password" ;
	$ena_url = $ena_url ."?auth=" . $auth;
}

# Project ID will be ID for all submission for the given project - new and updates
$submission_id = $project_id ;

# initialise user agent
my $ua = LWP::UserAgent->new;
$ua->agent('EBI Client 0.1');


# Setup ftp/aspera connection
my $ftp = Net::FTP->new( $ftp_ena, Debug => 1) or die "Cannot connect to $ftp_ena: $@";
$ftp->login($user,$password) or die "Cannot login using $user and $password", $ftp->message;
$ftp->mkdir($project_id) ;
$ftp->cwd($project_id);


my ($project_data , $error) = get_json_from_url($ua,$url,$resource,$project_id,$options);

if ($error) {
    print STDERR "Fatal: retrieving project $project_id with error $error!\n";
    exit;
}

my $center_name  = $project_data->{metadata}->{PI_organization} || "unknown" ;
my $study_ref_name = $project_data->{id};
my $study_xml = get_project_xml($project_data);

#create samples xml

my $sample_xml = <<"EOF";
<?xml version="1.0" encoding="UTF-8"?>
<SAMPLE_SET xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
xsi:noNamespaceSchemaLocation="ftp://ftp.sra.ebi.ac.uk/meta/xsd/sra_1_5/SRA.sample.xsd">
EOF

foreach my $sample_obj (@{$project_data->{samples}}) {
	my $metagenome_sample_id = $sample_obj->[0];
	my $metagenome_sample_url = $sample_obj->[1];
	
	my ($sample_data, $error) = get_json_from_url($ua,$url,$sample_resource,$metagenome_sample_id,$options);
	if($error){
	    print STDERR "Error retrieving sample $metagenome_sample_id with error message $error!\n";
	    next ;
	}
	$sample_xml .= get_sample_xml($sample_data,$center_name);
}

$sample_xml .= "</SAMPLE_SET>";

my $experiment_xml = <<"EOF";
<?xml version="1.0" encoding="UTF-8"?>
<EXPERIMENT_SET xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
xsi:noNamespaceSchemaLocation="ftp://ftp.sra.ebi.ac.uk/meta/xsd/sra_1_5/SRA.experiment.xsd">
EOF

foreach my $library_obj (@{$project_data->{metagenomes}}) {
	my $metagenome_id = $library_obj->[0];
	my ($experiment_data,$error) = get_json_from_url($ua,$url,$experiment_resource,$metagenome_id,$options);
	if($error){
	    print STDERR "Error retrieving library data for $metagenome_id (ERROR:$error)\n";
	    next;
	}
	$experiment_xml .= get_experiment_xml($experiment_data,$center_name,$study_ref_name);
}

$experiment_xml .= "</EXPERIMENT_SET>";

my $run_xml = <<"EOF";
<?xml version="1.0" encoding="UTF-8"?>
<RUN_SET xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
xsi:noNamespaceSchemaLocation="ftp://ftp.sra.ebi.ac.uk/meta/xsd/sra_1_5/SRA.run.xsd">
EOF

foreach my $metagenome_obj (@{$project_data->{metagenomes}}) {
	my $metagenome_id = $metagenome_obj->[0];
	
	my ($file_name , $md5 , $error) = &prep_files_for_upload($ftp , $url , $stage_name , $metagenome_id);
	if($error){
	    print STDERR "Can't get file for $metagenome_id (ERROR:$error)\n";
	    next;
	}

	my ($run_data,$error) = get_json_from_url($ua,$url,$run_resource,$metagenome_id,'');

	$run_xml .= get_run_xml($run_data,$center_name,$metagenome_id , $file_name , $md5 , $project_id);
}

$run_xml .= "</RUN_SET>";

if($submit){
    my $files = {
	"study" => "study.xml" ,
	"sample" => "sample.xml" ,
	"experiment" => "experiment.xml" ,
	"run" => "run.xml" ,
    };

    if($skip){
	$files->{$skip} = 0 ;
    }

   submit($study_xml,$sample_xml,$experiment_xml,$run_xml,$submission_id,$center_name, $files);
}
else{
   print $study_xml . "\n";
   print $sample_xml . "\n";
   print $experiment_xml . "\n";
   print $run_xml . "\n";
}

sub get_json_from_url {
	my ($user_agent,$url, $resource, $metagenome_id, $options) = @_;
	my $response = $ua->get( join "/" , $url, $resource , $metagenome_id , $options);

    unless($response->is_success){
    	print STDERR "Error retrieving data for $metagenome_id\n";
    	print STDERR $response->status_line , "\n" ;
	my $error = 1 ;
	eval{
	    print STDERR $response->content , "\n" ;
	    my $tmp = $json->decode($response->content) ;
	    $error = $tmp->{ERROR} if $tmp->{ERROR} ;
	};
	return ( undef , $error) ;
    }

	my $json = new JSON;
	my $data = undef;

	# error handling if not json
	eval{
    	$data = $json->decode($response->content)
	};

	if($@){
    	print STDERR "Error: $@\n";
    	exit;
	}
	return $data;
}

sub get_project_xml{
   my ($data) = @_;
   # get ncbi scientific name and tax id
   #my ($ncbiTaxId) = get_ncbiScientificNameTaxID() ;

   # Fill template now:

   my $study_alias = $data->{id};
   my $study_description  = $data->{description};
   my $study_name  = $data->{name};
   my $center_name  = $data->{metadata}->{PI_organization} || "unknown" ;
   my $pi_first_name = $data->{metadata}->{PI_firstname} ;
   my $pi_last_name = $data->{metadata}->{PI_lastname} ;

   my $study_xml = <<"EOF";
<?xml version="1.0" encoding="UTF-8"?><STUDY_SET>
    <STUDY center_name="$center_name" alias="$study_alias" >
        <DESCRIPTOR>
            <STUDY_TITLE>$study_name</STUDY_TITLE>
            <STUDY_TYPE existing_study_type="Metagenomics"/>
            <STUDY_ABSTRACT>$study_description</STUDY_ABSTRACT>
        </DESCRIPTOR>
        <STUDY_ATTRIBUTES>
	    <STUDY_ATTRIBUTE>
	     <TAG>BROKER_OBJECT_ID</TAG>
	     <VALUE>$study_alias</VALUE>
	     </STUDY_ATTRIBUTE>
	     <STUDY_ATTRIBUTE>
	     <TAG>BROKER_CUSTOMER_NAME</TAG>
	     <VALUE>$pi_first_name $pi_last_name</VALUE>
	     </STUDY_ATTRIBUTE>
        </STUDY_ATTRIBUTES>
        
    </STUDY>
</STUDY_SET>
   
EOF
   return $study_xml ;
}

sub get_sample_xml{
   my ($data,$center_name) = @_;

   # get ncbi scientific name and tax id
   my ($ncbiTaxId) = get_ncbiScientificNameTaxID( $data->{metadata}->{biome} ) ;
   
   unless($ncbiTaxId){
       print STDERR "No tax id for " . ($data->{metadata}->{biome}) . "\n";
       print STDERR Dumper $data;
       exit;
   }

   # Fill template now:

   my $sample_alias = $data->{id};
   my $sample_name  = $data->{name};
   my $sample_attribute_table = {};
   foreach my $key ( keys %{$data->{metadata}} ) {
       $sample_attribute_table->{$key} = $data->{metadata}->{$key} ;
   }

   my @metagenome_ids ;
   foreach my $tmp (@{$data->{metagenomes}}){
       push @metagenome_ids , $tmp->[0] ;
   }
   
   foreach my $metadata_key ( keys %{$data->{env_package}->{metadata}} ) {
   	   if (exists($sample_attribute_table->{$metadata_key})) {
   	   		
   	   } else {
   	   	  $sample_attribute_table->{$metadata_key} = $data->{env_package}->{metadata}->{$metadata_key} ;
   	   }
       
   }
   

   my $sample_xml = <<"EOF";

    <SAMPLE alias="$sample_alias"
    center_name="$center_name">
        <TITLE>$sample_name . " Taxonomy ID:" . $ncbiTaxId</TITLE>
        <SAMPLE_NAME>
            <TAXON_ID>$ncbiTaxId</TAXON_ID>
        </SAMPLE_NAME>
        <DESCRIPTION>$sample_name . " Taxonomy ID:" . $ncbiTaxId</DESCRIPTION>
        <SAMPLE_ATTRIBUTES>
EOF

   foreach my $id (@metagenome_ids){
    $sample_xml .= <<"EOF";
          <SAMPLE_ATTRIBUTE>
             <TAG>BROKER_OBJECT_ID</TAG>
             <VALUE>$id</VALUE>
          </SAMPLE_ATTRIBUTE>
EOF
}


                foreach my $key ( keys
   %{$sample_attribute_table} )
                {
                my $value = $sample_attribute_table->{$key} ;
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

   return $sample_xml ;
}

sub get_experiment_xml {
	my ($data,$center_name,$study_ref_name) = @_;
	my $experiment_id = $data->{id};
	my $experiment_name = $data->{name};
	# todo if sequence type amplicon set to amplicon 
	my $library_strategy = "WGS";
	my $library_selection = "RANDOM";
	my $library_source = "METAGENOMIC";
	my $sample_id = $data->{sample}->[0];
	my $experiment_xml = <<"EOF";

       <EXPERIMENT alias="$experiment_id" center_name="$center_name">
       <TITLE>$experiment_name</TITLE>
       <STUDY_REF refname="$study_ref_name"/>
       <DESIGN>
           <DESIGN_DESCRIPTION></DESIGN_DESCRIPTION>
		           <SAMPLE_DESCRIPTOR refname="$sample_id"/>
           <LIBRARY_DESCRIPTOR>
               <LIBRARY_NAME>$experiment_name</LIBRARY_NAME>
			   <LIBRARY_STRATEGY>$library_strategy</LIBRARY_STRATEGY>
			   <LIBRARY_SOURCE>$library_source</LIBRARY_SOURCE>
               <LIBRARY_SELECTION>$library_selection</LIBRARY_SELECTION>
			   <LIBRARY_LAYOUT><SINGLE/></LIBRARY_LAYOUT>
			</LIBRARY_DESCRIPTOR>
			<SPOT_DESCRIPTOR>
         <SPOT_DECODE_SPEC>
       	      <SPOT_LENGTH>100</SPOT_LENGTH>
              <READ_SPEC>
                 <READ_INDEX>0</READ_INDEX>
                 <READ_CLASS>Application Read</READ_CLASS>
                 <READ_TYPE>Forward</READ_TYPE>
                 <BASE_COORD>1</BASE_COORD>
              </READ_SPEC>
         </SPOT_DECODE_SPEC>
 </SPOT_DESCRIPTOR>
       </DESIGN>
       <PLATFORM>
       <ILLUMINA>
       <INSTRUMENT_MODEL>Illumina Genome Analyzer</INSTRUMENT_MODEL>
       </ILLUMINA>
       </PLATFORM>
    </EXPERIMENT>
EOF
	return $experiment_xml;
}

sub get_run_xml {
	my ($data,$center_name,$metagenome_id , $filename , $file_md5,$project_id) = @_;
	my $run_id = $data->{id};
	my $run_name = $data->{name};
	
	my $run_xml = <<"EOF";
	    <RUN alias="$metagenome_id" center_name="$center_name">      
        <EXPERIMENT_REF refname="$metagenome_id"/>
         <DATA_BLOCK>
            <FILES>
                <FILE filename="$project_id/$filename"
                    filetype="fasta"
                    checksum_method="MD5" checksum="$file_md5"/>
            </FILES>
        </DATA_BLOCK>
    </RUN>
EOF
return $run_xml;
}

# function for ncbi tax name id lookup
sub get_ncbiScientificNameTaxID{
    my ($term) = @_ ;

    my $key = lc($term);
    
    my $mapping = {
	'small lake biome' => 1169740 ,
	'terrestrial biome' => 1348798,
	'freshwater biome' => 449939,
    };

    print STDERR "Lookup for $key : " . $mapping->{$key} , "\n" if($verbose) ;

    return $mapping->{$key
} ;
}


sub submit{

   my ($study_xml,$sample_xml,$experiment_xml,$run_xml,$submission_id,$center_name , $files) = @_ ;

   unless($submission_id){
       print STDERR "No submission id\n";
       exit;
   }

   my $action = "ADD" ;
   $action = "VALIDATE" if ($validate);

   my @line_action ;
   if($files){
       foreach my $key (keys %$files){

	   if($files->{$key}){
	       push @line_action , "<ACTION><$action source=\"". $files->{$key} ."\" schema=\"".$key."\"/>" ;
	   }
	   print join "\n" , @line_action , "\n" if ($verbose);
       }
   }

   my $submission = <<"EOF";
<?xml version="1.0" encoding="UTF-8"?>
<SUBMISSION_SET xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
xsi:noNamespaceSchemaLocation="ftp://ftp.sra.ebi.ac.uk/meta/xsd/sra_1_5/SRA.submission.xsd">
<SUBMISSION alias="$submission_id"
 center_name="$center_name" >
        <ACTIONS>
            <ACTION>
                <$action source="study.xml" schema="study"/>
            </ACTION>
            <ACTION>
                <$action source="sample.xml" schema="sample"/>
            </ACTION>
            <ACTION>
                <$action source="experiment.xml" schema="experiment"/>
            </ACTION>
            <ACTION>
                <$action source="run.xml" schema="run"/>
            </ACTION>
        </ACTIONS>
    </SUBMISSION>
</SUBMISSION_SET>
EOF

   #print $submission ;

   # dump study_xml
   open(FILE , ">study.xml");
   print FILE $study_xml ;
   close(FILE);
   
   # dump sample_xml
   open(FILE , ">sample.xml");
   print FILE $sample_xml ;
   close(FILE);
   
   # dump study_xml
   open(FILE , ">experiment.xml");
   print FILE $experiment_xml ;
   close(FILE);
   
   # dump study_xml
   open(FILE , ">run.xml");
   print FILE $run_xml ;
   close(FILE);

   # dump submission xml
   open(FILE , ">submission.xml");
   print FILE  $submission ;
   close FILE;
   
   
   my $cmd = "curl -k -F \"SUBMISSION=\@submission.xml\" -F \"STUDY=\@study.xml\" -F \"SAMPLE=\@sample.xml\" -F \"EXPERIMENT=\@experiment.xml\" -F \"RUN=\@run.xml\" \"$ena_url\"";
   print "$cmd\n";
   my $receipt = `$cmd` ;

   print STDERR $receipt , "\n" if($verbose);

   open(FILE, ">receipt.xml");
   print FILE $receipt ;
   close FILE;

   my $log = undef;

   return $log ;
}


sub prep_files_for_upload{
	my ($ftp , $url , $stage_name , $metagenome_id) = @_;
	
	
	my $resource 	= "download" ;
	
	# get list of stages and files
	my $response = $ua->get( join "/" , $url , $resource , $metagenome_id );
	
	unless($response->is_success){
	   	 print STDERR "Error retrieving data for " . (join "/" , $url , $resource , $metagenome_id , "\n" );
	   	# add http error message
		 print STDERR "Message " . $response->content , "\n";
		 return ( undef , undef , 1 )
	}


	

	my $stages = &decode($response->content);
	
	foreach my $stage ( @{$stages->{data}} ){
	
		if ($stage->{stage_name} eq $stage_name){
			print join "\t" , $stage->{stage_name} , $stage->{url} , "\n"  if ($verbose);
			
			# get sequences from MGRAST
			my $file_zip 		= $stage->{file_name} . ".gz" ;
			my $call = "curl \"" . $stage->{url} . "\" | gzip >" . $file_zip ;  
			
			print $call , "\n" if ($verbose) ; 
			my $out = `$call` unless(-f $file_zip ) ;
			

			my $md5_check_call 	= "md5sum " . $file_zip ;
			my $tmp 	       	= `$md5_check_call` ;
			my ($md5)  = $tmp =~/^(\S+)/ ;


			if ($verbose) {
			    print STDERR $md5_check_call , "\n" ;
			    print STDERR "MD5 = $md5\n" ;
			}
		
			unless(-f $file_zip ){
				print STDERR "Error: Missing file " . $file_zip . "\n" ;
			}
			else{
				print STDERR ($out || "success for $call"), "\n" ;
			}
			# upload to ENA
			
			#my $call ="ftp -in <<EOF\nopen $ftp_ena\nuser $user:$password\nls\nbye\nEOF\echo Done\n";
			
			
		 
		   $ftp->put($file_zip) unless ($skip_upload);
		   #print join "\n" , $ftp->ls ;
		   #$ftp->cwd("/pub") or die "Cannot change working directory ", $ftp->message;
		   #$ftp->get("that.file") or die "get failed ", $ftp->message;
		   #$ftp->quit;
			
		   return ( $file_zip , $md5 , $error )
		}
	}
	
	
}


sub decode{
	my($json_string) = @_;
	

	my $data = undef;
	
	eval{
	   	 $data = $json->decode($json_string);
		};

	if($@){
	     print STDERR "Error: $@\n";
		 print STDERR $json_string;
	     exit;
	}
	
	return $data ;
}

