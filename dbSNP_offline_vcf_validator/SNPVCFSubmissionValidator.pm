# ===========================================================================
#
#                            PUBLIC DOMAIN NOTICE
#               National Center for Biotechnology Information
#
#  This software/database is a "United States Government Work" under the
#  terms of the United States Copyright Act.  It was written as part of
#  the author's official duties as a United States Government employee and
#  thus cannot be copyrighted.  This software/database is freely available
#  to the public for use. The National Library of Medicine and the U.S.
#  Government have not placed any restriction on its use or reproduction.
#
#  Although all reasonable efforts have been taken to ensure the accuracy
#  and reliability of the software and data, the NLM and the U.S.
#  Government do not and cannot warrant the performance or results that
#  may be obtained by using this software or data. The NLM and the U.S.
#  Government disclaim all warranties, express or implied, including
#  warranties of performance, merchantability or fitness for any particular
#  purpose.
#
# ===========================================================================
#
# Authors:  Hua Zhang
#
# File Description:
#   Validate dbSNP vcf submission file
#

package SNPVCFSubmissionValidator;
# $Id: SNPVCFSubmissionValidator.pm 5358 2019-01-29 12:48:23Z zhahua $

use strict;
use ValidateVCFRefAllele;
use GetAssGiFromGencoll;
use Util;
use LWP::Simple;
use XML::XPath;
use XML::XPath::XMLParser;
use File::Basename;
use Data::Dumper;

sub new {
    my $class = shift;
    my %param = @_;
    return undef if $param{assm_gi_path} eq '';

    my $self = {};
    bless($self, $class);
    $self->{assm_gi_path} = $param{'assm_gi_path'};	
    
    $self->{mode} = $param{'mode'};
    my %ref_assembly;
    $self->{ref_assembly} = \%ref_assembly;

    my %chr_gi;
    $self->{chr_gi} = \%chr_gi;
    my %gi_chr;
    $self->{gi_chr} = \%gi_chr;
    my %chr_size;
    $self->{chr_size} = \%chr_size;
    $self->{to_cron} = 0;
    $self->{submission_file} = "";
    $self->{submission_file_error} = "";

    my %vrt;
    $self->{VRT} = \%vrt;
    $self->{VRT}->{1}->{vrt_str} = 'SNV';
    $self->{VRT}->{1}->{counter} = 0;
    $self->{VRT}->{2}->{vrt_str} = 'DIV';
    $self->{VRT}->{2}->{counter} = 0;
    $self->{VRT}->{3}->{vrt_str} = 'HETEROZYGOUS';
    $self->{VRT}->{3}->{counter} = 0;
    $self->{VRT}->{4}->{vrt_str} = 'STR';
    $self->{VRT}->{4}->{counter} = 0;
    $self->{VRT}->{5}->{vrt_str} = 'NAMED';
    $self->{VRT}->{5}->{counter} = 0;
    $self->{VRT}->{6}->{vrt_str} = 'NO VARIATION';
    $self->{VRT}->{6}->{counter} = 0;
    $self->{VRT}->{7}->{vrt_str} = 'MIXED';
    $self->{VRT}->{7}->{counter} = 0;
    $self->{VRT}->{8}->{vrt_str} = 'MNV';
    $self->{VRT}->{8}->{counter} = 0;

    my %filter;
    my %result;
    $result{FILTER} = \%filter;
    $result{'content_error_flag'} = 0;
    $result{'content_warning_flag'} = 0;
    $result{'header_error_flag'} = 0;
    $result{'header_warning_flag'} = 0;
    $result{'invalid_reference_genome'} = 0;
    $result{'invalid_vcf_file'} = 0;
    $result{'no_sequence_accessions'} = 0;
    $result{'sequence_retrieve_failure'} = 0;
    $self->{result} = \%result;
    $self->{result}->{submission_type} = 'Variation';#submission type default to variations

    #submission header errors
    $self->{result}->{HEADER_ERROR}->{ERR_TAG_MISSING}->{counter} = 0;
    $self->{result}->{HEADER_ERROR}->{ERR_TAG_MISSING}->{tags} = ();
    $self->{result}->{HEADER_ERROR}->{ERR_TAG_MISSING}->{err_str} = "vcf meta tag missing";
    $self->{result}->{HEADER_ERROR}->{ERR_TAG_MISSING}->{fix} = "provide missing meta tags";
    $self->{result}->{HEADER_ERROR}->{ERR_TAG_DUPLICATION}->{counter} = 0;
    $self->{result}->{HEADER_ERROR}->{ERR_TAG_DUPLICATION}->{tags} = ();
    $self->{result}->{HEADER_ERROR}->{ERR_TAG_DUPLICATION}->{err_str} = "duplicated vcf meta tags";
    $self->{result}->{HEADER_ERROR}->{ERR_TAG_DUPLICATION}->{fix} = "remove duplicated meta tags";
    $self->{result}->{HEADER_ERROR}->{ERR_INVALID_REF_ASSEMBLY}->{counter} = 0;
    $self->{result}->{HEADER_ERROR}->{ERR_INVALID_REF_ASSEMBLY}->{tags} = ();
    $self->{result}->{HEADER_ERROR}->{ERR_INVALID_REF_ASSEMBLY}->{err_str} = "invalid reference genome";
    $self->{result}->{HEADER_ERROR}->{ERR_INVALID_REF_ASSEMBLY}->{fix} = "Reference assembly should be in GC[F/A]_xxxxxxxxxx.xx format";
    $self->{result}->{HEADER_ERROR}->{ERR_COLUMN_MISSING}->{counter} = 0;
    $self->{result}->{HEADER_ERROR}->{ERR_COLUMN_MISSING}->{tags} = ();
    $self->{result}->{HEADER_ERROR}->{ERR_COLUMN_MISSING}->{err_str} = "missing column";
    $self->{result}->{HEADER_ERROR}->{ERR_COLUMN_MISSING}->{fix} = "provide missing column, tab delimited";
    $self->{result}->{HEADER_ERROR}->{ERR_COLUMN_EXTRA_SPACE_BEFORE}->{counter} = 0;
    $self->{result}->{HEADER_ERROR}->{ERR_COLUMN_EXTRA_SPACE_BEFORE}->{tags} = ();
    $self->{result}->{HEADER_ERROR}->{ERR_COLUMN_EXTRA_SPACE_BEFORE}->{err_str} = "white space characters before column header";
    $self->{result}->{HEADER_ERROR}->{ERR_COLUMN_EXTRA_SPACE_BEFORE}->{fix} = "remove space characters before specified column headers";
    $self->{result}->{HEADER_ERROR}->{ERR_COLUMN_EXTRA_SPACE_AFTER}->{counter} = 0;
    $self->{result}->{HEADER_ERROR}->{ERR_COLUMN_EXTRA_SPACE_AFTER}->{tags} = ();
    $self->{result}->{HEADER_ERROR}->{ERR_COLUMN_EXTRA_SPACE_AFTER}->{err_str} = "white space characters after column header";
    $self->{result}->{HEADER_ERROR}->{ERR_COLUMN_EXTRA_SPACE_AFTER}->{fix} = "remove space characters after specified column headers";

    #submission header warnings
    $self->{result}->{HEADER_WARN}->{INVALID_BIOPROJ}->{counter} = 0;
    $self->{result}->{HEADER_WARN}->{INVALID_BIOPROJ}->{ids} = "";
    $self->{result}->{HEADER_WARN}->{INVALID_BIOPROJ}->{err_str} = "invalid bioproject ID";
    $self->{result}->{HEADER_WARN}->{INVALID_BIOPROJ}->{fix} = "verify bioproject IDs are valid";
    $self->{result}->{HEADER_WARN}->{INVALID_BIOSAMPLES}->{counter} = 0;
    $self->{result}->{HEADER_WARN}->{INVALID_BIOSAMPLES}->{ids} = "";
    $self->{result}->{HEADER_WARN}->{INVALID_BIOSAMPLES}->{err_str} = "invalid biosample ID";
    $self->{result}->{HEADER_WARN}->{INVALID_BIOSAMPLES}->{fix} = "verify biosample IDs are valid";

    #submission content warnings
    $self->{result}->{CONTENT_WARN}->{ERR_SNP_TOO_DENSE}->{counter} = 0;
    $self->{result}->{CONTENT_WARN}->{ERR_SNP_TOO_DENSE}->{err_str} = "Region contains too many SNPs";
    $self->{result}->{CONTENT_WARN}->{ERR_SNP_TOO_DENSE}->{fix} = "verify these regions are legit";

    #submission content errors
    $self->{result}->{ERR}->{ERR_POSITION}->{counter} = 0;
    $self->{result}->{ERR}->{ERR_POSITION}->{err_str} = "Invalid position";
    $self->{result}->{ERR}->{ERR_POSITION}->{fix} = "positions should be numbers";
    $self->{result}->{ERR}->{ERR_LONG_ID}->{counter} = 0;
    $self->{result}->{ERR}->{ERR_LONG_ID}->{err_str} = "ID longer than 64 characters";
    $self->{result}->{ERR}->{ERR_LONG_ID}->{fix} = "provide unique IDs shorter than 64 characters";
    $self->{result}->{ERR}->{ERR_NO_ID}->{counter} = 0;
    $self->{result}->{ERR}->{ERR_NO_ID}->{err_str} = "ID not set";
    $self->{result}->{ERR}->{ERR_NO_ID}->{fix} = "provide unique IDs shorter than 64 characters";
    $self->{result}->{ERR}->{ERR_DUP_SITES}->{counter} = 0;
    $self->{result}->{ERR}->{ERR_DUP_SITES}->{err_str} = "Duplicated sites";
    $self->{result}->{ERR}->{ERR_DUP_SITES}->{fix} = "remove duplicated sites";
    $self->{result}->{ERR}->{ERR_REF_INVALID}->{counter} = 0;
    $self->{result}->{ERR}->{ERR_REF_INVALID}->{err_str} = "Invalid ref allele";
    $self->{result}->{ERR}->{ERR_REF_INVALID}->{fix} = "remove non-ATGC base";
    $self->{result}->{ERR}->{ERR_REF_MISSING}->{counter} = 0;
    $self->{result}->{ERR}->{ERR_REF_MISSING}->{err_str} = "ref allele missing";
    $self->{result}->{ERR}->{ERR_REF_MISSING}->{fix} = "provide ref allele";
    $self->{result}->{ERR}->{ERR_REF_LEN}->{counter} = 0;
    $self->{result}->{ERR}->{ERR_REF_LEN}->{err_str} = "Ref allele longer than 50 nt";
    $self->{result}->{ERR}->{ERR_REF_LEN}->{fix} = "remove and submit to dbVar";
    $self->{result}->{ERR}->{ERR_REF_MISMATCH}->{counter} = 0;
    $self->{result}->{ERR}->{ERR_REF_MISMATCH}->{err_str} = "Ref allele mismatch";
    $self->{result}->{ERR}->{ERR_REF_MISMATCH}->{fix} = "need to match the reference genome on the FORWARD orientation";
    $self->{result}->{ERR}->{ERR_ALT_INVALID}->{counter} = 0;
    $self->{result}->{ERR}->{ERR_ALT_INVALID}->{err_str} = "Invalid alt allele";
    $self->{result}->{ERR}->{ERR_ALT_INVALID}->{fix} = "remove non-ATGC base";
    $self->{result}->{ERR}->{ERR_ALT_MISSING}->{counter} = 0;
    $self->{result}->{ERR}->{ERR_ALT_MISSING}->{err_str} = "alt allele missing";
    $self->{result}->{ERR}->{ERR_ALT_MISSING}->{fix} = "provide alt alleles";
    $self->{result}->{ERR}->{ERR_ALT_LEN}->{counter} = 0;
    $self->{result}->{ERR}->{ERR_ALT_LEN}->{err_str} = "Alt allele longer than 50 nt";
    $self->{result}->{ERR}->{ERR_ALT_LEN}->{fix} = "remove and submit to dbVar";
    $self->{result}->{ERR}->{ERR_CHR}->{counter} = 0;
    $self->{result}->{ERR}->{ERR_CHR}->{err_str} = "Invalid chromosome name";
    $self->{result}->{ERR}->{ERR_CHR}->{fix} = "chromosome name need to match the reference assembly";
    $self->{result}->{ERR}->{ERR_INVALID_VRT}->{counter} = 0;
    $self->{result}->{ERR}->{ERR_INVALID_VRT}->{err_str} = "Variation type is not in the defined set";
    $self->{result}->{ERR}->{ERR_INVALID_VRT}->{fix} = "provide variation type in the defined set";
    $self->{result}->{ERR}->{ERR_VRT_NOT_DEFINED}->{counter} = 0;
    $self->{result}->{ERR}->{ERR_VRT_NOT_DEFINED}->{err_str} = "Variation type not given";
    $self->{result}->{ERR}->{ERR_VRT_NOT_DEFINED}->{fix} = "provide variation type";
    $self->{result}->{ERR}->{ERR_VARI_LENGTH_INDEL}->{counter} = 0;
    $self->{result}->{ERR}->{ERR_VARI_LENGTH_INDEL}->{err_str} = "Indels with variable length alleles";
    $self->{result}->{ERR}->{ERR_VARI_LENGTH_INDEL}->{fix} = "break up into separate rows";
    $self->{result}->{ERR}->{ERR_DUP_ID}->{counter} = 0;
    $self->{result}->{ERR}->{ERR_DUP_ID}->{err_str} = "Duplicated IDs";
    $self->{result}->{ERR}->{ERR_DUP_ID}->{fix} = "IDs should be unqiue";
    $self->{result}->{ERR}->{ERR_IDENTICAL_REF_ALT}->{counter} = 0;
    $self->{result}->{ERR}->{ERR_IDENTICAL_REF_ALT}->{err_str} = "Reference allele and alternative alleles are the same";
    $self->{result}->{ERR}->{ERR_IDENTICAL_REF_ALT}->{fix} = "Reference allele and alternative alleles should not be the same";
    $self->{result}->{ERR}->{ERR_INVALID_INDEL_MNV_FMT}->{counter} = 0;
    $self->{result}->{ERR}->{ERR_INVALID_INDEL_MNV_FMT}->{err_str} = "Ref and alt alleles donnot have common leading base";
    $self->{result}->{ERR}->{ERR_INVALID_INDEL_MNV_FMT}->{fix} = "refer to dbSNP VCF submission to format indels";
    $self->{result}->{ERR}->{ERR_WRONG_VRT}->{counter} = 0;
    $self->{result}->{ERR}->{ERR_WRONG_VRT}->{err_str} = "VRT type is wrong";
    $self->{result}->{ERR}->{ERR_WRONG_VRT}->{fix} = "refer to dbSNP VCF submission to correctly set VRT type";
    $self->{result}->{ERR}->{ERR_SPACE_REF}->{counter} = 0;
    $self->{result}->{ERR}->{ERR_SPACE_REF}->{err_str} = "Extra space before/after ref. allele";
    $self->{result}->{ERR}->{ERR_SPACE_REF}->{fix} = "remove extra space from ref allele";
    $self->{result}->{ERR}->{ERR_SPACE_ALT}->{counter} = 0;
    $self->{result}->{ERR}->{ERR_SPACE_ALT}->{err_str} = "Extra space before/after alt. allele";
    $self->{result}->{ERR}->{ERR_SPACE_ALT}->{fix} = "remove extra space from ref allele";
    $self->{result}->{ERR}->{ERR_CHR_NOT_GROUPED}->{counter} = 0;
    $self->{result}->{ERR}->{ERR_CHR_NOT_GROUPED}->{err_str} = "Data on the same chromosome are not grouped together";
    $self->{result}->{ERR}->{ERR_CHR_NOT_GROUPED}->{fix} = "group data from the same chromosome";
    $self->{result}->{ERR}->{ERR_POS_NOT_SORTED}->{counter} = 0;
    $self->{result}->{ERR}->{ERR_POS_NOT_SORTED}->{err_str} = "Data are not sorted base on positions";
    $self->{result}->{ERR}->{ERR_POS_NOT_SORTED}->{fix} = "sort data base on their positions";
    $self->{result}->{ERR}->{ERR_LINE_EMPTY}->{counter} = 0;
    $self->{result}->{ERR}->{ERR_LINE_EMPTY}->{err_str} = "Line is empty";
    $self->{result}->{ERR}->{ERR_LINE_EMPTY}->{fix} = "remove the empty line";
    $self->{result}->{ERR}->{ERR_CHR_POS_OUT_OF_BOUND}->{counter} = 0;
    $self->{result}->{ERR}->{ERR_CHR_POS_OUT_OF_BOUND}->{err_str} = "Chromosome position is larger than chromosome size";
    $self->{result}->{ERR}->{ERR_CHR_POS_OUT_OF_BOUND}->{fix} = "check if the position is correct";

    return $self;
}

sub check_header {
    my ($self, $handle, $genome_fasta, $gi_list, $check_popfreq_vcf, $ref_assm) = @_;
    my %mandate_header = (
        'fileformat' => 0,
        'handle' => 0,
        'batch' => 0,
        'reference' => 0,
        );
    
    if($check_popfreq_vcf) {
	%mandate_header = (
	    'fileformat' => 0,
        );	
    }
    
    my %vcf_columns = (
        '#CHROM' => 0,
        'POS' => 0,
        'ID' => 0,
        'REF' => 0,
        'ALT' => 0,
        'QUAL' => 0,
        'FILTER' => 0,
        'INFO' => 0,
        );

    if($ref_assm) {
	$ref_assm =~ /(.+)\.([[:digit:]]+)/;
	$self->{ref_assembly}->{asm_acc} = $1;
	$self->{ref_assembly}->{asm_version} = $2;
    }
    
    my $line_cnt = 0;
    while(my $line = <$handle>) {
	$line =~ s/\r[\n]*/\n/g;
        chomp $line;
	$line =~ s/"//g;#deal with double quotes added by Excel text save out
	$line =~ s/^[[:space:]]+|[[:space:]]+$//g;
	$line_cnt++;
        $line =~ /^##(.+)=(.*)/;
	if($line_cnt == 1 && $1 ne 'fileformat') {
	    $self->{result}->{header_error_flag} = 1;
	    $self->{result}->{invalid_vcf_file} = 1;
	    return;
	}

	if(($1 eq 'reference') && $genome_fasta) {
	    $mandate_header{$1}++;
	}
	elsif(defined $mandate_header{$1} && ($2 ne '')) {
	    $mandate_header{$1}++;
	}

	if($1 eq 'bioproject_id') {
	    if(validate_bioproject_id($self, $2)) {
		$self->{result}->{header_warning_flag} = 1;
		$self->{result}->{HEADER_WARN}->{INVALID_BIOPROJ}->{counter}++;
		$self->{result}->{HEADER_WARN}->{INVALID_BIOPROJ}->{ids} = $2;
	    }
	}

	if($1 eq 'biosample_id') {
	    my $invalid_id = validate_biosample_id($self, $2);

	    if(length($invalid_id)) {
		$self->{result}->{header_warning_flag} = 1;
		my @temp = split(/,/, $invalid_id);
		$self->{result}->{HEADER_WARN}->{INVALID_BIOSAMPLES}->{counter} = @temp;
		$self->{result}->{HEADER_WARN}->{INVALID_BIOSAMPLES}->{ids} = $invalid_id;
	    }
	}

        if($line =~ /##reference=[[:space:]]*(.+)[[:space:]]*/ && !$ref_assm) {
	    my $acc = $1;
	    $acc =~ /(.+)\.([[:digit:]]+)/;
	    $self->{ref_assembly}->{asm_acc} = $1;
	    $self->{ref_assembly}->{asm_version} = $2;

        }

        if($line =~ /^#CHROM/i) {
            my @columns = split(/\t/, $line);

            $self->{result}->{submission_type} = 'Variation and Genotype/Frequency' if(@columns > 8);
            for(my $i = 0; $i < @columns; $i++) {
		if($columns[$i] =~ s/^[[:space:]]+//g) {#user may put spaces
		    $columns[$i] =~ s/^[[:space:]]+//g;
                    $self->{result}->{header_error_flag} = 1;
		    $self->{result}->{HEADER_ERROR}->{ERR_COLUMN_EXTRA_SPACE_BEFORE}->{counter}++;
		    push @{$self->{result}->{HEADER_ERROR}->{ERR_COLUMN_EXTRA_SPACE_BEFORE}->{tags}}, $columns[$i];
		}
		if($columns[$i] =~ s/[[:space:]]+$//g) {
		    $columns[$i] =~ s/[[:space:]]+$//g;
                    $self->{result}->{header_error_flag} = 1;
		    $self->{result}->{HEADER_ERROR}->{ERR_COLUMN_EXTRA_SPACE_AFTER}->{counter}++;
		    push @{$self->{result}->{HEADER_ERROR}->{ERR_COLUMN_EXTRA_SPACE_AFTER}->{tags}}, $columns[$i];
		}
                $vcf_columns{$columns[$i]} = 1 if defined $vcf_columns{$columns[$i]};
            }
            foreach my $key (keys %vcf_columns) {
                if($vcf_columns{$key} == 0) {
                    $self->{result}->{header_error_flag} = 1;
		    $self->{result}->{HEADER_ERROR}->{ERR_COLUMN_MISSING}->{counter}++;
		    push @{$self->{result}->{HEADER_ERROR}->{ERR_COLUMN_MISSING}->{tags}}, $key;
                }
            }
            last;
        }
    }

    if(!$genome_fasta && ((length($self->{ref_assembly}->{asm_acc}) == 13 && !($self->{ref_assembly}->{asm_acc} =~ /GC[A|F]_[[:digit:]]{9}/)) ||
			  length($self->{ref_assembly}->{asm_acc}) != 13 ||
			  length($self->{ref_assembly}->{asm_version} == 0))) {
	$self->{result}->{'invalid_reference_genome'} = 1;
	$self->{result}->{header_error_flag} = 1;
	$self->{result}->{HEADER_ERROR}->{ERR_INVALID_REF_ASSEMBLY}->{counter} = 1;
	push @{$self->{result}->{HEADER_ERROR}->{ERR_INVALID_REF_ASSEMBLY}->{tags}}, $self->{ref_assembly}->{asm_acc};
    }
    
    foreach my $key (keys %mandate_header) {
        $self->{result}->{header_error_flag} = 1 if $mandate_header{$key} != 1;
	if($mandate_header{$key} == 0) {
	    $self->{result}->{HEADER_ERROR}->{ERR_TAG_MISSING}->{counter}++;
	    push @{$self->{result}->{HEADER_ERROR}->{ERR_TAG_MISSING}->{tags}}, $key;
	}

	if($mandate_header{$key} > 1) {
	    $self->{result}->{HEADER_ERROR}->{ERR_TAG_DUPLICATION}->{counter}++;
	    push @{$self->{result}->{HEADER_ERROR}->{ERR_TAG_DUPLICATION}->{tags}}, $key;
	}
    }

    if((! grep(/reference/, @{$self->{result}->{HEADER_ERROR}->{ERR_TAG_DUPLICATION}->{tags}})) && 
       (! grep(/reference/, @{$self->{result}->{HEADER_ERROR}->{ERR_TAG_MISSING}->{tags}})) &&
       !defined $self->{result}->{HEADER_ERROR}->{ERR_INVALID_REF_ASSEMBLY}->{tags}) {

	get_chr_gi($self, $gi_list);
	get_custom_chr_size($self, $genome_fasta);

	if(!keys %{$self->{chr_gi}}) {
	    $self->{result}->{header_error_flag} = 1;
	    $self->{result}->{'no_sequence_accessions'} = 1;
	}
    }
}

sub validate_vcf_submission {
    my ($self, $file, $gi_list, $skip_dense_check, $tool_path, $genome_fasta, $check_popfreq_vcf, $ref_assm) = @_;

    convert_if_mac($file);
    $self->{submission_file} = $file;
    $self->{submission_file_error} = $file . '.error';
    $self->{use_custom_genome} = 1 if $genome_fasta ne '';
    my $open_file = "cat $file";
    $open_file = 'z' . $open_file if `file $file|grep "gzip compressed"`;
    open my $vcf_handle, "$open_file |" or die "Failed to open the VCF file\n";

    check_header($self, $vcf_handle, $genome_fasta, $gi_list, $check_popfreq_vcf, $ref_assm);
    close $vcf_handle;

    if($self->{result}->{invalid_vcf_file}) {
	$self->{submission_file_error} = "";
	return ($self->{result}->{header_error_flag}, $self->{result});
    }
    elsif(($self->{result}->{'invalid_reference_genome'} && !(defined $gi_list)) ||
	  $self->{result}->{'no_sequence_accessions'} ||
	  grep(/reference/, @{$self->{result}->{HEADER_ERROR}->{ERR_TAG_DUPLICATION}->{tags}}) ||
 	  grep(/reference/, @{$self->{result}->{HEADER_ERROR}->{ERR_TAG_MISSING}->{tags}})) {
	make_err_file($self);
	return ($self->{result}->{header_error_flag}, $self->{result});
    }

    validate_format($self, $file, $check_popfreq_vcf);

    if(!($self->{result}->{content_error_flag} == 1 || $self->{result}->{header_error_flag} == 1)) {
        validate_content($self, $file, $skip_dense_check, $tool_path, $genome_fasta, $gi_list);
    }
    elsif(($self->{result}->{header_error_flag} == 1 || $self->{result}->{header_warning_flag} == 1) && $self->{result}->{content_error_flag} == 0) {
	make_err_file($self);
    }

    return ($self->{result}->{content_error_flag} | $self->{result}->{header_error_flag}, $self->{result});
}

sub validate_format {
    my ($self, $file, $check_popfreq_vcf) = @_;

    my $open_file = "cat $file";
    $open_file = 'z' . $open_file if `file $file|grep "gzip compressed"`;
    open my $vcf_handle, "$open_file |" or die "Failed to open the VCF file\n";

    my $temp_err_file = `mktemp`;
    chomp $temp_err_file;
    open(ERROR, ">>$temp_err_file");

    my $line;
    my %sites;
    my %loc_snp_ids;
    my $curr_chr = '-1';
    my $previous_pos = 0;
    my %chr_clusters;
    $chr_clusters{'last'} = 0;
    my $passed_vcf_meta = 0;
    while ($line = <$vcf_handle>) {
	$line =~ s/"//g;#deal with double quotes added by Excel text save out
        if($line =~ /^#.+/) {#consume all header lines
	    $passed_vcf_meta = 1 if $line =~ /^#CHROM/i;
	    next;
	}
	next if !$passed_vcf_meta;

        my $current_line_error = 0;
	my $current_line_warning = 0;
	$line =~ s/\r[\n]*/\n/g;
	$line =~ s/^[[:space:]]+|[[:space:]]+$//g;
	if(length($line) == 0) {
            $current_line_error = 1;
            $self->{result}->{ERR}->{ERR_LINE_EMPTY}->{counter}++;
            $line .= ";ERR_LINE_EMPTY=Line is empty";
            $self->{result}->{content_error_flag} = 1;
            print ERROR $line . "\n";
	    next;
	}

        chomp $line;
        $line =~ /VRT=([[:digit:]]+)\t?/i;

        my $vrt = $1;
	if(defined $vrt) {
	    if(defined $self->{VRT}->{$vrt}) {
		$self->{VRT}->{$vrt}->{counter}++;
	    }
	    else {
		$current_line_error = 1;
		$self->{result}->{ERR}->{ERR_INVALID_VRT}->{counter}++;
		$line .= ";ERR_INVALID_VRT=Variation type is not in the defined set";
	    }
	}
	else {
	    if(!$check_popfreq_vcf) {
		$current_line_error = 1;	    
		$self->{result}->{ERR}->{ERR_VRT_NOT_DEFINED}->{counter}++;
		$line .= ";ERR_VRT_NOT_DEFINED=variation type not defined";
	    }
	}

        my @fields = split('\t', $line);
	$fields[0] =~ s/chr/chr/i;
	$fields[1] =~ s/^[[:space:]]+//g;
	$fields[1] =~ s/[[:space:]]+$//g;
        if(! ($fields[1] =~ /^[[:digit:]]+$/)) {
            $current_line_error = 1;
            $self->{result}->{ERR}->{ERR_POSITION}->{counter}++;
            $line .= ";ERR_POSITION=positions should be numbers";
        }
        elsif(defined $self->{chr_size}->{lc $fields[0]}) {#check if position is out of bound
	    if($fields[1] > $self->{chr_size}->{lc $fields[0]}) {
		$current_line_error = 1;
		$self->{result}->{ERR}->{ERR_CHR_POS_OUT_OF_BOUND}->{counter}++;
		$line .= ";ERR_CHR_POS_OUT_OF_BOUND=Chromosome position is larger then chromosome size";
	    }
        }

	if(!is_chr_grouped($self, \%chr_clusters, $fields[0])) {
	    $current_line_error = 1;
	    $self->{result}->{ERR}->{ERR_CHR_NOT_GROUPED}->{counter}++;
	    $line .= ";ERR_CHR_NOT_GROUPED=Data on the same chromosome are not grouped together";
	}

	if($curr_chr ne $fields[0]) {
	    $curr_chr = $fields[0];
	    $previous_pos = $fields[1];
	}
	else {
	    if($fields[1] =~ /^[[:digit:]]+$/ 
	       && $previous_pos =~ /^[[:digit:]]+$/
		&& $fields[1] < $previous_pos) {
		$current_line_error = 1;
		$self->{result}->{ERR}->{ERR_POS_NOT_SORTED}->{counter}++;
		$line .= ";ERR_POS_NOT_SORTED=Data are not sorted base on positions";
	    }
	    $previous_pos = $fields[1];
	}

        if(not defined $self->{chr_gi}->{lc $fields[0]}) {
            $current_line_error = 1;
            $self->{result}->{ERR}->{ERR_CHR}->{counter}++;
            $line .= ";ERR_CHR=invalid chromosome name";
        }
	
        #check for variable length indels
        my @alleles = split(',', $fields[4]);
        my $temp_allele_length = length($alleles[0]);
        my $vari_length_allele_flag = 0;
        for(my $i = 1; $i < @alleles; $i++) {
            #microsatellite ($vrt == 4) is fine to have variable length alleles
            $vari_length_allele_flag = 1 if (length($alleles[$i]) != $temp_allele_length) && (4 != $vrt);
            last;
        }

        if(1 == $vari_length_allele_flag) {
            $current_line_error = 1;
            $self->{result}->{ERR}->{ERR_VARI_LENGTH_INDEL}->{counter}++;
            $line .= ";ERR_VARI_LENGTH_INDEL=Indels with variable length alleles";
        }

        if(not defined $sites{$fields[0] . "_" . $fields[1] . "_" . length($alleles[0]) . "_" . $vrt}) {#duplicate sites?
            $sites{$fields[0] . "_" . $fields[1] . "_" . $vrt} = 1;
        }
        else {
            $current_line_error = 1;
            $sites{$fields[0] . "_" . $fields[1] . "_" . $vrt}++;
            $line .= ";ERR_DUP_SITES=Duplicated sites";
        }

	$fields[2] =~ s/^[[:space:]]+//g;
	$fields[2] =~ s/[[:space:]]+$//g;	
	if($fields[2] eq '.' || length($fields[2]) == 0) {#ID column is not set
            $current_line_error = 1;
            $self->{result}->{ERR}->{ERR_NO_ID}->{counter}++;
            $line .= ";ERR_NO_ID=id not set";
	}
	else {
	    if(length($fields[2]) > 64) {#ID is too long
		$current_line_error = 1;
		$self->{result}->{ERR}->{ERR_LONG_ID}->{counter}++;
		$line .= ";ERR_LONG_ID=ID is too long";
	    }
	    if(defined $loc_snp_ids{$fields[2]}) {
		$current_line_error = 1;
		$loc_snp_ids{$fields[2]}++;
		$line .= ";ERR_DUP_ID=duplicated id";
	    }
	    else {
		$loc_snp_ids{$fields[2]} = 1;
	    }
	}

        if($fields[3] =~ /^[[:space:]]+/ || $fields[3] =~ /[[:space:]]+$/) {
            $current_line_error = 1;
	    $self->{result}->{ERR}->{ERR_SPACE_REF}->{counter}++;
	    $line .= ";ERR_SPACE_REF=Extra space before/after ref. allele";
	    $fields[3] =~ s/^[[:space:]]+//g;
	    $fields[3] =~ s/[[:space:]]+$//g;
	}
        if($fields[4] =~ /^[[:space:]]+/ || $fields[4] =~ /[[:space:]]+$/) {
            $current_line_error = 1;
	    $self->{result}->{ERR}->{ERR_SPACE_ALT}->{counter}++;
	    $line .= ";ERR_SPACE_ALT=Extra space before/after alt. allele";
	    $fields[4] =~ s/^[[:space:]]+//g;
	    $fields[4] =~ s/[[:space:]]+$//g;
	}

        if($fields[3] =~ /[^ATGC]/i) {#invalid character in ref allele
            $current_line_error = 1;
            $self->{result}->{ERR}->{ERR_REF_INVALID}->{counter}++;
            $line .= ";ERR_REF_INVALID=invalid ref allele";
        }
	elsif(length($fields[3]) == 0) {#ref allele missing
            $current_line_error = 1;
            $self->{result}->{ERR}->{ERR_REF_MISSING}->{counter}++;
            $line .= ";ERR_REF_MISSING=ref allele missing";
	}

        if($fields[4] =~ /[^ATGC,]/i) {#invalid character in alt allele
            $current_line_error = 1;
            $self->{result}->{ERR}->{ERR_ALT_INVALID}->{counter}++;
            $line .= ";ERR_ALT_INVALID=invalid alt allele";
        }
	elsif(length($fields[4]) == 0) {#alt allele missing
            $current_line_error = 1;
            $self->{result}->{ERR}->{ERR_ALT_MISSING}->{counter}++;
            $line .= ";ERR_ALT_MISSING=alt allele missing";
	}

        if(length($fields[3]) > 51) {
            $current_line_error = 1;
            $self->{result}->{ERR}->{ERR_REF_LEN}->{counter}++;
            $line .= ";ERR_REF_LEN=ref allele longer than 50 nt";
        }

	@alleles = split(',', $fields[4]);
	for(my $i = 0; $i < @alleles; $i++) {
	    if(defined $self->{VRT}->{$vrt}) {#no need to check VRT if user provides an invalid VRT type
		if($vrt && (($vrt != 1 && length($fields[3]) == 1 && length($alleles[$i]) == 1))) { 
		    $current_line_error = 1;
		    $self->{result}->{ERR}->{ERR_WRONG_VRT}->{counter}++;
		    $line .= ";ERR_WRONG_VRT=VRT type is wrong";
		}
		elsif($vrt && (length($fields[3]) > 1 || length($alleles[$i]) > 1) 
		      && ($vrt != 2 && (index($fields[3], $alleles[$i]) == 0 || index($alleles[$i], $fields[3]) == 0))) {
		    $current_line_error = 1;
		    $self->{result}->{ERR}->{ERR_WRONG_VRT}->{counter}++;
		    $line .= ";ERR_WRONG_VRT=VRT type is wrong";
		}
		elsif($vrt && $vrt != 8 && length($fields[3]) > 1 && length($alleles[$i]) > 1 
		      && index($fields[3], $alleles[$i]) == -1 && index($alleles[$i], $fields[3]) == -1) {
		    $current_line_error = 1;
		    $self->{result}->{ERR}->{ERR_WRONG_VRT}->{counter}++;
		    $line .= ";ERR_WRONG_VRT=VRT type is wrong";
		}
	    }

	    if(length($alleles[$i]) > 51) {#could be multiple alt alleles separated by ','.  Still valid if each allele < 51
		$current_line_error = 1;
		$self->{result}->{ERR}->{ERR_ALT_LEN}->{counter}++;
		$line .= ";ERR_ALT_LEN=alt allele longer than 50 nt";
	    }
	    if(uc($alleles[$i]) eq uc($fields[3])) {
		$current_line_error = 1;
		$self->{result}->{ERR}->{ERR_IDENTICAL_REF_ALT}->{counter}++;
		$line .= ";ERR_IDENTICAL_REF_ALT=Reference allele and alternative alleles are the same";
	    }

	    if((substr($alleles[$i], 0, 1) ne substr($fields[3], 0, 1)) && (length($fields[3]) > 1 || length($alleles[$i]) > 1)) {
		$current_line_error = 1;
		$self->{result}->{ERR}->{ERR_INVALID_INDEL_MNV_FMT}->{counter}++;
		$line .= ";ERR_INVALID_INDEL_MNV_FMT=Ref and alt alleles don not have common leading base";
	    }
	}

        if($current_line_error == 1) {
            $self->{result}->{content_error_flag} = 1;
            print ERROR $line . "\n";
        }
    }
    close $vcf_handle;
    close ERROR;

    foreach my $key (keys %loc_snp_ids) {
        if($loc_snp_ids{$key} > 1) {
            $self->{result}->{content_error_flag} = 1;
            $self->{result}->{ERR}->{ERR_DUP_ID}->{counter}++;
        }
    }

    foreach my $key (keys %sites) {
        if($sites{$key} > 1) {
            $self->{result}->{content_error_flag} = 1;
            $self->{result}->{ERR}->{ERR_DUP_SITES}->{counter}++;
        }
    }

    if($self->{result}->{content_error_flag}) {
	make_err_file($self, $temp_err_file);
    }

    unlink $temp_err_file;
}

sub validate_content {
    my ($self, $file, $skip_dense_check, $tool_path, $genome_fasta, $gi_list) = @_;
    my %sliding_window = (chr => '-1', pos_start => -1, counter => 0);#to check SNP density
    my $window_size = 50;#50 nt sliding window
    my $snp_density = 10;#every 50 nt should have less than 10 SNPs
    my $validator = ValidateVCFRefAllele->new($tool_path, $genome_fasta, $gi_list);
    my $ref_res_file = $validator->get_ref_allele($file, $self->{chr_gi});
    if(-z $ref_res_file) {
	$self->{result}->{'sequence_retrieve_failure'} = 1;
	return;
    }

    my $temp_err_file = `mktemp`;
    chomp $temp_err_file;
    open(ERROR, ">>$temp_err_file");

    my $open_file = "cat $file";
    $open_file = 'z' . $open_file if `file $file|grep "gzip compressed"`;
    open my $vcf_handle, "$open_file |" or die "Failed to open the VCF file\n";

    my $vcf_line;
    my $passed_vcf_meta = 0;
    while ($vcf_line = <$vcf_handle>) {
	$vcf_line =~ s/"//g;#deal with double quotes added by Excel text save out
	$vcf_line =~ s/^[[:space:]]+|[[:space:]]+$//g;
	next if length($vcf_line) == 0;

        if($vcf_line =~ /^#.+/) {#consume all header lines
	    $passed_vcf_meta = 1 if $vcf_line =~ /^#CHROM/i;
	    next;
	}

	last if $passed_vcf_meta;
    }
    open my $ref_res_file_handle, "cat $ref_res_file |" or die "Failed to open the reference allele file\n";

    while (my $res_line = <$ref_res_file_handle>) {
	$vcf_line =~ s/^[[:space:]]+|[[:space:]]+$//g;
	next if length($vcf_line) == 0;

	$vcf_line =~ s/\r[\n]*/\n/g;
	chomp $vcf_line;
        my $current_line_error = 0;
        my @temp = split('\|', $res_line);

        if(uc($temp[0]) ne uc($temp[1])) {
            $self->{result}->{content_error_flag} = 1;
            $current_line_error = 1;
            $self->{result}->{ERR}->{ERR_REF_MISMATCH}->{counter}++;
            $vcf_line .= ";ERR_REF_MISMATCH=Ref allele mismatch (Expect: $temp[1], Found: $temp[0])";
        }

	my @fields = split('\t', $vcf_line);
	
	#get FILTER count
	if(defined $self->{result}->{FILTER}->{$fields[6]}) {
	    $self->{result}->{FILTER}->{$fields[6]}++ ;
	}
	else {
	    $self->{result}->{FILTER}->{$fields[6]} = 1;
	}
	
        #check SNP density
	if(!$skip_dense_check) {
	    if($sliding_window{chr} ne $fields[0] ||
		($fields[1] - $sliding_window{pos_start} > $window_size && $sliding_window{chr} eq $fields[0])) {
		if($sliding_window{counter} > $snp_density) {
		    $self->{result}->{content_warning_flag} = 1;
		    $current_line_error = 1;
		    $self->{result}->{CONTENT_WARN}->{ERR_SNP_TOO_DENSE}->{counter}++;
		    $vcf_line .= ";ERR_SNP_TOO_DENSE=starting from chr$sliding_window{chr}:$sliding_window{pos_start}";
		}

		$sliding_window{chr} = $fields[0];
		$sliding_window{pos_start} = $fields[1];
		$sliding_window{counter} = 1;
	    }
	    else {
		$sliding_window{counter}++;
	    }
	}

        print ERROR $vcf_line . "\n" if($current_line_error == 1);
	
        $vcf_line = <$vcf_handle>;
    }

    close $vcf_handle;
    close $ref_res_file_handle;
    close ERROR;

    if($self->{result}->{content_error_flag} || 
       $self->{result}->{content_warning_flag} ||
       $self->{result}->{header_error_flag} == 1 ||
       $self->{result}->{header_warning_flag} == 1) {
	make_err_file($self, $temp_err_file);
    }

    unlink $temp_err_file;
    unlink $ref_res_file;
}

sub print_rpt {
    my $self = shift;

    if($self->{result}->{invalid_vcf_file}) {
	print "The submission file is not a valid vcf file. \n";
	return;
    }
    elsif($self->{result}->{'no_sequence_accessions'}) {
	print "Cannot obtain sequence accessions. If you think your reference assembly is valid, please contact dbSNP\n";
	return;
    }

    my $validation_status = get_validation_status($self);
    print "dbSNP vcf submission file validation result\n\n";
    print "VCF Submisison file: " . basename($self->{submission_file}) . "\n";
    print "Reference genome: $self->{ref_assembly}->{asm_acc}.$self->{ref_assembly}->{asm_version}\n";
    print "Submission type: $self->{result}->{submission_type}\n";

    my $tmp_var_types = "";
    foreach my $key (keys %{$self->{VRT}}) {
        $tmp_var_types .= "\t" . $self->{VRT}->{$key}->{vrt_str} . ": " . $self->{VRT}->{$key}->{counter} . "\n" if $self->{VRT}->{$key}->{counter} > 0;
    }
    print "Number of variation types:\n$tmp_var_types\n" if length($tmp_var_types) > 0;

    if(%{$self->{result}->{FILTER}}) {
	print "Filter summary:\n";
	foreach my $key (keys %{$self->{result}->{FILTER}}) {
	    print "\t$key: " . $self->{result}->{FILTER}->{$key} . "\n";
	}
    }

    print "\nValidation status: $validation_status \n";

    if($self->{result}->{header_error_flag} == 1 || $self->{result}->{header_warning_flag} == 1) {
	print "Problems in vcf header:\n";
	print get_errors($self, 'HEADER_ERROR', "err_str", "counter", "\t", ": ", "\n");
	print get_errors($self, 'HEADER_WARN', "err_str", "counter", "\t", ": ", "\n");
    }
    if($self->{result}->{content_error_flag} == 1 || $self->{result}->{content_warning_flag} == 1) {
        print "\nProblem in the content:\n";
	print get_errors($self, 'ERR', "err_str", "counter", "\t", ": ", "\n");
	print get_errors($self, 'CONTENT_WARN', "err_str", "counter", "\t", ": ", "\n");
    }

    if($validation_status ne 'OK' 
       && $self->{result}->{sequence_retrieve_failure} == 0) {
	print "\nThe issue lines are in file \"" 
	    . basename($self->{submission_file_error}) 
	    . "\"\n" if $validation_status ne 'OK' && $self->{result}->{sequence_retrieve_failure} == 0;
    }
    elsif($self->{result}->{sequence_retrieve_failure} == 1) {
    	print "\nReference sequence not retrieved.\n\n";
    }
}

sub get_errors {
    my ($self, $err_type, $err_item1, $err_item2, $open_str, $connect_str, $end_str, $include_err_key) = @_;
    my $tmp_err_str = "";
    foreach my $key (keys %{$self->{result}->{$err_type}}) {
	if($self->{result}->{$err_type}->{$key}->{counter} > 0) {
	    $tmp_err_str .= $open_str;
	    $tmp_err_str .= "$key=" if $include_err_key;
	    $tmp_err_str .= $self->{result}->{$err_type}->{$key}->{$err_item1} . $connect_str;
	    if(lc(ref($self->{result}->{$err_type}->{$key}->{$err_item2})) eq "array") {
		$tmp_err_str .= join(',', @{$self->{result}->{$err_type}->{$key}->{$err_item2}});
	    }
	    else {
		$tmp_err_str .= $self->{result}->{$err_type}->{$key}->{$err_item2};
	    }
	    $tmp_err_str .= $end_str;
	}
    }
    return $tmp_err_str;
}

sub get_validation_status {
    my $self = shift;
    my $validation_status = 'ERROR';
    if($self->{to_cron} == 1) {
	$validation_status = 'Pending';
    }
    elsif($self->{result}->{header_error_flag} == 0 &&
       $self->{result}->{invalid_reference_genome} == 0 &&
       $self->{result}->{sequence_retrieve_failure} == 0 &&
       $self->{result}->{content_error_flag} == 0 &&
       $self->{result}->{invalid_vcf_file} == 0 &&
       $self->{result}->{content_warning_flag} == 0 &&
       $self->{result}->{header_warning_flag} == 0) {
	$validation_status = 'OK';
    }
    elsif(($self->{result}->{header_error_flag} == 0 &&
       $self->{result}->{invalid_reference_genome} == 0 &&
       $self->{result}->{sequence_retrieve_failure} == 0 &&
       $self->{result}->{content_error_flag} == 0 &&
       $self->{result}->{invalid_vcf_file} == 0) &&
       ($self->{result}->{content_warning_flag} == 1 ||
       $self->{result}->{header_warning_flag} == 1)) {
	$validation_status = 'Warning';
    }

    return $validation_status;
}

#The following code to make json result is not elegant. It is made in a quick way for online validator.
#Need to be optimized or rewritten once have time.
sub print_rpt_json {
    my $self = shift;

    if($self->{result}->{invalid_vcf_file}) {
	print "{\"invalid vcf file\":\"" . 1 . "\"}";
	return;
    }
    elsif($self->{result}->{no_sequence_accessions} && !$self->{to_cron}) {
    	print "{\"no sequence accessions\":\"" . 1 . "\"}";
    	return;
    }

    my $validation_status = get_validation_status($self);
    if($validation_status eq 'Pending') {
	print "{\"Validation status\":\"" . $validation_status . "\"}";
	return;
    }

    print "{";
    print "\"VCF Submission file\":\"$self->{submission_file}\",";
    print "\"Reference genome\":\"$self->{ref_assembly}->{asm_acc}.$self->{ref_assembly}->{asm_version}\",";
    print "\"Submission type\":\"" . $self->{result}->{submission_type} . "\"";

    my $tmp_var_types = "";
    foreach my $key (keys %{$self->{VRT}}) {
	if($self->{VRT}->{$key}->{counter} > 0) {
	    $tmp_var_types .= "\"" . $self->{VRT}->{$key}->{vrt_str} . "\":" . $self->{VRT}->{$key}->{counter} . ",";
	}
    }
    $tmp_var_types =~ s/\,$//g;

    if(length($tmp_var_types) > 0) {
	print ",\"Number of variation types\":{";
	print $tmp_var_types;
	print "}";
    }

    if(%{$self->{result}->{FILTER}}) {
	my @temp_filter = ();
	print ",\"Filter summary\":{";
	foreach my $key (keys %{$self->{result}->{FILTER}}) {
	    push @temp_filter, "\"$key\":" . $self->{result}->{FILTER}->{$key};
	}
	print join(",", @temp_filter);
	print "}";
    }

    
    if($self->{result}->{sequence_retrieve_failure} == 1) {
    	print ",\"Reference sequence not retrieved\":1";
    }

    if($self->{result}->{header_error_flag} == 1 || $self->{result}->{header_warning_flag} == 1) {
    	print ",\"Problems in vcf header\":{";
    	my $tmp_err_str = "";
	$tmp_err_str .= get_errors($self, 'HEADER_ERROR', "err_str", "counter", "\"", "\":\"", "\",");
	$tmp_err_str .= get_errors($self, 'HEADER_WARN', "err_str", "counter", "\"", "\":\"", "\",");
    	$tmp_err_str =~ s/\,$//g;
    	print $tmp_err_str;
    	print "}";
    }
    if($self->{result}->{content_error_flag} == 1 || $self->{result}->{content_warning_flag} == 1) {
    	print ",\"Problem in the content\":{";
    	my $tmp_err_str = "";
	$tmp_err_str .= get_errors($self, 'ERR', "err_str", "counter", "\"", "\":\"", "\",");
	$tmp_err_str .= get_errors($self, 'CONTENT_WARN', "err_str", "counter", "\"", "\":\"", "\",");
    	$tmp_err_str =~ s/\,$//g;
    	print $tmp_err_str;
    	print "}";
    }
    print ",\"Error file\":\"" . $self->{submission_file_error} . "\"" if $validation_status ne 'OK' && $self->{result}->{sequence_retrieve_failure} == 0;
    print ",\"Validation status\":\"" . $validation_status . "\"}";
}

sub validate_bioproject_id {
    my ($self, $id) = @_;
    $id =~ s/[[:space:]]+//g;
    my $eutil_base = 'http://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=bioproject&term=';
    my $eutil_res = get($eutil_base . $id);
    my $xp = XML::XPath->new(xml => $eutil_res);

    #sample Bioproject error
    #<eSearchResult>
    #<Count>0</Count>
    #<RetMax>0</RetMax>
    #<RetStart>0</RetStart>
    #<IdList/><TranslationSet/>
    #<QueryTranslation>(PRJEB64534[All Fields])</QueryTranslation>
    #<ErrorList><PhraseNotFound>PRJEB64534</PhraseNotFound></ErrorList>
    #<WarningList><OutputMessage>No items found.</OutputMessage></WarningList>
    #</eSearchResult>

    #valid Bioproject id will return 0, non-0 otherwise
    return 1 if $xp->exists("/eSearchResult/ErrorList") || $eutil_res =~ /No items found/i;
}

sub validate_biosample_id {
    my ($self, $id) = @_;

    $id =~ s/[[:space:]]+//g;
    my $eutil_base = 'http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=biosample&id=';
    my @samples = split(/,/, $id);
    my $invalid_biosamples = "";
    foreach my $sample (@samples) {
	my $eutil_res = get($eutil_base . $sample);
	if($eutil_res) {
	    my $xp = XML::XPath->new(xml => $eutil_res);

	    #invalid Biosample id will return an empty <BioSampleSet/>
	    $invalid_biosamples .= ($sample . ',') if ! $xp->exists("/BioSampleSet/BioSample");
	}
	else {
	    $invalid_biosamples .= ($sample . ',');
	}
    }

    chop($invalid_biosamples);

    return $invalid_biosamples;
}

sub get_chr_gi {
    my ($self, $gi_list) = @_;
    read_gi_file($self, $gi_list) if defined $gi_list;

    return if $self->{use_custom_genome};
    return if $self->{result}->{'invalid_reference_genome'};
    if(! -d $self->{assm_gi_path}) {
	`mkdir $self->{assm_gi_path}`;
	`chmod g+w $self->{assm_gi_path}`;
    }
    my $gi_file = $self->{assm_gi_path} . '/' . $self->{ref_assembly}->{asm_acc} . '.' . $self->{ref_assembly}->{asm_version};

    if(! -f $gi_file) {
	if($self->{mode} ne 'cgi') {
	    my $gencoll = GetAssGiFromGencoll->new();
	    my $success = $gencoll->get_gi_list($self->{ref_assembly}->{asm_acc}, $self->{ref_assembly}->{asm_version}, $gi_file);

	    read_gi_file($self, $gi_file) if $success;
	}
	else {
	    $self->{to_cron} = 1;
	}
    }
    else {
	read_gi_file($self, $gi_file);
    }
}

sub read_gi_file {
    my ($self, $gi_file) = @_;
    my $open_gi_list = "cat $gi_file";
    $open_gi_list = 'z' . $open_gi_list if `file $gi_file|grep "gzip compressed"`;
    open GI, "$open_gi_list |" or die $!;
    while(<GI>) {
	my @temp = split("\t", $_);
	$temp[$#temp] =~ s/\r[\n]*/\n/g;
	chomp $temp[$#temp];
	$self->{chr_gi}->{lc $temp[0]} = $temp[1];
	$self->{gi_chr}->{$temp[1]} = lc $temp[0];
	$self->{chr_size}->{lc $temp[0]} = $temp[2];

	if($temp[0] =~ /^chr/i) {
	    $temp[0] =~ s/^chr//ig;#submitter may strip 'chr'
	    $self->{chr_gi}->{lc $temp[0]} = $temp[1];
	    $self->{chr_size}->{lc $temp[0]} = $temp[2] if @temp > 2;#3rd column is chr size
	}
	else {
	    $temp[0] = 'chr' . $temp[0];#submitter may prefix 'chr'
	    $self->{chr_gi}->{lc $temp[0]} = $temp[1];
	    $self->{chr_size}->{lc $temp[0]} = $temp[2] if @temp > 2;#3rd column is chr size
	}
    }

    close GI;
}

sub get_custom_chr_size {
    my ($self, $genome_fasta) = @_;

    if($genome_fasta) {
	my $util = Util->new;
	my $fh = $util->open_file($genome_fasta);
	my $fasta = "";
	my $curr_chr = "";
	while(my $line = <$fh>) {
	    $line =~ s/\r[\n]*/\n/g;#handles DOS line end
	    chomp $line;

	    if($line =~ />(.+)/) {
		my $seq_id = $1;
		$seq_id =~ s/^[[:space:]]+|[[:space:]]+$//g;
		$self->{chr_size}->{$self->{gi_chr}->{$curr_chr}} = length($fasta) if $curr_chr ne "";
		$curr_chr = $seq_id;
		$fasta = "";
	    }
	    else {
		$fasta .= $line;
	    }
	}

	$self->{chr_size}->{$self->{gi_chr}->{$curr_chr}} = length($fasta) if $curr_chr ne "";

	close $fh;
    }
}

sub is_chr_grouped {
    my ($self, $chr_ref, $chr) = @_;

    my $chr_in_group = 1;
    if(not defined $chr_ref->{$chr}) {
	$chr_ref->{'last'}++;
	$chr_ref->{$chr} = $chr_ref->{'last'};
    }
    else {
	$chr_in_group = 0 if $chr_ref->{$chr} != $chr_ref->{'last'};
    }

    return $chr_in_group;
}

sub make_err_file {
    my ($self, $tmp_err_file) = @_;

    my $temp_err_file_meta = `mktemp`;
    chomp $temp_err_file_meta;
    open(ERROR, ">>$temp_err_file_meta");
    if($self->{result}->{header_error_flag} == 1 ||
       $self->{result}->{header_warning_flag} == 1) {
	print ERROR get_errors($self, 'HEADER_ERROR', "fix", "tags", "##", ": ", "\n");
	print ERROR get_errors($self, 'HEADER_WARN', "fix", "ids", "##", ": ", "\n");
	close ERROR;
	`cat $temp_err_file_meta > $self->{submission_file_error}`;
    }

    if($self->{result}->{content_error_flag} || $self->{result}->{content_warning_flag}) {
	open(ERROR, ">>$temp_err_file_meta");
	print ERROR '##reference=' . $self->{ref_assembly}->{asm_acc} . '.' . $self->{ref_assembly}->{asm_version} . "\n";
	print ERROR get_errors($self, 'ERR', "err_str", "fix", "##", ". Fix: ", "\n", 1);
	print ERROR get_errors($self, 'CONTENT_WARN', "err_str", "fix", "##", ". Fix: ", "\n", 1);
	close ERROR;

	`cat $temp_err_file_meta $tmp_err_file > $self->{submission_file_error}`;#lazy, just overwrite previous content, should be ok
    }
    `gzip -f $self->{submission_file_error}`;
    $self->{submission_file_error} .= '.gz';
    unlink $temp_err_file_meta;
}

sub convert_if_mac {
    my $original_file = shift;
    my $compressed_flag = 0;
    my $unzipped = $original_file;
    my $is_mac = 0;
    my $temp_file = `mktemp`;
    chomp $temp_file;
    my $converted = `mktemp`;
    chomp $converted;

    if(`file $original_file|grep "gzip compressed"`) {
	$compressed_flag = 1;

	`zcat $original_file > $temp_file`;
	$unzipped = $temp_file;
    }

    if(`file $unzipped|grep "with CR line terminators"`) {
	$is_mac = 1;
	open(OUT, ">$converted");
	open UNZIPPED, $unzipped or die $!;
	while(my $line = <UNZIPPED>) {
	    $line =~ s/\r/\n/g;
	    print OUT $line;
	}
	close OUT;
	close UNZIPPED;
	$unzipped = $converted;
    }
    
    if($is_mac) {
	if($compressed_flag) {
	    `cat $unzipped |gzip > $original_file`;
	}
	else {
	    `cat $unzipped > $original_file`;
	}
    }
    unlink $temp_file;
    unlink $converted;
}

return 1;

=head1 NAME

SNPVCFSubmissionValidator - A perl module to validate dbSNP vcf submission file

=head1 SYNOPSIS

  use strict;
  use SNPVCFSubmissionValidator;
  use Getopt::Long;

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

  my $vcf_checker = SNPVCFSubmissionValidator->new('assm_gi_path' => "./assembly_gi");
  my $res_code;
  my $res_ref;

  ($res_code, $res_ref) = $vcf_checker->validate_vcf_submission($file, $gi_list, $skip_dense, $getseq_path, $genome_fasta);
  $vcf_checker->print_rpt;

=head1 DESCRIPTION

This module validates dbSNP vcf submission file. Invalid sites will be saved in a separate, compressed file with an extension .error.gz

=head1 METHODS

=over 4

=item new

The constructor for SNPVCFSubmissionValidator. Need to provide directory path that saves genome assembly information files

=item param

Parameter hash.  Defines two parameters:
assm_gi_path: Directory that saves genome assembly information
mode: Running mode.  Only two options, 1. default. 2. cgi

=item validate_vcf_submission

The class method to validate vcf submission file

=item file

vcf submission file need to be validated.

=item gi_list

an optional two-column, tab delimited file to define molecule identifiers and accessions

=item skip_dense

signals if to perform SNP density check.

=item getseq_path

optional, customized utility to retrieve sequence from reference molecules.

=item genome_fasta

optional, customized genome fasta file.

=back

=head1 AUTHORS

Hua Zhang

=cut
