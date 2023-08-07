#! /usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'rubygems'
require 'pp'
require 'csv'
require 'fileutils'
require 'roo'

#
# Bioinformation and DDBJ Center
# Japan Variation Database (JVar)
#
# Submission type: SNP - Generate JVar-SNP TSV (dbSNP TSV)
# Submission type: SV - Generate JVar-SV XML (dbVar XML)
#

# Update history
# 2023-03-23 created

## VCF parser components
# Parse VCF and validate header
def vcf_parser(vcf_file, vcf_type, args)

	# sin_path = "/usr/local/bin/"
	sin_path = ""

	# Header
	required_header_tag_h = {
		"fileformat" => 0,
		"reference" => 0
	}

	# Column
	required_column_a = [
		"CHROM",
		"POS",
		"ID",
		"REF",
		"ALT",
		"QUAL",
		"FILTER",
		"INFO"
	]

	### for dbSNP VCF

	# SNP VCF VRT
	snp_vrt_h = {
		1 => "SNV",
		2 => "DIV",
		3 => "HETEROZYGOUS",
		4 => "STR",
		5 => "NAMED",
		6 => "NO VARIATION",
		7 => "MIXED",
		8 => "MNV"
	}

	# Archive target SNP VCF INFO
	target_info_tag_snp_h = {
		:VRT => "([1-8])",
		:AN => "([0-9.]+)",
		:AC => "([0-9.]+)",
		:AF => "([0-9.]*\.?[0-9]*)",
		:DESC => "([^;=]+)",
		:LINKS => "([A-Za-z]+:[-A-Za-z0-9]+)"
	}

	# Archive target SNP VCF FORMAT
	target_format_tag_snp_h = {
		:AN => "([0-9.]+)",
		:AC => "([0-9.]+)",
		:AF => "([0-9]*\.?[0-9]*)",
		:GT => "([^;=]+)",
		:GL => "([^;=]+)",
		:PL => "([^;=]+)",
		:GP => "([^;=]+)",
		:PP => "([^;=]+)"
	}

	### For SV VCF parse
	# SV VCF ALT
	# より specific な type を下に配置すること
	sv_type_alt_h = {
		:DEL => "deletion",
		:INS => "insertion",
		:DUP => "duplication",
		:INV => "inversion",
		:CNV => "copy number variation",
		:"DUP:TANDEM" => "tandem duplication",
		:"INS:NOVEL" => "novel sequence insertion",
		:"INS:ME" => "mobile element insertion",
		:"INS:ME:ALU" => "alu insertion",
		:"DEL:ME" => "mobile element deletion",
		:"DEL:ME:ALU" => "alu deletion"
	}

	# SV VCF INFO SVTYPE
	sv_type_svtype_h = {
		:DEL => "deletion",
		:INS => "insertion",
		:DUP => "duplication",
		:INV => "inversion",
		:CNV => "copy number variation"
	}

	# SV VCF INFO EVENTYPE
	sv_type_event_type_h = {
		:DEL => "deletion",
		:"DEL:ME" => "mobile element deletion",
		:INS => "insertion",
		:"INS:ME" => "mobile element insertion",
		:DUP => "duplication",
		:"DUP:TANDEM" => "tandem duplication",
		:"DUP:DISPERSED" => "duplication",
		:INV => "inversion"
	}

	# Archive target SV VCF INFO
	target_info_tag_sv_h = {
		:SVTYPE => "([A-Z]+)",
		:POSrange => "([0-9.]+),([0-9.]+)",
		:ENDrange => "([0-9.]+),([0-9.]+)",
		:CIPOS => "([0-9.+-]+),([0-9.+-]+)",
		:CIEND => "([0-9.+-]+),([0-9.+-]+)",
		:END => "([0-9]+)",
		:SVLEN => "(-?[0-9]+)",
		:AN => "([0-9.]+)",
		:AC => "([0-9.]+)",
		:AF => "([0-9.]*\.?[0-9]*)",
		:CN => "([0-9.]+)",
		:refCN => "([0-9.]+)",
		:DESC => "([^;=]+)",
		:valEXPERIMENT => "([0-9]+)",
		:ORIGIN => "([^;=]+)",
		:PHENO => "([^;=]+)",
		:LINKS => "([A-Za-z]+:[-A-Za-z0-9]+)",
		:EVENT => "([^;=]+)",
		:MATEID => "([^;=]+)"
	}

	# Archive target SV VCF FORMAT
	target_format_tag_sv_h = {
		:AN => "([0-9.]+)",
		:AC => "([0-9.]+)",
		:AF => "([0-9]*\.?[0-9]*)",
		:CN => "([0-9.]+)",
		:refCN => "([0-9.]+)",
		:GT => "([^;=]+)",
		:GL => "([^;=]+)",
		:PL => "([^;=]+)",
		:GP => "([^;=]+)",
		:PP => "([^;=]+)",
		:FT => "([^;=]+)"
	}

	## Header
	warning_vcf_header_a = []
	error_vcf_header_a = []
	error_ignore_vcf_header_a = []
	error_exchange_vcf_header_a = []

	## VCF lines
	vcf_header_a = []
	vcf_column_a = []
	vcf_content_a = []
	vcf_sample_a = []

	# lines for output
	vcf_header_out_a = []
	vcf_column_out_a = []
	vcf_content_out_a = []

	# lines for log
	vcf_log_a = []

	# dbSNP VCF
	vcf_variant_a = []

	# VCF file open
	vcf_f = open(vcf_file)

	# directory
	vcf_path = File.dirname(vcf_file)

	# VCF file for logging
	vcf_log_f = File.open("#{vcf_file}.log.txt", "w")

	# dbSNP VCF output
	dbsnp_vcf_f = open(args[:snp_vcf], "w") if vcf_type == "SNP"

	content_f = false
	header_tag_a = []
	vrt_tags_h = {}

	fileformat = ""
	reference = ""
	dataset_id = ""

	# meta tags info
	info_def_h = {}
	format_def_h = {}
	contig_def_h = {}
	line_c = 0

	# keys
	undefined_ft_key_a = []
	undefined_info_key_a = []

	# reference
	refseq_assembly = ""

	# empty line
	empty_line_c = 0

	##
	## Content
	##
	warning_vcf_content_a = []
	error_vcf_content_a = []
	error_ignore_vcf_content_a = []
	error_exchange_vcf_content_a = []

	## SNP
	vcf_content_dbsnp_a = []

	## VCF sample references
	invalid_sample_ref_vcf_a = []

	# SV VCF variant call and region
	vcf_variant_call_a = []
	vcf_variant_region_a = []
	vcf_variant_call_h = {}
	vcf_variant_region_h = {}

	chrom = ""
	pos = -1
	id = ""
	ref = ""
	alt = ""
	qual = ""
	filter = ""
	info = ""
	format = ""
	sample_a = []
	vrt = ""
	vrt_number = ""
	sv_type = ""

	field_whitespaces_c = 0
	dense_snp_c = 0
	window_size = 50

	pos_not_number_c = 0
	id_not_within_size_c = 0
	missing_id_c = 0
	not_defined_vrt_c = 0
	duplicated_site_c = 0
	duplicated_site_f = false
	duplicated_id_c = 0
	invalid_ref_c = 0
	invalid_sv_ref_c = 0
	invalid_sv_alt_c = 0
	missing_ref_c = 0
	invalid_alt_c = 0
	missing_alt_c = 0
	missing_vrt_c = 0
	longer_ref_c = 0
	longer_alt_c = 0
	invalid_chr_c = 0
	invalid_chr_f = true
	ref_mismatch_c = 0
	same_ref_alt_c = 0
	no_leading_base_indel_c = 0
	invalid_vrt_c = 0
	spaces_ref_alt_c = 0
	chr_not_grouped_c = 0
	not_sorted_pos_c = 0
	pos_outside_chr_c = 0
	pos_outside_chr_f = false
	non_standard_fq_gt_c = 0
	pos_one_c = 0
	telomere_c = 0
	multi_allelic_c = 0
	invalid_translocation_c = 0
	calculated_af_c = 0
	ac_greater_than_an_c = 0

	# fasta
	ref_fasta_no_exist_a = []

	# SV
	missing_svtype_c = 0
	invalid_svtype_c = 0
	invalid_posrange_c = 0
	invalid_endrange_c = 0
	not_supported_c = 0
	skipped_mate_c = 0

	mate_id_h = {}
	invalid_mate_id_a = []

	# INFO
	invalid_info_c = 0

	# FORMAT
	invalid_ft_c = 0
	inconsistent_format_c = 0

	id_h = {}
	sites_h = {}
	pre_chrom = ""
	pre_chr_name = ""
	pre_chr_accession = ""
	pre_chr_length = -1
	pre_invalid_chr_f = true
	pre_ref_download_f = false

	pre_pos = -1
	snp_in_window_c = 0
	chrom_h = {}

	# assembly
	chromosome_per_assembly_a = []

	# dbSNP VCF
	# keep: FILTER
	# keep: pre-defined INFO & FORMAT tags
	# keep: contig used
	# drop: other header lines

	# INFO first line
	first_info_f = true

	vcf_f.each_line{|line|

		line.strip!
		vcf_line_a = line.split("\t")

		skipped_mate_f = false
		invalid_translocation_f = false

		## first line should be fileformat
		if line_c == 0
			## JV_VCF0037: Missing fileformat
			unless line =~ /^##fileformat=VCFv4\.[0-4]$/
				error_vcf_header_a.push(["JV_VCF0037", "First line must be the fileformat tag."])
			end
		end

		# JV_VCF0028: Empty line
		if line =~ /^$/
			vcf_log_a.push("#{line.strip}\t# JV_VCF0028 Error: The empty line is automatically removed.")
			empty_line_c += 1
			next
		end

		# header
		if !content_f

			if line.start_with?("#")

				# fileformat and reference
				if line =~ /^##reference=(\S+)/ && refseq_assembly.empty?

					reference = $1
					required_header_tag_h["reference"] += 1

					## assembly から refseq accession 取得
					$assembly_a.each{|assembly_h|
						refseq_assembly = assembly_h[:refseq_assembly] if assembly_h.has_value?(reference)
					}

					## refseq assembly から構成配列を取得
					$sequence_a.each{|sequence_h|
						if sequence_h[:assemblyAccession] == refseq_assembly
							chromosome_per_assembly_a.push({:chrName => sequence_h[:chrName], :ucscStyleName => sequence_h[:ucscStyleName], :refseqAccession => sequence_h[:refseqAccession], :genbankAccession => sequence_h[:genbankAccession], :role => sequence_h[:role], :length => sequence_h[:length]})
						end
					}

					if vcf_type == "SNP" # dbSNP VCF
						dbsnp_vcf_f.puts "##handle=#{$submitter_handle}"
						dbsnp_vcf_f.puts "##batch_id=#{args[:batch_id]}" if args[:batch_id] && !args[:batch_id].empty?
						dbsnp_vcf_f.puts "##bioproject_id=#{args[:bioproject_accession]}" if args[:bioproject_accession] && !args[:bioproject_accession].empty?
						dbsnp_vcf_f.puts "##biosample_id=#{args[:biosample_accessions]}" if args[:biosample_accessions] && !args[:biosample_accessions].empty?
						dbsnp_vcf_f.puts "##reference=#{refseq_assembly}"
					end

				# INFO tags
				elsif line.start_with?("##INFO")

					# INFO definition
					if line =~ /^##INFO=<ID=([^,]+),/
						if info_def_h.has_key?($1.to_sym)
							error_vcf_header_a.push(["JV_VCF0044", "INFO tag ID must be unique in VCF. #{$1}"])
						end
						info_def_h.store($1.to_sym, line)
					end

					if line =~ /^##INFO.*VRT/
						unless line.scan(/([1-8]) *- *([A-Z ]+)/).empty?
							for svrt_number, svrt_string in line.scan(/([1-8]) *- *([A-Z ]+)/)
								vrt_tags_h.store(svrt_number.to_i, svrt_string)
							end
						end
					end

					if vcf_type == "SNP"
						if first_info_f
							dbsnp_vcf_f.puts '##INFO=<ID=VRT,Number=1,Type=Integer,Description="Variation type,1 - SNV: single nucleotide variation,2 - DIV: deletion/insertion variation,3 - HETEROZYGOUS: variable, but undefined at nucleotide level,4 - STR: short tandem repeat (microsatellite) variation, 5 - NAMED: insertion/deletion variation of named repetitive element,6 - NO VARIATION: sequence scanned for variation, but none observed,7 - MIXED: cluster contains submissions from 2 or more allelic classes (not used),8 - MNV: multiple nucleotide variation with alleles of common length greater than 1,9 - Exception">'
							first_info_f = false
						end

						unless line =~ /^##INFO=\<ID=VRT,/ # 元々の VRT 行は含めない
							dbsnp_vcf_f.puts line
						end
					end

				# FORMAT tags
				elsif line.start_with?("##FORMAT")

					# FORMAT definition
					if line =~ /^##FORMAT=<ID=([^,]+),/
						if format_def_h.has_key?(:"#{$1}")
							error_vcf_header_a.push(["JV_VCF0045", "FORMAT tag ID must be unique in VCF. #{$1}"])
						end
						format_def_h.store(:"#{$1}", line)
					end

					dbsnp_vcf_f.puts line if vcf_type == "SNP"

				elsif line.start_with?("##fileformat=")
					required_header_tag_h["fileformat"] += 1
					dbsnp_vcf_f.puts line if vcf_type == "SNP"

				# contig tags, dbSNP VCF には含めない
				elsif line.start_with?("##contig")

					# contig definition
					if line =~ /^##contig=<ID=([^,]+),/
						contig_def_h.store(:"#{$1}", line)
					end

				# content header
				elsif line.start_with?("#CHROM")
			 		content_f = true
			 		vcf_column_a = line.sub(/^#/, "").chomp.split("\t")

					## JV_VCF0005: White space characters before/after column header
					column_whitespaces_a = []
					for column in vcf_column_a
						if column.strip != column
							column_whitespaces_a.push(column)
						end
					end

					# column 前後の whitespace 削除
					unless column_whitespaces_a.empty?
						warning_vcf_header_a.push(["JV_VCF0005", "White space characters before/after fields are automatically removed. #{column_whitespaces_a.join(",")}"])
						vcf_log_a.push("#{line}\t# JV_VCF0005 Warning: White space characters before/after fields are automatically removed.")
						vcf_column_out_a = vcf_column_a.collect{|e| e.strip }
					else
						vcf_column_out_a = vcf_column_a
					end

					## JV_VCF0004: Missing VCF column
					if vcf_column_out_a.empty?
						error_vcf_header_a.push(["JV_VCF0004", "Provide missing VCF column."]) unless required_column_a == vcf_column_a[0, 8]
					else
						error_vcf_header_a.push(["JV_VCF0004", "Provide missing VCF column."]) unless required_column_a == vcf_column_out_a[0, 8]
					end

					## sample columns
					if vcf_column_out_a.empty?
						vcf_sample_a = vcf_column_a[9..-1] if vcf_column_a[9..-1]
					else
						vcf_sample_a = vcf_column_out_a[9..-1] if vcf_column_out_a[9..-1]
					end

					if vcf_type == "SNP"

						# JV_VCF0042: Invalid sample reference in VCF
						unless (vcf_sample_a - args[:valid_sample_sampleset_refs]).empty?
							error_vcf_header_a.push(["JV_VCF0042", "Reference a Sample Name of a Sample in the SampleSet or a SampleSet Name in the VCF sample column. #{(vcf_sample_a - args[:valid_sample_sampleset_refs]).sort.uniq.join(",")}"])
						end

						if vcf_type == "SNP" # dbSNP VCF output
							if $direct_sample_ref_f
								args[:sample_names].each{|population_id|
									dbsnp_vcf_f.puts "##population_id=#{population_id}"
								}
							else
								args[:sampleset_names].each{|population_id|
									dbsnp_vcf_f.puts "##population_id=#{population_id}"
								}
							end
							dbsnp_vcf_f.puts "##{vcf_column_out_a.join("\t")}"
						end

					end

					next # content 処理に入らせないため

				else # reference INFO FORMAT FILTER contig #CHROM 以外のヘッダー行
					dbsnp_vcf_f.puts line if vcf_type == "SNP"
				end # if reference

			end # if line.start_with?("##")

			line_c += 1

		end # if !content_f

		# content
		if content_f

			chrom = ""
			pos = -1
			id = ""
			ref = ""
			alt = ""
			qual = ""
			filter = ""
			info = ""
			format = ""
			sample_a = []
			vrt = ""
			vrt_number = ""
			sv_type = ""
			variant_sequence = ""

			# chromosome
			chr_name = ""
			chr_accession = ""
			chr_length = -1

			# SV 格納
			vcf_variant_call_h = {}

			## JV_VCF0005: White space characters before/after column header
			vcf_field_whitespaces_a = []
			for vcf_field in vcf_line_a
				if vcf_field.strip != vcf_field
					vcf_field_whitespaces_a.push(vcf_field)
				end
			end

			# field 前後の whitespace 削除
			unless vcf_field_whitespaces_a.empty?
				field_whitespaces_c += 1
				vcf_log_a.push("#{vcf_line_a.join("\t")} # JV_VCF0005 Warning: White space characters before/after fields are automatically removed.")
				vcf_line_a = vcf_line_a.collect{|e| e.strip }
			end

			chrom = vcf_line_a[0].sub(/chr/i, "") if vcf_line_a[0] && vcf_line_a[0].sub(/chr/i, "")
			pos = vcf_line_a[1]
			id = vcf_line_a[2]

			# chrom が変わったら格納
			if pre_chrom != chrom

				chrom_h.store(:"#{pre_chrom}", 0)

				if chrom_h.has_key?(:"#{chrom}")
					# JV_VCF0026: Same chromosome not grouped
					vcf_log_a.push("#{vcf_line_a.join("\t")} # JV_VCF0026 Error: Group data from the same chromosome.")
					chr_not_grouped_c += 1
				end

			end

			if vcf_line_a[3]
				ref = vcf_line_a[3]
			else
				ref = ""
			end

			if vcf_line_a[4]
				alt = vcf_line_a[4]
			else
				alt = ""
			end

			qual = vcf_line_a[5]
			filter = vcf_line_a[6]
			info = vcf_line_a[7]

			if vcf_line_a[8]
				format = vcf_line_a[8]
			else
				format = ""
			end

			sample_a = vcf_line_a[9..-1] if vcf_line_a[9..-1]

			info_h = {}
			if info && info.split(";").size > 0
				info.split(";").each{|info_item|
					key, value = "", ""
					key = info_item.split("=")[0].strip if info_item.split("=")[0]
					value = info_item.split("=")[1].strip if info_item.split("=")[1]

					# target INFO tag のみ格納
					if (vcf_type == "SNP" && target_info_tag_snp_h.has_key?(:"#{key}")) || (vcf_type == "SV" && target_info_tag_sv_h.has_key?(:"#{key}"))
						if value && !value.empty?
							info_h.store(:"#{key}", value.sub(/^"/, "").sub(/"$/, ""))
						else
							info_h.store(:"#{key}", "")
						end
					end

					# header INFO で定義されているかどうか
					if key != "." && !info_def_h.has_key?(:"#{key}")
						undefined_info_key_a.push(key)
					end

				} # info.split(";").each{|info_item|

			end

			# JV_VCF0031: Invalid INFO value format, validate target tag and value
			invalid_info_a = []

			if $info_regex_f
				if vcf_type == "SNP"
					for key_sym, regex in target_info_tag_snp_h
						if info_h[key_sym] && !info_h[key_sym].match?(/#{regex}/)
							invalid_info_a.push("#{key_sym}:#{info_h[key_sym]}")
							invalid_info_c += 1
						end
					end
				elsif vcf_type == "SV"
					for key_sym, regex in target_info_tag_sv_h
						if info_h[key_sym] && !info_h[key_sym].match?(/#{regex}/)
							invalid_info_a.push("#{key_sym}:#{info_h[key_sym]}")
							invalid_info_c += 1
						end
					end
				end
			end

			# JV_VCF0031
			unless invalid_info_a.empty?
				vcf_log_a.push("#{vcf_line_a.join("\t")} # JV_VCF0031 Warning: Provide INFO value in a valid format. #{invalid_info_a.join(",")}")
			end

			# JV_VCF0021: Duplicated local IDs
			# JV_VCFS0012: MATEID not found
			if id && !id.empty?
				if id_h.has_key?(:"#{id}")
					vcf_log_a.push("#{vcf_line_a.join("\t")} # JV_VCF0021 Error: Local IDs should be unique in a dataset/VCF.")
					duplicated_id_c += 1
				end
				id_h.store(:"#{id}", 1)
			end

			# JV_VCF0036: Multi-allelic ALT allele
			multi_allelic_f = false
			if !alt.empty? && alt.include?(",")
				vcf_log_a.push("#{vcf_line_a.join("\t")} # JV_VCF0036 Error: JVar only accepts mono-allelic ALT alleles (no commas in ALT).")
				multi_allelic_c += 1
				multi_allelic_f = true
			end

			# JV_VCF0008: Invalid position (POS)
			unless pos.match?(/^[0-9]+$/)
				vcf_log_a.push("#{vcf_line_a.join("\t")} # JV_VCF0008 Error: Positions (POS) should be numbers.")
				pos_not_number_c += 1
			else
				pos = pos.to_i
			end

			# chrom が同じであれば pre_pos <= pos
			if pre_chrom == chrom
				unless pos >= pre_pos
					# JV_VCF0027: Data not sorted based on positions
					vcf_log_a.push("#{vcf_line_a.join("\t")} # JV_VCF0027 Error: Sort data based on their positions.")
					not_sorted_pos_c += 1
				end

			end

			# JV_VCFP0001: Region contains too many SNPs
			if vcf_type == "SNP"

				if pos < pre_pos + window_size
					snp_in_window_c += 1
				else
					snp_in_window_c = 0
				end

				if snp_in_window_c > 10
					vcf_log_a.push("#{vcf_line_a.join("\t")} # JV_VCFP0001 Warning: Too many SNPs (more than 10 SNPs in 50bp). Verify these regions are legitimate.")
					dense_snp_c += 1
				end

			end

			# JV_VCF0009: Local ID longer than 64 characters
			if id.size > 64
				vcf_log_a.push("#{vcf_line_a.join("\t")} # JV_VCF0009 Error: Provide unique local IDs shorter than 64 characters.")
				id_not_within_size_c += 1
			end

			# JV_VCF0010: Missing local ID
			if id.nil? || id.empty?
				vcf_log_a.push("#{vcf_line_a.join("\t")} # JV_VCF0010 Error: Provide unique local IDs shorter than 64 characters.")
				missing_id_c += 1
			end

			# JV_VCF0013: Missing REF allele
			if ref.nil? || ref.empty?
				vcf_log_a.push("#{vcf_line_a.join("\t")} # JV_VCF0013 Error: Provide REF allele.")
				missing_ref_c += 1
			end

			# JV_VCF0016: Missing ALT allele
			if alt.nil? || alt.empty?
				vcf_log_a.push("#{vcf_line_a.join("\t")} # JV_VCF0016 Error: Provide ALT allele.")
				missing_alt_c += 1
			end

			# JV_VCF0022: Same REF and ALT alleles
			if !ref.nil? && !ref.empty? && !alt.nil? && !alt.empty? && ref == alt
				vcf_log_a.push("#{vcf_line_a.join("\t")} # JV_VCF0022 Error: REF and ALT alleles should not be the same.")
				same_ref_alt_c += 1
			end

			# reference chromosome
			if chrom == pre_chrom

				chr_name = pre_chr_name
				chr_accession = pre_chr_accession
				chr_length = pre_chr_length
				invalid_chr_f = pre_invalid_chr_f
				ref_download_f = pre_ref_download_f

			else
				invalid_chr_f = true
				ref_download_f = false
				for chromosome_per_assembly_h in chromosome_per_assembly_a

					## chromosome
					if chrom && chromosome_per_assembly_h[:chrName] == chrom.sub(/chr/i, "") && chromosome_per_assembly_h[:role] == "assembled-molecule"
						chr_name = chromosome_per_assembly_h[:chrName]
						chr_accession = chromosome_per_assembly_h[:refseqAccession]
						chr_length = chromosome_per_assembly_h[:length]

						invalid_chr_f = false
					elsif chrom && (chromosome_per_assembly_h[:refseqAccession] == chrom || chromosome_per_assembly_h[:genbankAccession] == chrom)
						chr_name = chrom
						chr_accession = chrom
						chr_length = chromosome_per_assembly_h[:length]

						invalid_chr_f = false
					elsif chrom && chromosome_per_assembly_h[:ucscStyleName].sub(/^chr/i, "") == chrom.sub(/^chr/i, "")
						chr_name = chromosome_per_assembly_h[:ucscStyleName]
						chr_accession = chromosome_per_assembly_h[:refseqAccession]
						chr_length = chromosome_per_assembly_h[:length]

						invalid_chr_f = false

					elsif chrom && $ref_download_h.has_key?(chrom)
						chr_name = chrom
						chr_accession = chrom
						chr_length = $ref_download_h[chrom].to_i if $ref_download_h[chrom].to_i

						invalid_chr_f = false
						ref_download_f = true
					end

				end

			end # if chrom == pre_chrom

			# JV_VCF0035: Variant at telomere
			# VCF spec と dbSNP VCF guideline では telomere 0 or N+1
			# dbVar VCF guideline では 1 (p-arm), N (q-arm) となっているが dbSNP/VCF spec に準拠する
			if chr_length != -1 && (pos == 0 || pos == chr_length + 1)
				vcf_log_a.push("#{vcf_line_a.join("\t")} # JV_VCF0035 Warning: Variant at telomere.")
				telomere_c += 1
			end

			# chrom is valid or not
			if invalid_chr_f
				vcf_log_a.push("#{vcf_line_a.join("\t")} # JV_VCF0017 Error: Chromosome name need to match the INSDC reference assembly.")
				invalid_chr_c += 1
			elsif chr_length != -1 && pos > 0 && (pos < chr_length + 1) && $ref_check_f

				ref_fasta = ""
				ref_fasta_extracted = ""

				if !ref_download_f
					ref_fasta_extracted = `#{sin_path}samtools faidx reference/#{refseq_assembly}.fna #{chr_accession}:#{pos}-#{pos+ref.size-1}`
				elsif ref_download_f
					ref_fasta_extracted = `#{sin_path}samtools faidx reference-download/#{chr_accession}.fna #{chr_accession}:#{pos}-#{pos+ref.size-1}`
				end

				ref_fasta = ref_fasta_extracted.split("\n").drop(1).join("").upcase if ref_fasta_extracted.split("\n").drop(1).join("").upcase

				# JV_VCF0014: REF allele mismatch with reference
				unless ref_fasta == ref
					vcf_log_a.push("#{vcf_line_a.join("\t")} # JV_VCF0014 Error: Need to match the reference genome on the forward orientation. Reference: #{ref_fasta.upcase}")
					ref_mismatch_c += 1
				end

			end

			## 前の chr を保存して chr が前と異なる場合のみ処理実施
			## keep previous chrom and pos
			pre_chrom = chrom
			pre_pos = pos
			pre_chr_name = chr_name
			pre_chr_accession = chr_accession
			pre_chr_length = chr_length
			pre_invalid_chr_f = invalid_chr_f
			pre_ref_download_f = ref_download_f

			### INFO & FORMAT allele, genotype, copy number

			### FORMAT
			format_data_h = {}
			format_data_a = []
			invalid_ft_value_a = []
			if !format.empty? && !vcf_sample_a.empty? && !sample_a.empty?

				s = 0
				for sample_value in sample_a

					if sample_value.split(":").size != format.split(":").size && s == 0
						# JV_VCF0039: Inconsistent FORMAT keys and sample values
						vcf_log_a.push("#{vcf_line_a.join("\t")} # JV_VCF0039 Warning: Number of FORMAT keys and sample values are different.")
						inconsistent_format_c += 1
					end

					k = 0
					tmp_format_data_h = {}
					for key in format.split(":")

						# JV_VCF0040: Undefined FORMAT key
						unless format_def_h.has_key?(key.to_sym)
							undefined_ft_key_a.push(key)
						end

						# archive target のみ格納
						if vcf_type == "SNP"
							target_format_tag_snp_h.keys.each{|target_ft_key_sym|
								tmp_format_data_h.store(target_ft_key_sym, sample_value.split(":")[k]) if key == "#{target_ft_key_sym}" && sample_value.split(":")[k] && sample_value.split(":")[k].gsub(".", "") # per SampleSet this VCF/dataset belongs to.
							}
						elsif vcf_type == "SV"
							target_format_tag_sv_h.keys.each{|target_ft_key_sym|
								tmp_format_data_h.store(target_ft_key_sym, sample_value.split(":")[k]) if key == "#{target_ft_key_sym}" && sample_value.split(":")[k] && sample_value.split(":")[k].gsub(".", "") # per SampleSet this VCF/dataset belongs to.
							}
						end

						k += 1
					end

					# FORMAT データ格納
					unless tmp_format_data_h.empty?

						# FORMAT データ形式チェック
						if $format_regex_f
							for ft_key_sym, ft_value in tmp_format_data_h
								if vcf_type == "SNP"
									if target_format_tag_snp_h[ft_key_sym] && !ft_value.match?(/^#{target_format_tag_snp_h[ft_key_sym]}$/)
										invalid_ft_value_a.push("#{ft_key_sym}:#{ft_value}")
									end
								elsif vcf_type == "SV"
									if target_format_tag_sv_h[ft_key_sym] && !ft_value.match?(/^#{target_format_tag_sv_h[ft_key_sym]}$/)
										invalid_ft_value_a.push("#{ft_key_sym}:#{ft_value}")
									end
								end
							end
						end

						# 形式チェックした後に . を "" に変換して格納
						format_data_h.store(:"#{vcf_sample_a[s]}", tmp_format_data_h.map{|key_sym,val| [key_sym, val.gsub(".", "")]}.to_h)

					end

					s += 1

				end # for sample_value in sample_a

				format_data_a.push(format_data_h)

				unless invalid_ft_value_a.empty?
					# JV_VCF0032: Invalid FORMAT value format
					vcf_log_a.push("#{vcf_line_a.join("\t")} # JV_VCF0032 Warning: Provide FORMAT value in a valid format. #{invalid_ft_value_a.join(",")}")
					invalid_ft_c += 1
				end

			end

			## Allele Frequency
			af = ""
			if info_h[:AN] && !info_h[:AN].empty? && info_h[:AC] && !info_h[:AC].empty?

				if vcf_type == "SV"
					vcf_variant_call_h.store(:"Allele Number", info_h[:AN])
					vcf_variant_call_h.store(:"Allele Count", info_h[:AC])
				end

				# JV_C0063: Allele count greater than allele number
				ac_greater_than_an_f = false
				if info_h[:AC].to_i > info_h[:AN].to_i
					ac_greater_than_an_c += 1
					vcf_log_a.push("#{vcf_line_a.join("\t")} # JV_C0063 Error: Allele count is greater than allele number.")
					ac_greater_than_an_f = true
				end

				# AF
				if info_h[:AF] && !info_h[:AF].empty?
					vcf_variant_call_h.store(:"Allele Frequency", info_h[:AF])
				else
					if info_h[:AC].to_i.fdiv(info_h[:AN].to_i).floor(6).to_s && !ac_greater_than_an_f
						af = info_h[:AC].to_i.fdiv(info_h[:AN].to_i).floor(6).to_s

						calculated_af_c += 1
						vcf_log_a.push("#{vcf_line_a.join("\t")} # JV_C0062 Warning: Allele frequency was calculated as allele count/allele number. #{af}")

						if vcf_type == "SNP"
							vcf_line_a[7] = "#{vcf_line_a[7]};AF=#{af}"
						elsif vcf_type == "SV"
							vcf_variant_call_h.store(:"Allele Frequency", af)
						end
					else
						vcf_variant_call_h.store(:"Allele Frequency", "") if vcf_type == "SV"
					end
				end
			else # if info_h["AN"] && !info_h["AN"].empty? && info_h["AC"] && !info_h["AC"].empty?
				if vcf_type == "SV"
					vcf_variant_call_h.store(:"Allele Number", "")
					vcf_variant_call_h.store(:"Allele Count", "")
					vcf_variant_call_h.store(:"Allele Frequency", "")
				end
			end

			## SNP specific validations
			if vcf_type == "SNP"

				# JV_VCFP0007: Invalid REF allele
				if !ref.empty? && !ref.match?(/^[ATGC]+$/)
					vcf_log_a.push("#{vcf_line_a.join("\t")} # JV_VCFP0007 Error: Remove non-ATGC base from REF allele.")
					invalid_ref_c += 1
				end

				# JV_VCFP0002: REF allele longer than 50 nucleotides
				if !ref.empty? && ref.size > 51
					vcf_log_a.push("#{vcf_line_a.join("\t")} # JV_VCFP0002 Error: Remove and submit the allele longer than 50 nucleotides (REF) to JVar-SV.")
					longer_ref_c += 1
				end

				# JV_VCFP0005: Invalid ALT allele
				if !alt.empty? && !alt.match?(/^[ATGC,]+$/)
					vcf_log_a.push("#{vcf_line_a.join("\t")} # JV_VCFP0005 Error: Remove non-ATGC base from ALT allele.")
					invalid_alt_c += 1
				end

				# JV_VCFP0003: ALT allele longer than 50 nucleotides
				if !alt.empty? && alt.size > 51
					vcf_log_a.push("#{vcf_line_a.join("\t")} # JV_VCFP0003 Error: Remove and submit the allele longer than 50 nucleotides (ALT) to JVar-SV.")
					longer_alt_c += 1
				end

				# VRT 優先順位 VRT > REF ALT 判定
				if info_h[:VRT] && info_h[:VRT].to_i && snp_vrt_h[info_h[:VRT].to_i]

					vrt_number = info_h[:VRT]
					vrt = snp_vrt_h[info_h[:VRT].to_i]

				elsif !ref.empty? && !alt.empty? && !alt.include?(",") && ref.size == 1 && alt.size == 1 && ref != alt

					vrt_number = "1"
					vrt = "SNV"

				elsif !ref.empty? && !alt.empty? && !alt.include?(",") && ref.size > 1 && alt.size > 1 && ref.size == alt.size && ref != alt
					all_different_f = true
					ref.size.times{|j|
						all_different_f = false if ref[j] == alt[j]
					}

					if all_different_f
						vrt_number = "8"
						vrt = "MNV"
					end

				elsif !ref.empty? && !alt.empty? && !alt.include?(",") && (ref.size - alt.size).abs > 0 && ref != alt

					# event の一塩基前が共通で記載されているかどうかは別でチェック
					vrt_number = "2"
					vrt = "DIV"

				else

					# JV_VCFP0006: Variation type not in defined set
					vcf_log_a.push("#{vcf_line_a.join("\t")} # JV_VCFP0006 Error: Provide variation type in the defined set.")
					not_defined_vrt_c += 1

				end # if info_h["VRT"]

				# JV_VCF0011: Duplicated sites
				duplicated_site_f = false

				unless vrt.empty?
					if sites_h.has_key?(:"#{chr_accession}:#{pos}:#{ref}:#{alt}:#{vrt}")
						duplicated_site_c += 1
						duplicated_site_f = true
					end

					# JV_VCF0011: Duplicated sites
					vcf_log_a.push("#{vcf_line_a.join("\t")} # JV_VCF0011 Error: Remove duplicated sites.") if duplicated_site_f

					# 重複チェック用に site を格納
					sites_h.store(:"#{chr_accession}:#{pos}:#{ref}:#{alt}:#{vrt}", 1)

				end

				if vrt.empty?
					# JV_VCF0019: Missing variation type
					vcf_log_a.push("#{vcf_line_a.join("\t")} # JV_VCF0019 Error: Provide variation type.")
					missing_vrt_c += 1
				end

				# JV_VCF0023: REF and ALT alleles without leading base
				if vrt == "DIV" && ref[0] != alt[0] && alt.size > 1
					vcf_log_a.push("#{vcf_line_a.join("\t")} # JV_VCF0023 Error: Indels need leading bases in REF and ALT alleles.")
					no_leading_base_indel_c += 1
				end

				# JV_VCFP0004: Insertion and deletion at base position 1
				if vrt == "DIV" && pos == 1
					vcf_log_a.push("#{vcf_line_a.join("\t")} # JV_VCFP0004 Warning: Provide a base after the insertion and deletion at base position 1.")
					pos_one_c += 1
				end

				# JV_C0061: Chromosome position larger than chromosome size + 1
				if chr_length != -1 && pos > chr_length + 1
					vcf_log_a.push("#{vcf_line_a.join("\t")} # JV_C0061 Error: Chromosome position is larger than chromosome size + 1. Check if the position is correct.")
					pos_outside_chr_c += 1
				end

			end # if vcf_type == "SNP"

			##
			## SV
			##
			if vcf_type == "SV"

				# Variant Call ID
				vcf_variant_call_h.store(:"Variant Call ID", id)

				# JV_VCFS0009: Invalid REF allele
				if !ref.empty? && !ref.match?(/^[ATGCN]+$/)
					vcf_log_a.push("#{vcf_line_a.join("\t")} # JV_VCFS0009 Error: Remove non-ATGCN base from REF allele.")
					invalid_sv_ref_c += 1
				end

				## Start and end
				outer_start = -1
				start = -1
				inner_start = -1
				inner_stop = -1
				stop = -1
				outer_stop = -1
				ciposleft = -1
				ciposright = -1
				ciendleft = -1
				ciendright = -1

				svlen = 0

				## Other INFO tags
				if info_h[:DESC]
					# DESC
					vcf_variant_call_h.store("Description", info_h[:DESC])
				end

				if info_h[:valEXPERIMENT]
					# valEXPERIMENT
					vcf_variant_call_h.store(:Validation, info_h[:valEXPERIMENT])
				else
					vcf_variant_call_h.store(:Validation, "")
				end

				if info_h[:ORIGIN]
					# ORIGIN
					vcf_variant_call_h.store(:Origin, info_h[:ORIGIN])
				else
					vcf_variant_call_h.store(:Origin, "")
				end

				if info_h[:PHENO]
					# PHENO
					vcf_variant_call_h.store(:Phenotype, info_h[:PHENO])
				else
					vcf_variant_call_h.store(:Phenotype, "")
				end

				if info_h[:LINKS]
					# LINKS
					vcf_variant_call_h.store(:"External Links", info_h[:LINKS])
				else
					vcf_variant_call_h.store(:"External Links", "")
				end

				## copy number
				# INFO にある場合は VCF dataset が参照している SampleSet 中のコピー数
				if info_h[:CN]
					# CN
					vcf_variant_call_h.store(:"Copy Number", info_h[:CN])
				else
					vcf_variant_call_h.store(:"Copy Number", "")
				end

				## reference_copy_number
				# INFO にある場合は VCF dataset が参照している SampleSet 中のコピー数
				if info_h[:refCN]
					# refCN
					vcf_variant_call_h.store(:reference_copy_number, info_h[:refCN])
				end

				## Genotype
				# INFO にある場合は VCF dataset が参照している SampleSet 中の genotype
				if info_h[:GT]
					# GT
					vcf_variant_call_h.store(:submitted_genotype, info_h[:GT])
				end

				### Translocation
				translocation_f = false
				telomere_translocation_f = false

				from_chr = ""
				from_coord = -1
				from_strand = ""
				to_chr = ""
				to_coord = -1
				to_strand = ""
				mutation_molecule = ""
				mutation_id = ""
				mate_id = ""

				if info_h[:EVENT] && info_h[:EVENT]
					mutation_id = info_h[:EVENT]
				end

				if info_h[:MATEID] && info_h[:MATEID]
					mate_id = info_h[:MATEID]
					mate_id_h.store(:"#{id}", :"#{mate_id}")
				end

				# EVENT (Mutation ID) の有る無しに関わらず MATEID の片方 (VCF で下に書いてある方) は同一 SV を双方向から記載したものなのでスキップ
				if mate_id_h.has_value?(:"#{id}")
					vcf_log_a.push("#{line.strip}\t# JV_VCFS0013 Warning: One of identical breakend mates of the same MATEID was skipped.")
					skipped_mate_f = true
					skipped_mate_c += 1
				end

				chr_trans_regex = "([A-Za-z0-9_.]+):([0-9]+)"

				# if translocation
				if alt.match?(/\[.*\[/) || alt.match?(/\].*\]/)

					valid_translocation_f = false
					translocation_f = true

					# single breakend は未対応
					if pos > 0
						if alt =~ /#{ref}([ATGCN]*)\[#{chr_trans_regex}\[/i
							from_chr = chrom
							from_coord = pos
							from_strand = "+"

							variant_sequence = $1
							to_coord = $3.to_i
							to_chr = $2.sub(/chr/i, "")
							to_strand = "+"

							valid_translocation_f = true
						elsif alt =~ /#{ref}([ATGCN]*)\]#{chr_trans_regex}\]/i
							from_chr = chrom
							from_coord = pos
							from_strand = "+"

							variant_sequence = $1
							to_coord = $3.to_i
							to_chr = $2.sub(/chr/i, "")
							to_strand = "-"

							valid_translocation_f = true
						elsif alt =~ /\]#{chr_trans_regex}\]([ATGCN]*)#{ref}/i
							from_chr = chrom
							from_coord = pos
							from_strand = "-"

							variant_sequence = $3
							to_coord = $2.to_i
							to_chr = $1.sub(/chr/i, "")
							to_strand = "-"

							valid_translocation_f = true
						elsif alt =~ /\[#{chr_trans_regex}\[([ATGCN]*)#{ref}/i
							from_chr = chrom
							from_coord = pos
							from_strand = "-"

							variant_sequence = $3
							to_coord = $2.to_i
							to_chr = $1.sub(/chr/i, "")
							to_strand = "+"

							valid_translocation_f = true
						end

					elsif pos == 0
						if alt =~ /\.([ATGCN]*)\[#{chr_trans_regex}\[/i
							from_chr = chrom
							from_coord = pos
							from_strand = "+"

							variant_sequence = $1
							to_coord = $3.to_i
							to_chr = $2.sub(/chr/i, "")
							to_strand = "+"

							valid_translocation_f = true
						elsif alt =~ /\.([ATGCN]*)\]#{chr_trans_regex}\]/i
							from_chr = chrom
							from_coord = pos
							from_strand = "+"

							variant_sequence = $1
							to_coord = $3.to_i
							to_chr = $2.sub(/chr/i, "")
							to_strand = "-"

							valid_translocation_f = true
						elsif alt =~ /\]#{chr_trans_regex}\]([ATGCN]*)\./i
							from_chr = chrom
							from_coord = pos
							from_strand = "-"

							variant_sequence = $3
							to_coord = $2.to_i
							to_chr = $1.sub(/chr/i, "")
							to_strand = "-"

							valid_translocation_f = true
						elsif alt =~ /\[#{chr_trans_regex}\[([ATGCN]*)\./i
							from_chr = chrom
							from_coord = pos
							from_strand = "-"

							variant_sequence = $3
							to_coord = $2.to_i
							to_chr = $1.sub(/chr/i, "")
							to_strand = "+"

							valid_translocation_f = true
						end

						telomere_translocation_f = true

					end # if pos > 0

					# translocation && valid translocation、より深いチェックは convert で.
					if valid_translocation_f

						# Assembly
						vcf_variant_call_h.store(:"Assembly for Translocation Breakpoint", reference)

						vcf_variant_call_h.store(:"From Chr", from_chr)
						vcf_variant_call_h.store(:"From Coord", from_coord.to_s)
						vcf_variant_call_h.store(:"From Strand", from_strand)
						vcf_variant_call_h.store(:"To Chr", to_chr)
						vcf_variant_call_h.store(:"To Coord", to_coord.to_s)
						vcf_variant_call_h.store(:"To Strand", to_strand)
						vcf_variant_call_h.store(:"Mutation ID", mutation_id)
						vcf_variant_call_h.store(:variant_sequence, variant_sequence)
						vcf_variant_call_h.store(:mate_id, mate_id)

						if from_chr == to_chr
							sv_type = "intrachromosomal translocation"
						else
							sv_type = "interchromosomal translocation"
						end

					end

					# translocation & invalid translocation
					if translocation_f && !valid_translocation_f
						# JV_VCFS0003: Invalid chromosome rearrangement
						vcf_log_a.push("#{vcf_line_a.join("\t")} # JV_VCFS0003 Error: Describe chromosome translocations according to the VCF specification and the JVar guideline.")
						invalid_translocation_c += 1
						invalid_translocation_f = true # translocation ALT [] であるがパースできないものは error を出してエラー回避のため取り込まない
					end

				else # if alt =~ /\[.*\[/ || alt =~ /\].*\]/

					# Assembly
					vcf_variant_call_h.store(:Assembly, reference)

					# Chr
					vcf_variant_call_h.store(:Chr, chrom)

					# empty を格納しておく
					vcf_variant_call_h.store(:"From Chr", "")
					vcf_variant_call_h.store(:"From Coord", "")
					vcf_variant_call_h.store(:"From Strand", "")
					vcf_variant_call_h.store(:"To Chr", "")
					vcf_variant_call_h.store(:"To Coord", "")
					vcf_variant_call_h.store(:"To Strand", "")
					vcf_variant_call_h.store(:"Mutation ID", "")

					# ALT が translocation 以外、かつ、symbolic ALT 以外の時に . があるとエラー
					# gridss sample data で N. .N のような出力例あり
					# https://github.com/PapenfussLab/gridss/blob/master/example/DO52605T.purple.sv.vcf
					if !alt.include?("<") && alt.include?(".")
						# JV_VCFS0010: Invalid ALT allele
						vcf_log_a.push("#{vcf_line_a.join("\t")} # JV_VCFS0010 Error: Remove invalid ALT allele other than ATGCN bases, symbolic allele and translocations.")
						invalid_sv_alt_c += 1
					end

				end # if translocation

				## SV TYPE
				# 優先順位 [[/]] in ALT > ALT > SVTYPE > if there is GATK-SV INFO CPX_TYPE --> sequence alteration
				# insertion REF 複数 - indel (delin)

				# translocation 以外
				if sv_type != "intrachromosomal translocation" && sv_type != "interchromosomal translocation" && !translocation_f

					# ALT, graphtyper のような <DEL:SVSIZE=129:COVERAGE> を想定して前方一致。より specific な type が後でマッチされるのでより特異的な type が選択される
					sv_type_alt_h.each{|sv_type_symbol_key, sv_type_symbol_value|
						sv_type = sv_type_symbol_value if alt.match?(/^\<#{sv_type_symbol_key}/)
					}

					# SVTYPE
					if sv_type == "" && info_h[:SVTYPE] && sv_type_svtype_h[:"#{info_h[:SVTYPE]}"]
						sv_type = sv_type_svtype_h[:"#{info_h[:SVTYPE]}"]
					end

					# REF:CA ALT:CGCCCTTGTGACGTCACGGAAGGCGCGCGCTTGCGACGTCACGGAAGGCGCGCCCTTGTGACGTCACGGAAGGCGCT END=778706;SVTYPE=INS;SVLEN=76;CIGAR=1M76I1D のような indel
					if ref.size > 1 && ref[0] == alt[0] && !alt[1].nil? && ref[1] != alt[1] && ref.size < alt.size && sv_type == "insertion"
						sv_type = "indel"
						variant_sequence = alt[ref.size, alt.size - ref.size]
						vcf_variant_call_h.store(:variant_sequence, variant_sequence)
					end

					# REF:GCGGCCGCCTCCTCCTCCGAACGCGGCCGCCTCCTCCTCCGAACGTGGCCTCCTCCGAACGTGGCCGCCTCCTCCTCCGAACGTGGCCTCCTCCGAACGCGGCCGCCGCCTCCTCCGAACGCGGCCT ALT:GTGG END=904656;SVTYPE=DEL;SVLEN=-126;CIGAR=1M3I126D のような indel
					if ref.size > 1 && ref[0] == alt[0] && !alt[1].nil? && ref[1] != alt[1] && ref.size > alt.size && sv_type == "deletion"
						sv_type = "indel"
						#variant_sequence = alt[ref.size, alt.size - ref.size]
						#vcf_variant_call_h.store(:variant_sequence, variant_sequence)
					end

				end # unless sv_type =~ /translocation/

				# GATK-SV INFO CPX_TYPE --> sequence alteration
				if sv_type == "" && info && info.match?(/CPX_TYPE=[^;]+/)
					sv_type = "sequence alteration"
				end

				# No SVTYPE, invalid SVTYPE, ALT symbolic SV type はここでカバー
				if sv_type == ""
					# JV_VCF0019: Missing variation type
					vcf_log_a.push("#{vcf_line_a.join("\t")} # JV_VCF0019 Error: Provide variation type.")
					missing_svtype_c += 1
				end

				# Variant Call Type
				vcf_variant_call_h.store(:"Variant Call Type", sv_type)

				# SVLEN
				if info_h[:SVLEN] && !info_h[:SVLEN].empty?
					svlen = info_h[:SVLEN].sub(/^-/, "") if info_h[:SVLEN].sub(/^-/, "")
					if sv_type == "deletion" || sv_type == "insertion"
						vcf_variant_call_h.store(:"Insertion Length", svlen)
					else
						vcf_variant_call_h.store(:"Insertion Length", "")
					end
				else
					vcf_variant_call_h.store(:"Insertion Length", "")
				end

				# START/POS
				start = pos
				posrange_f = false
				if info_h[:POSrange] && info_h[:POSrange].split(",")[0] && info_h[:POSrange].split(",")[1]
					outer_start = info_h[:POSrange].split(",")[0].to_i unless info_h[:POSrange].split(",")[0] == "."
					inner_start = info_h[:POSrange].split(",")[1].to_i unless info_h[:POSrange].split(",")[1] == "."
					posrange_f = true
				end

				# END/STOP
				if info_h[:END] && info_h[:END].to_i
					stop = info_h[:END].to_i
				end

				endrange_f = false
				if info_h[:ENDrange] && info_h[:ENDrange].split(",")[0] && info_h[:ENDrange].split(",")[1]
					inner_stop = info_h[:ENDrange].split(",")[0].to_i unless info_h[:ENDrange].split(",")[0] == "."
					outer_stop = info_h[:ENDrange].split(",")[1].to_i unless info_h[:ENDrange].split(",")[1] == "."
					endrange_f = true
				end

				# VCF spec に従って END が無い場合を計算
				# Non-symbolic alleles: POS + length of REF allele + 1
				# <INS> symbolic structural variant alleles: POS + length of REF allele + 1
				# <DEL>, <DUP>, <INV> and <CNV> symbolic structural variant alleles: POS + SVLEN
				if stop == -1
					if alt.match?(/^[ATGC]+$/i) || sv_type.match?(/insertion/)
						stop = start + ref.size + 1
					elsif sv_type.match?(/deletion|duplication|inversion|copy number variation/)
						stop = start + svlen.to_i.abs
					end
				end

				# JV_VCFS0005: Invalid POSrange
				if posrange_f && pos != inner_start && pos != outer_start
					vcf_log_a.push("#{vcf_line_a.join("\t")} # JV_VCFS0005 Error: One POSrange value must be the same as the POS value.")
					invalid_posrange_c += 1
				end

				# JV_VCFS0006: Invalid ENDrange
				if endrange_f && stop != inner_stop && stop != outer_stop
					vcf_log_a.push("#{vcf_line_a.join("\t")} # JV_VCFS0006 Error: One ENDrange value must be the same as the END value.")
					invalid_endrange_c += 1
				end

				# translocation 以外の場合に start/stop を格納
				unless valid_translocation_f

					if outer_start == -1
						vcf_variant_call_h.store(:"Outer Start", "")
					else
						vcf_variant_call_h.store(:"Outer Start", outer_start.to_s)
					end

					if start == -1
						vcf_variant_call_h.store(:Start, "")
					else
						vcf_variant_call_h.store(:Start, start.to_s)
					end

					if inner_start == -1
						vcf_variant_call_h.store(:"Inner Start", "")
					else
						vcf_variant_call_h.store(:"Inner Start", inner_start.to_s)
					end

					if inner_stop == -1
						vcf_variant_call_h.store(:"Inner Stop", "")
					else
						vcf_variant_call_h.store(:"Inner Stop", inner_stop.to_s)
					end

					if stop == -1
						vcf_variant_call_h.store(:Stop, "")
					else
						vcf_variant_call_h.store(:Stop, stop.to_s)
					end

					if outer_stop == -1
						vcf_variant_call_h.store(:"Outer Stop", "")
					else
						vcf_variant_call_h.store(:"Outer Stop", outer_stop.to_s)
					end

				end

				## CIPOS CIEND
				# Start CIPOS
				cipos_f = false
				if info_h[:CIPOS] && info_h[:CIPOS].split(",")[0] && info_h[:CIPOS].split(",")[1]
					ciposleft = info_h[:CIPOS].split(",")[0].sub(/^-/, "") unless info_h[:CIPOS].split(",")[0] == "."
					ciposright = info_h[:CIPOS].split(",")[1] unless info_h[:CIPOS].split(",")[1] == "."
					cipos_f = true
				end

				# End CIEND
				# VCF spec v4.4 p14 If CIEND is missing, it is assumed to match CIPOS.
				ciend_f = false
				if info_h[:CIEND] && info_h[:CIEND].split(",")[0] && info_h[:CIEND].split(",")[1]
					ciendleft = info_h[:CIEND].split(",")[0].sub(/^-/, "") unless info_h[:CIEND].split(",")[0] == "."
					ciendright = info_h[:CIEND].split(",")[1] unless info_h[:CIEND].split(",")[1] == "."
					ciend_f = true
				elsif cipos_f
					ciendleft = ciposleft
					ciendright = ciposright
				end

				if ciposleft == -1
					vcf_variant_call_h.store(:ciposleft, "")
				else
					vcf_variant_call_h.store(:ciposleft, ciposleft)
				end

				if ciposright == -1
					vcf_variant_call_h.store(:ciposright, "")
				else
					vcf_variant_call_h.store(:ciposright, ciposright)
				end

				if ciendleft == -1
					vcf_variant_call_h.store(:ciendleft, "")
				else
					vcf_variant_call_h.store(:ciendleft, ciendleft)
				end

				if ciendright == -1
					vcf_variant_call_h.store(:ciendright, "")
				else
					vcf_variant_call_h.store(:ciendright, ciendright)
				end

				# Null に対する操作エラーを回避するため VCF にない項目を格納
				vcf_variant_call_h.store(:Contig, "")
				vcf_variant_call_h.store(:Zygosity, "")
				vcf_variant_call_h.store(:Evidence, "")
				vcf_variant_call_h.store(:Sequence, "")
				vcf_variant_call_h.store(:"Mutation Order", "")
				vcf_variant_call_h.store(:"Mutation Molecule", "")

				# FORMAT data を格納
				vcf_variant_call_h.store(:FORMAT, format_data_a)

				# SV hash を配列に格納 mate id 指定 and invalid translocation は取り込まない
				if !skipped_mate_f && !invalid_translocation_f
					vcf_variant_call_a.push(vcf_variant_call_h)
				end

			end # if vcf_type == "SV"

			# dbSNP VCF 出力用
			if vcf_type == "SNP"

				# dbSNP VCF 用に VRT を挿入
				if !vcf_line_a[7].match?(/VRT=[0-9]/) && !vrt_number.empty?

					if vcf_line_a[7].nil? || vcf_line_a[7].empty?
						vcf_line_a[7] = "VRT=#{vrt_number}"
					else
						vcf_line_a[7] = "#{vcf_line_a[7]};VRT=#{vrt_number}"
					end

				end

			end

			# dbSNP VCF content 出力と格納
			dbsnp_vcf_f.puts vcf_line_a.collect{|e| e.strip}.join("\t") if vcf_type == "SNP"
			vcf_variant_a.push(vcf_line_a.collect{|e| e.strip}.join("\t"))

		end # if content_f

	} # vcf_f.each_line

	dbsnp_vcf_f.close if vcf_type == "SNP"

	## JV_VCF0002: Duplicated VCF meta tag
	duplicated_required_header_tag_a = []
	duplicated_required_header_tag_a = required_header_tag_h.select{|k,v| v > 1}.keys

	error_vcf_header_a.push(["JV_VCF0002", "Remove duplicated VCF meta tags. #{duplicated_required_header_tag_a.join(",")}"]) unless duplicated_required_header_tag_a.empty?

	## JV_VCF0003: Invalid reference genome
	error_vcf_header_a.push(["JV_VCF0003", "Reference assembly must refer to a valid assembly db name, UCSC name, assembly RefSeq accession, or assembly INSDC accession."]) if refseq_assembly.empty?

	## SNP specific header validation
	if vcf_type == "SNP"
		## JV_VCFP0009: Invalid variation type (VRT)
		if vrt_tags_h != snp_vrt_h
			error_vcf_header_a.push(["JV_VCFP0009", "Invalid variation type (VRT) definition. Refer to the JVar VCF submission guideline to correctly define the VRT type. INFO tag: #{(vrt_tags_h.to_a - snp_vrt_h.to_a).flatten.join(" - ")}"])
		end
	end

	## JV_VCF0005: white spaces
	warning_vcf_content_a.push(["JV_VCF0005", "White space characters before/after fields are automatically removed. #{field_whitespaces_c} lines"]) if field_whitespaces_c > 0

	## JV_VCF0028: Empty line
	warning_vcf_content_a.push(["JV_VCF0028", "The empty line is automatically removed. #{empty_line_c} lines"]) if empty_line_c > 0

	## JV_VCF0036: Multi-allelic ALT allele
	error_vcf_content_a.push(["JV_VCF0036", "JVar only accepts mono-allelic ALT alleles (no commas in ALT). #{multi_allelic_c} sites"]) if multi_allelic_c > 0

	## JV_VCF0026: Same chromosome not grouped
	error_vcf_content_a.push(["JV_VCF0026", "Same chromosome not grouped. #{chr_not_grouped_c} sites"]) if chr_not_grouped_c > 0

	## JV_VCF0027: Data not sorted based on positions
	error_vcf_content_a.push(["JV_VCF0027", "Sort data based on their positions. #{not_sorted_pos_c} sites"]) if not_sorted_pos_c > 0

	## JV_VCF0008: Invalid position (POS)
	error_vcf_content_a.push(["JV_VCF0008", "Positions (POS) should be numbers. #{pos_not_number_c} sites"]) if pos_not_number_c > 0

	## JV_VCF0009: Local ID longer than 64 characters
	error_vcf_content_a.push(["JV_VCF0009", "Provide unique local IDs shorter than 64 characters. #{id_not_within_size_c} sites"]) if id_not_within_size_c > 0

	## JV_VCF0010: Missing local ID
	error_vcf_content_a.push(["JV_VCF0010", "Provide unique local IDs shorter than 64 characters. #{missing_id_c} sites"]) if missing_id_c > 0

	# JV_VCF0017: Invalid chromosome name
	error_vcf_content_a.push(["JV_VCF0017", "Chromosome name need to match the INSDC reference assembly. #{invalid_chr_c} sites"]) if invalid_chr_c > 0

	# JV_VCF0014: REF allele mismatch with reference
	error_vcf_content_a.push(["JV_VCF0014", "Need to match the reference genome on the forward orientation. #{ref_mismatch_c} sites"]) if ref_mismatch_c > 0

	# JV_VCF0013: Missing REF allele
	error_vcf_content_a.push(["JV_VCF0013", "Provide REF allele. #{missing_ref_c} sites"]) if missing_ref_c > 0

	# JV_VCF0016: Missing ALT allele
	error_vcf_content_a.push(["JV_VCF0016", "Provide ALT allele. #{missing_alt_c} sites"]) if missing_alt_c > 0

	## JV_VCF0022: Same REF and ALT alleles
	error_vcf_content_a.push(["JV_VCF0022", "REF and ALT alleles should not be the same. #{same_ref_alt_c} sites"]) if same_ref_alt_c > 0

	# JV_VCF0035: Variant at telomere
	warning_vcf_content_a.push(["JV_VCF0035", "Variant at telomere. #{telomere_c} sites"]) if telomere_c > 0

	# JV_VCF0031: Invalid INFO value format
	warning_vcf_content_a.push(["JV_VCF0031", "Provide INFO value in a valid format. #{invalid_info_c} values"]) if invalid_info_c > 0

	# JV_VCF0032: Invalid FORMAT value format
	warning_vcf_content_a.push(["JV_VCF0032", "Provide FORMAT value in a valid format. #{invalid_ft_c} values"]) if invalid_ft_c > 0

	# JV_VCF0039: Inconsistent FORMAT keys and sample values
	warning_vcf_content_a.push(["JV_VCF0039", "Number of FORMAT keys and sample values are different. #{inconsistent_format_c} values"]) if inconsistent_format_c > 0

	# JV_VCF0040: Undefined FORMAT key
	warning_vcf_content_a.push(["JV_VCF0040", "The FORMAT key is not defined in the VCF header. #{undefined_ft_key_a.sort.uniq.join(",")}"]) if undefined_ft_key_a.sort.uniq.size > 0

	# JV_VCF0041: Undefined INFO key
	warning_vcf_content_a.push(["JV_VCF0041", "The INFO key is not defined in the VCF header. #{undefined_info_key_a.sort.uniq.join(",")}"]) if undefined_info_key_a.sort.uniq.size > 0

	# JV_C0062: Calculated allele frequency
	warning_vcf_content_a.push(["JV_C0062", "Allele frequency was calculated as allele count/allele number. #{calculated_af_c} sites"]) if calculated_af_c > 0

	# JV_C0063: Allele count greater than allele number
	error_vcf_content_a.push(["JV_C0063", "Allele count is greater than allele number. #{ac_greater_than_an_c} sites"]) if ac_greater_than_an_c > 0

	## SNP overall error & warning
	if vcf_type == "SNP"

		## JV_VCF0021: Duplicated local IDs
		error_vcf_content_a.push(["JV_VCF0021", "Local IDs should be unique in a dataset/VCF. #{duplicated_id_c} sites"]) if duplicated_id_c > 0

		# JV_VCFP0006: Variation type not in defined set
		error_vcf_content_a.push(["JV_VCFP0006", "Provide variation type in the defined set. #{not_defined_vrt_c} sites"]) if not_defined_vrt_c > 0

		# JV_VCF0011: Duplicated sites
		error_vcf_content_a.push(["JV_VCF0011", "Remove duplicated sites. #{duplicated_site_c} sites"]) if duplicated_site_c > 0

		# JV_VCFP0007: Invalid REF allele
		error_vcf_content_a.push(["JV_VCFP0007", "Remove non-ATGC base from REF allele. #{invalid_ref_c} sites"]) if invalid_ref_c > 0

		# JV_VCFP0002: REF allele longer than 50 nucleotides
		error_vcf_content_a.push(["JV_VCFP0002", "Remove and submit the allele longer than 50 nucleotides to JVar-SV. #{longer_ref_c} sites"]) if longer_ref_c > 0

		# JV_VCFP0005: Invalid ALT allele
		error_vcf_content_a.push(["JV_VCFP0005", "Remove non-ATGC base from ALT allele. #{invalid_alt_c} sites"]) if invalid_alt_c > 0

		# JV_VCFP0003: ALT allele longer than 50 nucleotides
		error_vcf_content_a.push(["JV_VCFP0003", "Remove and submit the allele longer than 50 nucleotides to JVar-SV. #{longer_alt_c} sites"]) if longer_alt_c > 0

		# JV_VCF0019: Missing variation type
		error_vcf_content_a.push(["JV_VCF0019", "Provide variation type. #{missing_vrt_c} sites"]) if missing_vrt_c > 0

		# JV_VCF0023: REF and ALT alleles without leading base
		error_vcf_content_a.push(["JV_VCF0023", "Indels need leading bases in REF and ALT alleles. #{no_leading_base_indel_c} sites"]) if no_leading_base_indel_c > 0

		# JV_C0061: Chromosome position larger than chromosome size + 1
		error_vcf_content_a.push(["JV_C0061", "Chromosome position is larger than chromosome size + 1. Check if the position is correct. #{pos_outside_chr_c} sites"]) if pos_outside_chr_c > 0

		# JV_VCFP0004: Insertion and deletion at base position 1
		warning_vcf_content_a.push(["JV_VCFP0004", "Provide a base after the insertion and deletion at base position 1. #{pos_one_c} sites"]) if pos_one_c > 0

		# JV_VCFP0001: Region contains too many SNPs
		warning_vcf_content_a.push(["JV_VCFP0001", "Too many SNPs (more than 10 SNPs in 50bp). Verify these regions are legitimate. #{dense_snp_c} sites"]) if dense_snp_c > 0

	end

	## SV overall error & warning
	if vcf_type == "SV"

		 if invalid_svtype_c > 0 && !(translocation_f && sv_type.match?(/translocation/))
		 	# JV_VCFS0004: Invalid structural variation type
			error_vcf_content_a.push(["JV_VCFS0004", "Invalid structural variation type. #{invalid_svtype_c} sites"])
		end

		# JV_VCFS0009: Invalid REF allele
		error_vcf_content_a.push(["JV_VCFS0009", "Remove non-ATGCN base from REF allele. #{invalid_sv_ref_c} sites"]) if invalid_sv_ref_c > 0

		# JV_VCFS0010: Invalid ALT allele
		error_vcf_content_a.push(["JV_VCFS0010", "Remove invalid ALT allele other than ATGCN bases, symbolic allele and translocations. #{invalid_sv_alt_c} sites"]) if invalid_sv_alt_c > 0

		# JV_VCF0019: Missing variation type
		error_vcf_content_a.push(["JV_VCF0019", "Provide variation type. #{missing_svtype_c} sites"]) if missing_svtype_c > 0

		# JV_VCFS0005: Invalid POSrange
		error_vcf_content_a.push(["JV_VCFS0005", "One POSrange value must be the same as the POS value. #{invalid_posrange_c} sites"]) if invalid_posrange_c > 0

		# JV_VCFS0006: Invalid ENDrange
		error_vcf_content_a.push(["JV_VCFS0006", "One ENDrange value must be the same as the END value. #{invalid_endrange_c} sites"]) if invalid_endrange_c > 0

		# JV_VCFS0003: Invalid chromosome translocation
		error_vcf_content_a.push(["JV_VCFS0003", "Describe chromosome translocations according to the VCF specification and the JVar guideline. #{invalid_translocation_c} sites"]) if invalid_translocation_c > 0

		# JV_VCFS0013: Identical breakend mate skipped
		warning_vcf_content_a.push(["JV_VCFS0013", "One of identical breakend mates of the same MATEID was skipped. #{skipped_mate_c} sites"]) if skipped_mate_c > 0

		# mate id does not exist
		not_found_mate_id_c = 0
		mate_id_h.each{|id, mate_id|
			unless id_h.has_key?(:"#{mate_id}")
				not_found_mate_id_c += 1
			end
		}

		# JV_VCFS0012: MATEID not found
		warning_vcf_content_a.push(["JV_VCFS0012", "An ID corresponds to the MATEID does not exist. #{not_found_mate_id_c} sites"]) if not_found_mate_id_c > 0

	end

	# VCF log error and warning
	unless vcf_log_a.empty?
		vcf_log_a.each{|log_line|
			vcf_log_f.puts log_line
		}
	end

	if vcf_type == "SNP"
		return error_vcf_header_a, error_ignore_vcf_header_a, error_exchange_vcf_header_a, warning_vcf_header_a, error_vcf_content_a, error_ignore_vcf_content_a, error_exchange_vcf_content_a, warning_vcf_content_a
	elsif vcf_type == "SV"
		return error_vcf_header_a, error_ignore_vcf_header_a, error_exchange_vcf_header_a, warning_vcf_header_a, error_vcf_content_a, error_ignore_vcf_content_a, error_exchange_vcf_content_a, warning_vcf_content_a, vcf_variant_call_a, vcf_variant_region_a, vcf_log_a
	end

	vcf_log_f.close
	vcf_f.close

end

###
### 配列の次元を取得
###
# getting dimension of multidimensional array in ruby
# https://stackoverflow.com/questions/9545613/getting-dimension-of-multidimensional-array-in-ruby
def get_dimension a
	return 0 if a.class != Array
	result = 1
	a.each do |sub_a|
		if sub_a.class == Array
			dim = get_dimension(sub_a)
			result = dim + 1 if dim + 1 > result
		end
	end
	return result
end

###
### ファイルサイズを human readable に
###
def readable_file_size(size)
	case
		when size == 0
			"0"
		when size < 1000
			"%d bytes" % size
		when size < 1000000
			"%.1f KB" % (size.to_f/1000)
		when size < 1000000000
			"%.1f MB" % (size.to_f/1000000)
		when size < 1000000000000
			"%.1f GB" % (size.to_f/1000000000)
	else
		"%.1f TB" % (size.to_f/1000000000000)
	end
end

###
### 連番をまとめる
###
def range_extraction(list, prefix, digit)
	list.map{|e| e.sub(/#{prefix}/, "").to_i}.chunk_while {|i, j| i + 1 == j }.map do |a|
		if a.size > 1
			"#{prefix}#{a.first.to_s.rjust(digit, "0")}-#{prefix}#{a.last.to_s.rjust(digit, "0")}"
		else
			"#{prefix}#{a[0].to_s.rjust(digit, "0")}"
		end
	end.join(',')
end

###
### sheet array parse
###

# 縦書き表をパース
# base_number は基軸となる必須カラム番号を 0 スタートで指定、1 or 2 必須のような場合は [1,2]
def table_parse(table_input_a, base_number_a, object)

	i = 0
	l = 0
	header_a = []
	header_size = 0
	table_a = []
	parsed_table_a = []
	error_missing_key_a = []
	for line_a in table_input_a

		# ヘッダー行以降を格納
		if line_a.join("") =~ /^#[^#]/
			first = true
			line_a.each{|item|
				if first
					header_a.push(item.sub(/^# */, ""))
					first = false
				else
					header_a.push(item)
				end
			}

			header_size = header_a.size
			next

		end

		# name などの先頭列以外が無いと格納しない必須列
		skip = true
		for base_number in base_number_a
			if !line_a[base_number].nil? && !line_a[base_number].empty?
				skip = false
			end
		end

		# 基軸が無ければエラーメッセージを出して格納をスキップ
		if skip
			error_missing_key_a.push(line_a) if !line_a.empty? && line_a.size != 1
			next
		end

		j = 0
		line_each_h = {}
		for item in line_a

			# each line
			line_each_h.store(:"#{header_a[j]}", item)
			j += 1

		end

		# トリミングで最後まで続く空の列は削除されているので、リストア
		if (header_size - j) > 0
			(header_size - j).times{|a|
				line_each_h.store(:"#{header_a[j]}", "")
				j += 1
			}
		end

		# tsv log 出力用に入力行を格納
		line_each_h.store(:row, line_a)

		parsed_table_a.push(line_each_h)

		l += 1

	end # table_input_a

	# 属性名ベースで格納
	attr_table_h = {}
	for header_attr in header_a

		column_a = []
		for item_h in parsed_table_a
			column_a.push(item_h[:"#{header_attr}"].nil? ? "" : item_h[:"#{header_attr}"])
		end

		attr_table_h.store(:"#{header_attr}", column_a)

	end

	return parsed_table_a, attr_table_h, error_missing_key_a

end # def

###
### publication info from pubmed id
###

# pubmed id から書誌情報を取得
def pubinfo_pmid(pmid_a)

	pub_s = ""
	submitter_handle = "JVAR"
	error_ignore_method_a = []

	for pmid in pmid_a

		pub_year = ""
		pub_title = ""

		if pmid =~ /^\d{1,}$/

			uri = URI.parse("https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&rettype=docsum&retmode=json&id=#{pmid}")
			response = Net::HTTP.get(uri)

			pub_h = JSON.parse(response)

			if pub_h["result"] && pub_h["result"][pmid] && !pub_h["result"][pmid]["error"]
				if pub_h["result"] && pub_h["result"][pmid] && pub_h["result"][pmid]["pubdate"] =~ /([12]\d{3})/
					pub_year = $1
				end

				if pub_h["result"] && pub_h["result"][pmid] && pub_h["result"][pmid]["title"]
					pub_title = pub_h["result"][pmid]["title"]
				end
			end

			if !pmid.empty? && !pub_year.empty? && !pub_title.empty?

pub_s += <<EOS
TYPE:\tPUB
HANDLE:\t#{submitter_handle}
PMID:\t#{pmid}
TITLE:\t#{pub_title}
YEAR:\t#{pub_year}
STATUS:\t4
||
EOS
			else # if !pmid.empty? && !pub_year.empty? && !pub_title.empty?

				## JV_C0018: Invalid PubMed ID
				error_ignore_method_a.push(["JV_C0018", "PubMed ID must be a valid publication #{pmid}"])

			end # if !pmid.empty? && !pub_year.empty? && !pub_title.empty?

		else # if pmid =~ /\d{1,}/

			## JV_C0018: Invalid PubMed ID
			error_ignore_method_a.push(["JV_C0018", "PubMed ID must be a valid publication #{pmid}"])

		end # if pmid =~ /\d{1,}/

	end # for pmid in pmid_a

	return pub_s, error_ignore_method_a

end