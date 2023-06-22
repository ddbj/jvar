#!/usr/bin/perl5.16

use strict;
use Data::Dumper;
use SNPVCFSubmissionValidator;
use Getopt::Long;

my $usage = "Usage: dbsnp_vcf_sub_validator.pl -file filename.gz -gi_list gi_list_file -skip_dense 1/0 -getseq_path path -genome_fasta path_to_fasta
             (1 - skip density check
              0 - check SNP density)\n";
my $file;
my $gi_list;
my $skip_dense = 0;
my $getseq_path;
my $genome_fasta;
my $seqid_cfg;

GetOptions('file=s' => \$file, 
	   'gi_list=s' => \$gi_list, 
	   'skip_dense' => \$skip_dense,
	   'getseq_path=s' => \$getseq_path,
	   'genome_fasta=s' => \$genome_fasta
    );

if($file eq "") {
    print "$usage";
    exit(1);
}

my $abs_path = `readlink -f $0`;
my $dir_name = `dirname $abs_path`;
chomp $dir_name;
my $vcf_checker = SNPVCFSubmissionValidator->new('assm_gi_path' => "$dir_name/assembly_gi");
my $res_code;
my $res_ref;

($res_code, $res_ref) = $vcf_checker->validate_vcf_submission($file, $gi_list, $skip_dense, $getseq_path, $genome_fasta);
$vcf_checker->print_rpt;
