#!/usr/bin/perl

## This program is distributed under the free software
## licensing model. You have a right to use, modify and
## and redistribute this software in any way you like. 


## This program is implemented by Anton Valouev, Ph.D.
## as a part of QuEST analytical pipeline. If you use
## this software as a part of another software or for publication
## purposes, you must cite the publication anouncing
## QuEST release:

## the citation goes here

## This program is a wrapper that runs generate_peak_profile program
## on the entire genome one contig at a time

use strict;
use warnings;
use diagnostics;

my $usage = qq{
    run_generate_peak_profile_with_param_file.pl
	
    This program is a wrapper that runs the generate_peak_profile
    
    -----------------------
    mandatory parameters:
    -p <params_file>               a file containing parameters calibrate_peak_shift

    -----------------------
    optional parameters:
    -e <exec_path>                 path to the calibrate_peak_shift executable
    -h                             to display this help

};

if(scalar(@ARGV) == 0){
    print $usage;
    exit(0);
}

## mandatory argmuments
my $params_fname = "";
## /mandatory arguments

## setting optional arguments
use Cwd qw(realpath);
my $fullpath = realpath($0);
my @fullpath_fields = split(/\//,$fullpath);
my $exec_path = "";

for(my $i=0; $i<scalar(@fullpath_fields)-1; $i++){
    if($fullpath_fields[$i] ne ""){
	$exec_path = $exec_path."/".$fullpath_fields[$i];
    }
}

$exec_path = $exec_path."/generate_profile";

if( ! -e $exec_path ){
    print "Error in generate profile batch script:\n";
    print "Failed to locate executable $exec_path.\n";
    print "Aborting.\n";
    exit(0);
}

## /setting optional arguments

## reading arguments
while(scalar(@ARGV) > 0){
    my $this_arg = shift @ARGV;    
    if ( $this_arg eq '-h') {die "$usage\n";}
    elsif ( $this_arg eq '-p') {$params_fname = shift @ARGV;}
    elsif ( $this_arg eq '-e') {$exec_path = shift @ARGV;}
    else{ print "Warning: unknown parameter: $this_arg\n"; }
}

my $die_pars_bad = "false";       ## die if parameters are bad
my $bad_par = "";                 ## store bad parameter here

print "\n=====================\n\n";
print "mandatory parameters: \n\n";
print "params_file:      $params_fname\n";
print "exec_path:        $exec_path\n";
if( $params_fname eq ''){ $die_pars_bad = "true"; $bad_par." "."$params_fname"; }
if( $exec_path eq ''){ $die_pars_bad = "true"; $bad_par." "."$exec_path"; }
print "\n=====================\n\n";

if( $die_pars_bad eq "true"){
    print "$usage";
    print "Bad parameters: $bad_par\n";
    exit(0);
}
## /reading arguments

## top-level script
open params_file, "< $params_fname" || die "$params_fname: $\n";
my @params = <params_file>;
close params_file;

#my $QuEST_align_file =     "** missing **";

my $bin_align_path = "** missing **";

my $genome_table_fname =   "** missing **";
my $output_score_path =    "** missing **";

my $peak_shift = "";          # optional
my $peak_shift_source_fname = "";   # optional
my $kde_bandwidth = "";       # optional
my $threads = "";             # optional
my $profile_baseline = 0;    # optional

for(my $i=0; $i<scalar(@params); $i++){
    my $cur_param = $params[$i];
    chomp($cur_param);
    
    my @cur_par_fields = split(/ /, $cur_param);
    if(scalar(@cur_par_fields >= 2)){
	my $cur_par_name = $cur_par_fields[0];
	if ($cur_par_name eq "skip"){
	    exit(0);
	}
	if ($cur_par_name eq "bin_align_path"){
	    $bin_align_path = $cur_par_fields[2];	
	}
	elsif( $cur_par_name eq "genome_table" ){
	    $genome_table_fname= $cur_par_fields[2];
	}
	elsif($cur_par_name eq "output_score_path"){
	    $output_score_path = $cur_par_fields[2];
	}
	elsif($cur_par_name eq "peak_shift"){
	    $peak_shift = $cur_par_fields[2];
	}
	elsif($cur_par_name eq "peak_shift_source_file"){
	    $peak_shift_source_fname = $cur_par_fields[2];
	}
	elsif($cur_par_name eq "kde_bandwidth"){
	    $kde_bandwidth = $cur_par_fields[2];
	}
	elsif($cur_par_name eq "threads"){
	    $threads = $cur_par_fields[2];
	}
	elsif($cur_par_name eq "profile_baseline"){
	    $profile_baseline = $cur_par_fields[2];
	}
	else{
	    if($params[$i] ne ""){
		print "Warning: unrecognized parameter: $cur_par_name";
	    }
	}
    }
}

if($peak_shift eq "" and $peak_shift_source_fname ne ""){
    print "Extracting peak shift value from the $peak_shift_source_fname file\n";
    open peak_shift_source_file, "< $peak_shift_source_fname" || 
	die "Failed to open $peak_shift_source_fname\n";

    while(<peak_shift_source_file>){
	chomp;
	my @cur_fields = split(/ /,$_);
	if($cur_fields[0] eq "peak_shift_estimate:"){
	    $peak_shift = $cur_fields[1];
	}
    }
}

print "Read the following parameters: \n\n";

print "bin_align_path:                    $bin_align_path\n";
print "genome_table:                      $genome_table_fname\n";
print "output_score_path:                 $output_score_path\n";
print "peak_shift:                        $peak_shift\n";                         # optional
print "kde_bandwidth:                     $kde_bandwidth\n";                      # optional
print "threads:                           $threads\n";                            # optional
print "profile_baseline:                  $profile_baseline\n";
print "\n";

my $optional_param_string = "";
if($kde_bandwidth ne ""){
    $optional_param_string = $optional_param_string . " kde_bandwidth=$kde_bandwidth";
}
if($peak_shift ne ""){
    $optional_param_string = $optional_param_string . " peak_shift=$peak_shift";
}
if($threads ne ""){
    $optional_param_string = $optional_param_string . " threads=$threads";
}
if($profile_baseline ne "0"){
    $optional_param_string = $optional_param_string . " profile_baseline=$profile_baseline";
}

## reading genome table

if( ! -e $genome_table_fname ){
    print "Error in generate profile master script: \n";
    print "Failed to locate genome table $genome_table_fname. Aborting.\n";
    exit(0);
}


open genome_table_file, "< $genome_table_fname" || die "$genome_table_fname: $\n";
my @genome_table = <genome_table_file>;

close genome_table_file;

my @contig_names;
my @contig_sizes;
my $contig_counter = 0;

for(my $i=0; $i < scalar(@genome_table); $i++){
    my $cur_contig_entry = $genome_table[$i];
    chomp($cur_contig_entry);
    my @cur_contig_entry_fields = split(/ /, $cur_contig_entry);
    if(scalar(@cur_contig_entry_fields) == 2){
	$contig_names[$contig_counter] = $cur_contig_entry_fields[0];
	$contig_sizes[$contig_counter] = $cur_contig_entry_fields[1];
	$contig_counter++;
    }
}

## /reading genome table



for(my $i=0; $i<scalar(@contig_names); $i++){
    my $cur_contig_name = $contig_names[$i];
    my $cur_contig_size = $contig_sizes[$i];
    my $cur_bin_align_fname = $bin_align_path . "/" . $cur_contig_name . ".align.bin";
    my $system_command = $exec_path . " bin_align_file=$cur_bin_align_fname contig_id=$cur_contig_name contig_size=$cur_contig_size output_score_file=$output_score_path/$cur_contig_name.score" . $optional_param_string;
    print "$system_command\n";
    my $error_code = system("$system_command\n");
    if($error_code != 0){
	print "run_generate_profile_with_param_file.pl: Caught an error message (code $error_code), passing error message to the top script.\n";
	exit(3);
    }
}


