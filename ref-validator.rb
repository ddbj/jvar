#! /usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'rubygems'
require 'pp'
require 'csv'
require 'fileutils'
require 'roo'
require 'parallel'
require './lib/jvar-config.rb'

#
# Bioinformation and DDBJ Center
# Japan Variation Database (JVar)
#
# Submission type: SNP - Generate JVar-SNP TSV (dbSNP TSV)
# Submission type: SV - Generate JVar-SV XML (dbVar XML)
#

# Update history
# 2023-03-23 created

vcf_f = open(ARGV[0])

refseq_assembly = "GCF_000001405.40"
#refseq_assembly = "GCF_000001405.25"

pre_chrom = ""
pre_pos = ""
pre_id = ""
pre_ref = ""
pre_chr_accession = ""

puts ARGV[0]
puts refseq_assembly

vcf_a = []
vcf_f.each_line{|line|

	next if line.start_with?("#")

	vcf_line_a = line.strip.split("\t")

	vcf_a.push(vcf_line_a)
}

parallel = 30
step = vcf_a.size.div(parallel)
puts "step: #{step}"
puts ""
Parallel.each(0.step(vcf_a.size, step)){|i|

	vcf_a[i..i+step].each{|vcf_line_a|
		
		chrom = ""
		pos = ""
		id = ""
		ref = ""
		chr_accession = ""

		chrom = vcf_line_a[0].sub(/chr/i, "")
		pos = vcf_line_a[1].to_i
		id = vcf_line_a[2]
		ref = vcf_line_a[3]

		if chrom == pre_chrom
			chr_accession = pre_chr_accession
		end

		if chr_accession.empty?
			for ref_h in $sequence_a
				if ref_h[:assemblyAccession] == refseq_assembly && ref_h[:chrName] == chrom && ref_h[:role] == "assembled-molecule"
					chr_accession = ref_h[:refseqAccession]
				end
			end
		end

		ref_fasta_extracted = `samtools faidx reference/#{refseq_assembly}.fna #{chr_accession}:#{pos}-#{pos+ref.size-1}`
		ref_fasta = ref_fasta_extracted.split("\n").drop(1).join("").upcase if ref_fasta_extracted.split("\n").drop(1).join("").upcase

		unless ref_fasta == ref
			puts "#{chrom}\t#{pos}\t#{id}\t#{ref}\tREFa: #{ref_fasta}"
		end

		pre_chrom = chrom
		pre_pos = pos
		pre_id = id
		pre_ref = ref
		pre_chr_accession = chr_accession

	}

}




=begin
Parallel.each(0..2) do |i|

	vcf_a[i*2000..(i+1)*2000].each{|line|
		
		next if line.start_with?("#")

		line.strip!
		vcf_line_a = line.split("\t")

		chrom = ""
		pos = ""
		id = ""
		ref = ""
		chr_accession = ""

		chrom = vcf_line_a[0].sub(/chr/i, "")
		pos = vcf_line_a[1].to_i
		id = vcf_line_a[2]
		ref = vcf_line_a[3]

		if chrom == pre_chrom
			chr_accession = pre_chr_accession
		end

		if chr_accession.empty?
			for ref_h in $sequence_a
				if ref_h[:assemblyAccession] == refseq_assembly && ref_h[:chrName] == chrom && ref_h[:role] == "assembled-molecule"
					chr_accession = ref_h[:refseqAccession]
				end
			end
		end

		ref_fasta_extracted = `samtools faidx reference/#{refseq_assembly}.fna #{chr_accession}:#{pos}-#{pos+ref.size-1}`
		ref_fasta = ref_fasta_extracted.split("\n").drop(1).join("").upcase if ref_fasta_extracted.split("\n").drop(1).join("").upcase

		unless ref_fasta == ref
			puts "#{chrom}\t#{pos}\t#{id}\t#{ref}\tREFa: #{ref_fasta}"
		end

		pre_chrom = chrom
		pre_pos = pos
		pre_id = id
		pre_ref = ref
		pre_chr_accession = chr_accession

	}

end

vcf_f.each_line{|line|
	
	next if line.start_with?("#")

	line.strip!
	vcf_line_a = line.split("\t")

	chrom = ""
	pos = ""
	id = ""
	ref = ""
	chr_accession = ""

	chrom = vcf_line_a[0].sub(/chr/i, "")
	pos = vcf_line_a[1].to_i
	id = vcf_line_a[2]
	ref = vcf_line_a[3]

	if chrom == pre_chrom
		chr_accession = pre_chr_accession
	end

	if chr_accession.empty?
		for ref_h in $sequence_a
			if ref_h[:assemblyAccession] == refseq_assembly && ref_h[:chrName] == chrom && ref_h[:role] == "assembled-molecule"
				chr_accession = ref_h[:refseqAccession]
			end
		end
	end

	ref_fasta_extracted = `samtools faidx reference/#{refseq_assembly}.fna #{chr_accession}:#{pos}-#{pos+ref.size-1}`
	ref_fasta = ref_fasta_extracted.split("\n").drop(1).join("").upcase if ref_fasta_extracted.split("\n").drop(1).join("").upcase

	unless ref_fasta == ref
		puts "#{chrom}\t#{pos}\t#{id}\t#{ref}\tREFa: #{ref_fasta}"
	end

	pre_chrom = chrom
	pre_pos = pos
	pre_id = id
	pre_ref = ref
	pre_chr_accession = chr_accession

}
=end