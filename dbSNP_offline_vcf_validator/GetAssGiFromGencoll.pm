package GetAssGiFromGencoll;
#$Id: GetAssGiFromGencoll.pm 5233 2017-11-06 16:47:11Z zhahua $
use strict;

sub new {
    my ($class) = @_;

    my $self = {};
    bless($self, $class);
    my $gencoll_api_root = '/home/';
    my $gc_get_assembly = $gencoll_api_root . 'gc_get_assembly';
    my $gc_get_molecules = $gencoll_api_root . 'gc_get_molecules';

    $self->{gc_get_assembly} = $gc_get_assembly;
    $self->{gc_get_molecules} = $gc_get_molecules;

    return $self;
}

sub get_gi_list {
    my ($self, $acc, $ver, $gi_list_file) = @_;

    my $temp_ass_asn = `mktemp`;
    chomp $temp_ass_asn;

    `$self->{gc_get_assembly} -acc $acc -ver $ver -o $temp_ass_asn &>/dev/null`;

    if(-z $temp_ass_asn) {
	return 0;
    }
    my $temp_gi_bed_fmt = `mktemp`;
    chomp $temp_gi_bed_fmt;
    `$self->{gc_get_molecules} -gc-assembly $temp_ass_asn -level top-level -filter all -ofmt bed -o $temp_gi_bed_fmt`;

    open GI, $temp_gi_bed_fmt or die $!;
    open GI_LIST_FILE, ">$gi_list_file" or die $!;
    my $line;
    while($line = <GI>) {
	chomp $line;
	my @temp = split('\t', $line);
	#temp[0] is gi, temp[2] is chr size, temp[3] is chr name (UCSC-style-name), 
	print GI_LIST_FILE $temp[3] . "\t" . $temp[0] . "\t" . $temp[2] . "\n";

        #BED format chrM is chrMT, need to get both chrM and chrMT because users could use either one
	print GI_LIST_FILE 'chrMT' . "\t" . $temp[0] . "\t" . $temp[2] . "\n" if $temp[3] eq 'chrM';

        #UCSC-style-name accession and version is separated by a dash, need to add entry for NCBI style as well.
	#i.e., separated accession and version by a dot
	if($temp[3] =~ /\-([[:digit:]]+)$/) {
	    $temp[3] =~ s/\-([[:digit:]]+)/\.$1/g;
	    print GI_LIST_FILE $temp[3] . "\t" . $temp[0] . "\t" . $temp[2] . "\n";
	}
    }

    #no MT info in GCF_000001405.12 and GCF_000001405.13, manually add
    if($acc eq 'GCF_000001405' && $ver == 12) {
	print GI_LIST_FILE 'chrM' . "\t" . '17981852' . "\t" . '16571' . "\n";
	print GI_LIST_FILE 'chrMT' . "\t" . '17981852' . "\t" . '16571' . "\n";
    }
    elsif($acc eq 'GCF_000001405' && $ver == 13) {
	print GI_LIST_FILE 'chrM' . "\t" . '251831106' . "\t" . '16569' . "\n";
	print GI_LIST_FILE 'chrMT' . "\t" . '251831106' . "\t" . '16569' . "\n";
    }

    close GI;
    close GI_LIST_FILE;

    unlink $temp_ass_asn;
    unlink $temp_gi_bed_fmt;

    return 1;
}

return 1;
