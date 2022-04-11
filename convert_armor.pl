#!/usr/bin/perl

use XML::LibXML;
use Data::Dumper;
use JSON;

# my $input_file = $ARGV[0] or die "Need to give 1st argument as input.CSV file on the command line\n";
# $input_file =~ /(.*)\.html/;
# $input_file = "data/html_table/$input_file";
my $output_file = $1.".json";

foreach my $file (glob("data/html_table/armor_base_armor.html")) {
  my @data = &get_table_data($file);
  $file =~ /(.*).html/;
  my $output_file = $1.".json";
  $output_file =~ s/html_table/processed/;

  # print Dumper \@data;
  my $json = encode_json \@data;
  # print("$json\n");
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
  my @data_table;
  # name and links
  # pfs
  # category
  # source
  # rarity
  # traits
  # level
  # price
  # dex
  # str
  # bulk
  my $source = XML::LibXML->load_xml(location => $input_file_local );
  
  foreach my $tbody ($source->findnodes("//tbody")) {
    # print Dumper $source->toString();
    foreach my $tr ($source->findnodes("//tr")) {
      my %row;
      my $i = 0;
      foreach my $td ($tr->findnodes("./td")) {
        if($i eq 0) {
          my @as = $td->findnodes("./span/u/a");
          my $a = $as[0];
          $row{name} = $a->textContent;
          $row{link} = "https://2e.aonprd.com/".$a->getAttribute("href");
        }
        if($i eq 2) {
          my @categories = $td->findnodes("./span/u/a");
          my $hash_data = "-";
          my $category = $categories[0];
          if($category) { $hash_data = $category->textContent; }
          $row{category} = $hash_data;
        }
        if($i eq 3) {
          my @sources = $td->findnodes("./span/u/a");
          my $hash_data = "-";
          my $source = $sources[0];
          if($source) { $hash_data = $source->textContent; }
          $row{source} = $hash_data;
        }
        if($i eq 4) {
          my @rarities = $td->findnodes("./span/u/a");
          my $hash_data = "-";
          my $rarity = $rarities[0];
          if($rarity) { $hash_data = $rarity->textContent; }
          $row{rarity} = $hash_data;
        }
        if($i eq 6) {
          my @levels = $td->findnodes("./span");
          my $level = $levels[0];
          my $hash_data = 0;
          if($level) { $hash_data = $level->textContent; }
          $row{level} = $hash_data;
        }
        if($i eq 7) {
          my @prices = $td->findnodes("./span");
          my $price = $prices[0];
          my $hash_data = 0;
          if($price) { $hash_data = $price->textContent; }
          if($hash_data !~ /^\d/) { $hash_data = 0; }
          $row{price} = $hash_data;
        }
        $i++;
      }
      push(@data_table,\%row);
    }
  }

  return @data_table;
}