#!/usr/bin/perl

use XML::LibXML;
use Data::Dumper;
use JSON;

# my $input_file = $ARGV[0] or die "Need to give 1st argument as input.CSV file on the command line\n";
# $input_file =~ /(.*)\.html/;
# $input_file = "data/html_table/$input_file";
my $output_file = $1.".json";

foreach my $file (glob("data/html_table/te.html")) {
  my @data = &get_table_data($file);
  $file =~ /(.*).html/;
  my $output_file = $1.".json";
  $output_file =~ s/html_table/processed/;

  # print Dumper \@data;
  my $json = encode_json \@data;
  print("$json\n");
    my $file_location = $output_file;
    # print $output_file."\n";
    open my $o_file, '>>', $file_location or die $!;
    print $o_file "$json\n";
    close $o_file;
}
# print Dumper @files;

# my @data = &get_table_data($input_file);
# print Dumper @data;

# ------------------------
sub get_table_data {
  my ($input_file_local) = @_;
  # print $input_file_local;
  my @data_table;
  my @row_keys = ("level","total","low","moderate","severe","extreme","extra");
  # level
  # total per level
  # low
  # moderate
  # severe
  # extreme
  # extra
  my $source = XML::LibXML->load_xml(location => $input_file_local );
  
  foreach my $tbody ($source->findnodes("//tbody")) {
    # print Dumper $source->toString();
    foreach my $tr ($source->findnodes("//tr")) {
      my %row;
      my $i = 0;
      foreach my $td ($tr->findnodes("./td")) {
        # print $row_keys[$i]."\n";
        $row{$row_keys[$i]} = $td->textContent;
        $i++;
      }
      push(@data_table,\%row);
    }
  }

  return \@data_table;
}