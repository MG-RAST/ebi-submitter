package Submitter::Project;

use strict;
use warnings;

# Get project document from API
sub new {
  my ($class, $pid, $data) = @_;
  
  my $self = {
    center_name => $data->{PI_organization} || "unknown",
    alias => $pid,
    study_title  => $data->{project_name},
    study_type => 'Metagenomics',
    study_abstract => $data->{project_description},
    PI_email => $data->{PI_email},
    PI_name => ($data->{PI_firstname} || "")." ".($data->{PI_lastname} || ""),
    submitter_name => ($data->{firstname} || "")." ".($data->{lastname} || "")
  };
  # clean names
  $self->{PI_name} =~ s/^\s+|\s+$//g;
  $self->{submitter_name} =~ s/^\s+|\s+$//g;
  
  unless ($self->{submitter_name}) {
      $self->{submitter_name} = $self->{PI_name};
  }
  unless ($self->{PI_name}) {
      $self->{PI_name} = $self->{submitter_name};
  }
  
  # remove email and misc_param from metadata
  for my $key (keys %$data) {
    if ($key =~ /email|misc_param|lastname|firstname/i) {
      delete $data->{$key};
    }
  }
  $self->{attributes} = $data;
  
  return bless $self;
}

# MG-RAST project ID
sub alias {
  my ($self) = @_;  
  return $self->{alias};
}
sub project_id {
  my ($self) = @_;
  return $self->{alias};
}

# project name
sub name {
  my ($self) = @_;
  return $self->{study_title};
}
sub study_name {
  my ($self) = @_;
  return $self->name;
}
sub study_title {
  my ($self) = @_;
  return $self->name;
}
 
sub study_abstract {
  my ($self) = @_;
  return $self->{study_abstract};
}

# alias for study_abstract 
sub description {
  my ($self) = @_;
  my $description = $self->{study_abstract};
  $description =~ s/\w\s*\K\n//g; 
  return $description;
}

sub pi {
  my ($self) = @_;
  return $self->{PI_name};
}

sub center_name {
  my ($self) = @_;
  return $self->{center_name};
}

# XML methods
sub attributes2xml {
  my ($self, $BROKER_OBJECT_ID, $BROKER_CUSTOMER_NAME) = @_;
  
  my $id        = $self->alias();
  my $customer  = $self->pi();
  my $xml;
  
  foreach my $key (keys %{$self->{attributes}}) {
    my $value = $self->{attributes}->{$key};
    
    $xml .= <<"EOF";
      <STUDY_ATTRIBUTE>
         <TAG>$key</TAG>
         <VALUE>$value</VALUE>
     </STUDY_ATTRIBUTE>
EOF
  }
  
  return $xml;
}
  
sub broker2xml {
  my ($self, $BROKER_OBJECT_ID, $BROKER_CUSTOMER_NAME) = @_;
  
  my $id        = $self->alias();
  my $customer  = $self->pi();
  my $attr_xml  = <<"EOF";
    <STUDY_ATTRIBUTE>
       <TAG>BROKER_OBJECT_ID</TAG>
       <VALUE>$id</VALUE>
   </STUDY_ATTRIBUTE>
   <STUDY_ATTRIBUTE>
       <TAG>BROKER_CUSTOMER_NAME</TAG>
       <VALUE>$customer</VALUE>
   </STUDY_ATTRIBUTE>  
    
EOF
  
  return $attr_xml;
}

sub key2attribute {
  my ($self, $key) = @_;
  
  my $xml;
  my $value = $self->{$key} || undef;
  
  unless (defined $value) {
    print STDERR "No value for $key\n";
    exit;
  }
    
  $xml  .= <<"EOF";
    <STUDY_ATTRIBUTE>
       <TAG>$key</TAG>
       <VALUE>$value</VALUE>
    </STUDY_ATTRIBUTE>
EOF
  
  return $xml;
}

sub xml2txt {
  my ($self) = @_ ;
  
  my $center_name = $self->center_name();
  my $alias       = $self->alias();
  my $title       = $self->name();
  my $abstract    = $self->description();
  
  my $xml = <<"EOF";
<?xml version="1.0" encoding="UTF-8"?><STUDY_SET>
    <STUDY center_name="$center_name" alias="$alias" >
        <DESCRIPTOR>
            <STUDY_TITLE>$title</STUDY_TITLE>
            <STUDY_TYPE existing_study_type="Metagenomics"/>
            <STUDY_ABSTRACT>$abstract</STUDY_ABSTRACT>
        </DESCRIPTOR>
        <STUDY_ATTRIBUTES>
EOF

    $xml .= $self->broker2xml;
    $xml .= $self->key2attribute('submitter_name');
    $xml .= $self->key2attribute('PI_email');
    $xml .= $self->attributes2xml;

    $xml .= <<"EOF";
        </STUDY_ATTRIBUTES>
    </STUDY>
</STUDY_SET>
EOF
  
  return $xml;
}

1;