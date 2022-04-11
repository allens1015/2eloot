#!/usr/bin/perl
#Author: gr8_Adakron.
#--------------------- Perl Packages --------------------
use strict;
use warnings;
use JSON;
use Text::CSV;

#-------------------- Globaling Variables --------------------
my $flag_header = 1;
my %hash;
my $input_file = $ARGV[0] or die "Need to give 1st argument as input.CSV file on the command line\n";
my $output_file = $ARGV[1] or die "Need to give 2nd argument as output.JSON file on the command line\n";
my $file = $input_file;
my $csv = Text::CSV->new ({
  binary    => 1,
  auto_diag => 1,
  sep_char  => ','    # not really needed as this is the default
});
 
#--------------------- Reading CSV --------------------------
my $sum = 0;
my @headers; 
open(my $data, '<:encoding(utf8)', $file) or die "Could not open '$file' $!\n";
while (my $fields = $csv->getline( $data )) {
  #$sum += $fields->[2];
  my @coloumns =();
  if($flag_header == 1){
  foreach(@{ $fields }) {
        my $new = $_;
        push(@headers, $new);
      }
     
  }
  else{
      foreach(@{ $fields }) {
        my $new = $_;
        push(@coloumns, $new);
      }

    for my $iteration (0..$#coloumns){
      my $key  = $headers[$iteration];
      my $data = $coloumns[$iteration];
      $hash{$key} = $data;
    }
  }
  if($flag_header>1){
    my $json = encode_json \%hash;
    #print("$json\n");
    my $file_location = $output_file;
    open my $o_file, '>>', $file_location or die $!;
    print $o_file "$json\n";
    close $o_file;
  }
  
  $flag_header +=1;
}
close $data;
print(">>Ended");
print("\nTotal rows Transformed : $flag_header");
