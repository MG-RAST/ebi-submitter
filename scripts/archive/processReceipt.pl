#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper ;
use LWP::UserAgent;
use JSON;
use Getopt::Long;
use Net::FTP;


my $file = shift @ARGV ;

my $upload  = 1 ;
my $debug   = 0 ;

print $file , "\n";

my $receipt = new Receipt();
$receipt->parse($file) ;
print join "\t" , "Success:" , $receipt->success() || "undef" , "\n";
print join "\t" , "Submission:" , $receipt->submission , "\n";


if ($upload) {
  
  my $json = JSON->new ;
  my $attributes = {
    project_id    => $receipt->xml->{STUDY}->{alias} ,
    submission_id => $receipt->xml->{SUBMISSION}->{alias},
    type          => 'EBI Submission Receipt' ,
    receipt       => $receipt->xml ,
    db_xref       => {
      submission  => $receipt->xml->{SUBMISSION} ,
      libraries   => $receipt->xml->{EXPERIMENT} ,
      project     => $receipt->xml->{STUDY} ,
      samples     => $receipt->xml->{SAMPLE} ,
      files       => $receipt->xml->{RUN} , # stage
      
    }
  };
  #$attributes = $json->encode($receipt->xml) ;
  
  print Dumper $attributes , "\n" ; 
  
}




sub get_md5{
  my ($file)  = @_ ;
  
  my $md5bin =  `which md5sum `;
  chomp $md5bin ;
  print "TEST:\n" , $md5bin , "END\n";
  
  # which md5 script, linux versus mac
  
  unless($md5bin){
    $md5bin =  `which md5`;
    chomp $md5bin ;
    unless($md5bin){
      print STDERR "Can't compute md5 sum. Can't find md5 tool.\n";
      exit;
    }
    else{
      $md5bin .= " -r" ;
    }
  }
  
  my $result     = `$md5bin $file` ;  
  my ($md5 , $f) = split " " , $result ;

  unless($md5){
    print STDERR "Can't compute md5 for $file\n" ;
    exit;
  }
  unless($f eq $file){
    print STDERR "Something wrong, computed md5 for wrong file:\n($file\t$f)\n";
    exit;
  }  
  
  print STDERR "MD5 for local files:\t" , $result , "\n" if ($debug);
  return $md5 ;
} 




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