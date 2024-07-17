#! /usr/bin/ruby
# -*- coding: utf-8 -*-

require 'rubygems'
require 'pp'
require 'csv'
require 'fileutils'
require 'roo'

#
# Bioinformation and DDBJ Center
# TogoVar-repository
#

# Update history
# 2024-07-17

###
### VCF
###

# VCF file open
vcf_file = ARGV[0]
vcf_f = open(vcf_file)

# trimmed VCF
vcf_trimmed_f = File.open("trimmed/#{vcf_file.sub("vcf", "trimmed.vcf")}", "w")

# VCF file for logging
vcf_log_f = File.open("trimmed/#{vcf_file}.trimmed.log.txt", "w")

if vcf_file =~ /_a(\d+).vcf$/
	assay_id = $1
end

puts vcf_file
puts assay_id
puts ""

line_c = 0
format_f = false
vcf_f.each_line{|line|

	if line[0,2] == "##"

		## handle
		if line_c == 1
			line = "##handle=DDBJ"
		end

		## batch_id
		if line_c == 2
			line = "##batch_id=VSUB000002_a#{assay_id}"
		end

		## bioproject
		if line_c == 3
			line = "##bioproject_id=PRJDB16199"
		end
		
		if line =~ /^##INFO=<ID=ExcHet,Number=A/
			vcf_trimmed_f.puts line
			vcf_trimmed_f.puts '##FORMAT=<ID=AC,Number=A,Type=Integer,Description="Allele count in genotypes, for each ALT allele, in the same order as listed">'
			vcf_trimmed_f.puts '##FORMAT=<ID=AF,Number=A,Type=Float,Description="Allele frequency, for each ALT allele, in the same order as listed">'
			vcf_trimmed_f.puts '##FORMAT=<ID=AN,Number=1,Type=Integer,Description="Total number of alleles in called genotypes">'
		elsif line =~ /^##population_id=/
			
		else
			vcf_trimmed_f.puts line
		end
	
	elsif line[0,1] == "#"
		vcf_trimmed_f.puts line
	# VCF content
	else
		vcf_line_a = line.split("\t")
		
		# REF ALT > 50
		if vcf_line_a[3].size > 50
			vcf_log_f.puts "#{line.rstrip} # skipped REF > 50"
		elsif vcf_line_a[4].size > 50
			vcf_log_f.puts "#{line.rstrip} # skipped ALT > 50"
		else
			vcf_trimmed_f.puts line
		end

	end
	
	line_c += 1
	
}

puts Time.now
puts "#{vcf_file} finished"
puts ""
puts ""

vcf_f.close
vcf_log_f.close
vcf_trimmed_f.close