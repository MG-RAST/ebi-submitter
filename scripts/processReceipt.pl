#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper ;
use LWP::UserAgent;
use JSON;
use Getopt::Long;
use Net::FTP;


my $file = shift @ARGV ;

print $file , "\n";

my $receipt = new Receipt();
$receipt->parse($file) ;
print join "\t" , "Success:" , $receipt->success() || "undef" , "\n";
print join "\t" , "Submission:" , $receipt->submission , "\n";







package Receipt;

use strict;
use warnings;
use Data::Dumper;
use XML::Simple;


sub new{
  my (@list) = @_ ;
  
  my $r = {
    success => undef ,
    submission => {
      alias     => undef ,
      accession => undef ,
    },
    xml => undef ,
  } ;
  
  print Dumper @list ;
  return bless $r
}

sub success{
  my ($self) = @_ ;
  return $self->{xml}->{success} ;
}

sub submission{
  my ($self) = @_ ;
  my ($accession , $alias) = undef ;
  if ($self->{xml} ){
    ($accession , $alias) = ($self->{xml}->{SUBMISSION}->{accession} ,  $self->{xml}->{SUBMISSION}->{alias});
  }
  return ($accession , $alias) ; 
}

sub parse{
  my ($self , $file) = @_ ;

    my $receipt = XMLin( $file , KeyAttr => { server => 'name' }, ForceArray => [ 'SAMPLE', 'EXPERIMENT'  , 'ACTIONS' , 'RUN' ]);
    $self->{xml} = $receipt ;
    print Dumper $receipt ;
}

sub xml{
  my ($self) = @_ ;
  return $self->{xml} ;
}

1;