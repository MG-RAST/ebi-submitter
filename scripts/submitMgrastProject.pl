#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper ;
use LWP::UserAgent;
use JSON;
use Getopt::Long;
use Net::FTP;

use Submitter::Project ;
use Submitter::Experiments ;

my $json = new JSON ;

# project id
my $project_id = undef ;

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
my $submit = 0;

# stage name of file to be uploaded to ENA
my $stage_name = "upload" || "preprocess.passed" ;

# schema/object type
my $sample_type = "Sample" ;
my $study_type = "Study" ;
my $experiment_type = "Experiment";
my $run_type = "Run";

# submission id
my $submission_id = undef ;

# ENA URL
my $auth = "" ;
my $ena_url = "https://www-test.ebi.ac.uk/ena/submit/drop-box/submit/";
my $user = $ENV{'EBI_USER'} || undef ;
my $password = $ENV{'EBI_PASSWORD'} || undef ;
my $ftp_ena = "webin.ebi.ac.uk";
my $validate = 0;
my $modify   = 0;

my $verbose         = 0;
my $debug           = 0;
my $dry_run         = 0;
my $skip_upload     = 0 ;
my $skip            = 0 ;
my $guess_taxon_id  = 0 ;
my $receipt_file    = "./receipt.xml";
my $download_files  = 0 ;     # Download sequence files from project and save them in $staging_dir
my $upload_files    = 0 ;     # Upload sequence files from $staging_dir to ENA inbox
my $staging_dir     = "./" ;  # Download/Upload directory

my $create_xml_options = {
  study => undef ,
  experiment => undef ,
  sample => undef ,
  run => undef ,
  all => undef ,
} ;

my $upload_options = {
  upload_reads => 0 ,
  upload_xml   => 0 ,
  dry_run      => 0 ,
};

my $submit_options = {
  VALIDATE  => 1 ,
  ADD       => 0 ,
  MODIFY    => 0 ,
  HOLD      => 0 ,
  RELEASE   => 0 
};


my ($file_id_key , $file_id_value) = ("stage_name" , "upload") ;



GetOptions(
	   'project_id=s'     => \$project_id ,
	   'user=s'           => \$user,
	   'password=s'       => \$password,
	   'url=s'            => \$url ,
	   'submission_url=s' => \$ena_url,
	   'submit'           => \$submit,
	   'verbose'          => \$verbose,
	   'auth=s'           => \$auth ,
	   'no_upload'        => \$skip_upload,
     'dry_run'          => \$dry_run,
	   'validate'         => \$validate,
     'modify'           => \$modify,
	   'skip=s'           => \$skip,
     'output=s'         => \$receipt_file,
     'download!'        => \$download_files,
     'upload!'          => \$upload_files,
     'staging_dir=s'    => \$staging_dir,
     'guess'            => \$guess_taxon_id,
     'file_id_key=s'    => \$file_id_key,
     'file_id_value=s'  => \$file_id_value,
     'submission_id=s'  => \$submission_id,
	  );

sub usage {
  print "\n\ncreate_xml.pl >>> create the ENA XML file for an MG-RAST project and submit it to EBI\n";
  print "create_xml.pl -user <username> -password <password> -project_id <project id>\n";
  print "\nOPTIONS\n";
  print "-user - EBI submitter login; if provided overrides environment variable EBI_USER\n" ;
  print "-password - password for user; if provided overrides environment variable EBI_PASSWORD\n" ; 
  print "-url - API URL to retrieve the project from\n";
  print "-submission_url - EBI submission URL\n";
  print "-submit - perform the submission to EBI\n";
  print "-verbose - verbose output\n";
  print "-auth - custom auth header\n";
  print "-no_upload - do not upload the files to the EBI dropbox\n";
  print "-validate - instead of adding the files, only validate them\n";
  print "-skip - file to skip in file generation\n";
  print "-output - name and path of receipt file , default is receipt.xml\n\n";
}

unless ((($user && $password) || $auth) && $project_id) {
  &usage();
  exit 0;
}

unless($auth){
	$auth = "ENA%20$user%20$password" ;
	$ena_url = $ena_url ."?auth=" . $auth;
}

# Project ID will be ID for all submission for the given project - new and updates
print STDERR "Checking submission id - create one if not provided\n" if ($verbose);
unless($submission_id){
  $submission_id = $project_id . time if ($project_id);
}

unless($submission_id){
    print STDERR "Can't create submission, no submisison ID or project provided\n" ;
    exit;
}

# initialise user agent
print STDERR "Setting up user agent and ftp connection\n" if ($verbose);
my $ua = LWP::UserAgent->new;
$ua->agent('EBI Client 0.1');


# Setup ftp/aspera connection and change into project dir for upload
# Change to binary mode for compressed file upload
my $ftp ;
if ($submit or $upload_files) {
  $ftp = Net::FTP->new( $ftp_ena) or die "Cannot connect to $ftp_ena: $@"; # , Debug => 1
  $ftp->login($user,$password) or die "Cannot login using $user and $password. ", $ftp->message;
  $ftp->mkdir($project_id) ;
  $ftp->cwd($project_id);
  $ftp->binary();
}

# get project overview
print STDERR "Getting project data from MG-RAST\n" if ($verbose);
my ($project_data, $error) = get_json_from_url($ua,$url,$resource,$project_id,$options);
if ($error) {
  print STDERR "ERROR: retrieving project $project_id with error $error!\n";
  exit;
}

# Download files from project
print STDERR "Downloading files ($download_files)\n" if ($verbose);
my $files = {} ; # List of files and md5s in staging dir
if ($download_files){
  ($files , $error) = &download_files_from_project($project_data,$file_id_key,$file_id_value) ;
  print Dumper $files ;
}

print STDERR "Uploading sequence files ($upload_files)\n" if ($verbose);
if ($upload_files){
  my ($f , $status , $error) = &upload_files_from_staging_dir($files) ;
  print STDERR "Files on ftp site:\n$status\n" if ($verbose) ;
  print STDERR "$error\n" if ($error) ;
}

# create project XML

my $center_name  = $project_data->{metadata}->{PI_organization} || "unknown" ;
my $study_ref_name = $project_data->{id};
# my $study_xml = get_project_xml($project_data);

my $prj       = new Submitter::Project($project_data);
my $study_xml = $prj->xml2txt ;
print Dumper  $study_xml if ($verbose); 


###### add to experiment // sequencing technology
my $ebi_tech = $project_data->{ebi_tech} ; 


# create samples XML

my $sample_xml = <<"EOF";
<?xml version="1.0" encoding="UTF-8"?>
<SAMPLE_SET xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
xsi:noNamespaceSchemaLocation="ftp://ftp.sra.ebi.ac.uk/meta/xsd/sra_1_5/SRA.sample.xsd">
EOF

foreach my $sample_obj (@{$project_data->{samples}}) {
	my $metagenome_sample_id = $sample_obj->[0];
	my $metagenome_sample_url = $sample_obj->[1];
	
	my ($sample_data, $err) = get_json_from_url($ua,$url,$sample_resource,$metagenome_sample_id,$options);
	if($error){
	    print STDERR "Error retrieving sample $metagenome_sample_id with error message $err!\n";
	    next ;
	}
	$sample_xml .= get_sample_xml($sample_data,$center_name);
}

$sample_xml .= "</SAMPLE_SET>";


###### Create Experiment XML ######

my $experiments = new Submitter::Experiments( {
  study_ref   => $study_ref_name,
  center_name => $center_name,
   
});

# build list of metagenomes
foreach my $library_obj (@{$project_data->{metagenomes}}) {
  my $metagenome_id = $library_obj->{metagenome_id};
	my ($experiment_data,$err) = get_json_from_url($ua,$url,$experiment_resource,$metagenome_id,$options);
	if($error){
	    print STDERR "Error retrieving library data for $metagenome_id (ERROR:$err)\n";
	    next;
	}
  else{
    print STDERR "Adding " . $experiment_data->{id} . "\n";
  }
  $experiments->add($experiment_data)
}

my $experiment_xml = $experiments->xml2txt ;





###### Create RUN XML ######

my $run_xml = <<"EOF";
<?xml version="1.0" encoding="UTF-8"?>
<RUN_SET xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
xsi:noNamespaceSchemaLocation="ftp://ftp.sra.ebi.ac.uk/meta/xsd/sra_1_5/SRA.run.xsd">
EOF

foreach my $metagenome_obj (@{$project_data->{metagenomes}}) {
	#my $metagenome_id = $metagenome_obj->[0];
  my $metagenome_id = $metagenome_obj->{metagenome_id};
	
  print STDERR "Prepping files for upload.\n" if ($verbose);
	my ($file_name , $md5 , $err) = &prep_files_for_upload($ftp , $url , $stage_name , $metagenome_id) ; #if ($download_files);
	if($err){
	    print STDERR "Can't get file for $metagenome_id (ERROR:$err)\n";
	    next;
	}

	my ($run_data,$err2) = get_json_from_url($ua,$url,$run_resource,$metagenome_id,'');

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
    print "Submitting\n" if ($verbose);
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
   my ($ncbiTaxId) = $data->{metadata}->{ncbi_taxon_id} ; 
   
  
   
   unless($ncbiTaxId){
     
      $ncbiTaxId = get_ncbiScientificNameTaxID( $data->{metadata}->{env_package} ) if ($guess_taxon_id);
      
      unless($ncbiTaxId){
        print STDERR "No tax id for " . ($data->{metadata}->{biome}) . "\n";
        print STDERR Dumper $data;
        exit;
      }
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
        <TITLE>$sample_name Taxonomy ID:$ncbiTaxId</TITLE>
        <SAMPLE_NAME>
            <TAXON_ID>$ncbiTaxId</TAXON_ID>
        </SAMPLE_NAME>
        <DESCRIPTION>$sample_name Taxonomy ID:$ncbiTaxId</DESCRIPTION>
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
  
  my $library = $data->{metadata}->{library} ;
  
	my $experiment_id = $library->{id};
	my $experiment_name = $library->{name};
	# todo if sequence type amplicon set to amplicon 
	my $library_strategy = $library->{type} ;
  my $sample_id = $data->{sample}->[0];
   
	my $library_selection = "RANDOM";
	my $library_source = undef ;
  
  my ($key, $value) = ('',''); # to get it work
  
  if ($library->{investigation_type} == "metagenome") {
      $library_source = "METAGENOMIC" ;
  }
  else{
    $library_source = $library->{investigation_type} || undef ;
  }
  
	
  
  # checks 
  unless ($library->{type}) {
    print STDERR "No library type for $experiment_id , exit!\n" ;
    exit;
  }
  
  unless ($library_source) {
    print STDERR "Missing library source for $experiment_id, exit!\n" ;
  }
  
  
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
       <EXPERIMENT_ATTRIBUTES>
       <EXPERIMENT_ATTRIBUTE>
          <TAG>$key</TAG>
          <VALUE>$value</VALUE>
       </EXPERIMENT_ATTRIBUTE>
       </EXPERIMENT_ATTRIBUTES>
    </EXPERIMENT>
EOF
	return $experiment_xml;
}

sub get_run_xml {
	my ($data,$center_name,$metagenome_id , $filename , $file_md5, $project_id) = @_;
	my $run_id = $data->{id};
	my $run_name = $data->{name};
	
  unless($filename){
    print STDERR "Error: No filename for <FILE>\n" ;
    exit;
  }
  
	my $run_xml = <<"EOF";
	    <RUN alias="$metagenome_id" center_name="$center_name">      
        <EXPERIMENT_REF refname="mgm$metagenome_id"/>
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
    
    # host-associated  human gut  408170
#     host-associated  human skin  539655
#     host-associated  human saliva  1679718
#     host-associated  human tracheal  1712573
#     host-associated  human vaginal  1632839
#     host-associated  human blood  1504969
#     host-associated  human oral  447426
#     host-associated  human eye  1774142
#     host-associated  human reproductive system  1842734
#     host-associated  human semen  1837932
#     host-associated  human milk  1633571
#     host-associated  human  646099
#     host-associated  human lung  433733
#     host-associated  human nasopharyngeal  1131769
#     host-associated  human bile  1630596
    
    
    my $mapping = {
		   'small lake biome' => 1169740 ,
		   'terrestrial biome' => 1348798,
		   'freshwater biome' => 449939,
		   'human-associated habitat' => 646099 ,
       'human-oral' => 447426 ,
    };

    print STDERR "Lookup for $key : " . $mapping->{$key} , "\n" if($verbose) ;

    return $mapping->{$key} || undef ;
}

# Submit xml files
sub submit{

   my ($study_xml,$sample_xml,$experiment_xml,$run_xml,$submission_id,$center_name , $files) = @_ ;

   unless($submission_id){
       print STDERR "No submission id\n";
       exit;
   }

   my $action = "ADD" ;
   $action = "VALIDATE" if ($validate);
   $action = "MODIFY" if ($modify);

   my @line_action ;
   if($files){
       foreach my $key (keys %$files){

	   if($files->{$key}){
	       push @line_action , "<ACTION><$action source=\"". $files->{$key} ."\" schema=\"".$key."\"/>" ;
	   }
	   print join "\n" , @line_action , "\n" if ($verbose);
       }
   }

   print "Preparing Submission XML\n" if ($verbose) ;

   my $submission = <<"EOF";
<?xml version="1.0" encoding="UTF-8"?>
<SUBMISSION_SET xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
xsi:noNamespaceSchemaLocation="ftp://ftp.sra.ebi.ac.uk/meta/xsd/sra_1_5/SRA.submission.xsd">
<SUBMISSION alias="$submission_id"
 center_name="$center_name" >
        <CONTACTS>
           <CONTACT name="Alex Mira"/>
           <CONTACT name="Andreas Wilke" inform_on_error="wilke\@mcs.anl.gov"/>
        </CONTACTS>
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
            <!-- ACTION>
                <$action source="run.xml" schema="run"/>
            </ACTION -->
        </ACTIONS>
    </SUBMISSION>
</SUBMISSION_SET>
EOF

   #print $submission ;

   # dump study_xml
   open(FILE , ">$staging_dir/study.xml") or die "Can't write to study.xml" ;
   print FILE $study_xml ;
   close(FILE);
   
   # dump sample_xml
   open(FILE , ">$staging_dir/sample.xml") or die "Can't write sample.xml" ;
   print FILE $sample_xml ;
   close(FILE);
   
   # dump experiment_xml
   open(FILE , ">$staging_dir/experiment.xml") or die "Can't write experiment.xml" ;
   print FILE $experiment_xml ;
   close(FILE);
   
   # dump run_xml
   open(FILE , ">$staging_dir/run.xml") or die "Can't write run.xml" ;
   print FILE $run_xml ;
   close(FILE);

   # dump submission xml
   open(FILE , ">$staging_dir/submission.xml") or die "Can't write submission.xml" ;
   print FILE  $submission ;
   close FILE;
   
   print "Initiating http transfer of XMLs\n" if ($verbose);
   
   my $cmd = "curl -k -F \"SUBMISSION=\@$staging_dir/submission.xml\" -F \"STUDY=\@$staging_dir/study.xml\" -F \"SAMPLE=\@$staging_dir/sample.xml\" -F \"EXPERIMENT=\@$staging_dir/experiment.xml\" -F \"RUN=\@$staging_dir/run.xml\" \"$ena_url\"";
   print "$cmd\n";
   my $receipt = `$cmd` unless ($dry_run);

   print STDERR $receipt , "\n" if($verbose);

   if ($receipt) {
     open(FILE, ">".$staging_dir."/".$receipt_file);
     print FILE $receipt ;
     close FILE;
   }
   else{
     print STDERR "No receipt for submission $submission_id\n";
     exit;
   }
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

sub download_files_from_project{
  my ($project_data,$file_id_key,$file_id_value) = @_ ;
  my $files = {} ;
  my $eror  = '' ;
  
	#my ($ftp , $url , $stage_name , $metagenome_id) = @_;
	my $resource 	= "download" ;
	
  foreach my $metagenome_obj (@{$project_data->{metagenomes}}) {
  
    my $metagenome_id = $metagenome_obj->{metagenome_id};
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
      
      if ($stage->{$file_id_key} eq $file_id_value){
        print join "\t" , "\nGetting file from" , $stage->{$file_id_key} , $stage->{url} , "\n"  if ($verbose);
			
			  # get sequences from MGRAST
			  my $file_zip 		=  $stage->{file_name} . ".gz" ;
			  my $call = "curl \"" . $stage->{url} . "\" | gzip >" . $staging_dir . "/" . $file_zip ;  
			
			  print STDERR "Download " . $call , "\n" if ($verbose) ; 
			  my $out   = `$call` unless(-f $file_zip ) ;
        my ($md5) = &get_md5($file_zip); 

			  

        # Check md5
        unless($stage->{file_md5} eq $md5){
          print STDERR "Download incomplete, MD5s not matching: " . $stage->{file_md5} ."!=" . $md5 . "\n" if ($debug);
        }
        else{
          print "Checked MD5 (". $stage->{file_md5} ."!=" . $md5 . ")\n" if ($verbose) ;
        }

			  $files->{$metagenome_id} = {  md5 => $md5 ,
                                      metagenome_id => $metagenome_id ,
                                      file => $file_zip ,
                                    };
		
			  unless(-f $staging_dir . "/" . $file_zip ){
				  print STDERR "Error: Missing file " . $file_zip . "\n" ;
          $error = "Missing files" ;
			  }
			  else{
				  print STDERR ($out || "Success for $call"), "\n" if ($verbose);
			  }
      }
    }
	}
  return ($files , $error) ;
}

# Upload files from dir
sub upload_files_from_staging_dir{
  my ($files) = @_ ;
  my $status  = '' ;
  my $error   = undef;
  

  unless ($files and ref $files and keys %$files){
    # get files from dir
    print STDERR "No files provided, creating list from $staging_dir\n" if ($verbose);
    
    opendir my($dh), $staging_dir or die "Couldn't open dir '$staging_dir: $!";
    my @fs = grep { /^mgm\d+\..+\.gz$/ } readdir $dh;
    closedir $dh;
    
    foreach my $f (@fs){
      my $md5     = &get_md5($staging_dir."/".$f);
      my ($mgid)  = $f =~ /^mgm(\d+\.\d+)\./ ;
      
      $files->{$mgid} = { 
        file          => $f ,
        md5           => $md5 ,
        metagenome_id => $mgid ,
      };
    }
    print STDERR join "\n" , (map { "Adding $_" } @fs) , "\n" ;    
  }
  
  foreach my $mg_id (keys %$files){
    my $file = $staging_dir . "/" . $files->{$mg_id}->{file} ;
    
    if(-f $file){
      print STDERR "Uploading $file\n" if ($verbose) ; 
      $ftp->put($file) unless ($skip_upload or $dry_run);
    }
    else{
      print STDERR "Something wrong, missing $file\n" ;
      exit;
    }
      
    $status = join "\n" , $ftp->ls ;
  }
  
  return ($files , $status , $error) ;
}

# Decode json string
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

# Compute md5 for file
sub get_md5{
  my ($file_zip) = @_ ;
  
  my $md5_check_call 	= "md5sum " . $file_zip ;
  my $tmp 	       	  = `$md5_check_call` ;
  my ($md5)           = $tmp =~/^(\S+)/ ;
  
  if ($verbose) {
    print STDERR $md5_check_call , " $md5\n" ;
  }
  
  return $md5 ;
}
