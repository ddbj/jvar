package ValidateVCFRefAllele;
# $Id: ValidateVCFRefAllele.pm 5370 2019-06-04 14:17:16Z zhahua $
use strict;
use Data::Dumper;

sub new {
    my ($class, $tool_path, $genome_fasta, $seqid_cfg) = @_;

    return undef if $tool_path ne '' && ($genome_fasta eq '' || $seqid_cfg eq '');

    my $self = {};
    bless($self, $class);

    $self->{use_custom_getseq} = 1 if $tool_path ne '';
    $self->{tool_path} = $tool_path;
    $self->{genome_fasta} = $genome_fasta if $tool_path ne '';
    $self->{seqid_cfg} = $seqid_cfg if $tool_path ne '';

    my %result;
    $self->{result} = \%result;

    return $self;
}

sub validate {
    my ($self, $file, $chr_gi_ref) = @_;

    my $check_result = get_ref_allele($self, $file, $chr_gi_ref);

    if(-z $check_result) {
	print "ERROR: no reference sequence retrieved.\n";
	exit;
    }

    #Analyze validation result
    open RESULT, $check_result or die "Failed to open validation result file $check_result!\n";
    my ($count1, $count2) = (0, 0);

    while (my $line = <RESULT>) {
        my @temp = split('\|', $line);
        if (uc($temp[0]) eq uc($temp[1])) {
            $count1++;
        }
        else {
            $count2++;
        }
    }
    close RESULT;

    $self->{result}->{total} = $count1 + $count2;
    $self->{result}->{validated} = $count1;
    $self->{result}->{mismatch} = $count2;

    unlink $check_result;
    return $self->{result};
}

sub get_ref_allele {
    my ($self, $file, $chr_gi_ref) = @_;

    my $open_file = "cat $file";
    $open_file = 'z' . $open_file if `file $file|grep "gzip compressed"`;
    open DATA, "$open_file |" or die "Failed to open the VCF file\n";

    my $check_input = `mktemp`; #hold the input data for Dima's tool
    chomp $check_input;

    my $check_result = $file . "result"; #hold the check_seq result

    open CHECKINPUT, ">$check_input";

    #reading SNP data
    my $line;
    my $passed_vcf_meta = 0;
    while ($line = <DATA>) {
	$line =~ s/"//g;#deal with double quotes added by Excel text save out
	$line =~ s/^[[:space:]]+|[[:space:]]+$//g;
	next if length($line) == 0;
        if($line =~ /^#.+/){#consume all header lines
	    $passed_vcf_meta = 1 if $line =~ /^#CHROM/i;
	    next;
	}
	next if !$passed_vcf_meta;

        my @fields = split('\t', $line);
        $fields[1]--;

	if($self->{use_custom_getseq}) {
	    print CHECKINPUT $fields[0] . "\t" . $fields[1] . "\t" . ($fields[1] + length($fields[3]) - 1) . "\t" . $fields[3] . "\n";
	}
	else {
	    print CHECKINPUT $chr_gi_ref->{lc $fields[0]} . "\t" . $fields[1] . "\t" . ($fields[1] + length($fields[3]) - 1) . "\t" . $fields[3] . "\n";
	}
    }
    close CHECKINPUT;
    close DATA;

    my $getseq_res = $file . ".result";
    my $additional_cmd_opt = "";

    $additional_cmd_opt .= "-fasta $self->{genome_fasta} -seqid_cfg $self->{seqid_cfg}" if $self->{use_custom_getseq};

    my $cmd = "$self->{tool_path} -i $check_input -o $getseq_res -check_seq $additional_cmd_opt";

    system($cmd);
    unlink $check_input;

    return $getseq_res;
}

return 1;
