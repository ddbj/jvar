#!/usr/bin/perl5.16

use strict;
use Data::Dumper;
use Getopt::Long;

my $usage = "Usage: GetSeqFromFasta.pl -i input_filename -o output_filename -fasta fasta_file -seqid_cfg sequence_id_config_filename [-check_seq]";

my $input_file;
my $output_file;
my $seqid_cfg_file;
my $check_seq;
my $genome_fasta;
my %fasta;
GetOptions('i=s' => \$input_file, 'o=s' => \$output_file, 'seqid_cfg=s' => \$seqid_cfg_file, 'fasta=s' => \$genome_fasta, 'check_seq' => \$check_seq);
if($input_file eq "" || $output_file eq "" || $seqid_cfg_file eq "" || $genome_fasta eq "") {
    print "$usage";
    exit(1);
}

my %seqid;

open SEQID, "$seqid_cfg_file" or die "Failed to open the sequence id configuration file\n";
while(<SEQID>) {
    chomp;
    my @temp = split(/\t/, $_);
    $temp[0] =~ s/^[[:space:]]+|[[:space:]]+$//g;
    $temp[1] =~ s/^[[:space:]]+|[[:space:]]+$//g;
    $seqid{$temp[1]} = $temp[0];
}

close SEQID;
get_chr_seq(\%fasta, \%seqid);

open INPUT, "< $input_file" or die "Failed to open $input_file for read\n";
open OUTPUT, "> $output_file" or die "Failed to open $output_file for write\n";
while(<INPUT>) {
    chomp;
    my @temp = split(/\t/, $_);
    my $output_str = ".|";
    $output_str = $temp[3] . "|" if $check_seq;
    my $retrieved_seq = substr($fasta{lc $temp[0]}, $temp[1], $temp[2] - $temp[1] + 1);
    my $match_flag = 1;
    $match_flag = 2 if (uc($retrieved_seq) ne uc($temp[3])) && $check_seq;
    print OUTPUT $output_str . $retrieved_seq . "|" . $match_flag . "|" . $temp[0] . "|" . $temp[1] . "|" . $temp[2] . "\n";
}

close OUTPUT;
close INPUT;

sub get_chr_seq {
    my ($fasta_ref, $seqid_cfg_ref) = @_;

    my $open_file = "cat $genome_fasta";
    $open_file = 'z' . $open_file if `file $genome_fasta|grep "gzip compressed"`;

    open FASTA, "$open_file |" or die "Failed to open the genome fasta file\n";

    my $fasta = "";
    my $curr_chr = "";
    while(my $line = <FASTA>) {
	$line =~ s/\r[\n]*/\n/g;#handles DOS line end
	chomp $line;

	if($line =~ />(.+)/) {
	    my $seq_id = $1;
	    $seq_id =~ s/^[[:space:]]+|[[:space:]]+$//g;
	    $fasta_ref->{lc $curr_chr} = $fasta if $curr_chr ne "";
	    $curr_chr = lc $seqid_cfg_ref->{$seq_id};
	    $fasta = "";
	}
	else {
	    $fasta .= $line;
	}
    }
    $fasta_ref->{$curr_chr} = $fasta;
    close FASTA;
}
