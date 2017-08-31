package Submitter::Experiments;
our @ISA = "Submitter";

use strict;
use warnings;
use Data::Dumper;

sub new {
  my ($class, $seq_model_map, $study_ref, $center_name) = @_ ;
  
  my $self = {
    experiments => [],
    seq_models  => $seq_model_map || {},
    study_ref   => $study_ref || undef,
    center_name => $center_name || undef
  };
  
  return bless $self 
}

sub study_ref {
  my ($self) = @_;
  return $self->{study_ref};
}

sub center_name {
  my ($self) = @_;
  return $self->{center_name};
}

sub add {
  my ($self, $sid, $lid, $mid, $data) = @_;
  if ($sid and $lid and $mid and $data and ref $data) {
    push @{$self->{experiments}}, {
        sample_id     => $sid,
        library_id    => $lid,
        metagenome_id => $mid,
        library_data  => $data
    };
  }
}

# Check model and return unspecified if model not supported
sub seq_model {
  my ($self, $model) = @_ ;
  
  if ($model) {
    if ($self->{seq_models}{$model}) {
      return $model;
    } else {
      print "Warning: Can't find model $model. Not in supported list of models. Setting to unspecified.\n";
      return "unspecified";
    }
  }
  
  print "Warning: Model not defined. Setting to unspecified.\n";
  return "unspecified";
}

sub platform2xml {
  my ($self, $library) = @_ ;
  
  # use seq_meth
  my $platform = uc($library->{seq_meth});
  $platform =~ s/\s+/_/g;
  if ($platform =~/454/) {
      $platform = "LS454";
  }
  
  # try seq_model than seq_make
  my $model = $self->seq_model($library->{seq_model});
  if (($model eq "unspecified") && $library->{seq_make}) {
      $model = $self->seq_model($library->{seq_make});
  }
  
  unless ($model && $platform) {
    # Never get here
    print STDERR "Something wrong, no sequencer model or platform identified.\n";
    print STDERR "Platform: $platform\tModel: $model\n";
    print STDERR Dumper $library;
    exit;
  }
  
  my $xml = <<"EOF"; 
    <PLATFORM>
      <$platform>
        <INSTRUMENT_MODEL>$model</INSTRUMENT_MODEL>
      </$platform>
    </PLATFORM>
EOF

  return $xml; 
}

sub attributes2xml {
  my ($self, $library) = @_ ;
  my $xml = "<EXPERIMENT_ATTRIBUTES>" ;
  
  foreach my $key (keys %$library) {
    my $value = $library->{$key};
    $xml .= <<"EOF";
     <EXPERIMENT_ATTRIBUTE>
        <TAG>$key</TAG>
        <VALUE>$value</VALUE>
     </EXPERIMENT_ATTRIBUTE>
EOF
  }
  
  $xml .= "</EXPERIMENT_ATTRIBUTES>";
  return $xml;
}

sub broker_object_id {
  my ($self, $id) = @_ ;
  
  my $xml .= <<"EOF";
   <EXPERIMENT_ATTRIBUTE>
      <TAG>BORKER_OBJECT_ID</TAG>
      <VALUE>$id</VALUE>
   </EXPERIMENT_ATTRIBUTE>
EOF

  return $xml;
}

# input is library object verbosity full
sub experiment2xml {
  my ($self, $data) = @_ ;
  
  my $center_name    = $self->center_name();
  my $study_ref_name = $self->study_ref();  
  my $library        = $data->{library_data};  
  
  # BORKER_OBJECT_ID used to link experiment to MG-RAST
  my $linkin_id = $data->{metagenome_id};
  my $sample_id = $data->{sample_id};
  
  my $experiment_id   = $library->{ebi_id} ? $library->{ebi_id} : $data->{library_id};
  my $experiment_name = $library->{metagenome_name};
  
  my $library_selection = "RANDOM";
  my $library_strategy  = undef;
  my $library_source    = undef;
  
  # translate investigation_type
  if ($library->{investigation_type} eq 'metagenome') {
      $library_strategy = "WGS";
      $library_source   = "METAGENOMIC";
  } elsif ($library->{investigation_type} eq 'mimarks-survey') {
      $library_strategy = "AMPLICON";
      $library_source   = "METAGENOMIC";
  } elsif ($library->{investigation_type} eq 'metatranscriptome') {
      $library_strategy = "RNA-Seq";
      $library_source   = "METATRANSCRIPTOMIC";
  }
  
  unless ($library_strategy && $library_source) {
      # Never get here
      print STDERR "Something wrong, no library strategy or source identified.\n" ;
      print STDERR "Strategy: $library_strategy\tSource: $library_source\n";
      print STDERR Dumper $library;
      exit;
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
         </DESIGN>
EOF

  $xml .= $self->platform2xml($library);
  $xml .= $self->attributes2xml($library);
  $xml .= $self->broker_object_id($linkin_id) ;
  $xml .= "</EXPERIMENT>" ; 
 
  return $xml
}


sub xml2txt {
  my ($self) = @_;
     
  my $xml = <<"EOF";
<?xml version="1.0" encoding="UTF-8"?>
<EXPERIMENT_SET xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
xsi:noNamespaceSchemaLocation="ftp://ftp.sra.ebi.ac.uk/meta/xsd/sra_1_5/SRA.experiment.xsd">
EOF

  foreach my $exp (@{$self->{experiments}}) {
    $xml .= $self->experiment2xml($exp);
  }
  $xml .= "</EXPERIMENT_SET>";
  return $xml;
}

1;