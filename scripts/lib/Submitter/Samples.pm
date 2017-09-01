package Submitter::Samples;
our @ISA = "Submitter";

use strict;
use warnings;
use Data::Dumper;

sub new {
  my ($class, $mg_tax_map, $mixs_term_map, $project_name, $center_name) = @_;
  
  my $self = {
    samples      => [],
    default_tax  => "metagenome",
    mg_taxonomy  => $mg_tax_map || {},
    mixs_map     => $mixs_term_map || {},
    center_name  => $center_name || undef,
    project_name => $project_name,
    default_ep   => "miscellaneous",
    envpack_map  => {
        "air"                   => {
            checklist => "ERC000012",
            fullname  => "air environmental package"
        },
        "built environment"     => {
            checklist => "ERC000031",
            fullname  => "built environment environmental package"
        },
        "host-associated"       => {
            checklist => "ERC000013",
            fullname  => "host-associated environmental package"
        },
        "human-associated"      => {
            checklist => "ERC000014",
            fullname  => "human-associated environmental package"
        },
        "human-gut"             => {
            checklist => "ERC000015",
            fullname  => "human gut environmental package"
        },
        "human-oral"            => {
            checklist => "ERC000016",
            fullname  => "human oral environmental package"
        },
        "human-skin"            => {
            checklist => "ERC000017",
            fullname  => "human skin environmental package"
        },
        "human-vaginal"         => {
            checklist => "ERC000018",
            fullname  => "human vaginal environmental package"
        },
        "microbial mat|biofilm" => {
            checklist => "ERC000019",
            fullname  => "microbial mat/biofilm environmental package"
        },
        "miscellaneous"         => {
            checklist => "ERC000025",
            fullname  => "miscellaneous environmental package"
        },
        "plant-associated"      => {
            checklist => "ERC000020",
            fullname  => "plant-associated environmental package"
        },
        "sediment"              => {
            checklist => "ERC000021",
            fullname  => "sediment environmental package"
        },
        "soil"                  => {
            checklist => "ERC000022",
            fullname  => "soil environmental package"
        },
        "wastewater|sludge"     => {
            checklist => "ERC000023",
            fullname  => "wastewater/sludge environmental package"
        },
        "water"                 => {
            checklist => "ERC000024",
            fullname  => "water environmental package"
        }
    }
  };
  
  return bless $self;
}

sub center_name {
  my ($self) = @_;
  return $self->{center_name};
}

sub add {
  my ($self, $sample, $mgids) = @_;
  if ($sample and $mgids) {
    push @{$self->{samples}}, {
        mg_ids       => $mgids,
        sample_id    => $sample->{id},
        sample_name  => $sample->{name},
        sample_data  => $self->simplify_hash($sample->{data}),
        envpack_data => $self->simplify_hash($sample->{envPackage}{data})
    };
  }
}

# Check model and return default if model not supported
sub get_tax_id {
  my ($self, $mg_tax) = @_;
  if ($mg_tax) {
    if ($self->{mg_taxonomy}{$mg_tax}) {
      return $self->{mg_taxonomy}{$mg_tax};
    } else {
      print "Warning: Can't find metagenome_taxonomy $mg_tax. Not in supported list. Setting to default.\n";
      return $self->{mg_taxonomy}{$self->{default_tax}};
    }
  }
  print "Warning: metagenome_taxonomy not defined. Setting to default.\n";
  return $self->{mg_taxonomy}{$self->{default_tax}};
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

sub checklist_ep {
  my ($self, $ep) = @_;
  unless (exists $self->{envpack_map}{$ep}) {
      print "Warning: Can't find env_package $ep. Not in supported list. Setting to default.\n";
      $ep = $self->{default_ep};
  }
  my $check_id = $self->{envpack_map}{$ep}{checklist};
  my $ep_name  = $self->{envpack_map}{$ep}{fullname};
  my $xml = <<"EOF";
    <SAMPLE_ATTRIBUTE>
       <TAG>ENA-CHECKLIST</TAG>
       <VALUE>$check_id</VALUE>
    </SAMPLE_ATTRIBUTE>
    <SAMPLE_ATTRIBUTE>
       <TAG>$ep_name</TAG>
       <VALUE>$ep</VALUE>
    </SAMPLE_ATTRIBUTE>
EOF
  return $xml;
}

sub attributes2xml {
  my ($self, $samples) = @_;
  my $xml = "";
  while (my ($key, $value) = each %$samples) {
    if (exists $self->{mixs_map}{$key}) {
       $key = $self->{mixs_map}{$key};
    }
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
   my ($self, $sample) = @_;

   my $center_name  = $self->center_name();
   my $sample_alias = $sample->{sample_id};
   my $sample_name  = $sample->{sample_name};
   my $taxonomy_id  = $self->get_tax_id($sample->{sample_data}{metagenome_taxonomy});
   
   my $sample_attributes = {
       project_name => $self->{project_name}
   };
   map { $sample_attributes->{$_} = $sample->{envpack_data}{$_} } keys %{$sample->{envpack_data}};
   map { $sample_attributes->{$_} = $sample->{sample_data}{$_} } keys %{$sample->{sample_data}};
   
   # hack to fix USA name
   if (exists($sample_attributes->{country}) && ($sample_attributes->{country} eq 'United States of America')) {
       $sample_attributes->{country} = 'USA';
   }

   my $xml = <<"EOF";
    <SAMPLE alias="$sample_alias" center_name="$center_name">
        <TITLE>$sample_name Taxonomy ID:$taxonomy_id</TITLE>
        <SAMPLE_NAME>
            <TAXON_ID>$taxonomy_id</TAXON_ID>
        </SAMPLE_NAME>
        <DESCRIPTION>$sample_name Taxonomy ID:$taxonomy_id</DESCRIPTION>
        <SAMPLE_ATTRIBUTES>
            
EOF

   $xml .= $self->broker_object_ids($sample->{mg_ids});
   $xml .= $self->checklist_ep($sample->{sample_data}{env_package});
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
