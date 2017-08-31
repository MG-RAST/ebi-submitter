package Submitter::Experiments;
our @ISA = "Submitter";

use strict;
use warnings;
use Data::Dumper;

sub new {
  my ($class, $center_name) = @_;
  
  my $self = {
    samples     => [],
    center_name => $center_name || undef,
    default_id  => "ERC000025";
    checklist   => {
        "air"                   => "ERC000012",
        "built environment"     => "ERC000031",
        "host-associated"       => "ERC000013",
        "human-associated"      => "ERC000014",
        "human-gut"             => "ERC000015",
        "human-oral"            => "ERC000016",
        "human-skin"            => "ERC000017",
        "human-vaginal"         => "ERC000018",
        "microbial mat|biofilm" => "ERC000019",
        "miscellaneous"         => "ERC000025",
        "plant-associated"      => "ERC000020",
        "sediment"              => "ERC000021",
        "soil"                  => "ERC000022",
        "wastewater|sludge"     => "ERC000023",
        "water"                 => "ERC000024"
    }
  };
  
  return bless $self 
}

sub center_name {
  my ($self) = @_;
  return $self->{center_name};
}

sub get_checklist_id {
   my ($self, $ep) = @_;
   if ($self->{checklist}{$ep}) {
      return $self->{checklist}{$ep};
   } else {
      return $self->{default_id};
   }
}

sub add {
  my ($self, $sample, $mgids) = @_;
  if ($sample and $mgids) {
    push @{$self->{samples}}, {
        mg_ids       => $mgids,
        sample_id    => $sample->{id},
        sample_name  => $sample->{name},
        sample_data  => $self->simplify_hash($sample->{data});
        envpack_data => $self->simplify_hash($sample->{envPackage}{data});
    };
  }
}

sub broker_object_ids {
  my ($self, $ids) = @_;
  my $xml = "";
  foreach my $id (@$ids) {
     $xml .= <<"EOF";
         <SAMPLE_ATTRIBUTE>
            <TAG>BROKER_OBJECT_ID</TAG>
            <VALUE>$id</VALUE>
         </SAMPLE_ATTRIBUTE>
EOF
   }
   return $xml;
}

sub checklist_id {
  my ($self, $ep) = @_;
  my $id  = $self->get_checklist_id($ep);
  my $xml = <<"EOF";
    <SAMPLE_ATTRIBUTE>
       <TAG>ENA-CHECKLIST</TAG>
       <VALUE>$id</VALUE>
    </SAMPLE_ATTRIBUTE>
EOF
  return $xml;
}

sub attributes2xml {
  my ($self, $samples) = @_;
  my $xml = "";
  foreach my $key (keys %$samples) {
    my $value = $samples->{$key};
    $xml .= <<"EOF";
       <SAMPLE_ATTRIBUTE>
          <TAG>$key</TAG>
          <VALUE>$value</VALUE>
       </SAMPLE_ATTRIBUTE>
EOF
  }
  return $xml;
}


sub sample2xml {
   my ($sample) = @_;

   my $center_name  = $self->center_name();
   my $sample_alias = $sample->{sample_id};
   my $sample_name  = $sample->{sample_name};
   my $ncbiTaxName  = $sample->{sample_data}{metagenome_taxonomy};
   my $ncbiTaxId    = $mg_tax_map->{$ncbiTaxName};
   
   my $sample_attributes = {};
   map { $sample_attributes->{$_} = $sample->{envpack_data}{$_} } keys %{$sample->{envpack_data}};
   map { $sample_attributes->{$_} = $sample->{sample_data}{$_} } keys %{$sample->{sample_data}};

   my $xml = <<"EOF";
    <SAMPLE alias="$sample_alias" center_name="$center_name">
        <TITLE>$sample_name Taxonomy ID:$ncbiTaxId</TITLE>
        <SAMPLE_NAME>
            <TAXON_ID>$ncbiTaxId</TAXON_ID>
        </SAMPLE_NAME>
        <DESCRIPTION>$sample_name Taxonomy ID:$ncbiTaxId</DESCRIPTION>
        <SAMPLE_ATTRIBUTES>
            
EOF

   $xml .= $self->broker_object_ids($sample->{mg_ids});
   $xml .= $self->checklist_id($sample->{sample_data}{env_package});
   $xml .= $self->attributes2xml($sample_attributes);
   
   $xml .= <<"EOF";
        </SAMPLE_ATTRIBUTES>
    </SAMPLE>
EOF

   return $xml;
}

sub xml2txt {
  my ($self) = @_;
  
  my $xml = <<"EOF";
  <?xml version="1.0" encoding="UTF-8"?>
  <SAMPLE_SET xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:noNamespaceSchemaLocation="ftp://ftp.sra.ebi.ac.uk/meta/xsd/sra_1_5/SRA.sample.xsd">
EOF
  
  foreach my $sam (@{$self->{samples}}) {
    $xml .= $self->sample2xml($sam);
  }
  $xml .= "</SAMPLE_SET>";
  return $xml;
}

sub simplify_hash {
    my ($self, $old) = @_;
    my $new = {};
    map { $new->{$_} = $old->{$_}{value} } grep { $old->{$_}{value} } keys %$old;
    return $new;
}

1;
