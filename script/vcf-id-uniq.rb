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
# 2024-07-25

###
### VCF
###

# VCF file open
vcf_file_a = Dir.glob("submitted/*vcf")

vcf_file_a.each{|vcf_file|
	
	vcf_f = open(vcf_file)
	vcf_uniq_f = open(vcf_file.sub("submitted/", "id-uniq/"), "w")
	vcf_uniq_log_f = open(vcf_file.sub("submitted/", "id-uniq/").sub(".vcf", ".log.vcf"), "w")
	
	id_h = {}
	vcf_f.each_line{|line|
	
		if line[0] == "#"
			if line =~ /^##INFO=<ID=ExcHet,Number=A/
				vcf_uniq_f.puts line
				vcf_uniq_f.puts '##INFO=<ID=CMT=1,Type=String,Description="Comment">'
			else
				vcf_uniq_f.puts line
			end			
		else
			vcf_line_a = line.split("\t")
			
			chr = vcf_line_a[0]
			pos = vcf_line_a[1]
			id = vcf_line_a[2]
			ref = vcf_line_a[3]
			alt = vcf_line_a[4]
			info = vcf_line_a[7]

			if id.include? "_"
				vcf_line_a[7] = "#{vcf_line_a[7]};CMT=\"Original ID - #{chr}:#{pos}:#{ref}:#{alt}\""
			end
			
			if id_h.has_key?(:"#{id}")
				vcf_uniq_log_f.puts "#{id}"
			else
				vcf_uniq_f.puts vcf_line_a.join("\t")
			end

			if 
			
			# ID uniq
			id_h.store(:"#{id}", 1)
		
		end

	}

	puts Time.now
	puts "#{vcf_file} finished"
	
	vcf_f.close
	vcf_uniq_f.close
	vcf_uniq_log_f.close
}

