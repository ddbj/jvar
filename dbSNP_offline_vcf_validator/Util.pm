package Util;
#$Id $
use strict;

sub new {
    my $class = shift;
    my $self = {};
    bless($self, $class);
    return $self;
}

sub reverse_complement {
    my ($class, $seq) = @_;
    if($seq =~ /[^ATGCMRWSYKVHDBN\/\d\(\)\-]/i) {#a named variation, don't do anything
        return $seq;
    }
    elsif($seq =~ /\((.+)\)((\/\d+)+)/) {#microsatellite, e.g., (AC)/5/7/12/20
        my $temp = $1;
        my $reversecomplement = reverse $1;
        $reversecomplement =~ tr/ACGTacgt/TGCAtgca/;
        $reversecomplement = '(' . $reversecomplement . ')' . $2;
        return $reversecomplement;
    }
    elsif($seq =~ /\//) {#variation
        my @alleles = split(/\//, $seq);
        for(my $i = 0; $i < @alleles; $i++) {
            $alleles[$i] = reverse $alleles[$i];
            $alleles[$i] =~ tr/ACGTacgt/TGCAtgca/;
        }
#        @alleles = sort @alleles;
        return join('/', @alleles);
    }
    else {
        my $reversecomplement = reverse $seq;
        $reversecomplement =~ tr/ACGTMRYKVHDBacgtmrykvhdb/TGCAKYRMBDHVtgcakyrmbdhv/;
        return $reversecomplement;
    }
}

sub get_db_credential {
    my ($class, $credential_file) = @_;

    my $db_username;
    my $db_passwd;

    open CREDENTIAL, "$credential_file" or die "Failed to open the db credential file $credential_file.\n";
    while(my $line = <CREDENTIAL>) {
	chomp $line;
	$line =~ s/[[:space:]]+//g;
	$line =~ s/"//g;
	if($line =~ /username=(.+)/) {
	    $db_username = $1;
	}
	elsif($line =~ /password=(.+)/) {
	    $db_passwd = $1;
	}
    }

    close CREDENTIAL;
    return ($db_username, $db_passwd);
}

sub open_file {
    my ($class, $file) = @_;
    my $fh;
    my $open_file = "cat $file";
    $open_file = 'z' . $open_file if `file $file|grep "gzip compressed"`;
    open $fh, "$open_file |" or die "Failed to open $file.\n";

    return $fh;
}

1;
