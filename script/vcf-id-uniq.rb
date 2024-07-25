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
			vcf_uniq_f.puts line
		else
			vcf_line_a = line.split("\t")
			id = vcf_line_a[2]

			if id_h.has_key?(:id)
				vcf_uniq_log_f.puts "#{id}"
			else
				vcf_uniq_f.puts line
			end
			
			# ID uniq
			id_h.store(:id, 1)
		
		end

	}

	puts Time.now
	puts "#{vcf_file} finished"
	
	vcf_f.close
	vcf_uniq_f.close
	vcf_uniq_log_f.close
}

