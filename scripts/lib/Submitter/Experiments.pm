package Submitter::Experiments;
our @ISA = "Submitter";

use strict;
use warnings;
use Data::Dumper;

# Get project document from API
sub new{
  my ($class , $data) = @_ ;
  
  my $self = { 
    experiments   => [] ,
    study_ref     => $data->{study_ref}   || undef ,
    center_name   => $data->{center_name} || undef ,
  } ;
  
  return bless $self 
}

sub center_name{
  my ($self) = @_ ;
  return $self->{center_name}
}

sub add{
  my ($self, $data) = @_ ;
  if ($data and ref $data){
    push @{$self->{experiments}} , $data;
  }
}


sub seq_model{
  my ($self , $model) = @_ ;

  my $models = { 
     "Illumina Genome Analyzer" => 1 ,
     "Illumina Genome Analyzer II" => 1 ,
     "Illumina Genome Analyzer IIx" => 1 ,
     "Illumina HiSeq 2500" => 1 ,
     "Illumina HiSeq 2000" => 1 ,
     "Illumina HiSeq 1500" => 1 ,
     "Illumina HiSeq 1000" => 1 ,
     "Illumina MiSeq" => 1 ,
     "Illumina HiScanSQ" => 1 ,
     "HiSeq X Ten" => 1 ,
     "NextSeq 500" => 1 ,
     "HiSeq X Five" => 1 ,
     "Illumina HiSeq 3000" => 1 ,
     "Illumina HiSeq 4000" => 1 ,
     "NextSeq 550" => 1 ,
     "454 GS" => 1 ,
     "454 GS 20" => 1 ,
     "454 GS FLX" => 1 ,
     "454 GS FLX+" => 1 ,
     "454 GS FLX Titanium" => 1 ,
     "454 GS Junior" => 1 ,
  };
  

  unless ($models->{ ($model || undef) }){
    print STDERR "Can't find model " . ($model|| "undef") ." in supported list.\n" ;
    $model = "unspecified";
  }
  
  return $model
}


sub platform2xml{
  my ($self,$library) = @_ ;
  
  my $platform = "" ;
  my $model = $self->seq_model( $library->{data}->{seq_model} || undef);
  if ($library->{data}->{seq_meth} =~/454/) {
    $platform = <<"EOF"; 
    <PLATFORM>
      <LS454>
        <INSTRUMENT_MODEL>$model</INSTRUMENT_MODEL>
      </LS454>
    </PLATFORM>
EOF
  }
  elsif($library->{data}->{seq_meth} =~/illumina/i) {
    $platform = <<"EOF"; 
    <PLATFORM>
      <ILLUMINA>
        <INSTRUMENT_MODEL>$model</INSTRUMENT_MODEL>
      </ILLUMINA>
    </PLATFORM>
EOF
  }
  else{
    print STDERR "Can't identy seq method \n";
    exit;
  }
  
}

sub attributes2xml{
  my ($self , $library) = @_ ;
  my $xml = "<EXPERIMENT_ATTRIBUTES>" ;
  
  foreach my $key (keys %{$library->{data}}){
    my $value = $library->{data}->{$key} ;
    $xml .= <<"EOF";
    <EXPERIMENT_ATTRIBUTE>
        <TAG>$key</TAG>
        <VALUE>$value</VALUE>
     </EXPERIMENT_ATTRIBUTE>
EOF
  }
  $xml .= "</EXPERIMENT_ATTRIBUTES>" ;

 
 return $xml ;
}

sub broker_object_id{
  my ($self, $id) = @_ ;
  
  my $xml .= <<"EOF";
  <EXPERIMENT_ATTRIBUTE>
      <TAG>BORKER_OBJECT_ID</TAG>
      <VALUE>$id</VALUE>
   </EXPERIMENT_ATTRIBUTE>
EOF
  return $xml 
}

# input is metagenome object verbosity full
sub experiment2xml{
  my ($self,$data) = @_ ;
  #my ($data,$center_name,$study_ref_name) = @_;
  
  my $center_name     = $self->center_name() ;
  my $study_ref_name  = $self->{study_ref} ;
  
  my $library = $data->{metadata}->{library} ;

  my $experiment_id = undef ;
  if (defined $library->{dbxref} and defined $library->{dbxref}->{ENA}){
    $experiment_id     = $library->{dbxref}->{ENA}
  }
  else{
	my $experiment_id     = $library->{dbxref}->{ENA} || $library->{id};
  #my $experiment_id    = $data->{id};
  }
  
  # BORKER_OBJECT_ID used to link experiment to MG-RAST
  my $linkin_id = $data->{id};
  
	my $experiment_name   = $library->{name};
	# todo if sequence type amplicon set to amplicon 
	my $library_strategy = $library->{type} ;
  my $sample_id = $data->{sample}->[0];
 
	my $library_selection = "RANDOM";
	my $library_source = undef ;

  if ($library->{data}->{investigation_type} eq "metagenome") {
      $library_source = "METAGENOMIC" ;
  }
  else{
    $library_source = $library->{data}->{investigation_type} || undef ;
  }
  
  # change to real key-value pairs
	my ($key,$value) = ('','');
  
  # checks 
  unless ($library->{type}) {
    print STDERR "No library type for $experiment_id , exit!\n" ;
    exit;
  }

  unless ($library_source) {
    print STDERR "Missing library source for $experiment_id, exit!\n" ;
  }
  
  
	my $xml = <<"EOF";

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
EOF
 $xml .= $self->platform2xml($library)  ;
 $xml .= $self->attributes2xml($library);
 $xml .= $self->broker_object_id($linkin_id) ;
 $xml .= "</EXPERIMENT>" ; 
 
  return $xml
}


sub xml2txt{
  my ($self) = @_ ;
     
  my $xml = <<"EOF";
<?xml version="1.0" encoding="UTF-8"?>
<EXPERIMENT_SET xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
xsi:noNamespaceSchemaLocation="ftp://ftp.sra.ebi.ac.uk/meta/xsd/sra_1_5/SRA.experiment.xsd">
EOF

  foreach my $mg_obj (@{$self->{experiments}}) {
    $xml .= $self->experiment2xml($mg_obj);
  }
  $xml .= "</EXPERIMENT_SET>";
  return $xml
}

1;