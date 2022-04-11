#!/usr/bin/perl

use JSON;
use Data::Dumper;

my ($cache,$cs_word);
my $level = 1;
my $xp = "l";
my $players = 4;
my $type = "armor";
use constant{
  DATAPATH => "data/processed/"
};

foreach my $arg (@ARGV) {
	if($arg =~ /--l=(\d+)/) { $level = $1; }
  if($arg =~ /--xp=([lmseLMSE])/) { $xp = $1; }
  if($arg =~ /--p=(\d+)/) { $players = $1; }
  if($arg =~ /--t=(.*)/) { $type = $1; }
  if($arg =~ /--cache/) { $cache = 1; }
}

# ----------
# setup
# ----------

$xp = lc $xp;
$xp_word = &get_xp_word($xp);

# get the treasure by encounter table as json
my $te_str = &get_json(DATAPATH."/te.json");
my $te_json = decode_json($te_str);
my @te_arr = @{$te_json};

# select the values from that table and convert to int
my $selected_te = $te_arr[$level-1];
my $selected_price_limit = $selected_te->{$xp_word};
my $selected_price_limit_int = &price_to_int($selected_price_limit);
if($p) {
  $selected_price_limit_int = int($p);
}

# set default aliases and maps
my @maps_arr = ("armor");
my $map_flag = 0;
my %maps_h = map { $_ => 1 } @maps_arr;
if(exists($maps_h{$type})) {
  $map_flag = 1;
}

# get the origin table
my $origin_filepath = DATAPATH."/$type.json";
# check that the origin exists
unless(-e $origin_filepath) {
  print "can't find $origin_filepath\n";
  exit;
}

# ----------
# loot calc
# ----------

my $remaining_price = $selected_price_limit_int;
my @loot;
my $i = 0;
while($remaining_price > 0) {
  last if $i > 10;

  # if you're lookin up a map...
  if($map_flag) {

    # get the map result
    my $selected_row = &get_map_result($origin_filepath);
    my $then = $selected_row->{then};
    # print "picked a row...\n";
    # print Dumper $selected_row;

    # roll in the row based on the price...
    my $loot_table_path = DATAPATH.$selected_row->{name}.".json";
    unless(-e $loot_table_path) {
      print "can't find loot table path $loot_table_path from type $type\n";
    }
    my $selected_loot_str;
    ($selected_loot_str,$remaining_price) = &roll_for_loot($loot_table_path,$remaining_price,$level,$then);
    if($selected_loot_str) {
      # print "remaining price dropped to $remaining_price\n";
      push(@loot, $selected_loot_str);
    }
  }
  else {
    my $loot_table_path = DATAPATH."$type.json";
    unless(-e $loot_table_path) {
      print "can't find loot table path $loot_table_path from type $type\n";
    }
    my $selected_loot_str;
    ($selected_loot_str,$remaining_price) = &roll_for_loot($loot_table_path,$remaining_price,$level);
    if($selected_loot_str) {
      push(@loot, $selected_loot_str);
    }
  }


  $i++;
}

# display
# print Dumper $selected_te;
# print "xp: $xp_word\n";
# print Dumper @loot;
# print "price limit gp: $selected_price_limit\n";
# print "price limit int: $selected_price_limit_int\n";

# ------------------------------
sub get_map_result {
  my ($origin_filepath) = @_;

  my $origin_str = &get_json($origin_filepath);
  my $origin_json = decode_json($origin_str);
  my @origin_arr = @{$origin_json};

  # figure out the weighting breakpoints
  my $total_weight = 0;
  my @breakpoints;
  foreach my $row (@origin_arr) {
    my $breakpoint = $row->{weight} + $total_weight;
    push(@breakpoints,$breakpoint);
    $total_weight += $row->{weight};
  }
  my $roll = &rng($total_weight);

  # get the correct table index from the breakpoints/roll
  my $j = 0;
  foreach my $breakpoint (@breakpoints) {
    last if $roll <= $breakpoint;
    $j++;
  }

  return $origin_arr[$j];

}

# ------------------------------
sub roll_for_loot {
  my ($filepath,$remaining_price,$level,$then_str,$ignore_price) = @_;

  my $loot_str;
  my $table_str = &get_json($filepath);
  my $table_json = decode_json($table_str);
  my @raw_table = @{$table_json};
  my @then = @{$then_str};
  my @level_gated_table;
  my @price_gated_table;
  my $price_for_then = $remaining_price;

  # pull out the pieces we dont care about because they're level gated
  foreach my $row (@raw_table) {
    if($row->{level} <= $level) {
      push(@level_gated_table,$row);
    }
  }
  # do an on the fly int conversion of price
  my $i = 0;
  foreach my $row (@level_gated_table) {
    $row->{int_price} = &price_to_int($row->{price});
    $level_gated_table[$i] = $row;
    $i++;
  }
  unless($ignore_price) {
    # pull out the pieces we dont care about because we're price gated
    foreach my $row (@level_gated_table) {
      if($row->{int_price} <= $remaining_price) {
        push(@price_gated_table,$row);
      }
    }
  }
  unless(scalar @price_gated_table) {
    @price_gated_table = @level_gated_table;
  }

  # print "beginning check price gated...\n";
  # print Dumper @price_gated_table;

  # if there's anything left
  if(scalar @price_gated_table) {
    my @sorted_table = sort { $a->{int_price} <=> $b->{int_price} } @price_gated_table;

    # print "checking sorted...\n";
    # print Dumper @sorted_table;
  
    my $loot_i = 0;
    my $common_count = 0;
    my $core_count = 0;
    my $done;
    while(!$done) {
      last if $loot_i > 0;
      my $selection = &rng((scalar @sorted_table)-1);
      # print "trying selection $selection...\n";
      # print Dumper $sorted_table[$selection];
      my $picked = $sorted_table[$selection];
      my $price = $picked->{int_price};

      my $rarity = $picked->{rarity};
      $rarity = lc $rarity;
      my $source = $picked->{source};
      $source = lc $source;
      my $common_enough = &is_it_enough("common",$rarity,$common_count);
      # my $normal_enough = &is_it_enough("core",$source,$core_count);
      my $normal_enough = 1;
      my $within_budget = &is_it_in_budget($price,$remaining_price);

      if($within_budget && $common_enough && $normal_enough) {
        # print "settled on this one: $price / $remaining_price\n";
        # print Dumper $picked;
        $loot_str = $picked->{name}.": Level ".$picked->{level}.", ".$picked->{price}.", ".$picked->{rarity}."/".$picked->{source};
        $adjusted_price = $remaining_price - int($picked->{int_price});

        $done = 1;
      }
      elsif($within_budget && !$common_enough) {
        # print "found a possible loot but it's not common enough $common_count/2... $price / $remaining_price\n";
        # print Dumper $picked;
        $common_count++;
      }
      elsif($within_budget && !$normal_enough) {
        # print "found a possible loot but it's too weird $core_count/2... $price / $remaining_price\n";
        # print Dumper $picked;
        $core_count++;
      }
      
      $loot_i++;
    }

    if(scalar @then) {
      my @additional_str_clauses;
      my $additional_str_clause;
      foreach my $clause (@then) {
        # print "applying then clause $clause...\n";
        my $bonus_str;
        my $price_after_then;
        my $loot_table_path = DATAPATH."$clause.json";
        unless(-e $loot_table_path) {
          print "can't find loot table path $loot_table_path from type $type\n";
        }
        print "input into then with clause: $clause\n";
        print "loot path=$loot_table_path, price=$price_for_then, level=$level, null str, 1\n\n";
        ($bonus_str,$price_after_then) = &roll_for_loot($loot_table_path,$price_for_then,$level,"",1);
        # print "BONII: $bonus_str //";
        if($bonus_str) {
          push(@additional_str_clauses, $bonus_str);
        }
      }
      if(scalar @additional_str_clauses) {
        foreach my $clause_test (@additional_str_clauses) {
          # print "TESTING: '$clause_test'\t//\t";
        }
        # print "found one, ".scalar @additional_str_clauses." /// \n";
        $additional_str_clause = join(" :: ",@additional_str_clauses);
        $loot_str .= "\n\t // $additional_str_clause //";
      }
    }


    # print "was it done? $done\n";
    # print "did we hit a limit? $loot_i\n";
  }

  print "Generated: $loot_str\n";

  return ($loot_str,$adjusted_price);
}

# ------------------------------
sub is_it_in_budget {
  my ($price,$remaining_price) = @_;
  
  if($price <= $remaining_price) {
    return 1;
  }

  return;
}

# ------------------------------
sub is_it_enough {
  my ($str_to_match,$whole_phrase,$count) = @_;

  if($str_to_match eq "common") {
    if(($count > 0) || ($whole_phrase =~ /$str_to_match/)) {
      return 1;
    }
    return;
  }
  elsif($str_to_match eq "core") {
    if(($count > 0) || ($whole_phrase =~ /$str_to_match/)) {
      return 1;
    }
    return;
  }

  return;
}

# ------------------------------
sub price_to_int {
  my ($price_str) = @_;

  my $int_price = $price_str;
  $int_price =~ s/,//;
  $int_price =~ s/(\d+) gp/$1/;

  return int($int_price);
}

# ------------------------------
sub get_xp_word {
  my ($xp_char) = @_;

  if($xp_char eq "m") { return "moderate"; }
  elsif($xp_char eq "s") { return "severe"; }
  elsif($xp_char eq "e") { return "extreme"; }

  return "low";
}

# ------------------------------
sub rng {
  my ($max) = @_;
  return int(rand($max))+1;
}

# ------------------------------
sub get_json {
  my ($path) = @_;
  my $data;

  open my $fh, "<", $path;
    while(my $row = <$fh>) {
      $data .= $row;
    }
  close $fh;

  return $data;
}