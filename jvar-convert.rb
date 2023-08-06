#! /usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'rubygems'
require 'roo'
require 'optparse'
require 'net/http'
require 'json'
require 'jsonl'
require 'builder'
require 'open3'
require './lib/jvar-method.rb'
require './lib/jvar-config.rb'
#sin require '/usr/local/bin/lib/jvar-method.rb'
#sin require '/usr/local/bin/lib/jvar-config.rb'

#
# Bioinformation and DDBJ Center
# Japan Variation Database (JVar)
#
# Submission type: SNP - Generate JVar-SNP TSV (dbSNP TSV)
# Submission type: SV - Generate JVar-SV XML (dbVar XML)
#

# Update history
# 2023-03-23 created

# ファイルオープン順序
# スパコン jvar 直下での実行を想定
# 1. 引数でエクセルが指定された場合、そのエクセルを開く
# 2. VCF はエクセルからの相対パスで探す
# エクセルが引数指定されていない場合
# 3. submission ID 配下の所定エクセル submission/VSUB000001/VSUB000001_SV/SNP.xlsx
# 4. VCF はエクセルの所在場所直下 submitted/ の下を相対パスで探す

### Options
submission_id = ""
xsd_f = false
$ref_check_f = true
$info_regex_f = true
$format_regex_f = true
OptionParser.new{|opt|

	opt.on('-v [VSUB ID]', 'VSUB submission ID'){|v|
		raise "usage: -v JVar submission ID (VSUB000001)" if v.nil? || !(/^VSUB\d{6}$/ =~ v)
		submission_id = v
		puts "JVar Submission ID: #{v}"
	}

	opt.on('-s', 'skip REF base identity check'){|v|
		$ref_check_f = false
		puts "Skip REF base identity check"
	}

	opt.on('-i', 'skip INFO regex check'){|v|
		$info_regex_f = false
		puts "Skip INFO regex check"
	}

	opt.on('-f', 'skip FORMAT regex check'){|v|
		$format_regex_f = false
		puts "Skip FORMAT regex check"
	}

	opt.on('-x', 'dbVar xsd validation'){|v|
		xsd_f = true
		puts "Validate against dbVar xsd"
	}

	begin
		opt.parse!
	rescue
		puts "Invalid option. #{opt}"
	end

	puts ""

}

# VSUB ない場合はエラー
raise "Specify a valid submission_id." if submission_id.empty?

## 設定
# sin_path = "/usr/local/bin/"
sin_path = ""

sub_path = "#{sin_path}submission"

$submitter_handle = "JVAR"
ref_download_path = "#{sin_path}reference-download"

$ref_download_h = {}
Dir.glob("#{ref_download_path}/*fna").each{|dl_fna|

	accession = ""
	length = ""

	if dl_fna =~ /\.fna$/
		accession = File.basename(dl_fna).sub(".fna", "")

		# if there is an index and length
		if FileTest.exist?("#{ref_download_path}/#{accession}.fna.fai")
			open("#{ref_download_path}/#{accession}.fna.fai").each{|fai_line|
				length = fai_line.split("\t")[1] if fai_line.split("\t")[1]
			}
		end

		if !accession.empty? && !length.empty?
			$ref_download_h.store(accession, length)
		end

	end
}

# SV is provided by VCF
vcf_sv_f = ""

vcf_file_a = []
vc_input_filename = ""

submission_type = ""
bioproject_accession = ""
biosample_accession_a = []
sample_name_a = []

# Download a contig fasta by an INSDC accession.
contig_download_a = []
contig_download_s = ""

## error, error_ignore, warning,
warning_snp_a = []
error_snp_a = []
error_ignore_snp_a = []
error_exchange_snp_a = []

warning_sv_a = []
error_sv_a = []
error_ignore_sv_a = []
error_exchange_sv_a = []

warning_common_a = []
error_common_a = []
error_ignore_common_a = []
error_exchange_common_a = []

# vcf header & content, error and warning
error_vcf_header_h = {}
error_ignore_vcf_header_h = {}
error_exchange_vcf_header_h = {}
warning_vcf_header_h = {}
error_vcf_content_h = {}
error_ignore_vcf_content_h = {}
error_exchange_vcf_content_h = {}
warning_vcf_content_h = {}

# variant call, error and warning
error_sv_vc_h = {}
error_ignore_sv_vc_h = {}
warning_sv_vc_h = {}

snp_genotype_f = false
sv_genotype_f = false

limit_for_etc = 5

# variant call 格納
total_variant_call_h = {}

### Function
def clean_number(num)

	if num.is_a?(Float) && num.to_s.match?(/\.0$/)
		return num.to_i
	else
		return num
	end

end

###
### SNP/SV common settings
###

# XML instruction
instruction = '<?xml version="1.0" encoding="UTF-8"?>'

## XREF
xref_db_phenotypes_regex = $xref_db_h[:Phenotypes].join("|")
xref_db_all_regex = $xref_db_h.values.join("|")

## assembly from NCBI Dataset
allowed_assembly_a = []
$assembly_a.each{|assembly_h|
	allowed_assembly_a.push(assembly_h.values)
}
allowed_assembly_a = allowed_assembly_a.flatten

## Globally defined samples (e.g. Hapmap, 1000 Genomes, https://www.internationalgenome.org/data-portal/sample)
defined_samples_list_h = {}
for defined_sample_name, defined_sample_h in $defined_samples_h
	defined_samples_list_h.store(defined_sample_h[:sample_name], 0) if defined_sample_h[:sample_name] && !defined_sample_h[:sample_name].empty?
	defined_samples_list_h.store(defined_sample_h[:biosample_accession], 0) if defined_sample_h[:biosample_accession] && !defined_sample_h[:biosample_accession].empty?
	defined_samples_list_h.store(defined_sample_h[:population_code], 0) if defined_sample_h[:population_code] && !defined_sample_h[:population_code].empty?
	defined_samples_list_h.store(defined_sample_h[:superpopulation_code], 0) if defined_sample_h[:superpopulation_code] && !defined_sample_h[:superpopulation_code].empty?
end

### Read the JVar submission excel file

# open xlsx file
excel_path = ""
if ARGV[0]
	s = Roo::Excelx.new(ARGV[0])
	excel_path = File.dirname(ARGV[0])
	vcf_path = excel_path
elsif FileTest.exist?("#{sub_path}/#{submission_id}/#{submission_id}_SNP.xlsx")
	s = Roo::Excelx.new("#{sub_path}/#{submission_id}/#{submission_id}_SNP.xlsx")
	excel_path = "#{sub_path}/#{submission_id}"
	vcf_path = "#{sub_path}/#{submission_id}/submitted"
elsif FileTest.exist?("#{sub_path}/#{submission_id}/#{submission_id}_SV.xlsx")
	s = Roo::Excelx.new("#{sub_path}/#{submission_id}/#{submission_id}_SV.xlsx")
	excel_path = "#{sub_path}/#{submission_id}"
	vcf_path = "#{sub_path}/#{submission_id}/submitted"
else
	raise "No JVar metadata excel to open."
end

# sheets
object_a = ['Study', 'SampleSet', 'Sample', 'Experiment', 'Dataset', 'Variant Call (SV)', 'Variant Region (SV)']

# array for metadata objects
study_sheet_a = Array.new
study_store_h = Hash.new
sampleset_sheet_a = Array.new
sample_sheet_a = Array.new
experiment_sheet_a = Array.new
dataset_sheet_a = Array.new
small_variant_sheet_a = Array.new
variant_call_sheet_a = Array.new
variant_region_sheet_a = Array.new

# open a sheet and put data into an array with line number
for object in object_a

	s.default_sheet = object

	i = 1 # line number
	for line_a in s

		# trailing nil を削除、文字列に変換、"" を削除、値を strip
		line_trimmed_a = line_a.reverse.drop_while(&:nil?).map(&:to_s).drop_while(&:empty?).reverse.map{|v| v.strip}

		# コメント行と空のアレイをスキップ
		next if line_trimmed_a[0].nil? || line_trimmed_a.empty? || line_trimmed_a[0].start_with?("##")

		case object

		when "Study" then
			study_sheet_a.push(line_trimmed_a)
			study_store_h.store(:"#{line_trimmed_a[0]}", line_trimmed_a[1..-1])
		when "SampleSet" then
			sampleset_sheet_a.push(line_trimmed_a)
		when "Sample" then
			sample_sheet_a.push(line_trimmed_a)
		when "Experiment" then
			experiment_sheet_a.push(line_trimmed_a)
		when "Dataset" then
			dataset_sheet_a.push(line_trimmed_a)
		when "Variant Call (SV)" then
			variant_call_sheet_a.push(line_trimmed_a)
		when "Variant Region (SV)" then
			variant_region_sheet_a.push(line_trimmed_a)
		end

		i += 1

	end

end

##
## Submission and Study
##
submission_h = Hash.new
study_h = Hash.new

## Submission
submission_h.store(:"Submission Type", study_store_h[:"Submission Type"][0])

submission_h.store(:"Hold/Release", study_store_h[:"Hold/Release"][0])

submitter_a = []
study_store_h[:"Submitter Last Name"].size.times{|i|
	submitter_each_h = {}
	submitter_each_h.store(:"Submitter Last Name", study_store_h[:"Submitter Last Name"][i].nil? ? "" : study_store_h[:"Submitter Last Name"][i])
	submitter_each_h.store(:"Submitter Middle Name", study_store_h[:"Submitter Middle Name"][i].nil? ? "" : study_store_h[:"Submitter Middle Name"][i])
	submitter_each_h.store(:"Submitter First Name", study_store_h[:"Submitter First Name"][i].nil? ? "" : study_store_h[:"Submitter First Name"][i])
	submitter_each_h.store(:"Submitter Email", study_store_h[:"Submitter Email"][i].nil? ? "" : study_store_h[:"Submitter Email"][i])
	submitter_each_h.store(:"Submitter Affiliation", study_store_h[:"Submitter Affiliation"][i].nil? ? "" : study_store_h[:"Submitter Affiliation"][i])
	submitter_a.push(submitter_each_h)
}

submission_h.store(:Submitter, submitter_a)
submission_h.store(:"Submission Date", study_store_h[:"Submission Date"][0].nil? ? "" : study_store_h[:"Submission Date"][0])
submission_h.store(:"Public Release Date", study_store_h[:"Public Release Date"][0].nil? ? "" : study_store_h[:"Public Release Date"][0])
submission_h.store(:"Last Update Date", study_store_h[:"Last Update Date"][0].nil? ? "" : study_store_h[:"Last Update Date"][0])
submission_h.store(:vload_id, study_store_h[:vload_id][0].nil? ? "" : study_store_h[:vload_id][0])

## Study
study_h.store(:"Submission Type", study_store_h[:"Submission Type"][0])
study_h.store(:"Study Title", study_store_h[:"Study Title"][0].nil? ? "" : study_store_h[:"Study Title"][0])
study_h.store(:"Study Description", study_store_h[:"Study Description"][0].nil? ? "" : study_store_h[:"Study Description"][0])
study_h.store(:"Study Type", study_store_h[:"Study Type"][0].nil? ? "" : study_store_h[:"Study Type"][0])
study_h.store(:"PubMed ID", study_store_h[:"PubMed ID"].empty? ? "" : study_store_h[:"PubMed ID"])
study_h.store(:"Publication DOI", study_store_h[:"Publication DOI"][0].nil? ? "" : study_store_h[:"Publication DOI"][0])
study_h.store(:"BioProject Accession", study_store_h[:"BioProject Accession"][0].nil? ? "" : study_store_h[:"BioProject Accession"][0])
study_h.store(:"Study URL", study_store_h[:"Study URL"][0].nil? ? "" : study_store_h[:"Study URL"][0])
study_h.store(:"Related Study", study_store_h[:"Related Study"][0].nil? ? "" : study_store_h[:"Related Study"][0])
study_h.store(:"Study ID", study_store_h[:"Study ID"][0].nil? ? "" : study_store_h[:"Study ID"][0])
study_h.store(:vload_id, study_store_h[:vload_id][0].nil? ? "" : study_store_h[:vload_id][0])

###
### SampleSet
###
sampleset_a, sampleset_h, sampleset_table_parse_error_a = table_parse(sampleset_sheet_a, [3], "SampleSet")
unless sampleset_table_parse_error_a.empty?
	error_common_a.push(["JV_C0058", "Provide a required key value. SampleSet: SampleSet Name"])
end

###
### Sample
###
sample_a, sample_h, sample_table_parse_error_a = table_parse(sample_sheet_a, [1], "Sample")

unless sample_table_parse_error_a.empty?
	error_common_a.push(["JV_C0058", "Provide a required key value. Sample: Sample Name"])
end

###
### Experiment
###
experiment_pre_a, experiment_pre_h, experiment_table_parse_error_a = table_parse(experiment_sheet_a, [1,2], "Experiment")
unless experiment_table_parse_error_a.empty?
	error_common_a.push(["JV_C0058", "Provide a required key value. Experiment: Experiment Type and Method Type"])
end

###
### Dataset
###
dataset_a, dataset_h, dataset_table_parse_error_a = table_parse(dataset_sheet_a, [2], "Dataset")
unless dataset_table_parse_error_a.empty?
	error_common_a.push(["JV_C0058", "Provide a required key value. Dataset: Experiment ID"])
end

###
### Variant Call
###
variant_call_table_parse_error_a = []
variant_call_a, variant_call_h, variant_call_table_parse_error_a = table_parse(variant_call_sheet_a, [0], "Variant Call")
variant_call_from_vcf_a = []
variant_call_sheet_header_a = []
variant_call_sheet_header_a = variant_call_sheet_a[0].map{|e| e.sub(/^# */, "")} if variant_call_sheet_a[0]
unless variant_call_table_parse_error_a.empty?
	error_common_a.push(["JV_C0058", "Provide a required key value. Variant Call: Variant Call ID"])
end

###
### Variant Region
###
variant_region_a, variant_region_h, variant_region_table_parse_error_a = table_parse(variant_region_sheet_a, [0], "Variant Region")
variant_region_from_vcf_a = []
variant_region_sheet_header_a = []
variant_region_sheet_header_a = variant_region_sheet_a[0].map{|e| e.sub(/^# */, "")} if variant_region_sheet_a[0]
unless variant_region_table_parse_error_a.empty?
	error_common_a.push(["JV_C0058", "Provide a required key value. Variant Region: Variant Region ID"])
end

##
## Common checks
##

# JV_C0008: Missing Dataset
if dataset_a.empty?
	error_common_a.unshift(["JV_C0008", "Dataset is missing."])
end

# JV_C0007: Missing Experiment
if experiment_pre_a.empty?
	error_common_a.unshift(["JV_C0007", "Experiment is missing."])
end

# JV_C0005: Missing SampleSet
if sampleset_a.empty?
	error_common_a.unshift(["JV_C0005", "SampleSet is missing."])
end

# JV_C0002: Missing Study
if study_h.empty?
	error_common_a.unshift(["JV_C0002", "Study is missing."])
end

# JV_C0001: Missing Submission
if submission_h.empty?
	error_common_a.unshift(["JV_C0001", "Submission is missing."])
end

## Experiment initial checks

# dbSNP 用 METHOD 作成、merge experiment の dbSNP METHOD 用結合
experiment_a = []
experiment_h = {}
experiment_id_a = []
non_merging_experiment_id_a = []
experiment_id_method_category_h = {}
for experiment_pre in experiment_pre_a

	experiment_id_a.push(experiment_pre[:"Experiment ID"].to_i) unless experiment_pre[:"Experiment ID"].empty?

	# merge 以外で METHOD を作成
	if experiment_pre[:"Method Type"] != "Merging" && experiment_pre[:"Analysis Type"] != "Merging"

		non_merging_experiment_id_a.push(experiment_pre[:"Experiment ID"].to_i)

		## Method category
		# experiment_pre[:"Method Type"]

		#experiment_id_method_category_h.store(experiment_pre["Experiment ID"], )

		## JV_C0048: Merged Experiment exist for non-Merging method and analysis types
		error_ignore_common_a.push(["JV_C0048", "Merged Experiment must only exist in an experiment with Method Type=Merging and Analysis Type=Merging Experiment ID: #{experiment_pre[:"Experiment ID"]}"]) unless experiment_pre[:"Merged Experiment IDs"].empty?

		method_a = []
		experiment_pre.each{|key_sym, value|
			method_a.push("#{key_sym}:#{value}") if !value.empty? && !["Merged Experiment IDs", "Experiment ID", "row"].include?("#{key_sym}")
		}

		method = method_a.join("\n")
		experiment_pre.store(:METHOD, method)
		experiment_a.push(experiment_pre)

	end

end

## JV_C0053: Duplicated Experiment ID
error_common_a.push(["JV_C0053", "Experiment ID must be unique within the study. Experiment ID: #{experiment_id_a.select{|e| experiment_id_a.count(e) > 1 }.sort.uniq.join(",")}"]) unless experiment_id_a.select{|e| experiment_id_a.count(e) > 1 }.empty?

# ループを再度回して merge experiment の METHOD 結合処理
for experiment_pre in experiment_pre_a

	# merge 対象 experiment を結合
	if experiment_pre[:"Method Type"] == "Merging" || experiment_pre[:"Analysis Type"] == "Merging"
		combined_method_a = ["Following multiple methods were performed."]
		combined_method_s = ""

		eid_count = 0
		experiment_pre[:"Merged Experiment IDs"].split(/ *, */).each{|eid|

			eid_count += 1

			## JV_C0047: Invalid Merged Experiment ID reference
			if !non_merging_experiment_id_a.include?(eid.to_i)
				error_ignore_common_a.push(["JV_C0047", "Merged Experiment/Experiment ID must refer to a valid experiment with the same Experiment Type. Experiment ID: #{eid}"])
			end

			for experiment in experiment_a
				if experiment[:"Experiment ID"] == eid.to_i
					combined_method_a.push(experiment[:METHOD])

					## JV_C0047: Invalid Merged Experiment ID reference
					error_ignore_common_a.push(["JV_C0047", "Merged Experiment/Experiment ID must refer to a valid experiment with the same Experiment Type. Experiment ID: #{eid}"]) if experiment[:"Experiment Type"] != experiment_pre[:"Experiment Type"]
				end
			end

		}

		## JV_C0049: Missing merged Experiment for Merging method and analysis types
		error_ignore_common_a.push(["JV_C0049", "When Method Type=Merging and Analysis Type=Merging, there must be multiple merged experiment. Merged Experiment IDs: #{experiment_pre[:"Merged Experiment IDs"]}"]) unless eid_count > 1

		combined_method_s = combined_method_a.join("\n\n")

		experiment_pre.store(:METHOD, combined_method_s)
		experiment_a.push(experiment_pre)

	end

end

## JV_C0004: Invalid Submission Type
submission_type_a = ["Short genetic variations", "Structural variations"]

unless submission_type_a.include?(submission_h[:"Submission Type"])
	error_common_a.push(["JV_C0004", 'A submission type must be either "Short genetic variations" or "Structural variations"'])
else
	if submission_h[:"Submission Type"] == "Short genetic variations"
		submission_type = "SNP"
	elsif submission_h[:"Submission Type"] == "Structural variations"
		submission_type = "SV"
	end
end

# 必須エラーチェック
# CV チェック
for object in $required_fields_error_h.keys

	case object

	when "Study" then

		# Submission
		submission_h.each{|key_sym, value|

			# 必須
			if value == "Submitter"
				$required_fields_error_h[object].each{|field|
					value.each{|submitter_key_sym, submitter_value|
						if "#{submitter_key_sym}" == field
							error_common_a.push(["JV_C0009", "#{object} has missing mandatory field(s) #{submitter_key_sym}."]) if submitter_value.nil? || submitter_value.empty?
						end
					}
				}
			else

				# 必須
				$required_fields_error_h[object].each{|field|
					if "#{key_sym}" == field
						error_common_a.push(["JV_C0009", "#{object} has missing mandatory field(s) #{key_sym}."]) if value.nil? || value.empty?
					end
				}

				# CV
				if value && !value.to_s.empty? && $cv_h[object] && $cv_h[object]["#{key_sym}"] && !$cv_h[object]["#{key_sym}"].include?(value)
					## JV_C0057: Invalid value for controlled terms
					error_ignore_common_a.push(["JV_C0057", "Value is not in controlled terms. #{object} #{key_sym}:#{value}"])
				end

			end

		}

		# Study
		study_h.each{|key_sym, value|

			$required_fields_error_h[object].each{|field|
				if "#{key_sym}" == field
					error_common_a.push(["JV_C0009", "#{object} has missing mandatory field(s) #{key_sym}."]) if value.nil? || value.empty?
				end
			}

			# CV
			if value && !value.empty? && $cv_h[object] && $cv_h[object]["#{key_sym}"] && !$cv_h[object]["#{key_sym}"].include?(value)
				## JV_C0057: Invalid value for controlled terms
				error_ignore_common_a.push(["JV_C0057", "Value is not in controlled terms. #{object} #{key_sym}:#{value}"])
			end

		}

	when "SampleSet" then

		for sampleset in sampleset_a
			$required_fields_error_h[object].each{|field|
				sampleset.each{|key_sym, value|
					if key == field
						error_common_a.push(["JV_C0009", "#{object} has missing mandatory field(s) #{key_sym}."]) if value.nil? || value.empty?
					end
				} # sampleset.each{|key, value|
			} # $required_fields_error_h[object].each{|field|

			sampleset.each{|key_sym, value|
				# CV
				if value && !value.empty? && $cv_h[object] && $cv_h[object]["#{key_sym}"] && !$cv_h[object]["#{key_sym}"].include?(value)
					## JV_C0057: Invalid value for controlled terms
					error_ignore_common_a.push(["JV_C0057", "Value is not in controlled terms. #{object} #{key_sym}:#{value}"])
				end
			}

		end

	when "Sample" then

		for sample in sample_a
			$required_fields_error_h[object].each{|field|
				sample.each{|key, value|
					if key == field
						error_common_a.push(["JV_C0009", "#{object} has missing mandatory field(s) #{key}."]) if value.nil? || value.empty?
					end
				} # sample.each{|key, value|
			} # $required_fields_error_h[object].each{|field|

			sample.each{|key, value|
				# CV
				if value && !value.empty? && $cv_h[object] && $cv_h[object][key] && !$cv_h[object][key].include?(value)
					## JV_C0057: Invalid value for controlled terms
					error_ignore_common_a.push(["JV_C0057", "Value is not in controlled terms. #{object} #{key}:#{value}"])
				end
			}

		end

	when "Experiment" then

		for experiment in experiment_a
			unless experiment[:"Method Type"] == "Merging"
				$required_fields_error_h[object].each{|field|
					experiment.each{|key_sym, value|
						if "#{key_sym}" == field
							error_common_a.push(["JV_C0009", "#{object} has missing mandatory field(s) #{key_sym}."]) if value.nil? || value.empty?
						end
					} # experiment.each{|key, value|
				} # $required_fields_error_h[object].each{|field|
			end

			experiment.each{|key_sym, value|
				# CV
				if value && !value.empty? && $cv_h[object] && $cv_h[object]["#{key_sym}"] && !$cv_h[object]["#{key_sym}"].include?(value)
					## JV_C0057: Invalid value for controlled terms
					error_ignore_common_a.push(["JV_C0057", "Value is not in controlled terms. #{object} #{key_sym}:#{value}"])
				end
			}

		end

	when "Dataset" then

		for dataset in dataset_a
			$required_fields_error_h[object].each{|field|
				dataset.each{|key_sym, value|
					if key == field
						error_common_a.push(["JV_C0009", "#{object} has missing mandatory field(s) #{key_sym}."]) if value.nil? || value.empty?
					end
				} # dataset.each{|key, value|
			} # $required_fields_error_h[object].each{|field|

			dataset.each{|key_sym, value|
				# CV
				if value && !value.empty? && $cv_h[object] && $cv_h[object]["#{key_sym}"] && !$cv_h[object]["#{key_sym}"].include?(value)
					## JV_C0057: Invalid value for controlled terms
					error_ignore_common_a.push(["JV_C0057", "Value is not in controlled terms. #{object} #{key_sym}:#{value}"])
				end
			}

		end

	end # case

end # for object in $required_fields_error_h.keys

# 必須エラー ignore チェック
for object in $required_fields_error_ignore_h.keys

	case object

	when "Study" then

		# Submission
		submission_h.each{|key_sym, value|

			if value == "Submitter"
				$required_fields_error_ignore_h[object].each{|field|
					value.each{|submitter_key_sym, submitter_value|
						if "#{submitter_key_sym}" == field
							error_ignore_common_a.push(["JV_C0010", "#{object} has missing mandatory field(s) #{submitter_key_sym}."]) if submitter_value.nil? || submitter_value.empty?
						end
					}
				}
			else
				$required_fields_error_ignore_h[object].each{|field|
					if key_sym == field
						error_ignore_common_a.push(["JV_C0010", "#{object} has missing mandatory field(s) #{key_sym}."]) if value.nil? || value.empty?
					end
				}
			end

		}

		# Study
		study_h.each{|key_sym, value|

			$required_fields_error_ignore_h[object].each{|field|
				if "#{key_sym}" == field
					error_common_a.push(["JV_C0009", "#{object} has missing mandatory field(s) #{key_sym}."]) if value.nil? || value.empty?
				end
			}

		}

	when "SampleSet" then

		for sampleset in sampleset_a
			$required_fields_error_ignore_h[object].each{|field|
				sampleset.each{|key_sym, value|
					if "#{key_sym}" == field
						error_ignore_common_a.push(["JV_C0010", "#{object} has missing mandatory field(s) #{key_sym}."]) if value.nil? || value.empty?
					end
				} # sampleset.each{|key, value|
			} # $required_fields_error_ignore_h
		end

	when "Sample" then

		for sample in sample_a
			$required_fields_error_ignore_h[object].each{|field|
				sample.each{|key_sym, value|
					if "#{key_sym}" == field
						error_ignore_common_a.push(["JV_C0010", "#{object} has missing mandatory field(s) #{key_sym}."]) if value.nil? || value.empty?
					end
				} # sample.each{|key, value|
			} # $required_fields_error_ignore_h
		end

	when "Experiment" then

		for experiment in experiment_a
			unless experiment[:"Method Type"] == "Merging"
				$required_fields_error_ignore_h[object].each{|field|
					experiment.each{|key_sym, value|
						if "#{key_sym}" == field
							error_ignore_common_a.push(["JV_C0010", "#{object} has missing mandatory field(s) #{key_sym}."]) if value.nil? || value.empty?
						end
					} # sampleset.each{|key, value|
				} # $required_fields_error_ignore_h
			end # unless experiment[:"Method Type"] == "Merging"
		end

	when "Dataset" then

		for dataset in dataset_a
			$required_fields_error_ignore_h[object].each{|field|
				dataset.each{|key_sym, value|
					if "#{key_sym}" == field
						error_ignore_common_a.push(["JV_C0010", "#{object} has missing mandatory field(s) #{key_sym}."]) if value.nil? || value.empty?
					end
				} # dataset.each{|key, value|
			} # $required_fields_error_ignore_h
		end

	end

end

## JV_C0011: Invalid Study ID format
if !study_h[:"Study ID"].empty? && !study_h[:"Study ID"].match?(/^[A-Za-z]+2\d{3}[a-z]?$/)
	warning_common_a.push(["JV_C0011", "Study ID is not formatted as AuthorYear"])
end

## JV_C0016: Invalid BioProject accession
if !study_h[:"BioProject Accession"].empty? && !study_h[:"BioProject Accession"].match?(/^PRJDB\d{1,}$/)
	warning_common_a.push(["JV_C0016", "BioProject accession must be a valid accession in BioProject"])
else
	bioproject_accession = study_h[:"BioProject Accession"]
end

## JV_C0018: Invalid PubMed ID
if !study_h[:"PubMed ID"].empty?
	pub_s, error_ignore_method_a = pubinfo_pmid(study_h[:"PubMed ID"])
	error_ignore_common_a =  error_ignore_common_a + error_ignore_method_a unless error_ignore_method_a.empty?
end

## Subject and family check
# subject id と性別を格納
subject_id_a = []
for sample in sample_a
	subject_id_a.push(sample[:"Subject ID"]) unless sample[:"Subject ID"].empty?
end

## JV_C0029 Duplicated Subject ID
unless subject_id_a.select{|e| subject_id_a.count(e) > 1 }.empty?
	error_common_a.push(["JV_C0029", "Duplicated Subject ID #{subject_id_a.select{|e| subject_id_a.count(e) > 1 }.sort.uniq.join(",")}"])
end

##
## SampleSet common check
##
sampleset_id_a = []
sampleset_name_a = []
sampleset_id_size_h = {}
sampleset_id_sex_h = {}
sampleset_name_per_sampleset_h = {}
for sampleset in sampleset_a

	sampleset_id = sampleset[:"SampleSet ID"].to_i
	unless sampleset[:"SampleSet ID"].empty?
		sampleset_id_a.push(sampleset_id)
	end

	unless sampleset[:"SampleSet Name"].empty?
		sampleset_name_a.push(sampleset[:"SampleSet Name"])
		sampleset_name_per_sampleset_h.store(sampleset_id, [sampleset[:"SampleSet Name"]])
	end

	unless sampleset[:"SampleSet Size"].empty?
		sampleset_id_size_h.store(sampleset_id, sampleset[:"SampleSet Size"])
	end

	unless sampleset[:"SampleSet Sex"].empty?
		sampleset_id_sex_h.store(sampleset_id, sampleset[:"SampleSet Sex"])
	end

end

##
## Subject check
##
sample_sampleset_id_a = []
sample_name_accession_h = {}
sampleset_biosample_acc_h = {}
biosample_accession_per_sampleset_h = {}
sample_name_per_sampleset_h = {}
sample_sampleset_id_a = []
for sample in sample_a

	unless sample[:"Sample Name"].empty?
		sample_name_a.push(sample[:"Sample Name"])
	end

	# sample name to biosample accession
	if !sample[:"Sample Name"].empty? && !sample[:"BioSample Accession"].empty?

		sample_name_accession_h.store(:"#{sample[:"Sample Name"]}", sample[:"BioSample Accession"])
		biosample_accession_a.push(sample[:"BioSample Accession"])
		sample_sampleset_id_a.push(sample[:"SampleSet ID"].to_i)

		# SampleSet ID and BioSample accession
		unless sampleset_biosample_acc_h[sample[:"SampleSet ID"]]
			sampleset_biosample_acc_h[sample[:"SampleSet ID"].to_i] = [sample[:"BioSample Accession"]]
		else
			sampleset_biosample_acc_h[sample[:"SampleSet ID"].to_i].push(sample[:"BioSample Accession"])
		end
	end

	## Maternal ID
	if !sample[:"Subject Maternal ID"].empty?
		unless subject_id_a.include?(sample[:"Subject Maternal ID"])
			## JV_C0020 Invalid Maternal ID
			error_ignore_common_a.push(["JV_C0020", "Subject Maternal ID must reference a subject in the same study #{sample[:"Subject Maternal ID"]}"])
		else
			sample_a.each{|sample_2|
				## JV_C0021 Non-female Maternal ID
				error_ignore_common_a.push(["JV_C0021", "Subject Maternal ID must reference a subject which is Female #{sample[:"Subject Maternal ID"]}"]) if sample_2[:"Subject ID"] == sample[:"Subject Maternal ID"] && sample_2[:"Subject Sex"] != "Female"
			}
			## JV_C0027 Subject is its own mother
			error_ignore_common_a.push(["JV_C0027", "Subject is its own mother #{sample[:"Subject Maternal ID"]}"]) if sample[:"Subject ID"] == sample[:"Subject Maternal ID"]
		end
	end

	## Paternal ID
	if !sample[:"Subject Paternal ID"].empty?
		unless subject_id_a.include?(sample[:"Subject Paternal ID"])
			## JV_C0024 Invalid Paternal ID
			error_ignore_common_a.push(["JV_C0024", "Subject Paternal ID must reference a subject in the same study #{sample[:"Subject Paternal ID"]}"])
		else
			sample_a.each{|sample_2|
				## JV_C0025 Non-male Paternal ID
				error_ignore_common_a.push(["JV_C0025", "Subject Paternal ID must reference a subject which is Male #{sample[:"Subject Paternal ID"]}"]) if sample_2[:"Subject ID"] == sample[:"Subject Paternal ID"] && sample_2[:"Subject Sex"] != "Male"
			}
			## JV_C0026 Subject is its own father
			error_ignore_common_a.push(["JV_C0026", "Subject cannot be its own father #{sample[:"Subject Paternal ID"]}"]) if sample[:"Subject ID"] == sample[:"Subject Paternal ID"]
		end
	end

	## Sex consistency check
	if ["Male", "Unknown"].include?(sample[:"Subject Sex"])
		for sampleset in sampleset_a
			## JV_C0040 Subject Sex (Male, Unknown) in SampleSet Sex (Female)
			error_ignore_common_a.push(["JV_C0040", "Subject Sex (Male, Unknown) in SampleSet Sex (Female) #{sample[:"Subject ID"]}"]) if sample[:"SampleSet ID"] == sampleset[:"SampleSet ID"] && sampleset[:"SampleSet Sex"] == "Female"
		end
	end

	if ["Female", "Unknown"].include?(sample[:"Subject Sex"])
		for sampleset in sampleset_a
			## JV_C0041 Subject Sex (Female, Unknown) in SampleSet Sex (Male)
			error_ignore_common_a.push(["JV_C0041", "If sample has subject with Subject Sex=Female or Unknown, it must not belong to a SampleSet with SampleSet Sex=Male #{sample[:"Subject ID"]}"]) if sample[:"SampleSet ID"] == sampleset[:"SampleSet ID"] && sampleset[:"SampleSet Sex"] == "Male"
		end
	end

	# sample reference validation per vcf file
	if biosample_accession_per_sampleset_h[sample[:"SampleSet ID"].to_i]
		biosample_accession_per_sampleset_h[sample[:"SampleSet ID"].to_i].push(sample[:"BioSample Accession"]) if sample[:"BioSample Accession"] && !sample[:"BioSample Accession"].empty?
	else
		biosample_accession_per_sampleset_h.store(sample[:"SampleSet ID"].to_i, [sample[:"BioSample Accession"]]) if sample[:"BioSample Accession"] && !sample[:"BioSample Accession"].empty?
	end

	if sample_name_per_sampleset_h[sample[:"SampleSet ID"].to_i]
		sample_name_per_sampleset_h[sample[:"SampleSet ID"].to_i].push(sample[:"Sample Name"]) if sample[:"Sample Name"] && !sample[:"Sample Name"].empty?
	else
		sample_name_per_sampleset_h.store(sample[:"SampleSet ID"].to_i, [sample[:"Sample Name"]]) if sample[:"Sample Name"] && !sample[:"Sample Name"].empty?
	end

end

## JV_C0036: Duplicated SampleSet Name
unless sampleset_name_a.select{|e| sampleset_name_a.count(e) > 1}.empty?
	## JV_C0036: Duplicated SampleSet Name
	error_ignore_common_a.push(["JV_C0036", "SampleSet Name must be unique within the study. Duplicated SampleSet Name: #{sampleset_name_a.select{|e| sampleset_name_a.count(e) > 1}.sort.uniq.join(",")}"])
end

## JV_C0035: Invalid SampleSet ID
if [*1..sampleset_id_a.size] != sampleset_id_a.map{|e| e.to_i}
	## JV_C0035: Invalid SampleSet ID
	error_common_a.push(["JV_C0035", "SampleSet ID must be unique serial numbers within the study"])
end

## JV_C0059: Duplicated Sample Name
unless sample_name_a.select{|e| sample_name_a.count(e) > 1}.empty?
	## JV_C0059: Duplicated Sample Name
	error_common_a.push(["JV_C0059", "Sample Name must be unique within the study. Duplicated Sample Name: #{sample_name_a.select{|e| sample_name_a.count(e) > 1}.sort.uniq.join(",")}"])
end

## JV_C0060: Duplicated BioSample accession
unless biosample_accession_a.select{|e| biosample_accession_a.count(e) > 1}.empty?
	## JV_C0060: Duplicated BioSample accession
	error_common_a.push(["JV_C0060", "BioSample accession must be unique within the study. Duplicated BioSample accession: #{biosample_accession_a.select{|e| biosample_accession_a.count(e) > 1}.sort.uniq.join(",")}"])
end

## JV_C0037: Different SampleSet Size
for sampleset_id, sampleset_size in sampleset_id_size_h
	## JV_C0037: Different SampleSet Size
	warning_common_a.push(["JV_C0037", "SampleSet Size differs from number of samples in the SampleSet. SampleSet ID: #{sampleset_id}"]) if sampleset_size.to_i != sample_sampleset_id_a.tally[sampleset_id] && sampleset_size.to_i != -1
end

# JV_C0006: Missing BioSample
if biosample_accession_a.empty?
	error_common_a.unshift(["JV_C0006", "BioSample is missing."])
end

# JV_C0003: Missing BioProject
if bioproject_accession.empty?
	error_common_a.unshift(["JV_C0003", "BioProject is missing."])
end


###
### Short genetic variations (SNP) metadata generation
###
cont_s = ""
pub_s = ""
method_s = ""
population_s = ""
assay_s = ""

# dataset id and SNP VCF filepath
vcf_snp_a = []

if submission_h[:"Submission Type"] == "Short genetic variations"

	##
	## CONT
	##
cont_s = <<EOS
TYPE:\tCONT
HANDLE:\t#{$submitter_handle}
NAME:\tYuichi Kodama
FAX:
TEL:
EMAIL:\tjvar@ddbj.nig.ac.jp
LAB:\tBioinformation and DDBJ Center
INST:\tNational Institute of Genetics
ADDR:\t1111 Yata, Mishima, Shizuoka 411-8540, Japan
||
EOS

	##
	## PUB
	##
	pub_s = ""
	if !study_h[:"PubMed ID"].empty?
		pub_s = pubinfo_pmid(study_h[:"PubMed ID"])
	end

	##
	## METHOD
	##
	# Merging Experiment + (Non-merging Experiment - target of merging Experiment)
	non_merging_experiment_id_a = []
	non_merging_experiment_id_for_method_a = []
	merging_experiment_id_for_method_a = []
	merging_experiment_target_id_a = []
	experiment_a.each{|experiment|
		if experiment[:"Method Type"] == "Merging"
			merging_experiment_id_for_method_a.push(experiment[:"Experiment ID"].to_i)
			experiment[:"Merged Experiment IDs"].split(/ *, */).each{|target_id|
				merging_experiment_target_id_a.push(target_id.to_i)
			}
		else
			non_merging_experiment_id_a.push(experiment[:"Experiment ID"].to_i)
		end
	}

	# METHOD 作成すべき merge experiment 対象以外の non-merging type experiment
	non_merging_experiment_id_for_method_a = non_merging_experiment_id_a - merging_experiment_target_id_a.sort.uniq

	# METHOD 作成すべき experiment
	experiment_id_for_method_a = []
	experiment_id_for_method_a = non_merging_experiment_id_for_method_a + merging_experiment_id_for_method_a

	for experiment in experiment_a

		if experiment_id_for_method_a.include?(experiment[:"Experiment ID"].to_i)

method_s += <<EOS
TYPE:\tMETHOD
HANDLE:\t#{$submitter_handle}
ID:\t#{submission_id}_e#{experiment[:"Experiment ID"]}
TEMPLATE_TYPE:\tDIPLOID
METHOD:\t
#{experiment[:"METHOD"]}
||
EOS

		end # if experiment_id_for_method_a.include?(experiment["Experiment ID"])

	end # for experiment in experiment_a

	##
	## POPULATION
	##
	# size == -1 is a flag for non-sampleset, HapMap population code references (not samples thus no BioSamples) from VCF.
	$direct_sample_ref_f = false
	$direct_sample_ref_f = true if sampleset_a[0] && sampleset_a[0][:"SampleSet Size"] == "-1"
	if $direct_sample_ref_f

		for sample in sample_a

			if sample[:"Sample Name"]

population_s += <<EOS
TYPE:\tPOPULATION
HANDLE:\t#{$submitter_handle}
ID:\t#{sample[:"Sample Name"]}
EOS

				population_s += sample[:"Subject Population"].empty? ? "" : "POPULATION:\t\n#{sample[:"Subject Population"]}\n"
				population_s += "||\n"

			end

		end

	# usual sampleset and/or sample names references from VCF
	else
		for sampleset in sampleset_a

			if !sampleset[:"SampleSet Name"].empty?

population_s += <<EOS
TYPE:\tPOPULATION
HANDLE:\t#{$submitter_handle}
ID:\t#{sampleset[:"SampleSet Name"]}
EOS

			population_s += sampleset[:"SampleSet Population"].empty? ? "POPULATION:\t\n" : "POPULATION:\t#{sampleset[:"SampleSet Population"]}\n"
			population_s += sampleset[:"SampleSet Size"].empty? ? "" : "Size:#{sampleset[:"SampleSet Size"]}\n"
			population_s += sampleset[:"SampleSet Type"].empty? ? "" : "Type:#{sampleset[:"SampleSet Type"]}\n"
			population_s += sampleset[:"SampleSet Name"].empty? ? "" : "Name:#{sampleset[:"SampleSet Name"]}\n"
			population_s += sampleset[:"SampleSet Description"].empty? ? "" : "Description:#{sampleset[:"SampleSet Description"]}\n"
			population_s += sampleset[:"SampleSet Phenotype"].empty? ? "" : "Phenotype:#{sampleset[:"SampleSet Phenotype"]}\n"
			population_s += sampleset[:"SampleSet Sex"].empty? ? "" : "Sex:#{sampleset[:"SampleSet Sex"]}\n"

			population_s += "||\n"

			end # if !sampleset["SampleSet Name"].empty?

		end # for sampleset in sampleset_a

	end # sampleset size == -1

	##
	## ASSAY
	##
	vcf_header_dataset_h = {}
	for dataset in dataset_a

		# JV_VCFP008: Missing short genetic variants
		error_snp_a.push(["JV_VCFP008", "Provide short genetic variants in VCF."]) if dataset[:"VCF Filename"].empty?

		if !dataset[:"Experiment ID"].empty? && !dataset[:"VCF Filename"].empty?

			# Dataset ID and VCF filepath
			vcf_snp_a.push([dataset[:"Dataset ID"], dataset[:"VCF Filename"]])

assay_s += <<EOS
TYPE:\tSNPASSAY
HANDLE:\t#{$submitter_handle}
BATCH:\t#{submission_id}_a#{dataset[:"Dataset ID"]}
MOLTYPE: Genomic
METHOD:\t#{submission_id}_e#{dataset[:"Experiment ID"]}
EOS

		assay_s += dataset[:"Number of Chromosomes Sampled"].empty? ? "" : "SAMPLESIZE:\t#{dataset[:"Number of Chromosomes Sampled"]}\n" unless $direct_sample_ref_f
		assay_s += "ORGANISM:\tHomo sapiens\n"
		assay_s += dataset[:"SampleSet ID"].empty? ? "" : "POPULATION:\t#{dataset[:"SampleSet ID"]}\n" unless $direct_sample_ref_f
		assay_s += dataset[:"Linkout URL"].empty? ? "" : "LINKOUT_URL:\t#{dataset[:"Linkout URL"]}\n"
		assay_s += dataset[:"Dataset Description"].empty? ? "" : "COMMENT:\t#{dataset[:"Dataset Description"]}\n"



		assay_s += "||\n"

		vcf_header_dataset_h.store(dataset[:"Dataset ID"].to_i, {:batch_id => "#{submission_id}_a#{dataset[:"Dataset ID"]}", :biosample_ids => sampleset_biosample_acc_h[dataset[:"SampleSet ID"].to_i]? sampleset_biosample_acc_h[dataset[:"SampleSet ID"].to_i] : ""})

		end # if !sampleset["SampleSet Name"].empty?

	end # for dataset in dataset_a

	## dbSNP metadata TSV を作成
	snp_tsv_f = open("#{excel_path}/#{submission_id}_dbsnp.tsv", "w")
	snp_tsv_f.puts cont_s
	snp_tsv_f.puts method_s
	snp_tsv_f.puts population_s
	snp_tsv_f.puts assay_s
	snp_tsv_f.close

	## dbSNP VCF を作成
	# VCF validation を実施のうえで target tags に限定せずに出力

	# VCF を跨った設定
	id_a = []

	error_vcf_header_a, error_ignore_vcf_header_a, error_exchange_vcf_header_a, warning_vcf_header_a, error_vcf_content_a, error_ignore_vcf_content_a, error_exchange_vcf_content_a, warning_vcf_content_a, vcf_variant_a = [], [], [], [], [], [], [], [], []
	for dataset in dataset_a

		# VCF ファイル毎の初期化
		invalid_sample_ref_vcf_a = []
		tmp_error_vcf_header_a = []
		tmp_error_ignore_vcf_header_a = []
		tmp_error_exchange_vcf_header_a = []
		tmp_warning_vcf_header_a = []
		tmp_error_vcf_content_a = []
		tmp_error_ignore_vcf_content_a = []
		tmp_error_exchange_vcf_content_a = []
		tmp_warning_vcf_content_a = []
		tmp_vcf_variant_call_a = []
		tmp_vcf_variant_region_a = []
		tmp_vcf_content_log_a = []

		if !dataset[:"Experiment ID"].nil? && !dataset[:"VCF Filename"].empty?

			vcf_file_a.push(dataset[:"VCF Filename"])

			batch_id = ""
			biosample_accessions = ""
			valid_sample_sampleset_refs = ""
			sampleset_names = ""
			sample_names = ""

			batch_id = vcf_header_dataset_h[dataset[:"Dataset ID"].to_i][:batch_id] if vcf_header_dataset_h[dataset[:"Dataset ID"].to_i][:batch_id]
			biosample_accessions = vcf_header_dataset_h[dataset[:"Dataset ID"].to_i][:biosample_ids].join(",") if vcf_header_dataset_h[dataset[:"Dataset ID"].to_i][:biosample_ids] && !vcf_header_dataset_h[dataset[:"Dataset ID"].to_i][:biosample_ids].empty?

			if biosample_accession_per_sampleset_h[dataset[:"SampleSet ID"].to_i].nil?
				valid_sample_sampleset_refs = sample_name_per_sampleset_h[dataset[:"SampleSet ID"].to_i] + sampleset_name_per_sampleset_h[dataset[:"SampleSet ID"].to_i] + defined_samples_list_h.keys
			else
				valid_sample_sampleset_refs = sample_name_per_sampleset_h[dataset[:"SampleSet ID"].to_i] + biosample_accession_per_sampleset_h[dataset[:"SampleSet ID"].to_i] + sampleset_name_per_sampleset_h[dataset[:"SampleSet ID"].to_i] + defined_samples_list_h.keys
			end

			sampleset_names = sampleset_name_per_sampleset_h[dataset[:"SampleSet ID"].to_i] if sampleset_name_per_sampleset_h[dataset[:"SampleSet ID"].to_i]
			sample_names = sample_name_per_sampleset_h[dataset[:"SampleSet ID"].to_i] if sample_name_per_sampleset_h[dataset[:"SampleSet ID"].to_i]

			tmp_error_vcf_header_a, tmp_error_ignore_vcf_header_a, tmp_error_exchange_vcf_header_a, tmp_warning_vcf_header_a, tmp_error_vcf_content_a, tmp_error_ignore_vcf_content_a, tmp_error_exchange_vcf_content_a, tmp_warning_vcf_content_a = [], [], [], [], [], [], [], []
			tmp_error_vcf_header_a, tmp_error_ignore_vcf_header_a, tmp_error_exchange_vcf_header_a, tmp_warning_vcf_header_a, tmp_error_vcf_content_a, tmp_error_ignore_vcf_content_a, tmp_error_exchange_vcf_content_a, tmp_warning_vcf_content_a = vcf_parser("#{vcf_path}/#{dataset[:"VCF Filename"]}", "SNP", {:batch_id => batch_id, :bioproject_accession => bioproject_accession, :biosample_accessions => biosample_accessions, :valid_sample_sampleset_refs => valid_sample_sampleset_refs, :sampleset_names => sampleset_names, :sample_names => sample_names, :snp_vcf => "#{excel_path}/#{submission_id}_a#{dataset[:"Dataset ID"]}.vcf"})

			# VCF 毎に格納
			error_vcf_header_h.store(dataset[:"VCF Filename"], tmp_error_vcf_header_a)
			error_ignore_vcf_header_h.store(dataset[:"VCF Filename"], tmp_error_ignore_vcf_header_a)
			error_exchange_vcf_header_h.store(dataset[:"VCF Filename"], tmp_error_exchange_vcf_header_a)
			warning_vcf_header_h.store(dataset[:"VCF Filename"], tmp_warning_vcf_header_a)
			error_vcf_content_h.store(dataset[:"VCF Filename"], tmp_error_vcf_content_a)
			error_ignore_vcf_content_h.store(dataset[:"VCF Filename"], tmp_error_ignore_vcf_content_a)
			error_exchange_vcf_content_h.store(dataset[:"VCF Filename"], tmp_error_exchange_vcf_content_a)
			warning_vcf_content_h.store(dataset[:"VCF Filename"], tmp_warning_vcf_content_a)

		end

	end # for dataset in dataset_a

end # if submission_h["Submission Type"] == "Short genetic variations"

###
### Structural variations (SV): Validate excel/VCF and generate dbVar XML
###
vcf_log_f = ""
variant_call_tsv_log_a = []
all_variant_call_tsv_log_a = []
variant_region_tsv_log_a = []
variant_call_from_vcf_f = false
variant_region_from_vcf_f = false

if submission_h[:"Submission Type"] == "Structural variations"

# dbVar XML
xml = Builder::XmlMarkup.new(:indent=>4)

xml_f = open("#{excel_path}/#{submission_id}_dbvar.xml", "w")
xml_f.puts instruction

# Output dbVar XML
submission_attr_h = {}
submission_attr_h.store(:"xmlns:xsi", "http://www.w3.org/2001/XMLSchema-instance")
submission_attr_h.store(:"xsi:noNamespaceSchemaLocation", "https://www.ncbi.nlm.nih.gov/data_specs/schema/other/dbvar/dbVar.xsd")
submission_attr_h.store(:study_id, study_h["Study ID"])
submission_attr_h.store(:dbvar_schema_version, "3.0.0")

unless study_h[:vload_id].empty?
	submission_attr_h.store(:vload_id, study_h[:vload_id])
else

	submission_attr_h.store(:vload_id, "")

	## JV_SV0003: Missing vload_id
	error_ignore_sv_a.push(["JV_SV0003", "vload_id is missing. JVar will fill in this value."])
end

xml_f.puts xml.SUBMISSION(submission_attr_h){|submission|

	## CONTACT
	first_contact = true
	for submitter_h in submission_h[:"Submitter"]

		# CONTACT attributes
		contact_attr_h = {}
		if first_contact
			contact_attr_h.store(:contact_role, "Submitter")
		else
			contact_attr_h.store(:contact_role, "Other")
		end

		contact_attr_h.store(:first_name, submitter_h[:"Submitter First Name"]) unless submitter_h[:"Submitter First Name"].empty?
		contact_attr_h.store(:last_name, submitter_h[:"Submitter Last Name"]) unless submitter_h[:"Submitter Last Name"].empty?
		contact_attr_h.store(:affiliation_name, submitter_h[:"Submitter Affiliation"]) unless submitter_h[:"Submitter Affiliation"].empty?
		contact_attr_h.store(:contact_email, submitter_h[:"Submitter Email"]) unless submitter_h[:"Submitter Email"].empty?
		# contact_attr_h.store(:contact_phone, "")
		# contact_attr_h.store(:affiliation_address, "")
		# contact_attr_h.store(:affiliation_url, "")

		submission.CONTACT(contact_attr_h)

		first_contact = false

	end

	## STUDY
	hold_date = ""
	hold_date = "2040-01-01" if submission_h[:"Hold/Release"] == "Hold"

	# STUDY attributes
	study_attr_h = {}
	study_attr_h.store(:study_type, study_h[:"Study Type"]) unless study_h[:"Study Type"].empty?

	unless study_h[:"BioProject Accession"].empty?
		study_attr_h.store(:bioproject_accession, study_h[:"BioProject Accession"])
	end

	study_attr_h.store(:hold_date, hold_date) unless hold_date.empty?
	study_attr_h.store(:study_accession, "")

	submission.STUDY(study_attr_h){|study|
		study.DESCRIPTION(study_h[:"Study Description"])
		study.ORGANISM(:taxonomy_id => "9606")
	}

	## SUBJECT
	subject_id_a = []
	for sample in sample_a

		# 重複している subject ID はスキップ。結果として最初のものが採用される
		next if subject_id_a.include?(sample[:"Subject ID"])
		subject_id_a.push(sample[:"Subject ID"])

		# SUBJECT attributes
		subject_attr_h = {}
		subject_attr_h.store(:subject_id, sample[:"Subject ID"]) unless sample[:"Subject ID"].empty?
		subject_attr_h.store(:subject_taxonomy_id, "9606")
		subject_attr_h.store(:subject_maternal_id, sample[:"Subject Maternal ID"]) unless sample[:"Subject Maternal ID"].empty?
		subject_attr_h.store(:subject_paternal_id, sample[:"Subject Paternal ID"]) unless sample[:"Subject Paternal ID"].empty?
		subject_attr_h.store(:subject_sex, sample[:"Subject Sex"]) unless sample[:"Subject Sex"].empty?
		subject_attr_h.store(:subject_collection, sample[:"Subject Collection"]) unless sample[:"Subject Collection"].empty?
		subject_attr_h.store(:subject_karyotype, sample[:"Subject Karyotype"]) unless sample[:"Subject Karyotype"].empty?
		subject_attr_h.store(:subject_population, sample[:"Subject Population"]) unless sample[:"Subject Population"].empty?
		subject_attr_h.store(:subject_age, sample[:"Subject Age"]) unless sample[:"Subject Age"].empty?
		subject_attr_h.store(:subject_age_units, sample[:"Subject Age Units"]) unless sample[:"Subject Age Units"].empty?

		submission.SUBJECT(subject_attr_h){|subject|

			unless sample[:"Subject Phenotype"].empty?
				if sample[:"Subject Phenotype"].scan(/(#{xref_db_phenotypes_regex}) *: *([-A-Za-z0-9]+)/).size > 0
					subject.PHENOTYPE{|phenotype|
						for db, id in sample[:"Subject Phenotype"].scan(/(#{xref_db_phenotypes_regex}) *: *([-A-Za-z0-9]+)/)
							phenotype.LINK(:db => db, :id => id)
						end # for db, id in sample["Subject Phenotype"].scan(/(#{xref_db_regex}) *: *([-A-Za-z0-9]+)/)
					}
				else
					subject.PHENOTYPE{|phenotype|
						phenotype.DESCRIPTION(sample[:"Subject Phenotype"])
					}

					## JV_SV0007: Invalid subject phenotype link
					warning_sv_a.push(["JV_SV0007", "Subject phenotype link must reference a valid medical vocabulary ID. Subject ID: #{subject_id}: #{sample[:"Subject Phenotype"]}"])

				end
			end # unless sample["Subject Phenotype"].empty?

		} # submission.SUBJECT

	end

	## SAMPLESET
	sampleset_id_a = []
	sampleset_id_size_h = {}
	sampleset_id_sex_h = {}
	for sampleset in sampleset_a

		# SAMPLESET attributes
		sampleset_attr_h = {}

		sampleset_id = sampleset[:"SampleSet ID"].to_i
		unless sampleset_id.nil?
			sampleset_attr_h.store(:sampleset_id, sampleset_id)
			sampleset_id_a.push(sampleset_id)
		end

		unless sampleset[:"SampleSet Name"].empty?
			sampleset_name_a.push(sampleset[:"SampleSet Name"])
			sampleset_attr_h.store(:sampleset_name, sampleset[:"SampleSet Name"])
		end

		unless sampleset[:"SampleSet Size"].empty?
			sampleset_id_size_h.store(sampleset_id, sampleset[:"SampleSet Size"])
			sampleset_attr_h.store(:sampleset_size, sampleset[:"SampleSet Size"])
		end

		unless sampleset[:"SampleSet Type"].empty?
			sampleset_attr_h.store(:sampleset_type, sampleset[:"SampleSet Type"])
		else
			## JV_SV0096: Missing SampleSet Type for Study Type
			error_ignore_sv_a.push(["JV_SV0096", 'Must have SampleSet Type if Study Type is "Case-Control" or "Tumor vs. Matched-Normal"']) if ["Case-Control", "Tumor vs. Matched-Normal"].include?(study_h[:"Study Type"])
		end

		unless sampleset[:"SampleSet Sex"].empty?
			sampleset_attr_h.store(:sampleset_sex, sampleset[:"SampleSet Sex"])
			sampleset_id_sex_h.store(sampleset_id, sampleset[:"SampleSet Sex"])
		end

		sampleset_attr_h.store(:sampleset_population, sampleset[:"SampleSet Population"]) unless sampleset[:"SampleSet Population"].empty?

		submission.SAMPLESET(sampleset_attr_h){|sampleset_e|

			sampleset_e.DESCRIPTION(sampleset[:"SampleSet Description"])
			sampleset_e.ORGANISM(:taxonomy_id => "9606")

			unless sampleset[:"SampleSet Phenotype"].empty?
				if sampleset[:"SampleSet Phenotype"].scan(/(#{xref_db_phenotypes_regex}) *: *([-A-Za-z0-9]+)/).size > 0
					sampleset_e.PHENOTYPE{|phenotype|
						for db, id in sampleset[:"SampleSet Phenotype"].scan(/(#{xref_db_phenotypes_regex}) *: *([-A-Za-z0-9]+)/)
							phenotype.LINK(:db => db, :id => id)
						end # for db, id in sampleset["SampleSet Phenotype"].scan(/(#{xref_db_regex}) *: *([-A-Za-z0-9]+)/)
					}
				else
					sampleset_e.PHENOTYPE{|phenotype|
						phenotype.DESCRIPTION(sampleset[:"SampleSet Description"])
					}

					## JV_SV0008: Invalid SampleSet phenotype link
					warning_sv_a.push(["JV_SV0008", "SampleSet phenotype link must reference a valid medical vocabulary ID. SampleSet ID: #{sampleset_id}: #{sampleset[:"SampleSet Phenotype"]}"])

				end
			end # unless sampleset["SampleSet Phenotype"].empty?

		} # submission.SAMPLESET

	end	# for sampleset in sampleset_a

	## SAMPLE
	for sample in sample_a

		# SAMPLE attributes
		sample_attr_h = {}
		sample_attr_h.store(:sample_id, sample[:"Sample Name"]) unless sample[:"Sample Name"].empty?
		sample_attr_h.store(:sample_cell_type, sample[:"Sample Cell Type"]) unless sample[:"Sample Cell Type"].empty?
		sample_attr_h.store(:subject_id, sample[:"Subject ID"]) unless sample[:"Subject ID"].empty?
		sample_attr_h.store(:sample_attribute, sample[:"Sample Attribute"]) unless sample[:"Sample Attribute"].empty?
		sample_attr_h.store(:sample_karyotype, sample[:"Sample Karyotype"]) unless sample[:"Sample Karyotype"].empty?

		unless sample[:"Sample Name"].empty?
			sample_name_a.push(sample[:"Sample Name"])
		end

		unless sample[:"BioSample Accession"].empty?

			unless sample[:"BioSample Accession"].match?(/^SAMD\d{8}$|^SAME\d{1,}$|^SAMN\d{8}$/)
				## JV_C0042: Invalid BioSample accession
				error_common_a.push(["JV_C0042", "BioSample accession must be a valid BioSample accession. #{sample[:"BioSample Accession"]}"])
			end

			sample_attr_h.store(:biosample_accession, sample[:"BioSample Accession"])
			biosample_accession_a.push(sample[:"BioSample Accession"])

		end

			unless sample[:"SampleSet ID"].empty?

				submission.SAMPLE(sample_attr_h){|sample_e|
					sample_e.SAMPLESET(:sampleset_id => sample[:"SampleSet ID"])
				}

				unless sampleset_id_a.include?(sample[:"SampleSet ID"].to_i)
					## JV_C0039: Invalid SampleSet ID
					error_common_a.push(["JV_C0039", "SampleSet ID must reference a valid sampleset in the study. Invalid SampleSet ID: #{sample[:"SampleSet ID"]}"])
				end

			end

		# Links
		if sample[:"Sample Resource"].scan(/(#{xref_db_all_regex}) *: *([-A-Za-z0-9]+)/).size > 0
			for db, id in sample[:"Sample Resource"].scan(/(#{xref_db_all_regex}) *: *([-A-Za-z0-9]+)/)

				submission.SAMPLE(sample_attr_h){|sample_e|
					sample_e.LINK(:db => db, :id => id)
				}

			end # for db, id in sample[:"Sample Resource"].scan(/(#{xref_db_all_regex}) *: *([-A-Za-z0-9]+)/)
		elsif !sample[:"Sample Resource"].empty?
			## JV_SV0009: Invalid Sample link
			warning_sv_a.push(["JV_SV0009", "Sample link must reference a valid external db:id #{sample[:"Sample Resource"]}"])
		end

	end

	# Merge
	non_merging_experiment_id_a = []
	non_merging_experiment_id_for_method_a = []
	merging_experiment_id_for_method_a = []
	merging_experiment_target_id_a = []
	experiment_a.each{|experiment|
		if experiment[:"Method Type"] == "Merging"
			merging_experiment_id_for_method_a.push(experiment[:"Experiment ID"])
			experiment[:"Merged Experiment IDs"].split(/ *, */).each{|target_id|
				merging_experiment_target_id_a.push(target_id.to_i)
			}
		else
			non_merging_experiment_id_a.push(experiment[:"Experiment ID"])
		end
	}

	## EXPERIMENT
	experiment_type_h = {}
	for experiment in experiment_a

		# EXPERIMENT attributes
		experiment_attr_h = {}
		experiment_attr_h.store(:experiment_id, experiment[:"Experiment ID"]) unless experiment[:"Experiment ID"].nil?

		# Experiment Resolution
		unless experiment[:"Experiment Resolution"].empty?

			experiment_attr_h.store(:experiment_resolution, experiment[:"Experiment Resolution"])

			## JV_SV0011: Invalid Experiment Resolution
			unless experiment[:"Experiment Resolution"].match?(/[-<>=~. 0-9BbPp]+/)
				error_ignore_sv_a.push(["JV_SV0011", "Experiment Resolution must only contain numbers or 'bp' or any of these characters: '<>=~- .' #{experiment[:"Experiment Resolution"]}"])
			end

			## JV_SV0019: Experiment Resolution is not 'bp' for Sequencing
			if experiment[:"Method Type"] == "Sequencing" && ["de novo and local sequence assembly", "de novo sequence assembly", "Local sequence assembly", "Sequence alignment", "SNP genotyping analysis", "Split read and paired-end mapping", "Split read mapping"].include?(experiment[:"Analysis Type"])
				warning_sv_a.push(["JV_SV0019", "Warning if Method Type='Sequencing' and Analysis Type=de novo sequence assembly, de novo and local sequence assembly, Local sequence assembly, Sequence alignment, Split read mapping, and Experiment Resolution is not 'bp'"]) unless experiment[:"Experiment Resolution"].match?(/\d{1,}\.\d{1,}|BP/i)
			end

			## JV_SV0020: Experiment Resolution>40 for Sequencing
			if experiment[:"Method Type"] == "Sequencing" && ["One end anchored assembly", "Read depth"].include?(experiment[:"Analysis Type"])
				if (experiment[:"Experiment Resolution"].match?(/(\d{1,}\.\d{1,})/) && $1.to_f > 40) || (experiment[:"Experiment Resolution"].match?(/(\d{1,}) *BP/i) && $1.to_f > 40000)
					warning_sv_a.push(["JV_SV0020", "Warning if Method Type='Sequencing' and Analysis Type=One end anchored assembly, Read depth, and Experiment Resolution > 40"])
				end
			end

			## JV_SV0021: Experiment Resolution>5 for Optical mapping
			if experiment[:"Method Type"] == "Optical mapping" && experiment[:"Analysis Type"] == "Optical mapping"
				if (experiment[:"Experiment Resolution"].match?(/(\d{1,}\.\d{1,})/) && $1.to_f > 5) || (experiment[:"Experiment Resolution"].match?(/(\d{1,}) *BP/i) && $1.to_f > 5000)
					warning_sv_a.push(["JV_SV0021", "Warning if Method Type='Optical mapping' and Analysis Type=Optical mapping and Experiment Resolution > 5"])
				end
			end

			## JV_SV0022: Experiment Resolution>40 for Paired-end Sequencing
			if experiment[:"Method Type"] == "Sequencing" && experiment[:"Analysis Type"] == "Paired-end mapping"
				if (experiment[:"Experiment Resolution"].match?(/(\d{1,}\.\d{1,})/) && $1.to_f > 40) || (experiment[:"Experiment Resolution"].match?(/(\d{1,}) *BP/i) && $1.to_f > 40000)
					warning_sv_a.push(["JV_SV0022", "Warning if Method Type='Sequencing' and Analysis Type=Paired-end mapping and Experiment Resolution > 40"])
				end
			end

			## JV_SV0023: Experiment Resolution<100 for BAC aCGH or FISH
			if ["BAC aCGH", "FISH"].include?(experiment[:"Method Type"])
				if (experiment[:"Experiment Resolution"].match?(/(\d{1,}\.\d{1,})/) && $1.to_f < 100)
					warning_sv_a.push(["JV_SV0023", "Warning if Method Type=BAC aCGH or FISH and Experiment Resolution < 100"])
				end
			end

			## JV_SV0024: Experiment Resolution>=100 for Oligo aCGH or SNP array
			if ["Oligo aCGH", "SNP array"].include?(experiment[:"Method Type"])
				if (experiment[:"Experiment Resolution"].match?(/(\d{1,}\.\d{1,})/) && $1.to_f >= 100)
					warning_sv_a.push(["JV_SV0024", "Warning if Method Type=Oligo aCGH, or SNP array and Experiment Resolution >= 100"])
				end
			end

			## JV_SV0027: Experiment Resolution is 'bp' for Sequencing Method Type
			if experiment[:"Method Type"] == "Sequencing" && experiment[:"Experiment Resolution"].match?(/(\d{1,}) *BP/i)
				unless ["de novo sequence assembly", "de novo and local sequence assembly", "Local sequence assembly", "Sequence alignment", "Split read mapping", "Split read and paired-end mapping"].include?(experiment[:"Analysis Type"])
					warning_sv_a.push(["JV_SV0027", "Warning if Method Type=Sequencing and Experiment Resolution is 'bp' and Analysis Type IS NOT de novo sequence assembly, de novo and local sequence assembly, Local sequence assembly, Sequence alignment, Split read mapping, Split read and paired-end mapping"])
				end
			end

		end # unless experiment[:"Experiment Resolution"].empty?

		# 他オブジェクトでのチェック用に格納
		experiment_type_h.store(experiment[:"Experiment ID"], {:"Experiment Type" => experiment[:"Experiment Type"], :"Method Type" => experiment[:"Method Type"], :"Analysis Type" => experiment[:"Analysis Type"]})

		## JV_SV0025: Inappropriate combination of Method Type and Analysis Type
		for inapp_type_h in $inapp_method_analysis_types_a
			if inapp_type_h[:"Method Type"].include?(experiment[:"Method Type"]) && !inapp_type_h[:"Analysis Type"].include?(experiment[:"Analysis Type"])
				warning_sv_a.push(["JV_SV0025", "Warning if Method Type=Sequencing and Analysis Type is not: de novo and local sequence assembly, de novo sequence assembly, Local sequence assembly, One end anchored assembly, Paired-end mapping, Read depth, Sequence alignment, Split read mapping, Genotyping, Read depth and paired-end mapping, Split read and paired-end mapping"]) if ["Sequencing"].include?(experiment[:"Method Type"])
				warning_sv_a.push(["JV_SV0025", "Warning if Method Type is: Digital array, Gene expression array, MAPH, qPCR, ROMA, RT-PCR, and Analysis Type is not Probe signal intensity"]) if ["Digital array", "Gene expression array", "MAPH", "qPCR", "ROMA", "RT-PCR"].include?(experiment[:"Method Type"])
				warning_sv_a.push(["JV_SV0025", "Warning if Method Type is: BAC aCGH, MLPA, Oligo aCGH and Analysis Type is not: Probe signal intensity, Genotyping"]) if ["BAC aCGH", "MLPA", "Oligo aCGH"].include?(experiment[:"Method Type"])
				warning_sv_a.push(["JV_SV0025", "Warning if Method Type is SNP array and Analysis Type is not: SNP genotyping analysis, Probe signal intensity, Other, Genotyping"]) if ["SNP array"].include?(experiment[:"Method Type"])
				warning_sv_a.push(["JV_SV0025", "Warning if Method Type is Curated and Analysis Type is not Curated or Manual observation"]) if ["Curated"].include?(experiment[:"Method Type"])
				warning_sv_a.push(["JV_SV0025", "Warning if Method Type is FISH or Karyotyping and Analysis Type is not: Probe signal intensity, Manual observation, Other, Genotyping"]) if ["FISH", "Karyotyping"].include?(experiment[:"Method Type"])
				warning_sv_a.push(["JV_SV0025", "Warning if Method Type is Multiple complete digestion and Analysis Type is not MCD analysis"]) if ["Multiple complete digestion"].include?(experiment[:"Method Type"])
				warning_sv_a.push(["JV_SV0025", "Warning if Method Type is Optical mapping and Analysis Type is not Optical mapping"]) if ["Optical mapping"].include?(experiment[:"Method Type"])
				warning_sv_a.push(["JV_SV0025", "Warning if Method Type is PCR and Analysis Type is not: Manual observation, Other, Genotyping"]) if ["PCR"].include?(experiment[:"Method Type"])
				warning_sv_a.push(["JV_SV0025", "Warning if Method Type is Merging and Analysis Type is not Merging, or Reference Type is not Other (or the value from Reference Type of the merged experiments if they are all the same), or Reference Value is not Merged experiments (or the value from Reference Value of the merged experiments if they are all the same)"]) if ["Merging"].include?(experiment[:"Method Type"])
				warning_sv_a.push(["JV_SV0025", "Warning if Method Type=MassSpec and Analysis Type is not Other"]) if ["MassSpec"].include?(experiment[:"Method Type"])
				warning_sv_a.push(["JV_SV0025", "Warning if Method Type=Southern or Western and Analysis Type is not Manual observation"]) if ["Southern", "Western"].include?(experiment[:"Method Type"])
			end
		end

		experiment_attr_h.store(:experiment_type, experiment[:"Experiment Type"]) unless experiment[:"Experiment Type"].empty?

		submission.EXPERIMENT(experiment_attr_h){|experiment_e|
			if !experiment[:"Method Type"].empty?
				experiment_e.METHOD(:method_type => experiment[:"Method Type"]){|method_e|
					method_e.DESCRIPTION(experiment[:"Method Description"]) if !experiment[:"Method Description"].empty?
				}
			end

		# if not merging
		if experiment[:"Method Type"] != "Merging" && experiment[:"Analysis Type"] != "Merging"

			## JV_C0046: Missing Description for Other analysis type
			error_ignore_common_a.push(["JV_C0046", "Description is required if Analysis Type='Other'"]) if experiment[:"Analysis Type"] == "Other" && experiment[:"Analysis Description"].empty?

			case experiment[:"Experiment Type"]

			when "Discovery"

			# DISCOVERY_ANALYSIS attributes
			discovery_analysis_attr_h = {}
			discovery_analysis_attr_h.store(:analysis_type, experiment[:"Analysis Type"]) unless experiment[:"Analysis Type"].empty?
			discovery_analysis_attr_h.store(:reference_type, experiment[:"Reference Type"]) unless experiment[:"Reference Type"].empty?
			discovery_analysis_attr_h.store(:reference_value, experiment[:"Reference Value"]) unless experiment[:"Reference Value"].empty?

			experiment_e.DISCOVERY_ANALYSIS(discovery_analysis_attr_h){|discovery_analysis|
				discovery_analysis.DESCRIPTION(experiment[:"Analysis Description"]) if !experiment[:"Analysis Description"].empty?
			}

			when "Validation"

			# VALIDATION_ANALYSIS attributes
			validation_analysis_attr_h = {}
			validation_analysis_attr_h.store(:analysis_type, experiment[:"Analysis Type"]) unless experiment[:"Analysis Type"].empty?
			validation_analysis_attr_h.store(:reference_type, experiment[:"Reference Type"]) unless experiment[:"Reference Type"].empty?
			validation_analysis_attr_h.store(:reference_value, experiment[:"Reference Value"]) unless experiment[:"Reference Value"].empty?

			experiment_e.VALIDATION_ANALYSIS(validation_analysis_attr_h){|validation_analysis|
				validation_analysis.DESCRIPTION(experiment[:"Analysis Description"]) if !experiment[:"Analysis Description"].empty?
			}

			when "Genotyping"

			# GENOTYPING_ANALYSIS attributes
			genotype_analysis_attr_h = {}
			genotype_analysis_attr_h.store(:analysis_type, experiment[:"Analysis Type"]) unless experiment[:"Analysis Type"].empty?
			genotype_analysis_attr_h.store(:reference_type, experiment[:"Reference Type"]) unless experiment[:"Reference Type"].empty?
			genotype_analysis_attr_h.store(:reference_value, experiment[:"Reference Value"]) unless experiment[:"Reference Value"].empty?

			experiment_e.GENOTYPING_ANALYSIS(genotype_analysis_attr_h){|genotyping_analysis|
				genotyping_analysis.DESCRIPTION(experiment[:"Analysis Description"]) if !experiment[:"Analysis Description"].empty?
			}

			end

		end # if not merging

		# JV_C0043: Invalid Reference Assembly
		if !experiment[:"Reference Type"].empty? && !experiment[:"Reference Value"].empty? && experiment[:"Reference Type"] == "Assembly"
			## assembly から refseq accession 取得
			unless allowed_assembly_a.include?(experiment[:"Reference Value"])
				error_common_a.push(["JV_C0043", "Reference Value must refer to a valid Assembly if Reference Type=\"Assembly\". Experiment ID: #{experiment["Experiment ID"]}, #{experiment[:"Reference Value"]}"])
			end
		end

		## JV_C0044: Invalid Reference SampleSet
		error_common_a.push(["JV_C0044", "Reference Value must refer to a valid SampleSet if Reference Type=\"SampleSet\". Invalid SampleSet ID reference: #{experiment[:"Reference Value"]}"]) if experiment[:"Reference Type"] == "Sampleset" && !sampleset_id_a.include?(experiment[:"Reference Value"])

		## JV_C0045: Invalid Reference Sample
		error_common_a.push(["JV_C0045", "Reference Value must refer to a valid BioSample accession if Reference Type=\"Sample\". Invalid BioSample reference: #{experiment[:"Reference Value"]}"]) if experiment[:"Reference Type"] == "Sample" && !biosample_accession_a.include?(experiment[:"Reference Value"])

		# Detection

		# DETECTION attributes
		detection_attr_h = {}
		detection_attr_h.store(:detection_method, experiment[:"Detection Method"]) unless experiment[:"Detection Method"].empty?

		if !experiment[:"Detection Method"].empty? || !experiment[:"Detection Description"].empty?
			experiment_e.DETECTION(detection_attr_h){|detection|
				detection.DESCRIPTION(experiment[:"Detection Description"]) if !experiment[:"Detection Description"].empty?
			}
		end

		# Platform
		if !experiment[:"Method Platform"].empty?
			experiment_e.PLATFORM(:platform_name => experiment[:"Method Platform"])
		end

		# Platform
		if experiment[:"Method Platform"].scan(/(#{xref_db_all_regex}) *: *([-A-Za-z0-9]+)/).size > 0
			for db, id in experiment[:"Method Platform"].scan(/(#{xref_db_all_regex}) *: *([-A-Za-z0-9]+)/)
				experiment_e.PLATFORM{|platform_e|
					platform_e.LINK(:db => db, :id => id)

					## JV_SV0026: Invalid Platform link
					warning_sv_a.push(["JV_SV0026", "Warning if Platform link is not to AE, GEO, GEA, SRA, ENA. DB: #{db}"]) unless ["AE", "GEO", "GEA", "SRA", "ENA"].include?(db)
				}
			end # for db, id in experiment[:"Method Platform"].scan(/(#{xref_db_all_regex}) *: *([-A-Za-z0-9]+)/)
		elsif !experiment[:"Method Platform"].empty?
			experiment_e.PLATFORM(:platform_name => experiment[:"Method Platform"])

			## JV_SV0013: Invlalid Platform link
			# warning_sv_a.push(["JV_SV0013", "Platform link must refer to a valid db:id"])
		end

		# Links
		if experiment[:"External Links"].scan(/(#{xref_db_all_regex}) *: *([-A-Za-z0-9]+)/).size > 0
			for db, id in experiment[:"External Links"].scan(/(#{xref_db_all_regex}) *: *([-A-Za-z0-9]+)/)
				experiment_e.LINK{|link|
					link.DB_ID(:db => db, :id => id)
				}
			end # for db, id in experiment[:"External Links"].scan(/(#{xref_db_all_regex}) *: *([-A-Za-z0-9]+)/)
		elsif !experiment[:"External Links"].empty?
			experiment_e.LINK{|link|
				link.URL(:url => experiment[:"External Links"])

				## JV_SV0015: Invalid Experiment link URL
				warning_sv_a.push(["JV_SV0015", "Experiment link URL must be valid"]) unless experiment[:"External Links"].match?(/https?/)
			}

			## JV_SV0013: Invlalid Platform link
			# warning_sv_a.push(["JV_SV0015", "Experiment link URL must be valid"])

		end

		# Merge
		unless experiment[:"Merged Experiment IDs"].split(/ *, */).empty?
			experiment[:"Merged Experiment IDs"].split(/ *, */).each{|eid|
				if non_merging_experiment_id_a.include?(eid)
					experiment_e.MERGED_EXPERIMENT(:merged_experiment_id => "#{eid}")
				end
			}
		end

		} # experiment_e

	end

	#
	# Variant Call
	#

	# tsv Dataset ID to Experiment/SamplaSet IDs
	dataset_to_experiment_h = {}
	dataset_to_sampleset_h = {}

	## Variant Call Sheet or VCF
	error_vcf_header_a, error_ignore_vcf_header_a, error_exchange_vcf_header_a, warning_vcf_header_a, error_vcf_content_a, error_ignore_vcf_content_a, error_exchange_vcf_content_a, warning_vcf_content_a, vcf_variant_call_a, vcf_variant_region_a, vcf_content_log_a = [], [], [], [], [], [], [], [], [], []
	for dataset in dataset_a

		dataset_to_experiment_h.store(dataset[:"Dataset ID"].to_i, dataset[:"Experiment ID"].to_i)
		dataset_to_sampleset_h.store(dataset[:"Dataset ID"].to_i, dataset[:"SampleSet ID"].to_i)

		# VCF と variant call sheet 両方ある場合は sheet を優先。VCF 登録で region 作成時の処理
		if !dataset[:"VCF Filename"].empty? && variant_call_a.empty?
			vcf_sv_f = dataset[:"VCF Filename"]
		else
			if variant_call_a.empty?
				# JV_VCFS0008: Missing structural variants
				error_sv_a.push(["JV_VCFS0008", "Provide structural variants in the Variant Call/Variant Region sheets or in VCF."])
			end
		end

		## Variant Call from VCF
		unless vcf_sv_f.empty?

			vcf_file_a.push(vcf_sv_f)

			# VCF file for logging
			# vcf_log_f = File.open("#{excel_path}/#{vcf_sv_f}.log.txt", "w")

			# VCF ファイル毎の初期化
			invalid_sample_ref_vcf_a = []
			tmp_error_vcf_header_a = []
			tmp_error_ignore_vcf_header_a = []
			tmp_error_exchange_vcf_header_a = []
			tmp_warning_vcf_header_a = []
			tmp_error_vcf_content_a = []
			tmp_error_ignore_vcf_content_a = []
			tmp_error_exchange_vcf_content_a = []
			tmp_warning_vcf_content_a = []
			tmp_vcf_variant_call_a = []
			tmp_vcf_variant_region_a = []
			tmp_vcf_content_log_a = []

			tmp_error_vcf_header_a, tmp_error_ignore_vcf_header_a, tmp_error_exchange_vcf_header_a, tmp_warning_vcf_header_a, tmp_error_vcf_content_a, tmp_error_ignore_vcf_content_a, tmp_error_exchange_vcf_content_a, tmp_warning_vcf_content_a, tmp_vcf_variant_call_a, tmp_vcf_variant_region_a, tmp_vcf_content_log_a = vcf_parser("#{vcf_path}/#{vcf_sv_f}", "SV", {})

			for tmp_vcf_variant_call_h in tmp_vcf_variant_call_a

				unless dataset[:"Dataset ID"].nil?
					tmp_vcf_variant_call_h.store(:"Dataset ID", dataset[:"Dataset ID"])
				else
					tmp_vcf_variant_call_h.store(:"Dataset ID", "")
				end

				unless dataset[:"Experiment ID"].nil?
					tmp_vcf_variant_call_h.store(:"Experiment ID", dataset[:"Experiment ID"])
				else
					tmp_vcf_variant_call_h.store(:"Experiment ID", "")
				end

				unless dataset[:"SampleSet ID"].nil?
					tmp_vcf_variant_call_h.store(:"SampleSet ID", dataset[:"SampleSet ID"])
				else
					tmp_vcf_variant_call_h.store(:"SampleSet ID", "")
				end

				# JV_VCF0042: Invalid sample reference in VCF
				unless tmp_vcf_variant_call_h[:FORMAT].empty?
					for ft_value_h in tmp_vcf_variant_call_h[:FORMAT]
						if sample_name_per_sampleset_h[tmp_vcf_variant_call_h[:"SampleSet ID"].to_i] && biosample_accession_per_sampleset_h[tmp_vcf_variant_call_h[:"SampleSet ID"].to_i] && sampleset_name_per_sampleset_h[tmp_vcf_variant_call_h[:"SampleSet ID"].to_i]
							unless (ft_value_h.keys.map{|e| "#{e}"} - sample_name_per_sampleset_h[tmp_vcf_variant_call_h[:"SampleSet ID"].to_i] - biosample_accession_per_sampleset_h[tmp_vcf_variant_call_h[:"SampleSet ID"].to_i] - sampleset_name_per_sampleset_h[tmp_vcf_variant_call_h[:"SampleSet ID"].to_i] - defined_samples_list_h.keys).empty?
								invalid_sample_ref_vcf_a.push((ft_value_h.keys.map{|e| "#{e}"} - sample_name_per_sampleset_h[tmp_vcf_variant_call_h[:"SampleSet ID"].to_i] - biosample_accession_per_sampleset_h[tmp_vcf_variant_call_h[:"SampleSet ID"].to_i] - sampleset_name_per_sampleset_h[tmp_vcf_variant_call_h[:"SampleSet ID"].to_i] - defined_samples_list_h.keys))
							end

							# Genotype flag
							ft_value_h.values.each{|ft_value|
								ft_value.each{|key_sym, value|
									sv_genotype_f = true if "#{key_sym}" == "GT" || "#{key_sym}" == "CN"
								}
							}

						end
					end
				end # unless tmp_vcf_variant_call_h["FORMAT"].empty?

				# row に VCF を row にしたものを格納
				unless tmp_vcf_variant_call_h[:row]
					# VCF variant call に tsv 用の row 格納
					row_a = []
					for item in variant_call_sheet_header_a
						# sheet header 項目名が無いものは "" を格納
						row_a.push(tmp_vcf_variant_call_h[:"#{item}"] ? tmp_vcf_variant_call_h[:"#{item}"] : "")
					end

					tmp_vcf_variant_call_h.store(:row, row_a)
				end

			end # for tmp_vcf_variant_call_h in tmp_vcf_variant_call_a

			# JV_VCF0042: Invalid sample reference in VCF
			unless invalid_sample_ref_vcf_a.sort.uniq.empty?
				tmp_error_vcf_header_a.push(["JV_VCF0042", "Reference a Sample Name of a Sample in the SampleSet or a SampleSet Name in the VCF sample column. #{invalid_sample_ref_vcf_a.sort.uniq.join(",")}"])
			end

			# VCF 毎に variant call を格納
			total_variant_call_h.store(vcf_sv_f, tmp_vcf_variant_call_a)
			variant_call_from_vcf_f = true

			# VCF 毎に VCF 段階でのチェック結果を格納
			error_vcf_header_h.store(vcf_sv_f, tmp_error_vcf_header_a)
			error_ignore_vcf_header_h.store(vcf_sv_f, tmp_error_ignore_vcf_header_a)
			error_exchange_vcf_header_h.store(vcf_sv_f, tmp_error_exchange_vcf_header_a)
			warning_vcf_header_h.store(vcf_sv_f, tmp_warning_vcf_header_a)
			error_vcf_content_h.store(vcf_sv_f, tmp_error_vcf_content_a)
			error_ignore_vcf_content_h.store(vcf_sv_f, tmp_error_ignore_vcf_content_a)
			error_exchange_vcf_content_h.store(vcf_sv_f, tmp_error_exchange_vcf_content_a)
			warning_vcf_content_h.store(vcf_sv_f, tmp_warning_vcf_content_a)

			error_vcf_header_a += tmp_error_vcf_header_a
			error_ignore_vcf_header_a += tmp_error_ignore_vcf_header_a
			error_exchange_vcf_header_a += tmp_error_exchange_vcf_header_a
			warning_vcf_header_a += tmp_warning_vcf_header_a
			error_vcf_content_a += tmp_error_vcf_content_a
			error_ignore_vcf_content_a += tmp_error_ignore_vcf_content_a
			error_exchange_vcf_content_a += tmp_error_exchange_vcf_content_a
			warning_vcf_content_a += tmp_warning_vcf_content_a
			vcf_variant_call_a += tmp_vcf_variant_call_a
			vcf_variant_region_a += tmp_vcf_variant_region_a

		end # unless vcf_sv_f.empty? SV VCF 毎の処理

	end # for dataset in dataset_a

	## Variant call in TSV or VCF
	# variant call は sheet から
	if vcf_sv_f.empty?
		total_variant_call_h.store("tsv", variant_call_a)
	end

	#
	# Generate Variant Call XML
	#

	# vcf を跨った variant call 全体の設定
	validation_result_regex = "Fail|Pass|Inconclusive"

	variant_call_id_h = {}
	variant_call_site_h = {}
	identical_variant_call_site_id_h = {}
	object = "Variant Call"
	all_variant_call_tsv_s = ""

	# GENOTYPE XML
	gt_xml = Builder::XmlMarkup.new(:indent=>4, :margin=>1)

	vcf_count = 0
	for vc_input, variant_call_a in total_variant_call_h

		vc_line = 0

		error_sv_vc_a = []
		error_ignore_sv_vc_a = []
		warning_sv_vc_a = []

		variant_call_tsv_log_a = []
		variant_call_tsv_s = ""

		# VCF 毎に初期化
		chromosome_per_assembly_a = []

		variant_call_id_type_h = {}
		variant_call_id_sampleset_h = {}
		variant_call_translocation_h = {}
		variant_call_mutation_h = {}
		variant_calls_by_mutation_id_h = {}
		variant_call_placement_h = {}
		variant_call_by_id_h = {}

		# assembly チェック用に格納
		translocation_assembly_a = []
		variant_call_assembly_a = []
		variant_region_assembly_a = []

		# assembly and sequences
		refseq_assembly = ""
		chromosome_per_assembly_a = []
		chr_name = ""
		chr_accession = ""
		chr_length = -1
		contig_accession = ""
		assembly = ""

		pre_assembly = ""
		pre_chr_name = ""
		pre_chr_accession = ""
		pre_chr_length = ""
		pre_contig_accession = ""

		pre_from_assembly = ""
		pre_from_chr_name = ""
		pre_from_chr_accession = ""
		pre_from_chr_length = -1
		pre_from_contig_accession = ""

		pre_to_assembly = ""
		pre_to_chr_name = ""
		pre_to_chr_accession = ""
		pre_to_chr_length = -1
		pre_to_contig_accession = ""

		# error and warning counts
		missing_variant_call_id_a = [] # JV_SV0001
		duplicated_variant_call_id_a = [] # JV_SV0030

		invalid_value_for_cv_call_a = [] # JV_C0057
		invalid_phenotype_link_call_a = [] # JV_SV0033
		invalid_phenotype_link_evidence_call_a = [] # JV_SV0036
		missing_strand_call_a = [] # JV_SV0094
		invalid_from_to_call_a = [] # JV_SV0045
		different_chrs_for_intra_call_a = [] # JV_SV0041
		same_chrs_for_inter_call_a = [] # JV_SV0042
		invalid_chr_ref_call_a = [] # JV_SV0072
		invalid_contig_acc_ref_call_a = [] # JV_SV0074
		missing_chr_contig_acc_call_a = [] # JV_SV0076
		strand_for_translocation_call_a = [] # JV_SV0095
		inconsistent_outer_start_stop_call_a = [] # JV_SV0047
		contig_acc_for_chr_acc_call_a = [] # JV_SV0077
		chry_for_female_call_a = [] # JV_SV0059
		missing_start_call_a = [] # JV_SV0078
		missing_stop_call_a = [] # JV_SV0079
		invalid_start_stop_call_a = [] # JV_SV0080
		invalid_outer_start_outer_stop_call_a = [] # JV_SV0081
		invalid_outer_start_inner_start_call_a = [] # JV_SV0082
		invalid_inner_stop_outer_stop_call_a = [] # JV_SV0083
		invalid_start_inner_stop_call_a = [] # JV_SV0084
		invalid_inner_start_stop_call_a = [] # JV_SV0085
		invalid_inner_start_inner_stop_call_a = [] # JV_SV0086
		multiple_starts_call_a = [] # JV_SV0087
		multiple_stops_call_a = [] # JV_SV0088
		inconsistent_length_start_stop_call_a = [] # JV_SV0089
		inconsistent_inner_start_stop_call_a = [] # JV_SV0090
		start_outer_inner_start_coexist_call_a = [] # JV_SV0091
		stop_outer_inner_stop_coexist_call_a = [] # JV_SV0092
		invalid_placements_pe_seq_call_a = [] # JV_SV0054
		invalid_seq_call_a = [] # JV_SV0060
		invalid_dataset_id_call_a = [] # JV_SV0099
		calculated_af_a = [] # JV_C0062
		ac_greater_than_an_a = [] # JV_C0063
		pos_outside_chr_call_a = [] # JV_C0061

		missing_sample_sampleset_ref_a = [] # GENOTYPE

		for variant_call in variant_call_a

			# variant call 毎に初期化
			chr_name = ""
			chr_accession = ""
			chr_length = -1
			contig_accession = ""
			assembly = ""

			# VARIANT_CALL attributes
			variant_call_attr_h = {}

			variant_call_id = ""
			variant_call_type = ""
			unless variant_call[:"Variant Call ID"].empty?

				variant_call_id = variant_call[:"Variant Call ID"]
				variant_call_attr_h.store(:variant_call_id, variant_call_id)

				if variant_call_id_h.has_key?(:"#{variant_call_id}")
					# JV_SV0030: Duplicated Variant Call ID
					duplicated_variant_call_id_a.push(variant_call_id)
					variant_call_tsv_log_a.push("#{variant_call[:row].join("\t")}\t# JV_SV0030 Error: Variant Call ID must be unique.")
				end

				# VCF を跨った study (submission) 単位のチェック
				variant_call_id_h.store(:"#{variant_call_id}", 0)

			end

			variant_call_attr_h.store(:variant_call_accession, "")

			# CV
			variant_call.each{|key_sym, value|
				if value && !value.empty? && $cv_h[object] && $cv_h[object]["#{key_sym}"] && !$cv_h[object]["#{key_sym}"].include?(value)
					## JV_C0057: Invalid value for controlled terms
					invalid_value_for_cv_call_a.push("#{variant_call_id} #{key_sym}:#{value}")
					variant_call_tsv_log_a.push("#{variant_call[:row].join("\t")}\t# JV_C0057 Error: Invalid value for controlled terms. #{key_sym}:#{value}")
				end
			}

			if !variant_call[:"Variant Call Type"].empty? && $vtype_h[:"Variant Call Type"][:"#{variant_call[:"Variant Call Type"]}"]
				variant_call_type = $vtype_h[:"Variant Call Type"][:"#{variant_call[:"Variant Call Type"]}"]
				variant_call_attr_h.store(:variant_call_type, variant_call_type)
				variant_call_id_type_h.store(:"#{variant_call_id}", variant_call_type)
			end

			# JV_SV0099: Invalid dataset reference, variant call が tsv で提供された場合、call と experiment/sampleset のリンクは dataset を介さなくなるのでチェックしない
			if !vcf_sv_f.empty? && !dataset_to_experiment_h.has_key?(variant_call[:"Dataset ID"].to_i)
				invalid_dataset_id_call_a.push(variant_call_id)
				variant_call_tsv_log_a.push("#{variant_call[:row].join("\t")}\t# JV_SV0099 Error: Provide a valid dataset ID. #{variant_call[:"Dataset ID"]}")
			end

			variant_call_attr_h.store(:variant_call_type_SO_id, "")
			variant_call_attr_h.store(:clinical_source, "")
			variant_call_attr_h.store(:clinical_significance, "")
			variant_call_attr_h.store(:insertion_length, variant_call[:"Insertion Length"]) unless !variant_call[:"Insertion Length"] && variant_call[:"Insertion Length"].empty?
			variant_call_attr_h.store(:zygosity, variant_call[:Zygosity]) unless variant_call[:Zygosity].empty?
			variant_call_attr_h.store(:origin, variant_call[:Origin]) unless variant_call[:Origin].empty?
			variant_call_attr_h.store(:copy_number, variant_call[:"Copy Number"]) unless variant_call[:"Copy Number"].empty?
			variant_call_attr_h.store(:reference_copy_number, "")
			# variant_call_attr_h.store(:support_count, "")
			# variant_call_attr_h.store(:log2_value, "")
			# variant_call_attr_h.store(:is_low_quality, "")

			# Experiment ID
			# from VCF and has an experiment ID
			if variant_call[:"Experiment ID"]
				variant_call_attr_h.store(:experiment_id, variant_call[:"Experiment ID"])
			# from tsv
			elsif !variant_call[:"Dataset ID"].empty? && dataset_to_experiment_h[variant_call[:"Dataset ID"].to_i]
				variant_call_attr_h.store(:experiment_id, dataset_to_experiment_h[variant_call[:"Dataset ID"].to_i])
			end

			variant_call_attr_h.store(:allele_count, variant_call[:"Allele Count"]) if variant_call[:"Allele Count"] && !variant_call[:"Allele Count"].empty?
			variant_call_attr_h.store(:allele_number, variant_call[:"Allele Number"]) if variant_call[:"Allele Number"] && !variant_call[:"Allele Number"].empty?

			# JV_C0063: Allele count greater than allele number
			ac_greater_than_an_f = false
			if variant_call[:"Allele Count"].to_i && variant_call[:"Allele Number"].to_i && variant_call[:"Allele Count"].to_i > variant_call[:"Allele Number"].to_i
				ac_greater_than_an_a.push(variant_call_id)
				variant_call_tsv_log_a.push("#{variant_call[:row].join("\t")}\t# JV_C0063 Error: Allele count is greater than allele number.")
				ac_greater_than_an_f = true
			end

			af = ""
			if variant_call[:"Allele Frequency"] && !variant_call[:"Allele Frequency"].empty?
				variant_call_attr_h.store(:allele_frequency, variant_call[:"Allele Frequency"])
			# AN AC があって AF がない場合、AF を計算
			elsif variant_call[:"Allele Number"] && !variant_call[:"Allele Number"].empty? && variant_call[:"Allele Number"].to_i && variant_call[:"Allele Count"] && !variant_call[:"Allele Count"].empty? && variant_call[:"Allele Count"].to_i && !ac_greater_than_an_f
				if variant_call[:"Allele Count"].to_i.fdiv(variant_call[:"Allele Number"].to_i).floor(6).to_s
					af = variant_call[:"Allele Count"].to_i.fdiv(variant_call[:"Allele Number"].to_i).floor(6).to_s
					variant_call_attr_h.store(:allele_frequency, af)
					calculated_af_a.push(variant_call_id)
					variant_call_tsv_log_a.push("#{variant_call[:row].join("\t")}\t# JV_C0062 Warning: Allele frequency was calculated as allele count/allele number.")
				end
			end

			variant_call_attr_h.store(:repeat_count, "")

			submission.VARIANT_CALL(variant_call_attr_h){|variant_call_e|

				# VALIDATION
				if variant_call[:Validation].scan(/(\d{1,}) *: *(#{validation_result_regex})/i).size > 0
					for eid, result in variant_call[:Validation].scan(/(\d{1,}) *: *(#{validation_result_regex})/i)
						variant_call_e.VALIDATION(:experiment_id => eid, :result => result.capitalize)
					end
				end

				# DESCRIPTION
				variant_call_e.DESCRIPTION(variant_call[:Description])

				# SAMPLESET
				# from VCF and has an SampleSet ID
				if variant_call[:"SampleSet ID"]
					variant_call_e.SAMPLESET(:sampleset_id => variant_call[:"SampleSet ID"])
					variant_call_id_sampleset_h.store(:"#{variant_call_id}", variant_call[:"SampleSet ID"])
				# from tsv
				elsif !variant_call[:"Dataset ID"].empty? && dataset_to_sampleset_h[variant_call[:"Dataset ID"].to_i]
					variant_call_e.SAMPLESET(:sampleset_id => dataset_to_sampleset_h[variant_call[:"Dataset ID"].to_i])
					variant_call_id_sampleset_h.store(:"#{variant_call_id}", dataset_to_sampleset_h[variant_call[:"Dataset ID"].to_i])
				end

				# LINK
				if variant_call[:"External Links"].scan(/(#{xref_db_all_regex}) *: *([-A-Za-z0-9]+)/).size > 0
					for db, id in variant_call[:"External Links"].scan(/(#{xref_db_all_regex}) *: *([-A-Za-z0-9]+)/)
						variant_call_e.LINK(:db => db, :id => id)
					end # for db, id in variant_call["External Links"].scan(/(#{xref_db_all_regex}) *: *([-A-Za-z0-9]+)/)
				end

				# PHENOTYPE
				unless variant_call[:Phenotype].empty?
					if variant_call[:Phenotype].scan(/(#{xref_db_phenotypes_regex}) *: *([-A-Za-z0-9]+)/).size > 0
						variant_call_e.PHENOTYPE{|phenotype|
							for db, id in variant_call[:Phenotype].scan(/(#{xref_db_phenotypes_regex}) *: *([-A-Za-z0-9]+)/)
								phenotype.LINK(:db => db, :id => id)
							end # for db, id in variant_call["Phenotype"].scan(/(#{xref_db_phenotypes_regex}) *: *([-A-Za-z0-9]+)/)
						}
					else
						variant_call_e.PHENOTYPE{|phenotype|
							phenotype.DESCRIPTION(variant_call[:Phenotype])
						}

						## JV_SV0033: Invalid Variant Call Phenotype link
						invalid_phenotype_link_call_a.push("#{variant_call_id} #{variant_call[:Phenotype]}")
						variant_call_tsv_log_a.push("#{variant_call[:row].join("\t")}\t# JV_SV0033 Warning: Invalid Variant Call Phenotype link. #{variant_call[:Phenotype]}")

					end
				end # unless sample["Subject Phenotype"].empty?

				# PLACEMENT attributes
				placement_attr_h = {}
				placement_attr_h.store(:placement_method, "Submitted genomic")

				## translocation
				if variant_call_type == "intrachromosomal translocation" || variant_call_type == "interchromosomal translocation"

					from_chr_name = ""
					from_chr_accession = ""
					from_chr_length = -1
					from_coord = -1
					from_contig_accession = ""
					from_assembly = ""
					from_strand = ""

					to_chr_name = ""
					to_chr_accession = ""
					to_chr_length = -1
					to_coord = -1
					to_contig_accession = ""
					to_assembly = ""
					to_strand = ""

					## mutation ID, order チェック用に格納 translocation のみ。translocation 以外にあっても無視
					if variant_call[:"Mutation ID"] && !variant_call[:"Mutation ID"].empty?
						variant_call_mutation_h.store(:"#{variant_call_id}", variant_call)
						if variant_calls_by_mutation_id_h[variant_call[:"Mutation ID"]].nil?
							variant_calls_by_mutation_id_h[variant_call[:"Mutation ID"]] = [variant_call_id]
						else
							variant_calls_by_mutation_id_h[variant_call[:"Mutation ID"]].push(variant_call_id)
						end
					end

					## JV_SV0094: Missing strand for translocation
					if variant_call[:"From Strand"].empty? || variant_call[:"To Strand"].empty?
						missing_strand_call_a.push(variant_call_id)
						variant_call_tsv_log_a.push("#{variant_call[:row].join("\t")}\t# JV_SV0094 Warning: Missing strand for translocation.")
					end

					## JV_SV0045: Invalid translocation from and to
					if variant_call[:"Assembly for Translocation Breakpoint"] && variant_call[:"Assembly for Translocation Breakpoint"].empty? || variant_call[:"From Chr"].empty? || variant_call[:"From Coord"].empty? || variant_call[:"From Strand"].empty? || variant_call[:"To Chr"].empty? || variant_call[:"To Coord"].empty? || variant_call[:"To Strand"].empty?
						invalid_from_to_call_a.push(variant_call_id)
						variant_call_tsv_log_a.push("#{variant_call[:row].join("\t")}\t# JV_SV0045 Error: Invalid translocation from and to.")

					else

						## translocation call を格納
						variant_call_translocation_h.store(:"#{variant_call_id}", variant_call)

						## JV_SV0041: Different chromosomes for intrachromosomal translocation
						if variant_call[:"Variant Call Type"] == "intrachromosomal translocation" && variant_call[:"From Chr"] != variant_call[:"To Chr"]
							different_chrs_for_intra_call_a.push(variant_call_id)
							variant_call_tsv_log_a.push("#{variant_call[:row].join("\t")}\t# JV_SV0041 Error: Different chromosomes for intrachromosomal translocation.")
						end

						## JV_SV0042: Same chromosomes for interchromosomal translocation
						if variant_call[:"Variant Call Type"] == "interchromosomal translocation" && variant_call[:"From Chr"] == variant_call[:"To Chr"]
							same_chrs_for_inter_call_a.push(variant_call_id)
							variant_call_tsv_log_a.push("#{variant_call[:row].join("\t")}\t# JV_SV0042 Error: Same chromosomes for interchromosomal translocation.")
						end

						translocation_assembly_a.push(variant_call[:"Assembly for Translocation Breakpoint"])

						# 最初の assembly で以降は同じと仮定して valid な chromosome list を構築。assembly 混在は最後にチェック
						if variant_call[:"Assembly for Translocation Breakpoint"] && !variant_call[:"Assembly for Translocation Breakpoint"].empty? && refseq_assembly.empty? && chromosome_per_assembly_a.empty?

							## assembly から refseq accession 取得
							$assembly_a.each{|assembly_h|
								refseq_assembly = assembly_h[:refseq_assembly] if assembly_h.values.include?(variant_call[:"Assembly for Translocation Breakpoint"])
							}

							## refseq assembly から構成配列を取得
							$sequence_a.each{|sequence_h|
								if sequence_h[:assemblyAccession] == refseq_assembly
									chromosome_per_assembly_a.push({:chrName => sequence_h[:chrName], :ucscStyleName => sequence_h[:ucscStyleName], :refseqAccession => sequence_h[:refseqAccession], :genbankAccession => sequence_h[:genbankAccession], :role => sequence_h[:role], :length => sequence_h[:length]})
								end
							}

						end

						variant_call.store(:refseq_assembly_breakpoint, refseq_assembly)

						# FROM
						placement_attr_h.store(:breakpoint_order, "From")

						variant_call_e.PLACEMENT(placement_attr_h){|placement_e|

							# variant call 毎に初期化
							from_chr_name = ""
							from_chr_accession = ""
							from_chr_length = -1
							from_coord = -1
							from_contig_accession = ""
							from_assembly = ""
							from_strand = ""

							## JV_SV0072: Invalid chromosome reference
							from_valid_chr_f = false
							from_valid_contig_f = false
							from_ref_download_f = false
							from_found_f = false

							# contig が download ref にある場合 (assembly には含まれていない)
							# contig は SV のみ。from/to は chr/contig がエクセルで分かれていないので、ここで download にある = contig として扱う
							if !variant_call[:"From Chr"].empty? && $ref_download_h.has_key?(variant_call[:"From Chr"]) && !from_found_f
								from_assembly = ""
								from_chr_name = ""
								from_chr_accession = ""
								from_chr_length = $ref_download_h[variant_call[:"From Chr"]].to_i if $ref_download_h[variant_call[:"From Chr"]].to_i
								from_contig_accession = variant_call[:"From Chr"]

								from_valid_contig_f = true
								from_ref_download_f = true
								from_found_f = true
							# contig accession が前と一致
							elsif !variant_call[:"From Chr"].empty? && variant_call[:"From Chr"] == pre_from_contig_accession
								from_assembly = pre_from_assembly
								from_chr_name = ""
								from_chr_accession = ""
								from_chr_length = pre_from_chr_length
								from_contig_accession = pre_from_contig_accession

								from_valid_contig_f = true
								from_found_f = true
							# chromosome name が前と一致
							elsif !variant_call[:"From Chr"].empty? && variant_call[:"From Chr"] == pre_from_chr_name
								from_assembly = pre_from_assembly
								from_chr_name = pre_from_chr_name
								from_chr_accession = pre_from_chr_accession
								from_chr_length = pre_from_chr_length
								from_contig_accession = ""

								from_valid_chr_f = true
								from_found_f = true
							# 前と一致しない場合
							else
								for chromosome_per_assembly_h in chromosome_per_assembly_a

									## From Chr が chromosome ではなく RefSeq/GenBank アクセッション番号で指定された contig
									if !variant_call[:"From Chr"].empty? && (chromosome_per_assembly_h[:refseqAccession] == variant_call[:"From Chr"] || chromosome_per_assembly_h[:genbankAccession] == variant_call[:"From Chr"]) && !from_found_f
										from_assembly = variant_call[:"Assembly for Translocation Breakpoint"]
										from_chr_name = ""
										from_chr_accession = ""
										from_chr_length = chromosome_per_assembly_h[:length]
										from_contig_accession = chromosome_per_assembly_h[:refseqAccession] # fna は refseqAccession 記載

										from_valid_contig_f = true
										from_found_f = true
									## From Chr が assembly で規定されている chromosome name (例 chr1, 1)
									elsif !variant_call[:"From Chr"].empty? && chromosome_per_assembly_h[:chrName] == variant_call[:"From Chr"].sub(/chr/i, "") && chromosome_per_assembly_h[:role] == "assembled-molecule" && !from_found_f
										from_assembly = variant_call[:"Assembly for Translocation Breakpoint"]
										from_chr_name = chromosome_per_assembly_h[:chrName]
										from_chr_accession = chromosome_per_assembly_h[:refseqAccession]
										from_chr_length = chromosome_per_assembly_h[:length]
										from_contig_accession = ""

										from_valid_chr_f = true
										from_found_f = true
									## From Chr が UCSC stype の contig name (例 chr1_gl000191_random)
									elsif !variant_call[:"From Chr"].empty? && chromosome_per_assembly_h[:ucscStyleName].sub(/^chr/i, "") == variant_call[:"From Chr"].sub(/^chr/i, "") && !from_found_f
										from_assembly = variant_call[:"Assembly for Translocation Breakpoint"]
										from_chr_name = chromosome_per_assembly_h[:ucscStyleName]
										from_chr_accession = chromosome_per_assembly_h[:refseqAccession]
										from_chr_length = chromosome_per_assembly_h[:length]
										from_contig_accession = ""

										from_valid_chr_f = true
										from_found_f = true
									end

								end # for chromosome_per_assembly_h in chromosome_per_assembly_a

								pre_from_assembly = from_assembly
								pre_from_chr_name = from_chr_name
								pre_from_chr_accession = from_chr_accession
								pre_from_chr_length = from_chr_length
								pre_from_contig_accession = from_contig_accession

							end # if !variant_call["From Chr"].empty? && $ref_download_h.has_key?(variant_call["From Chr"])

							## JV_SV0072: Invalid chromosome reference, to/from は contig 列がなく一体
							if !variant_call[:"From Chr"].empty? && !from_valid_chr_f && !from_valid_contig_f && !from_ref_download_f
								invalid_chr_ref_call_a.push(variant_call_id)
								variant_call_tsv_log_a.push("#{variant_call[:row].join("\t")}\t# JV_SV0072 Error: Invalid chromosome reference.")
							end

							from_strand = variant_call[:"From Strand"]

							# FROM GENOME
							from_genome_attr_h = {}
							from_genome_attr_h.store(:assembly, refseq_assembly)

							from_genome_attr_h.store(:chr_name, from_chr_name)
							from_genome_attr_h.store(:chr_accession, from_chr_accession)
							from_genome_attr_h.store(:contig_accession, from_contig_accession)
							from_genome_attr_h.store(:strand, from_strand)

							variant_call.store(:refseq_assembly_breakpoint, refseq_assembly)
							variant_call.store(:from_chr_accession, from_chr_accession)
							variant_call.store(:from_contig_accession, from_contig_accession)

							# FROM COORD
							if variant_call[:"From Coord"] && variant_call[:"From Coord"].to_i
								from_coord = variant_call[:"From Coord"].to_i
								from_genome_attr_h.store(:start, variant_call[:"From Coord"])
								from_genome_attr_h.store(:stop, variant_call[:"From Coord"])
							else
								from_genome_attr_h.store(:start, "")
								from_genome_attr_h.store(:stop, "")
							end

							# cipos
							from_genome_attr_h.store(:ciposleft, variant_call[:ciposleft]) if variant_call[:ciposleft] && !variant_call[:ciposleft].empty?
							from_genome_attr_h.store(:ciposright, variant_call[:ciposright]) if variant_call[:ciposright] && !variant_call[:ciposright].empty?

							# GENOME attributes
							placement_e.GENOME(from_genome_attr_h)

							if from_chr_length != -1
								if from_coord != -1 && (from_coord > from_chr_length + 1)
									pos_outside_chr_call_a.push(variant_call_id)
									variant_call_tsv_log_a.push("#{variant_call[:row].join("\t")}\t# JV_C0061 Error: Chromosome position is larger than chromosome size + 1. Check if the position is correct.")
								end
							end

						} # placement_e

						# TO
						placement_attr_h.store(:breakpoint_order, "To")

						variant_call_e.PLACEMENT(placement_attr_h){|placement_e|

							# variant call 毎に初期化
							to_chr_name = ""
							to_chr_accession = ""
							to_chr_length = -1
							to_coord = -1
							to_contig_accession = ""
							to_assembly = ""
							to_strand = ""

							## JV_SV0072: Invalid chromosome reference
							to_valid_chr_f = false
							to_valid_contig_f = false
							to_ref_download_f = false
							to_found_f = false

							# contig が download ref にあるかどうか. download にある = assembly には含まれていない
							if !variant_call[:"To Chr"].empty? && $ref_download_h.has_key?(variant_call[:"To Chr"]) && !to_found_f
								to_assembly = ""
								to_chr_name = ""
								to_chr_accession = ""
								to_chr_length = $ref_download_h[variant_call[:"To Chr"]].to_i if $ref_download_h[variant_call[:"To Chr"]].to_i
								to_contig_accession = variant_call[:"To Chr"]

								to_valid_contig_f = true
								to_ref_download_f = true
								to_found_f = true
							# contig accession が前と一致
							elsif !variant_call[:"To Chr"].empty? && variant_call[:"To Chr"] == pre_to_contig_accession
								to_assembly = pre_to_assembly
								to_chr_name = ""
								to_chr_accession = ""
								to_chr_length = pre_to_chr_length
								to_contig_accession = pre_to_contig_accession

								to_valid_contig_f = true
								to_found_f = true
							# chromosome name が前と一致
							elsif !variant_call[:"To Chr"].empty? && variant_call[:"To Chr"] == pre_to_chr_name
								to_assembly = pre_to_assembly
								to_chr_name = pre_to_chr_name
								to_chr_accession = pre_to_chr_accession
								to_chr_length = pre_to_chr_length
								to_contig_accession = ""

								to_valid_chr_f = true
								to_found_f = true
							# 前と一致しない場合
							else
								for chromosome_per_assembly_h in chromosome_per_assembly_a
									## From Chr に sequence report にある RefSeq/GenBank accession が記載されているかどうか
									if !variant_call[:"To Chr"].empty? && (chromosome_per_assembly_h[:refseqAccession] == variant_call[:"To Chr"] || chromosome_per_assembly_h[:genbankAccession] == variant_call[:"To Chr"]) && !to_found_f
										to_assembly = variant_call[:"Assembly for Translocation Breakpoint"]
										to_chr_name = ""
										to_chr_accession = ""
										to_chr_length = chromosome_per_assembly_h[:length]
										to_contig_accession = chromosome_per_assembly_h[:refseqAccession] # fna は refseqAccession 記載

										to_valid_contig_f = true
										to_found_f = true
									elsif !variant_call[:"To Chr"].empty? && chromosome_per_assembly_h[:chrName] == variant_call[:"To Chr"].sub(/chr/i, "") && chromosome_per_assembly_h[:role] == "assembled-molecule" && !to_found_f
										to_assembly = variant_call[:"Assembly for Translocation Breakpoint"]
										to_chr_name = chromosome_per_assembly_h[:chrName]
										to_chr_accession = chromosome_per_assembly_h[:refseqAccession]
										to_chr_length = chromosome_per_assembly_h[:length]
										to_contig_accession = ""

										to_valid_chr_f = true
										to_found_f = true
									elsif !variant_call[:"To Chr"].empty? && chromosome_per_assembly_h[:ucscStyleName].sub(/^chr/i, "") == variant_call[:"To Chr"].sub(/^chr/i, "") && !to_found_f
										to_assembly = variant_call[:"Assembly for Translocation Breakpoint"]
										to_chr_name = chromosome_per_assembly_h[:ucscStyleName]
										to_chr_accession = chromosome_per_assembly_h[:refseqAccession]
										to_chr_length = chromosome_per_assembly_h[:length]
										to_contig_accession = ""

										to_valid_chr_f = true
										to_found_f = true
									end

								end # for chromosome_per_assembly_h in chromosome_per_assembly_a

								pre_to_assembly = to_assembly
								pre_to_chr_name = to_chr_name
								pre_to_chr_accession = to_chr_accession
								pre_to_chr_length = to_chr_length
								pre_to_contig_accession = to_contig_accession

							end # if !variant_call["To Chr"].empty? && $ref_download_h.has_key?(variant_call["To Chr"])

							## JV_SV0072: Invalid chromosome reference, to/from は contig 列がなく一体
							if !variant_call[:"To Chr"].empty? && !to_valid_chr_f && !to_valid_contig_f && !to_ref_download_f
								invalid_chr_ref_call_a.push(variant_call_id)
								variant_call_tsv_log_a.push("#{variant_call[:row].join("\t")}\t# JV_SV0072 Error: Invalid chromosome reference.")
							end

							to_strand = variant_call[:"To Strand"]

							# TO GENOME
							to_genome_attr_h = {}
							to_genome_attr_h.store(:assembly, refseq_assembly)

							to_genome_attr_h.store(:chr_name, to_chr_name)
							to_genome_attr_h.store(:chr_accession, to_chr_accession)
							to_genome_attr_h.store(:contig_accession, to_contig_accession)
							to_genome_attr_h.store(:strand, to_strand)

							variant_call.store(:to_chr_accession, to_chr_accession)
							variant_call.store(:to_contig_accession, to_contig_accession)

							# TO COORD
							if variant_call[:"To Coord"] && variant_call[:"To Coord"].to_i
								to_coord = variant_call[:"To Coord"].to_i
								to_genome_attr_h.store(:start, variant_call[:"To Coord"])
								to_genome_attr_h.store(:stop, variant_call[:"To Coord"])
							else
								to_genome_attr_h.store(:start, "")
								to_genome_attr_h.store(:stop, "")
							end

							# ciend
							to_genome_attr_h.store(:ciendleft, variant_call[:ciendleft]) if variant_call[:ciendleft] && !variant_call[:ciendleft].empty?
							to_genome_attr_h.store(:ciendright, variant_call[:ciendright]) if variant_call[:ciendright] && !variant_call[:ciendright].empty?

							# GENOME attributes
							placement_e.GENOME(to_genome_attr_h)

							## JV_C0061: Chromosome position larger than chromosome size + 1
							if to_chr_length != -1
								if to_coord != -1 && (to_coord > to_chr_length + 1)
									pos_outside_chr_call_a.push(variant_call_id)
									variant_call_tsv_log_a.push("#{variant_call[:row].join("\t")}\t# JV_C0061 Error: Chromosome position is larger than chromosome size + 1. Check if the position is correct.")
								end
							end

						} # placement_e

					end # if there are translocation placements

				else # if not =~ /translocation/

					## JV_SV0095: Strand for non-translocation
					if (variant_call[:"From Strand"] && !variant_call[:"From Strand"].empty?) || (variant_call[:"To Strand"] && !variant_call[:"To Strand"].empty?)
						strand_for_translocation_call_a.push(variant_call_id)
						variant_call_tsv_log_a.push("#{variant_call[:row].join("\t")}\t# JV_SV0095 Warning: Strand for non-translocation.")
					end

					# placement_attr_h.store(:alt_status, "")
					# placement_attr_h.store(:breakpoint_order, "")

					# 最初の assembly で VCF/variant call tsv 毎に以降は同じと仮定して valid な chromosome list を構築。assembly 混在は最後にチェック
					if variant_call[:Assembly] && !variant_call[:Assembly].empty? && refseq_assembly == "" && chromosome_per_assembly_a.empty?

						## assembly から refseq accession 取得
						$assembly_a.each{|assembly_h|
							refseq_assembly = assembly_h[:refseq_assembly] if assembly_h.values.include?(variant_call[:Assembly])
						}

						## refseq assembly から構成配列を取得
						$sequence_a.each{|sequence_h|
							if sequence_h[:assemblyAccession] == refseq_assembly
								chromosome_per_assembly_a.push({:chrName => sequence_h[:chrName], :ucscStyleName => sequence_h[:ucscStyleName], :refseqAccession => sequence_h[:refseqAccession], :genbankAccession => sequence_h[:genbankAccession], :role => sequence_h[:role], :length => sequence_h[:length]})
							end
						}

					end

					variant_call.store(:refseq_assembly, refseq_assembly)

					# deletion
					if variant_call[:"Variant Call Type"] == "deletion"

						# if outers-only
						if !variant_call[:"Outer Start"].empty? && !variant_call[:"Outer Stop"].empty? && variant_call[:Start].empty? && variant_call[:"Inner Start"].empty? && variant_call[:Stop].empty? && variant_call[:"Inner Stop"].empty?
							## JV_SV0047: Inconsistent outer start and outer stop
							inconsistent_outer_start_stop_call_a.push(variant_call_id) if variant_call[:"Outer Start"].to_i > variant_call[:"Outer Stop"].to_i
							variant_call_tsv_log_a.push("#{variant_call[:row].join("\t")}\t# JV_SV0047 Error: Inconsistent outer start and outer stop.")
						end

					end

					variant_call_e.PLACEMENT(placement_attr_h){|placement_e|

						# GENOME
						genome_attr_h = {}

						## JV_SV0072: Invalid chromosome reference
							# variant call 毎に初期化
							chr_name = ""
							chr_accession = ""
							chr_length = -1
							contig_accession = ""
							assembly = ""
							start_pos = -1
							stop_pos = -1

							## JV_SV0072: Invalid chromosome reference
							valid_chr_f = false
							valid_contig_f = false
							ref_download_f = false
							found_f = false

							# contig が download ref にあるかどうか. download にある = assembly には含まれていない
							if variant_call[:Chr] && !variant_call[:Chr].empty? && $ref_download_h.has_key?(variant_call[:Chr]) && !found_f
								assembly = ""
								chr_name = ""
								chr_accession = ""
								chr_length = $ref_download_h[variant_call[:Chr]].to_i if $ref_download_h[variant_call[:Chr]].to_i
								contig_accession = variant_call[:Chr]

								valid_contig_f = true
								ref_download_f = true
								found_f = true
							# contig accession が前と一致
							elsif variant_call[:Chr] && !variant_call[:Chr].empty? && variant_call[:Chr] == pre_contig_accession
								assembly = pre_assembly
								chr_name = ""
								chr_accession = ""
								chr_length = pre_chr_length
								contig_accession = pre_contig_accession

								valid_contig_f = true
								found_f = true
							# chromosome name が前と一致
							elsif variant_call[:Chr] && !variant_call[:Chr].empty? && variant_call[:Chr] == pre_chr_name
								assembly = pre_assembly
								chr_name = pre_chr_name
								chr_accession = pre_chr_accession
								chr_length = pre_chr_length
								contig_accession = ""

								valid_chr_f = true
								found_f = true
							# 前と一致しない場合
							else
								for chromosome_per_assembly_h in chromosome_per_assembly_a
									## From Chr に sequence report にある RefSeq/GenBank accession が記載されているかどうか
									if !variant_call[:Chr].empty? && (chromosome_per_assembly_h[:refseqAccession] == variant_call[:Chr] || chromosome_per_assembly_h[:genbankAccession] == variant_call[:Chr]) && !found_f
										assembly = variant_call[:"Assembly for Translocation Breakpoint"]
										chr_name = ""
										chr_accession = ""
										chr_length = chromosome_per_assembly_h[:length]
										contig_accession = chromosome_per_assembly_h[:refseqAccession] # fna は refseqAccession 記載

										valid_contig_f = true
										found_f = true
									elsif !variant_call[:Chr].empty? && chromosome_per_assembly_h[:chrName] == variant_call[:Chr].sub(/chr/i, "") && chromosome_per_assembly_h[:role] == "assembled-molecule" && !found_f
										assembly = variant_call[:"Assembly for Translocation Breakpoint"]
										chr_name = chromosome_per_assembly_h[:chrName]
										chr_accession = chromosome_per_assembly_h[:refseqAccession]
										chr_length = chromosome_per_assembly_h[:length]
										contig_accession = ""

										valid_chr_f = true
										found_f = true
									elsif !variant_call[:Chr].empty? && chromosome_per_assembly_h[:ucscStyleName].sub(/^chr/i, "") == variant_call[:Chr].sub(/^chr/i, "") && !found_f
										assembly = variant_call[:"Assembly for Translocation Breakpoint"]
										chr_name = chromosome_per_assembly_h[:ucscStyleName]
										chr_accession = chromosome_per_assembly_h[:refseqAccession]
										chr_length = chromosome_per_assembly_h[:length]
										contig_accession = ""

										valid_chr_f = true
										found_f = true
									end

								end # for chromosome_per_assembly_h in chromosome_per_assembly_a

								variant_call[:Contig] = contig_accession unless contig_accession.empty?

								pre_assembly = assembly
								pre_chr_name = chr_name
								pre_chr_accession = chr_accession
								pre_chr_length = chr_length
								pre_contig_accession = contig_accession

							end # if !variant_call["Chr"].empty? && $ref_download_h.has_key?(variant_call["Chr"])

						## JV_SV0077: Contig accession exists for chromosome accession
						if !variant_call[:Contig].empty? && !variant_call[:Chr].empty?
							contig_acc_for_chr_acc_call_a.push(variant_call_id)
							variant_call_tsv_log_a.push("#{variant_call[:row].join("\t")}\t# JV_SV0077 Error: Contig accession exists for chromosome accession.")
						end

						## JV_SV0072: Invalid chromosome reference !valid_contig_f は chr に contig accession が書いてある場合を考慮
						if !variant_call[:Chr].empty? && !valid_chr_f && !valid_contig_f
							invalid_chr_ref_call_a.push(variant_call_id)
							variant_call_tsv_log_a.push("#{variant_call[:row].join("\t")}\t# JV_SV0072 Error: Invalid chromosome reference.")
						end

						## JV_SV0074: Invalid contig accession reference
						if !variant_call[:Contig].empty? && !valid_contig_f
							invalid_contig_acc_ref_call_a.push("#{variant_call_id} #{variant_call[:Contig]}")
							variant_call_tsv_log_a.push("#{variant_call[:row].join("\t")}\t# JV_SV0074 Error: Invalid contig accession reference.")

							# download fasta
							contig_download_a.push("wget \"http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nucleotide&id=#{variant_call["Contig"]}&rettype=fasta\" -O #{ref_download_path}/#{variant_call["Contig"]}.fna")
							contig_download_a.push("samtools faidx #{variant_call[:Contig]}.fna")
						end

						## JV_SV0076: Missing chromosome/contig accession
						if chr_name.empty? && chr_accession.empty? && contig_accession.empty?
							missing_chr_contig_acc_call_a.push(variant_call_id)
							variant_call_tsv_log_a.push("#{variant_call[:row].join("\t")}\t# JV_SV0076 Error: Missing chromosome/contig accession.")
						end

						## JV_SV0059: Chromosome Y for female
						if chr_name == "Y" && variant_call[:"SampleSet ID"] && !variant_call[:"SampleSet ID"].empty? && sampleset_id_sex_h[variant_call[:"SampleSet ID"]] && sampleset_id_sex_h[variant_call[:"SampleSet ID"]] == "Female"
							chry_for_female_call_a.push(variant_call_id)
							variant_call_tsv_log_a.push("#{variant_call[:row].join("\t")}\t# JV_SV0059 Warning: Chromosome Y for female")
						end

						## genome_attr_h
						## download に存在　=　Assembly　には含まれていない
						genome_attr_h.store(:assembly, refseq_assembly)

						## chr/chr_accession/contig_accession
						genome_attr_h.store(:chr_name, chr_name)
						genome_attr_h.store(:chr_accession, chr_accession)
						genome_attr_h.store(:contig_accession, contig_accession)

						variant_call.store(:refseq_assembly, refseq_assembly)
						variant_call.store(:chr_accession, chr_accession)
						variant_call.store(:contig_accession, contig_accession)

						## placement check
						## JV_SV0078: Missing start
						if variant_call[:"Outer Start"].empty? && variant_call[:Start].empty? && variant_call[:"Inner Start"].empty? && !variant_call_type.match?(/translocation/) && variant_call_type != "novel sequence insertion"
							missing_start_call_a.push(variant_call_id)
							variant_call_tsv_log_a.push("#{variant_call[:row].join("\t")}\t# JV_SV0078 Error: Missing start.")
						end

						## JV_SV0079: Missing stop
						if variant_call[:"Outer Stop"].empty? && variant_call[:Stop].empty? && variant_call[:"Inner Stop"].empty? && !variant_call_type.match?(/translocation/) && variant_call_type != "novel sequence insertion"
							missing_stop_call_a.push(variant_call_id)
							variant_call_tsv_log_a.push("#{variant_call[:row].join("\t")}\t# JV_SV0079 Error: Missing stop.")
						end

						# JV_SV0080: When on same sequence, start must be <= stop
						if !variant_call[:Start].empty? && !variant_call[:Stop].empty? && (variant_call[:Start].to_i > variant_call[:Stop].to_i)
							invalid_start_stop_call_a.push(variant_call_id)
							variant_call_tsv_log_a.push("#{variant_call[:row].join("\t")}\t# JV_SV0080 Error: When on same sequence, start must be <= stop.")
						end

						# JV_SV0081: When on same sequence, outer_start must be <= outer_stop
						if !variant_call[:"Outer Start"].empty? && !variant_call[:"Outer Stop"].empty? && (variant_call[:"Outer Start"].to_i > variant_call[:"Outer Stop"].to_i)
							invalid_outer_start_outer_stop_call_a.push(variant_call_id)
							variant_call_tsv_log_a.push("#{variant_call[:row].join("\t")}\t# JV_SV0081 Error: When on same sequence, outer_start must be <= outer_stop.")
						end

						# JV_SV0082: When on same sequence, outer_start must be <= inner_start
						if !variant_call[:"Outer Start"].empty? && !variant_call[:"Inner Start"].empty? && (variant_call[:"Outer Start"].to_i > variant_call[:"Inner Start"].to_i)
							invalid_outer_start_inner_start_call_a.push(variant_call_id)
							variant_call_tsv_log_a.push("#{variant_call[:row].join("\t")}\t# JV_SV0082 Error: When on same sequence, outer_start must be <= inner_start.")
						end

						# JV_SV0083: When on same sequence, inner_stop must be <= outer_stop
						if !variant_call[:"Inner Stop"].empty? && !variant_call[:"Outer Stop"].empty? && (variant_call[:"Inner Stop"].to_i > variant_call[:"Outer Stop"].to_i)
							invalid_inner_stop_outer_stop_call_a.push(variant_call_id)
							variant_call_tsv_log_a.push("#{variant_call[:row].join("\t")}\t# JV_SV0083 Error: When on same sequence, inner_stop must be <= outer_stop.")
						end

						# JV_SV0084: Invalid start and inner stop
						if !variant_call[:Start].empty? && !variant_call[:"Inner Stop"].empty? && (variant_call[:Start].to_i >= variant_call[:"Inner Stop"].to_i) && !(!variant_call[:Start].empty? && !variant_call[:Stop].empty? && !variant_call[:"Outer Start"].empty? && !variant_call[:"Outer Stop"].empty? && !variant_call[:"Inner Start"].empty? && !variant_call[:"Inner Stop"].empty?)
							invalid_start_inner_stop_call_a.push(variant_call_id)
							variant_call_tsv_log_a.push("#{variant_call[:row].join("\t")}\t# JV_SV0084 Error: Invalid start and inner stop.")
						end

						# JV_SV0085: Invalid inner start and stop
						if !variant_call[:"Inner Start"].empty? && !variant_call[:Stop].empty? && (variant_call[:"Inner Start"].to_i >= variant_call[:Stop].to_i) && !(!variant_call[:Start].empty? && !variant_call[:Stop].empty? && !variant_call[:"Outer Start"].empty? && !variant_call[:"Outer Stop"].empty? && !variant_call[:"Inner Start"].empty? && !variant_call[:"Inner Stop"].empty?)
							invalid_inner_start_stop_call_a.push(variant_call_id)
							variant_call_tsv_log_a.push("#{variant_call[:row].join("\t")}\t# JV_SV0085 Error: Invalid inner start and stop")
						end

						# JV_SV0086: When on same sequence, inner_start must be <= inner_stop if there are only inner placements
						if !variant_call[:"Inner Start"].empty? && !variant_call[:"Inner Stop"].empty? && (variant_call[:"Inner Start"].to_i > variant_call[:"Inner Stop"].to_i) && !(variant_call[:Start].empty? && variant_call[:Stop].empty? && variant_call[:"Outer Start"].empty? && variant_call[:"Outer Stop"].empty? && !variant_call[:"Inner Start"].empty? && !variant_call[:"Inner Stop"].empty?)
							invalid_inner_start_inner_stop_call_a.push(variant_call_id)
							variant_call_tsv_log_a.push("#{variant_call[:row].join("\t")}\t# JV_SV0086 Error: When on same sequence, inner_start must be <= inner_stop if there are only inner placements.")
						end

						# JV_SV0087: Multiple starts
						if !variant_call[:Start].empty? && (!variant_call[:"Inner Start"].empty? || !variant_call[:"Outer Start"].empty?) || (!variant_call[:"Inner Start"].empty? && !variant_call[:"Outer Start"].empty?) && !variant_call[:Start].empty?
							if (!variant_call[:Start].empty? && !variant_call[:"Outer Start"].empty? && variant_call[:Start] != variant_call[:"Outer Start"]) && (!variant_call[:Start].empty? && !variant_call[:"Inner Start"].empty? && variant_call[:Start] != variant_call[:"Inner Start"])
								multiple_starts_call_a.push(variant_call_id)
								variant_call_tsv_log_a.push("#{variant_call[:row].join("\t")}\t# JV_SV0087 Error: Multiple starts.")
							end
						end

						# JV_SV0088: Multiple stops
						if !variant_call[:Stop].empty? && (!variant_call[:"Inner Stop"].empty? || !variant_call[:"Outer Stop"].empty?) || (!variant_call[:"Inner Stop"].empty? && !variant_call[:"Outer Stop"].empty?) && !variant_call[:Stop].empty?
							if (!variant_call[:Stop].empty? && !variant_call[:"Outer Stop"].empty? && variant_call[:Stop] != variant_call[:"Outer Stop"]) && (!variant_call[:Stop].empty? && !variant_call[:"Inner Stop"].empty? && variant_call[:Stop] != variant_call[:"Inner Stop"])
								multiple_stops_call_a.push(variant_call_id)
								variant_call_tsv_log_a.push("#{variant_call[:row].join("\t")}\t# JV_SV0088 Error: Multiple stops.")
							end
						end

						# JV_SV0089: Inconsistent sequence length and start/stop
						if chr_length != -1
							if (!variant_call[:Stop].empty? && variant_call[:Stop].to_i > chr_length.to_i) || (!variant_call[:"Inner Stop"].empty? && variant_call[:"Inner Stop"].to_i > chr_length.to_i) || (!variant_call[:"Outer Stop"].empty? && variant_call[:"Outer Stop"].to_i > chr_length.to_i)
								inconsistent_length_start_stop_call_a.push(variant_call_id)
								variant_call_tsv_log_a.push("#{variant_call[:row].join("\t")}\t# JV_SV0089 Error: Inconsistent sequence length and start/stop.")
							end
						end

						# JV_SV0090: Inconsistent inner start and stop
						if !variant_call[:"Inner Start"].empty? && !variant_call[:"Inner Stop"].empty? && (variant_call[:"Inner Start"].to_i > variant_call[:"Inner Stop"].to_i) && (!variant_call[:"Outer Start"].empty? || !variant_call[:"Outer Stop"].empty?)
							inconsistent_inner_start_stop_call_a.push(variant_call_id)
							variant_call_tsv_log_a.push("#{variant_call[:row].join("\t")}\t# JV_SV0090 Warning: Inconsistent inner start and stop.")
						end

						# JV_SV0091: Start and outer/inner starts co-exist
						start_outer_inner_start_coexist_call_a.push(variant_call_id) if !variant_call[:"Inner Start"].empty? && !variant_call[:Start].empty? && !variant_call[:"Outer Start"].empty?

						# JV_SV0092: Stop and outer/inner stops co-exist
						stop_outer_inner_stop_coexist_call_a.push(variant_call_id) if !variant_call[:"Inner Stop"].empty? && !variant_call[:Stop].empty? && !variant_call[:"Outer Stop"].empty?

						# start
						genome_attr_h.store(:outer_start, variant_call[:"Outer Start"]) unless variant_call[:"Outer Start"].empty?
						genome_attr_h.store(:start, variant_call[:Start]) unless variant_call[:Start].empty?
						genome_attr_h.store(:inner_start, variant_call[:"Inner Start"]) unless variant_call[:"Inner Start"].empty?

						# stop
						genome_attr_h.store(:stop, variant_call[:Stop]) unless variant_call[:Stop].empty?
						genome_attr_h.store(:inner_stop, variant_call[:"Inner Stop"]) unless variant_call[:"Inner Stop"].empty?
						genome_attr_h.store(:outer_stop, variant_call[:"Outer Stop"]) unless variant_call[:"Outer Stop"].empty?
						genome_attr_h.store(:ciposleft, variant_call[:ciposleft]) if variant_call[:ciposleft] && !variant_call[:ciposleft].empty?
						genome_attr_h.store(:ciposright, variant_call[:ciposright]) if variant_call[:ciposright] && !variant_call[:ciposright].empty?
						genome_attr_h.store(:ciendleft, variant_call[:ciendleft]) if variant_call[:ciendleft] && !variant_call[:ciendleft].empty?
						genome_attr_h.store(:ciendright, variant_call[:ciendright]) if variant_call[:ciendright] && !variant_call[:ciendright].empty?
						# genome_attr_h.store(:remap_score, "")
						# genome_attr_h.store(:strand, "")
						# genome_attr_h.store(:assembly_unit, "")
						# genome_attr_h.store(:alignment, "")
						# genome_attr_h.store(:remap_failure_code, "")
						# genome_attr_h.store(:placement_rank, "")
						# genome_attr_h.store(:placements_per_assembly, "")
						# genome_attr_h.store(:remap_diff_chr, "")
						# genome_attr_h.store(:remap_best_within_cluster, "")

						# translocation 以外の region に機械的にまとめる same pos and type の SVs, pos は cipos ciend も考慮
						# https://ddbj-dev.atlassian.net/wiki/spaces/jvar/pages/2470674436/Variant+region+assertion
						hash_sv = :"#{variant_call_type}:#{chr_accession}:#{contig_accession}:#{variant_call[:"Outer Start"]}:#{variant_call[:Start]}:#{variant_call[:"Inner Start"]}:#{variant_call[:"Inner Stop"]}:#{variant_call[:Stop]}:#{variant_call[:"Outer Stop"]}:#{variant_call[:ciposleft]}:#{variant_call[:ciposright]}:#{variant_call[:ciendleft]}:#{variant_call[:ciendright]}:#{variant_call[:"Insertion Length"]}"
						if variant_call_site_h.has_key?(hash_sv)
							identical_variant_call_site_id_h[hash_sv] = [variant_call_site_h[hash_sv]] if identical_variant_call_site_id_h[hash_sv].nil?
							identical_variant_call_site_id_h[hash_sv].push(variant_call_id)
						end
						variant_call_site_h.store(hash_sv, variant_call_id)

						# GENOME attributes
						placement_e.GENOME(genome_attr_h)

						# min start
						if [variant_call[:"Outer Start"], variant_call[:Start], variant_call[:"Inner Start"]].reject{|e| e.empty? }.map{|e| e.to_i}.min
							start_pos = [variant_call[:"Outer Start"], variant_call[:Start], variant_call[:"Inner Start"]].reject{|e| e.empty? }.map{|e| e.to_i}.min
						end

						# max stop
						if [variant_call[:"Outer Stop"], variant_call[:Stop], variant_call[:"Inner Stop"]].reject{|e| e.empty? }.map{|e| e.to_i}.max
							stop_pos = [variant_call[:"Outer Stop"], variant_call[:Stop], variant_call[:"Inner Stop"]].reject{|e| e.empty? }.map{|e| e.to_i}.max
						end

						# JV_C0061: Chromosome position larger than chromosome size + 1
						if chr_length != -1
							if (start_pos != -1 && (start_pos > chr_length + 1)) || (stop_pos != -1 && (stop_pos > chr_length + 1))
								pos_outside_chr_call_a.push(variant_call_id)
								variant_call_tsv_log_a.push("#{variant_call[:row].join("\t")}\t# JV_C0061 Error: Chromosome position is larger than chromosome size + 1. Check if the position is correct.")
							end
						end

						## parent region の placement との整合性チェック
						variant_call_placement_h.store(:"#{variant_call_id}", {:Assembly => refseq_assembly, :Chr => chr_name, :Contig => contig_accession, :"Outer Start" => variant_call[:"Outer Start"], :Start => variant_call[:Start], :"Inner Start" => variant_call[:"Inner Start"], :Stop => variant_call[:Stop], :"Inner Stop" => variant_call[:"Inner Stop"], :"Outer Stop" => variant_call[:"Outer Stop"]})

					} # placement_e

				end # if translocation

				## JV_SV0054: Invalid placements for paired-end sequencing
				if experiment_type_h[variant_call[:"Experiment ID"]] && experiment_type_h[variant_call[:"Experiment ID"]]["Method Type"] == "Sequencing" && experiment_type_h[variant_call[:"Experiment ID"]]["Analysis Type"] == "Paired-end mapping" && (!variant_call[:Start].empty? || !variant_call[:"Inner Start"].empty? || !variant_call[:Stop].empty? || !variant_call[:"Inner Stop"].empty?)
					invalid_placements_pe_seq_call_a.push(variant_call_id)
				end

				# VARIANT_SEQUENCE
				if variant_call[:Sequence] && !variant_call[:Sequence].empty?
					variant_call_e.VARIANT_SEQUENCE(variant_call[:Sequence])

					## JV_SV0060: Invalid sequence
					unless variant_call[:Sequence].match?(/^[- .ABCDGHKMNRSTUVWY]+$/i)
						invalid_seq_call_a.push(variant_call_id) # JV_SV0060
					end
				end

				# VARIANT_SEQUENCE from VCF
				if variant_call[:variant_sequence] && !variant_call[:variant_sequence].empty?
					variant_call_e.VARIANT_SEQUENCE(variant_call[:variant_sequence])

					## JV_SV0060: Invalid sequence
					unless variant_call[:variant_sequence].match?(/^[- .ABCDGHKMNRSTUVWY]+$/i)
						invalid_seq_call_a.push(variant_call_id) # JV_SV0060
					end
				end

				# SUPPORT db id
				unless variant_call[:Evidence].empty?
					if variant_call[:Evidence].scan(/(#{xref_db_all_regex}) *: *([-A-Za-z0-9]+)/).size > 0
						for db, id in variant_call[:Evidence].scan(/(#{xref_db_all_regex}) *: *([-A-Za-z0-9]+)/)
							variant_call_e.SUPPORT(:db => db, :id => id, :sequence_type => "evidence_seq")
						end # for db, id in variant_call["Evidence"].scan(/(#{xref_db_all_regex}) *: *([-A-Za-z0-9]+)/)
					else
						## JV_SV0036: Invalid Variant Call Phenotype link
						invalid_phenotype_link_evidence_call_a.push(variant_call_id)
					end
				end

			} # variant_call_e

			##
			## GENOTYPE
			##
			if sv_genotype_f

				# Sample Name, Subject ID は BioSample accession に置換
				unless variant_call[:FORMAT].empty?

					for ft_value_h in variant_call[:FORMAT]

						genotype_attr_h = {}

						unless variant_call[:"Variant Call ID"] && variant_call[:"Variant Call ID"].empty?
							genotype_attr_h.store(:variant_accession, variant_call[:"Variant Call ID"])
						else
							genotype_attr_h.store(:variant_accession, "")
						end

						unless variant_call[:"Experiment ID"] && variant_call[:"Experiment ID"].empty?
							genotype_attr_h.store(:experiment_id, variant_call[:"Experiment ID"])
						end

						# per sample
						# genotype から sample への reference は sample_name (sample_id in XML)
						# genotype から sampleset への reference は sampleset_id

						ft_value_h.each{|sample_key_sym, sample_value_h|

							ref_sample_name = ""
							ref_sampleset_id = ""
							cn = ""
							if "#{sample_key_sym}".match?(/^SAM[D|E|N]\d{1,}$/) && sample_name_accession_h.key("#{sample_key_sym}")
								ref_sample_name = sample_name_accession_h.key("#{sample_key_sym}")
							elsif sample_name_accession_h[sample_key_sym]
								ref_sample_name = "#{sample_key_sym}"
							# sampleset name であれば OK
							elsif sampleset_name_per_sampleset_h[variant_call[:"SampleSet ID"].to_i] && sampleset_name_per_sampleset_h[variant_call[:"SampleSet ID"].to_i] == ["#{sample_key_sym}"]
								ref_sampleset_id = variant_call[:"SampleSet ID"]
							# defined name
							elsif defined_samples_list_h.has_key?("#{sample_key_sym}")
								ref_sample_name = "#{sample_key_sym}"
							end

							missing_sample_sampleset_ref_a.push("#{sample_key_sym}") if ref_sample_name.empty? && ref_sampleset_id.empty?

							# xsd error を回避するためデフォルト true
							success = "true"
							for ft_key_sym, sample_value in sample_value_h

								if "#{ft_key_sym}" == "GT"
									genotype_attr_h.store(:submitted_genotype, sample_value)
								end

								if "#{ft_key_sym}" == "CN"
									cn = sample_value
								end

								# FT PASS or not
								if "#{ft_key_sym}" == "FT"
									if sample_value.match?(/PASS/i)
										success = "true"
									else
										success = "false"
									end
								end

							end

							genotype_attr_h.store(:success, success)

							if !ref_sample_name.empty?
								gt_xml.GENOTYPE(genotype_attr_h){|genotype_e|
									genotype_e.SAMPLE(:sample_id => ref_sample_name)
									genotype_e.ALLELE(:allele_copy_number => cn) unless cn.empty?
								}
							elsif !ref_sampleset_id.empty?
								gt_xml.GENOTYPE(genotype_attr_h){|genotype_e|
									genotype_e.SAMPLESET(:sampleset_id => ref_sampleset_id)
									genotype_e.ALLELE(:allele_copy_number => cn) unless cn.empty?
								}
							end

						} # ft_value_h.each{|sample_key, sample_value_h|

					end # for ft_value_h in variant_call["FORMAT"]

				end # unless variant_call["FORMAT"].empty?

			end # if sv_genotype_f

			##
			## Variant call TSV
			##

			# VCF で提供された場合、variant call tsv を出力
			if !vcf_sv_f.empty?

				variant_call_tsv_s += "# #{$variant_call_field_a[0]}\t#{$variant_call_field_a[1..-1].join("\t")}\n" if vc_line == 0
				all_variant_call_tsv_s += "# #{$variant_call_field_a[0]}\t#{$variant_call_field_a[1..-1].join("\t")}\n" if vc_line == 0 && vcf_count == 0

				variant_call_tsv_line_a = []
				for field in $variant_call_field_a

					if field == "FORMAT"
						if !variant_call[:"#{field}"].nil? && !variant_call[:"#{field}"].empty?
							format_for_tsv_a = []
							variant_call[:"#{field}"].each{|sample_value_h|
								sample_value_h.each{|ft_sample, ft_sample_value_h|
									ft_sample_value_s = ""
									ft_sample_value_s = ft_sample_value_h.map{|k,v| "#{k}:#{v}"}.join(";") if ft_sample_value_h
									format_for_tsv_a.push("#{ft_sample}=#{ft_sample_value_s}") unless ft_sample_value_s.empty?
								}
							}

							variant_call_tsv_line_a.push(format_for_tsv_a.join(";"))
						else
							variant_call_tsv_line_a.push("")
						end
					else
						if !variant_call[:"#{field}"].nil? && !variant_call[:"#{field}"].empty?
							variant_call_tsv_line_a.push(variant_call[:"#{field}"])
						else
							variant_call_tsv_line_a.push("")
						end
					end

				end

				variant_call_tsv_s += "#{variant_call_tsv_line_a.join("\t")}\n"
				all_variant_call_tsv_s += "#{variant_call_tsv_line_a.join("\t")}\n"

			end

			vc_line += 1

			# variant region からの参照用に格納
			variant_call_by_id_h.store(:"#{variant_call_id}", variant_call.reject{|k| k == :FORMAT })

		end # for variant_call in variant_call_a

		all_variant_call_tsv_log_a.push(variant_call_tsv_log_a)

		# VCF 毎の tsv 出力
		vc_input_filename = File.basename(vc_input)
		if !variant_call_tsv_s.empty?

			if vc_input_filename == "tsv"
				variant_call_tsv_f = open("#{excel_path}/#{submission_id}.variant_call.tsv", "w")
			else
				variant_call_tsv_f = open("#{excel_path}/#{submission_id}_#{vc_input_filename}.variant_call.tsv", "w")
			end

			variant_call_tsv_f.puts variant_call_tsv_s
			variant_call_tsv_f.close
		end

		# VCF 毎の tsv log 出力
		if !variant_call_tsv_log_a.empty?

			if vc_input_filename == "tsv"
				variant_call_tsv_log_f = open("#{excel_path}/#{submission_id}.variant_call.tsv.log.txt", "w")
			else
				variant_call_tsv_log_f = open("#{excel_path}/#{submission_id}_#{vc_input_filename}.variant_call.tsv.log.txt", "w")
			end

			variant_call_tsv_log_f.puts variant_call_sheet_header_a.join("\t")

			variant_call_tsv_log_a.each{|line|
				variant_call_tsv_log_f.puts line
			}

			variant_call_tsv_log_f.close
		end

		vcf_count += 1

		# VCF header error
		unless missing_sample_sampleset_ref_a.empty?

			# JV_VCF0042: Invalid sample reference in VCF
			if error_vcf_header_h[vc_input]
				if error_vcf_header_h[vc_input].size == 0
					error_vcf_header_h[vc_input] = [["JV_VCF0042", "Reference a Sample Name of a Sample in the SampleSet or a SampleSet Name in the VCF sample column (GT). #{missing_sample_sampleset_ref_a.sort.uniq.join(",")}"]]
				elsif error_vcf_header_h[vc_input].size > 0
					error_vcf_header_h[vc_input] = error_vcf_header_h[vc_input].push(["JV_VCF0042", "Reference a Sample Name of a Sample in the SampleSet or a SampleSet Name in the VCF sample column (GT). #{missing_sample_sampleset_ref_a.sort.uniq.join(",")}"])
				end
			end

		end # unless missing_sample_sampleset_ref_a.empty?

		## Variant Call, Error
		error_sv_vc_a.push(["JV_SV0072", "chr_name or chr_accession must refer to a valid chromosome for the specified assembly, and chr_name can contain 'chr'. Variant Call: #{invalid_chr_ref_call_a.size} sites, #{invalid_chr_ref_call_a.size > 4? invalid_chr_ref_call_a[0, limit_for_etc].join(",") + " etc" : invalid_chr_ref_call_a.join(",")}"]) unless invalid_chr_ref_call_a.empty?
		error_sv_vc_a.push(["JV_SV0074", "Contig accession must refer to a valid INSDC accession and version. Variant Call: #{invalid_contig_acc_ref_call_a.size} sites, #{invalid_contig_acc_ref_call_a.size > 4? invalid_contig_acc_ref_call_a[0, limit_for_etc].join(",") + " etc" : invalid_contig_acc_ref_call_a.join(",")}"]) unless invalid_contig_acc_ref_call_a.empty?
		error_sv_vc_a.push(["JV_SV0076", "Genomic placement must contain either a chr_name, chr_accession, or contig_accession unless it is on a novel sequence insertion or translocation. Variant Call: #{missing_chr_contig_acc_call_a.size} sites, #{missing_chr_contig_acc_call_a.size > 4? missing_chr_contig_acc_call_a[0, limit_for_etc].join(",") + " etc" : missing_chr_contig_acc_call_a.join(",")}"]) unless missing_chr_contig_acc_call_a.empty?
		error_sv_vc_a.push(["JV_SV0077", "Genomic placement should not have a contig_accession if there is also a chr_name or chr_accession. Variant Call: #{contig_acc_for_chr_acc_call_a.size} sites, #{contig_acc_for_chr_acc_call_a.size > 4? contig_acc_for_chr_acc_call_a[0, limit_for_etc].join(",") + " etc" : contig_acc_for_chr_acc_call_a.join(",")}"]) unless contig_acc_for_chr_acc_call_a.empty?
		error_sv_vc_a.push(["JV_SV0099", "Provide a valid dataset ID. Variant Call: #{invalid_dataset_id_call_a.size} sites, #{invalid_dataset_id_call_a.size > 4? invalid_dataset_id_call_a[0, limit_for_etc].join(",") + " etc" : invalid_dataset_id_call_a.join(",")}"]) unless invalid_dataset_id_call_a.empty?

		## Variant Call, Error ignore
		error_ignore_sv_vc_a.push(["JV_SV0045", "Missing From/To in translocation. Variant Call: #{invalid_from_to_call_a.size} sites, #{invalid_from_to_call_a.size > 4? invalid_from_to_call_a[0, limit_for_etc].join(",") + " etc" : invalid_from_to_call_a.join(",")}"]) unless invalid_from_to_call_a.empty?
		error_ignore_sv_vc_a.push(["JV_SV0041", "Placements that are part of a variant call with Variant Call Type = 'intrachromosomal translocation' must have same chromosome. Variant Call: #{different_chrs_for_intra_call_a.size} sites, #{different_chrs_for_intra_call_a.size > 4? different_chrs_for_intra_call_a[0, limit_for_etc].join(",") + " etc" : different_chrs_for_intra_call_a.join(",")}"]) unless different_chrs_for_intra_call_a.empty?
		error_ignore_sv_vc_a.push(["JV_SV0042", "Placements that are part of a variant call with Variant Call Type = 'interchromosomal translocation' must have a different chromosome. Variant Call: #{same_chrs_for_inter_call_a.size} sites, #{same_chrs_for_inter_call_a.size > 4? same_chrs_for_inter_call_a[0, limit_for_etc].join(",") + " etc" : same_chrs_for_inter_call_a.join(",")}"]) unless same_chrs_for_inter_call_a.empty?
		error_ignore_sv_vc_a.push(["JV_SV0047", "Deletion calls with outers-only should have Outer Stop > Outer Start. Variant Call: #{inconsistent_outer_start_stop_call_a.size} sites, #{inconsistent_outer_start_stop_call_a.size > 4? inconsistent_outer_start_stop_call_a[0, limit_for_etc].join(",") + " etc" : inconsistent_outer_start_stop_call_a.join(",")}"]) unless inconsistent_outer_start_stop_call_a.empty?
		error_ignore_sv_vc_a.push(["JV_SV0078", "Genomic placement must contain either a start, outer_start, or inner_start unless it is a novel sequence insertion or translocation. Variant Call: #{missing_start_call_a.size} sites, #{missing_start_call_a.size > 4? missing_start_call_a[0, limit_for_etc].join(",") + " etc" : missing_start_call_a.join(",")}"]) unless missing_start_call_a.empty?
		error_ignore_sv_vc_a.push(["JV_SV0079", "Genomic placement must contain either a stop, outer_stop, or inner_stop unless it is a novel sequence insertion or translocation. Variant Call: #{missing_stop_call_a.size} sites, #{missing_stop_call_a.size > 4? missing_stop_call_a[0, limit_for_etc].join(",") + " etc" : missing_stop_call_a.join(",")}"]) unless missing_stop_call_a.empty?
		error_ignore_sv_vc_a.push(["JV_SV0080", "When on same sequence, start must be <= stop. Variant Call: #{invalid_start_stop_call_a.size} sites, #{invalid_start_stop_call_a.size > 4? invalid_start_stop_call_a[0, limit_for_etc].join(",") + " etc" : invalid_start_stop_call_a.join(",")}"]) unless invalid_start_stop_call_a.empty?
		error_ignore_sv_vc_a.push(["JV_SV0081", "When on same sequence, outer_start must be <= outer_stop. Variant Call: #{invalid_outer_start_outer_stop_call_a.size} sites, #{invalid_outer_start_outer_stop_call_a.size > 4? invalid_outer_start_outer_stop_call_a[0, limit_for_etc].join(",") + " etc" : invalid_outer_start_outer_stop_call_a.join(",")}"]) unless invalid_outer_start_outer_stop_call_a.empty?
		error_ignore_sv_vc_a.push(["JV_SV0082", "When on same sequence, outer_start must be <= inner_start. Variant Call: #{invalid_outer_start_inner_start_call_a.size} sites, #{invalid_outer_start_inner_start_call_a.size > 4? invalid_outer_start_inner_start_call_a[0, limit_for_etc].join(",") + " etc" : invalid_outer_start_inner_start_call_a.join(",")}"]) unless invalid_outer_start_inner_start_call_a.empty?
		error_ignore_sv_vc_a.push(["JV_SV0083", "When on same sequence, inner_stop must be <= outer_stop. Variant Call: #{invalid_inner_stop_outer_stop_call_a.size} sites, #{invalid_inner_stop_outer_stop_call_a.size > 4? invalid_inner_stop_outer_stop_call_a[0, limit_for_etc].join(",") + " etc" : invalid_inner_stop_outer_stop_call_a.join(",")}"]) unless invalid_inner_stop_outer_stop_call_a.empty?
		error_ignore_sv_vc_a.push(["JV_SV0084", "When on same sequence, start must be < inner_stop, unless placement contains all of the following: start, stop, outer_start, outer_stop, inner_start and inner_stop. Also, if using confidence intervals, start must be < (stop - ciendleft). Variant Call: #{invalid_start_inner_stop_call_a.size} sites, #{invalid_start_inner_stop_call_a.size > 4? invalid_start_inner_stop_call_a[0, limit_for_etc].join(",") + " etc" : invalid_start_inner_stop_call_a.join(",")}"]) unless invalid_start_inner_stop_call_a.empty?
		error_ignore_sv_vc_a.push(["JV_SV0085", "When on same sequence, inner_start must be < stop, unless placement contains all of the following: start, stop, outer_start, outer_stop, inner_start and inner_stop. Also, if using confidence intervals, (start + ciposright) must be < stop. Variant Call: #{invalid_inner_start_stop_call_a.size} sites, #{invalid_inner_start_stop_call_a.size > 4? invalid_inner_start_stop_call_a[0, limit_for_etc].join(",") + " etc" : invalid_inner_start_stop_call_a.join(",")}"]) unless invalid_inner_start_stop_call_a.empty?
		error_ignore_sv_vc_a.push(["JV_SV0086", "When on same sequence, inner_start must be <= inner_stop if there are only inner placements. Variant Call: #{invalid_inner_start_inner_stop_call_a.size} sites, #{invalid_inner_start_inner_stop_call_a.size > 4? invalid_inner_start_inner_stop_call_a[0, limit_for_etc].join(",") + " etc" : invalid_inner_start_inner_stop_call_a.join(",")}"]) unless invalid_inner_start_inner_stop_call_a.empty?
		error_ignore_sv_vc_a.push(["JV_SV0087", "Genomic placement with start must only contain start, or must also contain both outer_start and inner_start. Variant Call: #{multiple_starts_call_a.size} sites, #{multiple_starts_call_a.size > 4? multiple_starts_call_a[0, limit_for_etc].join(",") + " etc" : multiple_starts_call_a.join(",")}"]) unless multiple_starts_call_a.empty?
		error_ignore_sv_vc_a.push(["JV_SV0088", "Genomic placement with stop must only contain stop, or must also contain both outer_stop and inner_stop. Variant Call: #{multiple_stops_call_a.size} sites, #{multiple_stops_call_a.size > 4? multiple_stops_call_a[0, limit_for_etc].join(",") + " etc" : multiple_stops_call_a.join(",")}"]) unless multiple_stops_call_a.empty?
		error_ignore_sv_vc_a.push(["JV_SV0089", "Error if inner_stop, stop, or outer_stop are beyond the length of the sequence (chromosome or scaffold). Variant Call: #{inconsistent_length_start_stop_call_a.size} sites, #{inconsistent_length_start_stop_call_a.size > 4? inconsistent_length_start_stop_call_a[0, limit_for_etc].join(",") + " etc" : inconsistent_length_start_stop_call_a.join(",")}"]) unless inconsistent_length_start_stop_call_a.empty?

		## Variant Call, Warning
		warning_sv_vc_a.push(["JV_SV0033", "Variant Call Phenotype/Link must reference a valid medical vocabulary db:id. Variant Call: #{invalid_phenotype_link_call_a.size} sites, #{invalid_phenotype_link_call_a.size > 4? invalid_phenotype_link_call_a[0, limit_for_etc].join(",") + " etc" : invalid_phenotype_link_call_a.join(",")}"]) unless invalid_phenotype_link_call_a.empty?
		warning_sv_vc_a.push(["JV_SV0036", "Variant Call Evidence should reference a valid db:id. Variant Call: #{invalid_phenotype_link_evidence_call_a.size} sites, #{invalid_phenotype_link_evidence_call_a.size > 4? invalid_phenotype_link_evidence_call_a[0, limit_for_etc].join(",") + " etc" : invalid_phenotype_link_evidence_call_a.join(",")}"]) unless invalid_phenotype_link_evidence_call_a.empty?
		warning_sv_vc_a.push(["JV_SV0094", "Warning if call type=interchromosomal translocation or intrachromosomal translocation and placement does not contain strand. Variant Call: #{missing_strand_call_a.size} sites, #{missing_strand_call_a.size > 4? missing_strand_call_a[0, limit_for_etc].join(",") + " etc" : missing_strand_call_a.join(",")}"]) unless missing_strand_call_a.empty?
		warning_sv_vc_a.push(["JV_SV0095", "Warning if call placement contains a strand and type is NOT interchromosomal translocation or intrachromosomal translocation, or if region placement contains a strand and type is NOT translocation or complex chromosomal rearrangement. Variant Call: #{strand_for_translocation_call_a.size} sites, #{strand_for_translocation_call_a.size > 4? strand_for_translocation_call_a[0, limit_for_etc].join(",") + " etc" : strand_for_translocation_call_a.join(",")}"]) unless strand_for_translocation_call_a.empty?
		warning_sv_vc_a.push(["JV_SV0090", "Warning if when on same sequence, inner_start > inner_stop and there are also valid outer placements. Variant Call: #{inconsistent_inner_start_stop_call_a.size} sites, #{inconsistent_inner_start_stop_call_a.size > 4? inconsistent_inner_start_stop_call_a[0, limit_for_etc].join(",") + " etc" : inconsistent_inner_start_stop_call_a.join(",")}"]) unless inconsistent_inner_start_stop_call_a.empty?
		warning_sv_vc_a.push(["JV_SV0091", "Warning if genomic placement with start also contains outer_start and inner_start. Variant Call: #{start_outer_inner_start_coexist_call_a.size} sites, #{start_outer_inner_start_coexist_call_a.size > 4? start_outer_inner_start_coexist_call_a[0, limit_for_etc].join(",") + " etc" : start_outer_inner_start_coexist_call_a.join(",")}"]) unless start_outer_inner_start_coexist_call_a.empty?
		warning_sv_vc_a.push(["JV_SV0092", "Warning if genomic placement with stop also contains outer_stop and inner_stop. Variant Call: #{stop_outer_inner_stop_coexist_call_a.size} sites, #{stop_outer_inner_stop_coexist_call_a.size > 4? stop_outer_inner_stop_coexist_call_a[0, limit_for_etc].join(",") + " etc" : stop_outer_inner_stop_coexist_call_a.join(",")}"]) unless stop_outer_inner_stop_coexist_call_a.empty?
		warning_sv_vc_a.push(["JV_SV0054", "Warning if method_type=Sequencing and analysis_type=Paired-end mapping, and there are placements other than outer_start, outer_stop. Variant Call: #{invalid_placements_pe_seq_call_a.size} sites, #{invalid_placements_pe_seq_call_a.size > 4? invalid_placements_pe_seq_call_a[0, limit_for_etc].join(",") + " etc" : invalid_placements_pe_seq_call_a.join(",")}"]) unless invalid_placements_pe_seq_call_a.empty?
		warning_sv_vc_a.push(["JV_SV0060", "Warning if Variant/Sequence contains other than valid iupac codes (ABCDGHKMNRSTUVWY) or space, period '.' or dash '-' Variant Call: #{invalid_seq_call_a.size} sites, #{invalid_seq_call_a.size > 4? invalid_seq_call_a[0, limit_for_etc].join(",") + " etc" : invalid_seq_call_a.join(",")}"]) unless invalid_seq_call_a.empty?
		warning_sv_vc_a.push(["JV_SV0059", "Warning if variant call has a placement on Chr Y for a female subject. Variant Call: #{chry_for_female_call_a.size} sites, #{chry_for_female_call_a.size > 4? chry_for_female_call_a[0, limit_for_etc].join(",") + " etc" : chry_for_female_call_a.join(",")}"]) unless chry_for_female_call_a.empty?
		warning_sv_vc_a.push(["JV_C0062", "Allele frequency was calculated as allele count/allele number. Variant Call: #{calculated_af_a.size} sites, #{calculated_af_a.size > 4? calculated_af_a[0, limit_for_etc].join(",") + " etc" : calculated_af_a.join(",")}"]) unless calculated_af_a.empty?

		# VCF 毎に格納
		error_sv_vc_h.store(vc_input, error_sv_vc_a)
		error_ignore_sv_vc_h.store(vc_input, error_ignore_sv_vc_a)
		warning_sv_vc_h.store(vc_input, warning_sv_vc_a)

	end # for vc_input, variant_call_a in total_variant_call_h

	## JV_SV0030: Duplicated Variant Call ID
	error_sv_a.push(["JV_SV0030", "Variant Call ID must be unique. Duplicated Variant Call ID(s): #{duplicated_variant_call_id_a.sort.uniq.size > 4? duplicated_variant_call_id_a.sort.uniq[0, limit_for_etc].join(",") + " etc" : duplicated_variant_call_id_a.sort.uniq.join(",")}"]) unless duplicated_variant_call_id_a.empty?

	## JV_C0057: Invalid value for controlled terms
	error_ignore_common_a.push(["JV_C0057", "Value is not in controlled terms. Variant Call: #{invalid_value_for_cv_call_a.size} sites, #{invalid_value_for_cv_call_a.size > 4? invalid_value_for_cv_call_a[0, limit_for_etc].join(",") + " etc" : invalid_value_for_cv_call_a.join(",")}"]) unless invalid_value_for_cv_call_a.empty?

	# VCF を Variant Call TSV として出力
	if !vcf_sv_f.empty?
		variant_call_tsv_f = open("#{excel_path}/#{submission_id}_variant_call.tsv", "w")
		variant_call_tsv_f.puts all_variant_call_tsv_s
		variant_call_tsv_f.close
	end

	#
	# Variant region sheet data がない場合、variant call から variant region を生成し、tsv 出力する。
	#
	variant_region_from_call_a = []
	if variant_region_a.empty? && !variant_call_a.empty?

		# JV_VCFS0007: Missing variant region
		warning_sv_a.push(["JV_VCFS0007", "Variant regions are not submitted. JVar will generate variant regions from variant calls."])

		# Generate variant region tsv
		# 1. complex と translocation 以外は same pos and type でまとめる。complex と translocation 以外にある mutation ID は無視でワーニング。
		# 2. complex と translocation は mutation id でまとめる。same pos and type ではまとめない。mutation_order なければ1から自動アサイン。variant call = 1 - region type = translocation, calls > 1 - region type = complex
		variant_region_tsv_a = []
		variant_region_tsv_a.push(["# #{$variant_region_field_a[0]}"] + $variant_region_field_a[1..-1])
		merged_variant_call_ids_h = {}
		r_first = true
		for variant_call in variant_call_a

			variant_region_from_call_h = {}
			variant_region_tsv_each_a = []
			supporting_variant_call_id_a = []

			r_variant_call_id = variant_call[:"Variant Call ID"]
			r_variant_call_type = variant_call[:"Variant Call Type"]
			r_variant_region_type = ""
			r_assertion_method = ""
			merged_calls_c = 1

			# merge された call はスキップ
			next if merged_variant_call_ids_h.has_key?(r_variant_call_id)

			# translocation call で mutation id があるものをまとめる
			group_by_mutation_id_f = false
			supporting_call_json_a = []
			supporting_call_json_s = ""
			for r_mutation_id, r_calls_by_mutation_id_a in variant_calls_by_mutation_id_h
				if r_calls_by_mutation_id_a.include?(r_variant_call_id)

					group_by_mutation_id_f = true
					supporting_variant_call_id_a = r_calls_by_mutation_id_a

					if supporting_variant_call_id_a.size == 1
						r_variant_region_type = "translocation"
						r_assertion_method = "Breakpoint calls grouped by submitter, and merged into regions by JVar staff (no regions submitted)"
					elsif supporting_variant_call_id_a.size > 1
						r_variant_region_type = "complex chromosomal rearrangement"
						r_assertion_method = "Breakpoint calls grouped by submitter, and merged into regions by JVar staff (no regions submitted)"
					end

					# merge された call を除くため格納
					r_calls_by_mutation_id_a.each{|e|
						if e != r_variant_call_id
							merged_variant_call_ids_h.store(e, 1)
							merged_calls_c += 1
						end
					}

				end
			end

			# Identical pos and type - translocation 以外
			identical_pos_type_f = false
			unless group_by_mutation_id_f # Mutation id によるグループ化を優先。translocation 以外の mutation ID は無いはずなので実質的に無効
				for hash_key, r_calls_by_identity_a in identical_variant_call_site_id_h
					if r_calls_by_identity_a.include?(r_variant_call_id)

						identical_pos_type_f = true
						supporting_variant_call_id_a = r_calls_by_identity_a

						# translocation は identity では merge せず、mutation id でのみ merge
						r_variant_region_type = $variant_call_type_to_region_type_h[:"#{r_variant_call_type}"] if $variant_call_type_to_region_type_h[:"#{r_variant_call_type}"]
						r_assertion_method = "Identical calls merged by JVar staff (no regions submitted)"

						# merge された call を除くため格納
						r_calls_by_identity_a.each{|e|
							if e != r_variant_call_id
								merged_variant_call_ids_h.store(e, 1)
								merged_calls_c += 1
							end
						}

					end
				end
			end

			# Mutation id がない translocation SV や same pos and type がない translocation 以外の call について 1:1 で region を作成
			if !group_by_mutation_id_f && !identical_pos_type_f

				supporting_variant_call_id_a.push(r_variant_call_id)

				if r_variant_call_type == "intrachromosomal translocation" || r_variant_call_type == "interchromosomal translocation"
					r_variant_region_type = "translocation"
				else
					r_variant_region_type = $variant_call_type_to_region_type_h[:"#{r_variant_call_type}"] if $variant_call_type_to_region_type_h[:"#{r_variant_call_type}"]
				end

				r_assertion_method = "Identical to variant call (no regions submitted)"

			end

			# merged region は c[number of merged calls] で示す
			if merged_calls_c == 1
				r_variant_region_id = "region_#{variant_call[:"Variant Call ID"]}"
			else
				r_variant_region_id = "region_#{variant_call[:"Variant Call ID"]}_c#{merged_calls_c}"
			end

			# Variant region tsv 出力と hash への格納
			variant_region_from_call_h.store(:"Variant Region ID", r_variant_region_id)
			variant_region_from_call_h.store(:"Variant Region Type", r_variant_region_type)
			variant_region_from_call_h.store(:"Assertion Method", r_assertion_method)

			# Assembly から Outer Stop まで
			for field in $variant_region_field_a[3..11]
				if variant_call[:"#{field}"]
					variant_region_tsv_each_a.push(variant_call[:"#{field}"])
					variant_region_from_call_h.store(:"#{field}", variant_call[:"#{field}"])
				else
					variant_region_tsv_each_a.push("")
					variant_region_from_call_h.store(:"#{field}", "")
				end
			end

			# Supporting Variant Call IDs, Supporting Variant Region IDs, Description を挿入
			variant_region_tsv_each_a.push(supporting_variant_call_id_a.join(","))
			variant_region_tsv_each_a.push("") # supporting variant region ids
			variant_region_tsv_each_a.push("") # description

			variant_region_from_call_h.store(:"Supporting Variant Call IDs", supporting_variant_call_id_a.join(","))
			variant_region_from_call_h.store(:"Supporting Variant Region IDs", "")
			variant_region_from_call_h.store(:Description, "")

			# Assembly for Translocation Breakpoint から ciendright まで
			for field in $variant_region_field_a[15..-1]
				if variant_call[:"#{field}"]
					variant_region_tsv_each_a.push(variant_call[:"#{field}"])
					variant_region_from_call_h.store(:"#{field}", variant_call[:"#{field}"])
				else
					variant_region_tsv_each_a.push("")
					variant_region_from_call_h.store(:"#{field}", "")
				end
			end

			# 先頭に追加 Variant Region ID, Variant Region Type, Assertion Method
			variant_region_tsv_each_a.unshift(r_assertion_method)
			variant_region_tsv_each_a.unshift(r_variant_region_type)
			variant_region_tsv_each_a.unshift(r_variant_region_id)

			# chr accession 関連
			variant_region_from_call_h.store(:refseq_assembly, variant_call[:refseq_assembly]) if variant_call[:refseq_assembly]
			variant_region_from_call_h.store(:chr_accession, variant_call[:chr_accession]) if variant_call[:chr_accession]
			variant_region_from_call_h.store(:contig_accession, variant_call[:contig_accession]) if variant_call[:contig_accession]
			variant_region_from_call_h.store(:refseq_assembly_breakpoint, variant_call[:refseq_assembly_breakpoint]) if variant_call[:refseq_assembly_breakpoint]
			variant_region_from_call_h.store(:from_chr_accession, variant_call[:from_chr_accession]) if variant_call[:from_chr_accession]
			variant_region_from_call_h.store(:from_contig_accession, variant_call[:from_contig_accession]) if variant_call[:from_contig_accession]
			variant_region_from_call_h.store(:to_chr_accession, variant_call[:to_chr_accession]) if variant_call[:to_chr_accession]
			variant_region_from_call_h.store(:to_contig_accession, variant_call[:to_contig_accession]) if variant_call[:to_contig_accession]

			# tsv log 出力用 row
			r_line_a = []
			$variant_region_field_a.each{|field|
				if variant_region_from_call_h[:"#{field}"]
					r_line_a.push(variant_region_from_call_h[:"#{field}"])
				else
					r_line_a.push("")
				end
			}

			variant_region_from_call_h.store(:row, r_line_a)

			variant_region_tsv_a.push(variant_region_tsv_each_a)
			variant_region_from_call_a.push(variant_region_from_call_h)

			r_first = false

		end # for variant_call in variant_call_a

		variant_region_tsv_f = open("#{excel_path}/#{submission_id}_variant_region.tsv", "w")
		variant_region_tsv_a.each{|r_line_a|
			variant_region_tsv_f.puts r_line_a.join("\t")
		}
		variant_region_tsv_f.close

	elsif !variant_region_a.empty? && !variant_call_a.empty?

		for variant_region in variant_region_a

			if variant_region[:"Supporting Variant Call IDs"] && variant_region[:"Supporting Variant Call IDs"].split(",")
				variant_region[:"Supporting Variant Call IDs"].split(",").each{|supporting_variant_call_id|
					if variant_call_by_id_h[:"#{supporting_variant_call_id}"]
						supporting_variant_call_h = variant_call_by_id_h[:"#{supporting_variant_call_id}"]

						variant_region.store(:refseq_assembly, supporting_variant_call_h[:refseq_assembly]) if supporting_variant_call_h[:refseq_assembly]
						variant_region.store(:chr_accession, supporting_variant_call_h[:chr_accession]) if supporting_variant_call_h[:chr_accession]
						variant_region.store(:contig_accession, supporting_variant_call_h[:contig_accession]) if supporting_variant_call_h[:contig_accession]
						variant_region.store(:refseq_assembly_breakpoint, supporting_variant_call_h[:refseq_assembly_breakpoint]) if supporting_variant_call_h[:refseq_assembly_breakpoint]
						variant_region.store(:from_chr_accession, supporting_variant_call_h[:from_chr_accession]) if supporting_variant_call_h[:from_chr_accession]
						variant_region.store(:from_contig_accession, supporting_variant_call_h[:from_contig_accession]) if supporting_variant_call_h[:from_contig_accession]
						variant_region.store(:to_chr_accession, supporting_variant_call_h[:to_chr_accession]) if supporting_variant_call_h[:to_chr_accession]
						variant_region.store(:to_contig_accession, supporting_variant_call_h[:to_contig_accession]) if supporting_variant_call_h[:to_contig_accession]
					end
				}
			end

		end

	end # if variant_region_a.empty?

	##
	## Variant Region
	##
	supporting_call_id_a = []
	supporting_region_id_a = []
	variant_region_id_h = {}

	object = "Variant Region"

	chr_name = ""
	chr_accession = ""
	chr_length = -1
	contig_accession = ""
	assembly = ""
	start_pos = -1
	stop_pos = -1

	# error and warning counts
	duplicated_variant_region_id_a = [] # JV_SV0064

	missing_assertion_method_region_a = [] # JV_SV0068
	invalid_value_for_cv_region_a = [] # JV_C0057
	inconsistent_type_region_a = [] # JV_SV0050
	mixed_type_region_a = [] # JV_SV0051
	copy_number_gain_loss_same_sample_region_a = [] # JV_SV0069
	call_outside_parent_region_a = [] # JV_SV0053
	missing_mutation_order_region_a = [] # JV_SV0066
	missing_variant_call_for_region_a = [] # JV_SV0065
	invalid_translocation_placement_SV0043_region_a = [] # JV_SV0043
	invalid_translocation_placement_SV0044_region_a = [] # JV_SV0044
	invalid_translocation_placement_SV0097_region_a = [] # JV_SV0097
	invalid_translocation_placement_SV0098_region_a = [] # JV_SV0098
	mixed_mutation_id_region_a = [] # JV_SV0100
	missing_serial_mutation_order_region_a = [] # JV_SV0067
	contig_acc_for_chr_acc_region_a = [] # JV_SV0077
	invalid_chr_ref_region_a = [] # JV_SV0072
	invalid_contig_acc_ref_region_a = [] # JV_SV0074
	missing_chr_contig_acc_region_a = [] # JV_SV0076
	missing_start_region_a = [] # JV_SV0078
	missing_stop_region_a = [] # JV_SV0079
	invalid_start_stop_region_a = [] # JV_SV0080
	invalid_outer_start_outer_stop_region_a = [] # JV_SV0081
	invalid_outer_start_inner_start_region_a = [] # JV_SV0082
	invalid_inner_stop_outer_stop_region_a = [] # JV_SV0083
	invalid_start_inner_stop_region_a = [] # JV_SV0084
	invalid_inner_start_stop_region_a = [] # JV_SV0085
	invalid_inner_start_inner_stop_region_a = [] # JV_SV0086
	multiple_starts_region_a = [] # JV_SV0087
	multiple_stops_region_a = [] # JV_SV0088
	inconsistent_length_start_stop_region_a = [] # JV_SV0089
	inconsistent_inner_start_stop_region_a = [] # JV_SV0090
	start_outer_inner_start_coexist_region_a = [] # JV_SV0091
	stop_outer_inner_stop_coexist_region_a = [] # JV_SV0092
	missing_variant_region_type_a = [] # JV_SV0102

	pos_outside_chr_region_a = [] # JV_C0061

	# VCF での variant region 登録はないとする

	## variant call と region で assembly は同じとする
	## VARIANT_REGION tsv があれば tsv から読み込み、なければ call から自動生成したものを使用。supporting call の情報は variant_call_by_id_h から取得
	variant_region_a = variant_region_from_call_a if variant_region_a.empty? && !variant_region_from_call_a.empty?

	for variant_region in variant_region_a

		# VARIANT_REGION attributes
		variant_region_attr_h = {}

		variant_region_id = ""
		variant_region_type = ""
		unless variant_region[:"Variant Region ID"].empty?

			variant_region_id = variant_region[:"Variant Region ID"]
			variant_region_attr_h.store(:variant_region_id, variant_region_id)

			if variant_region_id_h.has_key?(:"#{variant_region_id}")
				# JV_SV0064: Duplicated Variant Region ID
				duplicated_variant_region_id_a.push(variant_region_id)
				variant_region_tsv_log_a.push("#{variant_region[:row].join("\t")}\t# JV_C0064 Error: Variant Region ID must be unique.")
			end

			variant_region_id_h.store(:"#{variant_region_id}", 0)
		end

		variant_region_attr_h.store(:variant_region_accession, "")

		unless variant_region[:"Assertion Method"].empty?
			variant_region_attr_h.store(:assertion_method, variant_region[:"Assertion Method"])
		else
			## JV_SV0068: Missing assertion_method
			missing_assertion_method_region_a.push(variant_region_id)
			variant_region_tsv_log_a.push("#{variant_region[:row].join("\t")}\t# JV_SV0068 Error: Region MUST have an assertion_method.")
		end

		# CV
		variant_region.each{|key_sym, value|
			if value && !value.empty? && $cv_h[object] && $cv_h[object]["#{key_sym}"] && !$cv_h[object]["#{key_sym}"].include?(value)
				## JV_C0057: Invalid value for controlled terms
				invalid_value_for_cv_region_a.push("#{variant_region_id} #{"#{key_sym}"}:#{value}")
				variant_region_tsv_log_a.push("#{variant_region[:row].join("\t")}\t# JV_C0057 Error: Value is not in controlled terms.")
			end
		}

		# variant_region_type CV check
		if !variant_region[:"Variant Region Type"].empty? && !$vtype_h[:"Variant Region Type"][:"#{variant_region[:"Variant Region Type"]}"].nil?
			variant_region_type = $vtype_h[:"Variant Region Type"][:"#{variant_region[:"Variant Region Type"]}"]
			variant_region_attr_h.store(:variant_region_type, variant_region_type)
		else
			# JV_SV0102 Missing Variant Region Type
			missing_variant_region_type_a.push(variant_region_id)
			variant_region_tsv_log_a.push("#{variant_region[:row].join("\t")}\t# V_SV0102 Error: Variant Region Type is missing.")
		end

		variant_region_attr_h.store(:variant_region_type_SO_id, "")
		# variant_region_attr_h.store(:is_low_quality, "")
		# variant_region_attr_h.store(:repeat_motif, "")
		# variant_region_attr_h.store(:repeat_counts, "")

		submission.VARIANT_REGION(variant_region_attr_h){|variant_region_e|

			# DESCRIPTION
			variant_region_e.DESCRIPTION(variant_region[:Description]) unless variant_region[:Description].empty?

			# boundary of variant region
			region_start_a = []
			region_stop_a = []

			# start of region
			region_min_start = ""
			region_start_a.push(variant_region[:"Outer Start"].to_i) if !variant_region[:"Outer Start"].empty? && variant_region[:"Outer Start"].to_i
			region_start_a.push(variant_region[:Start].to_i) if !variant_region[:Start].empty? && variant_region[:Start].to_i
			region_start_a.push(variant_region[:"Inner Start"].to_i) if !variant_region[:"Inner Start"].empty? && variant_region[:"Inner Start"].to_i
			region_min_start = region_start_a.min

			# stop of region
			region_max_stop = ""
			region_stop_a.push(variant_region[:Stop].to_i) if !variant_region[:Stop].empty? && variant_region[:Stop].to_i
			region_stop_a.push(variant_region[:"Inner Stop"].to_i) if !variant_region[:"Inner Stop"].empty? && variant_region[:"Inner Stop"].to_i
			region_stop_a.push(variant_region[:"Outer Stop"].to_i) if !variant_region[:"Outer Stop"].empty? && variant_region[:"Outer Stop"].to_i
			region_max_stop = region_stop_a.max

			## translocation: mutation ID and mutation order
			# supporting_variant_call hash
			supporting_variant_call_id_a = []
			unless variant_region[:"Supporting Variant Call IDs"].empty? && variant_region[:"Supporting Variant Call IDs"].split(",").size > 0
				supporting_variant_call_id_a = variant_region[:"Supporting Variant Call IDs"].split(",")
			end

			supporting_variant_call_a = []
			supporting_variant_call_id_a.each{|supporting_variant_call_id|
				supporting_variant_call_a.push(variant_call_by_id_h[:"#{supporting_variant_call_id}"]) if variant_call_by_id_h[:"#{supporting_variant_call_id}"]
			}

			# mutation id
			if variant_region_type == "complex chromosomal rearrangement" || variant_region_type == "translocation"

				mutation_id_exist = false
				mutation_order_exist = false
				mutation_order_perfect = false
				mutation_order = 1
				mutation_id_a = []
				mutation_order_a = []

				supporting_variant_call_a.each{|supporting_variant_call_h|
					if !supporting_variant_call_h[:"Mutation ID"].nil? && !supporting_variant_call_h[:"Mutation ID"].empty?
						mutation_id_a.push(supporting_variant_call_h[:"Mutation ID"])
					end
				} # supporting_variant_call_h

				## JV_SV0100 Mixed mutation ID for complex chromosomal rearrangement and translocation.
				if !mutation_id_a.empty? && mutation_id_a.sort.uniq.size != 1
					mixed_mutation_id_region_a.push(variant_region_id)
					variant_region_tsv_log_a.push("#{variant_region[:row].join("\t")}\t# JV_SV0100 Error: Mixed mutation ID for complex chromosomal rearrangement and translocation.")
				elsif mutation_id_a.sort.uniq.size == 1
					mutation_id_exist = true
				end

				# mutation ID がある場合、order をチェック、自動埋め込み
				if mutation_id_exist

					supporting_variant_call_a.each{|supporting_variant_call_h|
						# mutation order が文字列の場合、整数に変換
						if supporting_variant_call_h[:"Mutation Order"].match?(/^[0-9]+$/) && supporting_variant_call_h[:"Mutation Order"].to_i
							supporting_variant_call_h[:"Mutation Order"] = supporting_variant_call_h[:"Mutation Order"].to_i
						end

						# mutation id が一つでもなければ exist=false、部分的にないものは上書きで連番アサイン
						if supporting_variant_call_h[:"Mutation Order"].is_a?(Integer)
							mutation_order_a.push(supporting_variant_call_h[:"Mutation Order"])
						end
					} # supporting_variant_call_h

					## JV_SV0067: Missing serial mutation order number for complex chromosomal rearrangement and translocation、連番であればよく、順番は問わない
					if [*1..supporting_variant_call_a.size] == mutation_order_a.sort
						mutation_order_perfect = true
					else
						missing_serial_mutation_order_region_a.push(variant_region_id)
						variant_region_tsv_log_a.push("#{variant_region[:row].join("\t")}\t# JV_SV0067 Error: Missing serial mutation order number for complex chromosomal rearrangement and translocation. JVar will assign serial order(s).")
					end

					# mutation order の自動埋め込み、完璧ではない場合以外は自動埋め込み。SV0067 でそのメッセージを伝える
					from_strand_a = []
					to_strand_a = []
					strand_a = []
					placement_from_call_f = false
					unless mutation_order_perfect
						if supporting_variant_call_a.size == 1
							supporting_variant_call_a[0].store(:"Mutation Order", 1)
						# strand が揃っている場合は一意に order を埋め込めるが、strand が混在している場合は一意に決まらないので、そのままの順番で埋め込み後のチェックに委ねる
						elsif supporting_variant_call_a.size > 1
							supporting_variant_call_a.each{|supporting_variant_call_h|
								unless supporting_variant_call_h[:"From Strand"].empty?
									from_strand_a.push(supporting_variant_call_h[:"From Strand"])
									strand_a.push(supporting_variant_call_h[:"From Strand"])
								end

								unless supporting_variant_call_h[:"To Strand"].empty?
									to_strand_a.push(supporting_variant_call_h[:"To Strand"])
									strand_a.push(supporting_variant_call_h[:"To Strand"])
								end
							}

							# + で揃っている From Chr, From Coord
							m_order = 1
							if strand_a.sort.uniq == ["+"]
								supporting_variant_call_a.sort_by{|h| [h[:"From Chr"], h[:"From Coord"].to_i] }.each{|supporting_variant_call_h|
									supporting_variant_call_h.store(:"Mutation Order", m_order)
									m_order += 1
								}

							# - で揃っている
							elsif strand_a.sort.uniq == ["-"]
								supporting_variant_call_a.sort_by{|h| [h[:"From Chr"], h[:"From Coord"].to_i] }.reverse.each{|supporting_variant_call_h|
									supporting_variant_call_h.store(:"Mutation Order", m_order)
									m_order += 1
								}
							# 揃っていない
							else
								supporting_variant_call_a.each{|supporting_variant_call_h|
									supporting_variant_call_h.store(:"Mutation Order", m_order)
									m_order += 1
								}
							end

						end # if supporting_variant_call_a.size == 1

					end # unless mutation_order_perfect

				end # if !mutation_order_exist

				## region type complex, translocation で mutation ID がある supporting call に mutation order が無いとエラー、自動埋め込み後のチェック
				## JV_SV0066: Missing mutation order for complex chromosomal rearrangement and translocation
				supporting_variant_call_a.each{|supporting_variant_call_h|
					if !supporting_variant_call_h[:"Mutation ID"].nil? && !supporting_variant_call_h[:"Mutation ID"].empty? && (supporting_variant_call_h[:"Mutation Order"].nil? || !supporting_variant_call_h[:"Mutation Order"].is_a?(Integer))
						missing_mutation_order_region_a.push(variant_region_id)
						variant_region_tsv_log_a.push("#{variant_region[:row].join("\t")}\t# JV_SV0066 Error: Variant regions with type 'complex chromosomal rearrangement' and 'translocation' must have mutation order in their supporting variant calls with Mutation ID. JVar will embed order(s)")
					end
				} # supporting_variant_call_a

			end # if variant_region_type == "complex chromosomal rearrangement" || variant_region_type == "translocation"

			## Translocation placements validations
			if !supporting_variant_call_a.empty? && supporting_variant_call_a[0][:"Mutation Order"].is_a?(Integer)

				# mutation order がある場合、order で昇順ソート
				supporting_variant_call_a = supporting_variant_call_a.sort_by{|h| h[:"Mutation Order"] }

				(supporting_variant_call_a.size - 1).times{|n|

					## JV_SV0043: Invalid translocation placements
					## In translocation calls supporting the same variant region, the chromosome and strand of the To placement must match the chromosome and strand of the From placement of the next variant call (based on Mutation Order)
					if supporting_variant_call_a[n][:"To Chr"] != supporting_variant_call_a[n+1][:"From Chr"] || supporting_variant_call_a[n][:"To Strand"] != supporting_variant_call_a[n+1][:"From Strand"]
						invalid_translocation_placement_SV0043_region_a.push(variant_region_id)
						variant_region_tsv_log_a.push("#{variant_region[:row].join("\t")}\t# JV_SV0043 Error: Invalid translocation placements.")
					end

					## JV_SV0097: Invalid translocation placements
					## In translocation calls supporting the same variant region, the chromosome placement of the To placement must be less than the chromosome placement of the From placement of the next variant call (based on Mutation Order) if their strand is '+'
					if supporting_variant_call_a[n][:"To Chr"] == supporting_variant_call_a[n+1][:"From Chr"] && supporting_variant_call_a[n][:"To Strand"] == "+" && supporting_variant_call_a[n+1][:"From Strand"] == "+" && supporting_variant_call_a[n][:"To Coord"].to_i > supporting_variant_call_a[n+1][:"From Coord"].to_i
						invalid_translocation_placement_SV0097_region_a.push(variant_region_id)
						variant_region_tsv_log_a.push("#{variant_region[:row].join("\t")}\t# JV_SV0097 Error: Invalid translocation placements.")
					end

					## JV_SV0098: Invalid translocation placements
					## In translocation calls supporting the same variant region, the chromosome placement of the To placement must be greater than the chromosome placement of the From placement of the next variant call (based on mutation_order) if their strand is '-'
					if supporting_variant_call_a[n][:"To Chr"] == supporting_variant_call_a[n+1][:"From Chr"] && supporting_variant_call_a[n][:"To Strand"] == "-" && supporting_variant_call_a[n+1][:"From Strand"] == "-" && supporting_variant_call_a[n][:"To Coord"].to_i < supporting_variant_call_a[n+1][:"From Coord"].to_i
						invalid_translocation_placement_SV0098_region_a.push(variant_region_id)
						variant_region_tsv_log_a.push("#{variant_region[:row].join("\t")}\t# JV_SV0098 Error: Invalid translocation placements.")
					end

				}

			end # if !supporting_variant_call_a.empty? && supporting_variant_call_a[0]["Mutation Order"].is_a?(Integer)

			# SUPPORTING_VARIANT_REGION
			if variant_region[:"Supporting Variant Region IDs"].split(/,/).size > 0
				for supporting_region_id in variant_region[:"Supporting Variant Region IDs"].split(/,/)
					supporting_region_id_a.push(:"#{supporting_region_id}")
					variant_region_e.SUPPORTING_VARIANT_REGION(:variant_region_id => supporting_region_id)
				end
			end

			#
			# SUPPORTING_VARIANT_CALL elements
			#
			sampleset_id_of_variant_call_a = []
			unless supporting_variant_call_a.empty?
				for supporting_variant_call_h in supporting_variant_call_a

					supporting_call_id = ""
					supporting_call_id = supporting_variant_call_h[:"Variant Call ID"] unless supporting_variant_call_h[:"Variant Call ID"].empty?
					supporting_call_id_a.push(:"#{supporting_call_id}")

					supporting_variant_call_attr_h = {}
					supporting_variant_call_attr_h.store(:variant_call_id, supporting_call_id)
					supporting_variant_call_attr_h.store(:mutation_order, supporting_variant_call_h[:"Mutation Order"]) if supporting_variant_call_h[:"Mutation Order"] && supporting_variant_call_h[:"Mutation Order"].is_a?(Integer)
					supporting_variant_call_attr_h.store(:mutation_molecule, supporting_variant_call_h[:"Mutation Molecule"]) if supporting_variant_call_h[:"Mutation Molecule"] && !supporting_variant_call_h[:"Mutation Molecule"].empty?

					variant_region_e.SUPPORTING_VARIANT_CALL(supporting_variant_call_attr_h)

					## JV_SV0050: Inconsistent Variant Call Type and Variant Region Type
					if (variant_call_id_type_h[:"#{supporting_call_id}"] == "copy number gain" || variant_call_id_type_h[:"#{supporting_call_id}"] == "copy number loss") && variant_region_type != "copy number variation"
						inconsistent_type_region_a.push(variant_region_id)
						variant_region_tsv_log_a.push("#{variant_region[:row].join("\t")}\t# JV_SV0050 Warning: Inconsistent Variant Call Type and Variant Region Type.")
					end

					## JV_SV0051: Mixed Variant Region Type
					supporting_variant_call_type = ""
					supporting_variant_call_type = supporting_variant_call_h[:"Variant Call Type"] unless supporting_variant_call_h[:"Variant Call Type"] && supporting_variant_call_h[:"Variant Call Type"].empty?
					if variant_region_type != supporting_variant_call_type && (!$variant_region_call_type_h[:"#{variant_region_type}"].nil? && !$variant_region_call_type_h[:"#{variant_region_type}"].include?(supporting_variant_call_type))
						mixed_type_region_a.push(variant_region_id)
						variant_region_tsv_log_a.push("#{variant_region[:row].join("\t")}\t# JV_SV0051 Warning: Warning if variant call is in a variant region with different type UNLESS the region type is 'copy number variation' and the call type is ('copy number gain','copy number loss','deletion', or 'duplication'), OR the region type is 'mobile element insertion' and the call type is ('alu insertion', 'herv insertion', 'line1 insertion', or 'sva insertion'), OR the region type is 'mobile element deletion' and the call type is ('alu deletion', 'herv deletion', 'line1 deletion', or 'sva deletion'), OR the region type is ('translocation' or 'complex chromosomal rearrangement') and the call type is ('interchromosomal translocation' or 'intrachromosomal translocation').")
					end

					## JV_SV0069: Copy number gain and loss in the same sample
					# supporting variant call が属する sampleset ID が異なる場合は warning
					if supporting_variant_call_type == "copy number gain" || supporting_variant_call_type == "copy number loss"
						sampleset_id_of_variant_call_a.push(variant_call_id_sampleset_h[:"#{supporting_call_id}"])
					end

					## min max で境界を比較 JV_SV0053: Variant Call is outside of parent Variant Region
					call_start_a = []
					call_stop_a = []
					call_min_start = ""
					call_max_stop = ""
					if variant_region_type.match?(/translocation/) && variant_region_type != "complex chromosomal rearrangement"

						# start of call
						call_start_a.push(supporting_variant_call_h[:"Outer Start"].to_i) if supporting_variant_call_h[:"Outer Start"] && !supporting_variant_call_h[:"Outer Start"].empty? && supporting_variant_call_h[:"Outer Start"].to_i
						call_start_a.push(supporting_variant_call_h[:"Start"].to_i) if supporting_variant_call_h[:Start] && !supporting_variant_call_h[:Start].empty? && supporting_variant_call_h[:Start].to_i
						call_start_a.push(supporting_variant_call_h[:"Inner Start"].to_i) if supporting_variant_call_h[:"Inner Start"] && !supporting_variant_call_h[:"Inner Start"].empty? && supporting_variant_call_h[:"Inner Start"].to_i

						# stop of call
						call_stop_a.push(supporting_variant_call_h[:"Outer Stop"].to_i) if supporting_variant_call_h[:"Outer Stop"] && !supporting_variant_call_h[:"Outer Stop"].empty? && supporting_variant_call_h[:"Outer Stop"].to_i
						call_stop_a.push(supporting_variant_call_h[:"Stop"].to_i) if supporting_variant_call_h[:Stop] && !supporting_variant_call_h[:Stop].empty? && supporting_variant_call_h[:Stop].to_i
						call_stop_a.push(supporting_variant_call_h[:"Inner Stop"].to_i) if supporting_variant_call_h[:"Inner Stop"] && !supporting_variant_call_h[:"Inner Stop"].empty? && supporting_variant_call_h[:"Inner Stop"].to_i

					end

					## call と parent region で境界を比較
					call_min_start = call_start_a.min
					call_max_stop = call_stop_a.max

					## JV_SV0053: Variant Call is outside of parent Variant Region
					if (call_min_start.to_s.match?(/^[0-9]+$/) && call_max_stop.to_s.match?(/^[0-9]+$/) && region_min_start.to_s.match?(/^[0-9]+$/) && region_max_stop.to_s.match?(/^[0-9]+$/)) && (call_min_start < region_min_start || region_max_stop < call_max_stop)
						call_outside_parent_region_a.push(variant_region_id)
						variant_region_tsv_log_a.push("#{variant_region[:row].join("\t")}\t# JV_SV0053 Warning: Warning if variant call is outside of range of parent variant region, unless region is of type translocation or 'complex chromosomal rearrangement'.")
					end

				end

			else  # unless supporting_variant_call_a.empty?
				## JV_SV0065: Missing variant call for region
				missing_variant_call_for_region_a.push(variant_region_id)
				variant_region_tsv_log_a.push("#{variant_region[:row].join("\t")}\t# JV_SV0065 Error: Region MUST have a child variant call.")
			end # unless variant_region["Supporting Variant Call IDs"].empty?

			# sampleset ids of copy number gain and loss supporting calls
			if sampleset_id_of_variant_call_a.sort.uniq.size == 1
				copy_number_gain_loss_same_sample_region_a.push(variant_region_id)
				variant_region_tsv_log_a.push("#{variant_region[:row].join("\t")}\t# JV_SV0069 Warning: Copy number gain and loss in the same sample.")
			end

			##
			## Placement
			##
			# 1. Mutation ID がある translocation - call の from to を記載し、mutation order etc を記載
			# 2. same pos and type で merge (translocation 以外) - region の placement をそのまま記載
			# 3. identical - translocation region の from to, translocation 以外 region の placement そのまま

			# Mutation ID
	        if mutation_id_exist

	        	supporting_variant_call_a.each{|supporting_variant_call_h|

	        		# from/to しか存在しないはず
			        # PLACEMENT attributes
			        from_placement_attr_h = {}
			        # from_placement_attr_h.store(:alt_status, "")
			        # from_placement_attr_h.store(:placement_method, "")
			        from_placement_attr_h.store(:breakpoint_order, "From")
			        from_placement_attr_h.store(:variant_call_id, supporting_variant_call_h[:"Variant Call ID"]) if supporting_variant_call_h[:"Variant Call ID"] && !supporting_variant_call_h[:"Variant Call ID"].empty?
			        from_placement_attr_h.store(:mutation_order, supporting_variant_call_h[:"Mutation Order"]) if supporting_variant_call_h[:"Mutation Order"] && supporting_variant_call_h[:"Mutation Order"].is_a?(Integer)
			        from_placement_attr_h.store(:mutation_molecule, supporting_variant_call_h[:"Mutation Molecule"]) if supporting_variant_call_h[:"Mutation Molecule"] && !supporting_variant_call_h[:"Mutation Molecule"].empty?

			        variant_region_e.PLACEMENT(from_placement_attr_h){|from_placement_e|

			            # GENOME
			            from_genome_attr_h = {}
						from_genome_attr_h.store(:assembly, supporting_variant_call_h[:refseq_assembly_breakpoint])

						from_genome_attr_h.store(:chr_name, supporting_variant_call_h[:"From Chr"])
						from_genome_attr_h.store(:chr_accession, supporting_variant_call_h[:from_chr_accession])
						from_genome_attr_h.store(:contig_accession, supporting_variant_call_h[:from_contig_accession])

						# start, stop
			            if supporting_variant_call_h[:"From Coord"] && !supporting_variant_call_h[:"From Coord"].empty?
			            	from_genome_attr_h.store(:start, supporting_variant_call_h[:"From Coord"])
							from_genome_attr_h.store(:stop, supporting_variant_call_h[:"From Coord"])
						end

						from_genome_attr_h.store(:strand, supporting_variant_call_h[:"From Strand"]) if supporting_variant_call_h[:"From Strand"] && !supporting_variant_call_h[:"From Strand"].empty?

			            from_genome_attr_h.store(:ciposleft, supporting_variant_call_h[:ciposleft]) if supporting_variant_call_h[:ciposleft] && !supporting_variant_call_h[:ciposleft].empty?
			            from_genome_attr_h.store(:ciposright, supporting_variant_call_h[:ciposright]) if supporting_variant_call_h[:ciposright] && !supporting_variant_call_h[:ciposright].empty?
			            from_genome_attr_h.store(:ciendleft, supporting_variant_call_h[:ciendleft]) if supporting_variant_call_h[:ciendleft] && !supporting_variant_call_h[:ciendleft].empty?
			            from_genome_attr_h.store(:ciendright, supporting_variant_call_h[:ciendright]) if supporting_variant_call_h[:ciendright] && !supporting_variant_call_h[:ciendright].empty?

			            # genome_attr_h.store(:remap_score, "")
			            # genome_attr_h.store(:assembly_unit, "")
			            # genome_attr_h.store(:alignment, "")
			            # genome_attr_h.store(:remap_failure_code, "")
			            # genome_attr_h.store(:placement_rank, "")
			            # genome_attr_h.store(:placements_per_assembly, "")
			            # genome_attr_h.store(:remap_diff_chr, "")
			            # genome_attr_h.store(:remap_best_within_cluster, "")

			            # GENOME attributes
			            from_placement_e.GENOME(from_genome_attr_h)

			        } # from_placement_e

			        to_placement_attr_h = {}
			        # to_placement_attr_h.store(:alt_status, "")
			        # to_placement_attr_h.store(:placement_method, "")
			        to_placement_attr_h.store(:breakpoint_order, "To")
			        to_placement_attr_h.store(:variant_call_id, supporting_variant_call_h[:"Variant Call ID"]) if supporting_variant_call_h[:"Variant Call ID"] && !supporting_variant_call_h[:"Variant Call ID"].empty?
			        to_placement_attr_h.store(:mutation_order, supporting_variant_call_h[:"Mutation Order"]) if supporting_variant_call_h[:"Mutation Order"] && supporting_variant_call_h[:"Mutation Order"].is_a?(Integer)
			        to_placement_attr_h.store(:mutation_molecule, supporting_variant_call_h[:"Mutation Molecule"]) if supporting_variant_call_h[:"Mutation Molecule"] && !supporting_variant_call_h[:"Mutation Molecule"].empty?

			        variant_region_e.PLACEMENT(to_placement_attr_h){|to_placement_e|

			            # GENOME
			            to_genome_attr_h = {}
						to_genome_attr_h.store(:assembly, supporting_variant_call_h[:refseq_assembly_breakpoint])

						to_genome_attr_h.store(:chr_name, supporting_variant_call_h[:"To Chr"])
						to_genome_attr_h.store(:chr_accession, supporting_variant_call_h[:to_chr_accession])
						to_genome_attr_h.store(:contig_accession, supporting_variant_call_h[:to_contig_accession])

						# start, stop
			            if supporting_variant_call_h[:"To Coord"] && !supporting_variant_call_h[:"To Coord"].empty?
			            	to_genome_attr_h.store(:start, supporting_variant_call_h[:"To Coord"])
							to_genome_attr_h.store(:stop, supporting_variant_call_h[:"To Coord"])
						end

						to_genome_attr_h.store(:strand, supporting_variant_call_h[:"To Strand"]) if supporting_variant_call_h[:"To Strand"] && !supporting_variant_call_h[:"To Strand"].empty?

			            to_genome_attr_h.store(:ciposleft, supporting_variant_call_h[:ciposleft]) if supporting_variant_call_h[:ciposleft] && !supporting_variant_call_h[:ciposleft].empty?
			            to_genome_attr_h.store(:ciposright, supporting_variant_call_h[:ciposright]) if supporting_variant_call_h[:ciposright] && !supporting_variant_call_h[:ciposright].empty?
			            to_genome_attr_h.store(:ciendleft, supporting_variant_call_h[:ciendleft]) if supporting_variant_call_h[:ciendleft] && !supporting_variant_call_h[:ciendleft].empty?
			            to_genome_attr_h.store(:ciendright, supporting_variant_call_h[:ciendright]) if supporting_variant_call_h[:ciendright] && !supporting_variant_call_h[:ciendright].empty?

			            # genome_attr_h.store(:remap_score, "")
			            # genome_attr_h.store(:assembly_unit, "")
			            # genome_attr_h.store(:alignment, "")
			            # genome_attr_h.store(:remap_failure_code, "")
			            # genome_attr_h.store(:placement_rank, "")
			            # genome_attr_h.store(:placements_per_assembly, "")
			            # genome_attr_h.store(:remap_diff_chr, "")
			            # genome_attr_h.store(:remap_best_within_cluster, "")

			            # GENOME attributes
			            to_placement_e.GENOME(to_genome_attr_h)

			        } # to_placement_e

			    } # supporting_variant_call_a.each{|supporting_variant_call_h|

	        else # if not mutation_id_exist

	        	# translocation, 1:1
	        	if variant_region_type == "complex chromosomal rearrangement" || variant_region_type == "translocation"

			        # PLACEMENT attributes
			        from_placement_attr_h = {}
			        # from_placement_attr_h.store(:alt_status, "")
			        # from_placement_attr_h.store(:placement_method, "")
			        from_placement_attr_h.store(:breakpoint_order, "From")

			        variant_region_e.PLACEMENT(from_placement_attr_h){|from_placement_e|

			            # GENOME
			            from_genome_attr_h = {}
						from_genome_attr_h.store(:assembly, variant_region[:refseq_assembly_breakpoint])

						from_genome_attr_h.store(:chr_name, variant_region[:"From Chr"])
						from_genome_attr_h.store(:chr_accession, variant_region[:from_chr_accession])
						from_genome_attr_h.store(:contig_accession, variant_region[:from_contig_accession])

						# start, stop
			            if variant_region[:"From Coord"] && !variant_region[:"From Coord"].empty?
			            	from_genome_attr_h.store(:start, variant_region[:"From Coord"])
							from_genome_attr_h.store(:stop, variant_region[:"From Coord"])
						end

						from_genome_attr_h.store(:strand, variant_region[:"From Strand"]) if variant_region[:"From Strand"] && !variant_region[:"From Strand"].empty?

			            from_genome_attr_h.store(:ciposleft, variant_region[:ciposleft]) if variant_region[:ciposleft] && !variant_region[:ciposleft].empty?
			            from_genome_attr_h.store(:ciposright, variant_region[:ciposright]) if variant_region[:ciposright] && !variant_region[:ciposright].empty?
			            from_genome_attr_h.store(:ciendleft, variant_region[:ciendleft]) if variant_region[:ciendleft] && !variant_region[:ciendleft].empty?
			            from_genome_attr_h.store(:ciendright, variant_region[:ciendright]) if variant_region[:ciendright] && !variant_region[:ciendright].empty?

			            # genome_attr_h.store(:remap_score, "")
			            # genome_attr_h.store(:assembly_unit, "")
			            # genome_attr_h.store(:alignment, "")
			            # genome_attr_h.store(:remap_failure_code, "")
			            # genome_attr_h.store(:placement_rank, "")
			            # genome_attr_h.store(:placements_per_assembly, "")
			            # genome_attr_h.store(:remap_diff_chr, "")
			            # genome_attr_h.store(:remap_best_within_cluster, "")

			            # GENOME attributes
			            from_placement_e.GENOME(from_genome_attr_h)

			        } # from placement

			        to_placement_attr_h = {}
			        # to_placement_attr_h.store(:alt_status, "")
			        # to_placement_attr_h.store(:placement_method, "")
			        to_placement_attr_h.store(:breakpoint_order, "To")
			        to_placement_attr_h.store(:variant_call_id, variant_region[:"Variant Call ID"]) if variant_region[:"Variant Call ID"] && !variant_region[:"Variant Call ID"].empty?

			        variant_region_e.PLACEMENT(to_placement_attr_h){|to_placement_e|

			            # GENOME
			            to_genome_attr_h = {}
						to_genome_attr_h.store(:assembly, variant_region[:refseq_assembly_breakpoint])

						to_genome_attr_h.store(:chr_name, variant_region[:"To Chr"])
						to_genome_attr_h.store(:chr_accession, variant_region[:to_chr_accession])
						to_genome_attr_h.store(:contig_accession, variant_region[:to_contig_accession])

						# start, stop
			            if variant_region[:"To Coord"] && !variant_region[:"To Coord"].empty?
			            	to_genome_attr_h.store(:start, variant_region[:"To Coord"])
							to_genome_attr_h.store(:stop, variant_region[:"To Coord"])
						end

						to_genome_attr_h.store(:strand, variant_region[:"To Strand"]) if variant_region[:"To Strand"] && !variant_region[:"To Strand"].empty?

			            to_genome_attr_h.store(:ciposleft, variant_region[:ciposleft]) if variant_region[:ciposleft] && !variant_region[:ciposleft].empty?
			            to_genome_attr_h.store(:ciposright, variant_region[:ciposright]) if variant_region[:ciposright] && !variant_region[:ciposright].empty?
			            to_genome_attr_h.store(:ciendleft, variant_region[:ciendleft]) if variant_region[:ciendleft] && !variant_region[:ciendleft].empty?
			            to_genome_attr_h.store(:ciendright, variant_region[:ciendright]) if variant_region[:ciendright] && !variant_region[:ciendright].empty?

			            # genome_attr_h.store(:remap_score, "")
			            # genome_attr_h.store(:assembly_unit, "")
			            # genome_attr_h.store(:alignment, "")
			            # genome_attr_h.store(:remap_failure_code, "")
			            # genome_attr_h.store(:placement_rank, "")
			            # genome_attr_h.store(:placements_per_assembly, "")
			            # genome_attr_h.store(:remap_diff_chr, "")
			            # genome_attr_h.store(:remap_best_within_cluster, "")

			            # GENOME attributes
			            to_placement_e.GENOME(to_genome_attr_h)

			        } # to_placement_e

	        	else # translocation 以外 1:1, identical merge, supporting call 要素は call 数分挿入済み

			        # PLACEMENT attributes
			        placement_attr_h = {}
			        # placement_attr_h.store(:alt_status, "")
			        # placement_attr_h.store(:placement_method, "")
			        # placement_attr_h.store(:breakpoint_order, "")

			        variant_region_e.PLACEMENT(placement_attr_h){|placement_e|

			            # GENOME
			            genome_attr_h = {}
						genome_attr_h.store(:assembly, variant_region[:refseq_assembly]) if variant_region[:refseq_assembly]

						genome_attr_h.store(:chr_name, variant_region[:Chr])
						genome_attr_h.store(:chr_accession, variant_region[:chr_accession]) if variant_region[:chr_accession]
						genome_attr_h.store(:contig_accession, variant_region[:contig_accession]) if variant_region[:contig_accession]

						# start
			            genome_attr_h.store("outer_start", variant_region[:"Outer Start"]) unless variant_region[:"Outer Start"].empty?
			            genome_attr_h.store("start", variant_region[:Start]) unless variant_region[:Start].empty?
			            genome_attr_h.store("inner_start", variant_region[:"Inner Start"]) unless variant_region[:"Inner Start"].empty?

			            # stop
			            genome_attr_h.store("stop", variant_region[:Stop]) unless variant_region[:Stop].empty?
			            genome_attr_h.store("inner_stop", variant_region[:"Inner Stop"]) unless variant_region[:"Inner Stop"].empty?
			            genome_attr_h.store("outer_stop", variant_region[:"Outer Stop"]) unless variant_region[:"Outer Stop"].empty?

			            genome_attr_h.store(:ciposleft, variant_region[:ciposleft]) if variant_region[:ciposleft] && !variant_region[:ciposleft].empty?
			            genome_attr_h.store(:ciposright, variant_region[:ciposright]) if variant_region[:ciposright] && !variant_region[:ciposright].empty?
			            genome_attr_h.store(:ciendleft, variant_region[:ciendleft]) if variant_region[:ciendleft] && !variant_region[:ciendleft].empty?
			            genome_attr_h.store(:ciendright, variant_region[:ciendright]) if variant_region[:ciendright] && !variant_region[:ciendright].empty?
			            # genome_attr_h.store(:remap_score, "")
			            # genome_attr_h.store(:strand, "")
			            # genome_attr_h.store(:assembly_unit, "")
			            # genome_attr_h.store(:alignment, "")
			            # genome_attr_h.store(:remap_failure_code, "")
			            # genome_attr_h.store(:placement_rank, "")
			            # genome_attr_h.store(:placements_per_assembly, "")
			            # genome_attr_h.store(:remap_diff_chr, "")
			            # genome_attr_h.store(:remap_best_within_cluster, "")

			            # GENOME attributes
			            placement_e.GENOME(genome_attr_h)

					} #placement_e

				end #if variant_region_type == "complex chromosomal rearrangement" || variant_region_type == "translocation"

			end # mutation id or not

	   } # variant_region_e

		## placement check
		## JV_SV0078: Missing start
		if variant_region[:"Outer Start"].empty? && variant_region[:Start].empty? && variant_region[:"Inner Start"].empty? && variant_region_type != "translocation" && variant_region_type != "complex chromosomal rearrangement" && variant_region_type != "novel sequence insertion"
			missing_start_region_a.push(variant_region_id)
			variant_region_tsv_log_a.push("#{variant_region[:row].join("\t")}\t# JV_SV0078 Error: Genomic placement must contain either a start, outer_start, or inner_start unless it is a novel sequence insertion, translocation or complex chromosomal rearrangement.")
		end

		## JV_SV0079: Missing stop
		if variant_region[:"Outer Stop"].empty? && variant_region[:Stop].empty? && variant_region[:"Inner Stop"].empty? && variant_region_type != "translocation" && variant_region_type != "novel sequence insertion"
			missing_stop_region_a.push(variant_region_id)
			variant_region_tsv_log_a.push("#{variant_region[:row].join("\t")}\t# JV_SV0079 Error: Genomic placement must contain either a stop, outer_stop, or inner_stop unless it is a novel sequence insertion or translocation.")
		end

		# JV_SV0080: When on same sequence, start must be <= stop
		if !variant_region[:Start].empty? && !variant_region[:Stop].empty? && (variant_region[:Start].to_i > variant_region[:Stop].to_i)
			invalid_start_stop_region_a.push(variant_region_id)
			variant_region_tsv_log_a.push("#{variant_region[:row].join("\t")}\t# JV_SV0080 Error: When on same sequence, start must be <= stop.")
		end

		# JV_SV0081: When on same sequence, outer_start must be <= outer_stop
		if !variant_region[:"Outer Start"].empty? && !variant_region[:"Outer Stop"].empty? && (variant_region[:"Outer Start"].to_i > variant_region[:"Outer Stop"].to_i)
			invalid_outer_start_outer_stop_region_a.push(variant_region_id)
			variant_region_tsv_log_a.push("#{variant_region[:row].join("\t")}\t# JV_SV0081 Error: When on same sequence, outer_start must be <= outer_stop.")
		end

		# JV_SV0082: When on same sequence, outer_start must be <= inner_start
		if !variant_region[:"Outer Start"].empty? && !variant_region[:"Inner Start"].empty? && (variant_region[:"Outer Start"].to_i > variant_region[:"Inner Start"].to_i)
			invalid_outer_start_inner_start_region_a.push(variant_region_id)
			variant_region_tsv_log_a.push("#{variant_region[:row].join("\t")}\t# JV_SV0082 Error: When on same sequence, outer_start must be <= inner_start.")
		end

		# JV_SV0083: When on same sequence, inner_stop must be <= outer_stop
		if !variant_region[:"Inner Stop"].empty? && !variant_region[:"Outer Stop"].empty? && (variant_region[:"Inner Stop"].to_i > variant_region[:"Outer Stop"].to_i)
			invalid_inner_stop_outer_stop_region_a.push(variant_region_id)
			variant_region_tsv_log_a.push("#{variant_region[:row].join("\t")}\t# JV_SV0083 Error: When on same sequence, inner_stop must be <= outer_stop.")
		end

		# JV_SV0084: Invalid start and inner stop
		if !variant_region[:Start].empty? && !variant_region[:"Inner Stop"].empty? && (variant_region[:Start].to_i >= variant_region[:"Inner Stop"].to_i) && !(!variant_region[:Start].empty? && !variant_region[:Stop].empty? && !variant_region[:"Outer Start"].empty? && !variant_region[:"Outer Stop"].empty? && !variant_region[:"Inner Start"].empty? && !variant_region[:"Inner Stop"].empty?)
			invalid_start_inner_stop_region_a.push(variant_region_id)
			variant_region_tsv_log_a.push("#{variant_region[:row].join("\t")}\t# JV_SV0084 Error: When on same sequence, start must be < inner_stop, unless placement contains all of the following: start, stop, outer_start, outer_stop, inner_start and inner_stop. Also, if using confidence intervals, start must be < (stop - ciendleft).")
		end

		# JV_SV0085: Invalid inner start and stop
		if !variant_region[:"Inner Start"].empty? && !variant_region[:Stop].empty? && (variant_region[:"Inner Start"].to_i >= variant_region[:Stop].to_i) && !(!variant_region[:Start].empty? && !variant_region[:Stop].empty? && !variant_region[:"Outer Start"].empty? && !variant_region[:"Outer Stop"].empty? && !variant_region[:"Inner Start"].empty? && !variant_region[:"Inner Stop"].empty?)
			invalid_inner_start_stop_region_a.push(variant_region_id)
			variant_region_tsv_log_a.push("#{variant_region[:row].join("\t")}\t# JV_SV0085 Error: When on same sequence, inner_start must be < stop, unless placement contains all of the following: start, stop, outer_start, outer_stop, inner_start and inner_stop. Also, if using confidence intervals, (start + ciposright) must be < stop.")
		end

		# JV_SV0086: When on same sequence, inner_start must be <= inner_stop if there are only inner placements
		if !variant_region[:"Inner Start"].empty? && !variant_region[:"Inner Stop"].empty? && (variant_region[:"Inner Start"].to_i > variant_region[:"Inner Stop"].to_i) && !(variant_region[:Start].empty? && variant_region[:Stop].empty? && variant_region[:"Outer Start"].empty? && variant_region[:"Outer Stop"].empty? && !variant_region[:"Inner Start"].empty? && !variant_region[:"Inner Stop"].empty?)
			invalid_inner_start_inner_stop_region_a.push(variant_region_id)
			variant_region_tsv_log_a.push("#{variant_region[:row].join("\t")}\t# JV_SV0086 Error: When on same sequence, inner_start must be <= inner_stop if there are only inner placements.")
		end

		# JV_SV0087: Multiple starts
		if !variant_region[:Start].empty? && (!variant_region[:"Inner Start"].empty? || !variant_region[:"Outer Start"].empty?) || (!variant_region[:"Inner Start"].empty? && !variant_region[:"Outer Start"].empty?) && !variant_region[:Start].empty?
			if (!variant_region[:Start].empty? && !variant_region[:"Outer Start"].empty? && variant_region[:Start] != variant_region[:"Outer Start"]) && (!variant_region[:Start].empty? && !variant_region[:"Inner Start"].empty? && variant_region[:Start] != variant_region[:"Inner Start"])
				multiple_starts_region_a.push(variant_region_id)
				variant_region_tsv_log_a.push("#{variant_region[:row].join("\t")}\t# JV_SV0087 Error: Genomic placement with start must only contain start, or must also contain both outer_start and inner_start.")
			end
		end

		# JV_SV0088: Multiple stops
		if !variant_region[:Stop].empty? && (!variant_region[:"Inner Stop"].empty? || !variant_region[:"Outer Stop"].empty?) || (!variant_region[:"Inner Stop"].empty? && !variant_region[:"Outer Stop"].empty?) && !variant_region[:Stop].empty?
			if (!variant_region[:Stop].empty? && !variant_region[:"Outer Stop"].empty? && variant_region[:Stop] != variant_region[:"Outer Stop"]) && (!variant_region[:Stop].empty? && !variant_region[:"Inner Stop"].empty? && variant_region[:Stop] != variant_region[:"Inner Stop"])
				multiple_stops_region_a.push(variant_region_id)
				variant_region_tsv_log_a.push("#{variant_region[:row].join("\t")}\t# JV_SV0088 Error: Genomic placement with stop must only contain stop, or must also contain both outer_stop and inner_stop.")
			end
		end

		# JV_SV0089: Inconsistent sequence length and start/stop
		if chr_length != -1
			if (!variant_region[:Stop].empty? && variant_region[:Stop].to_i > chr_length.to_i) || (!variant_region[:"Inner Stop"].empty? && variant_region[:"Inner Stop"].to_i > chr_length.to_i) || (!variant_region[:"Outer Stop"].empty? && variant_region[:"Outer Stop"].to_i > chr_length.to_i)
				inconsistent_length_start_stop_region_a.push(variant_region_id)
				variant_region_tsv_log_a.push("#{variant_region[:row].join("\t")}\t# JV_SV0089 Error: Error if inner_stop, stop, or outer_stop are beyond the length of the sequence (chromosome or scaffold).")
			end
		end

		# JV_SV0090: Inconsistent inner start and stop
		if !variant_region[:"Inner Start"].empty? && !variant_region[:"Inner Stop"].empty? && (variant_region[:"Inner Start"].to_i > variant_region[:"Inner Stop"].to_i) && (!variant_region[:"Outer Start"].empty? || !variant_region[:"Outer Stop"].empty?)
			inconsistent_inner_start_stop_region_a.push(variant_region_id)
			warning_sv_a.push(["JV_SV0090", "Warning if when on same sequence, inner_start > inner_stop and there are also valid outer placements. Variant Region ID: #{variant_region_id}"])
		end

		# JV_SV0091: Start and outer/inner starts co-exist
		if !variant_region[:"Inner Start"].empty? && !variant_region[:Start].empty? && !variant_region[:"Outer Start"].empty?
			start_outer_inner_start_coexist_region_a.push(variant_region_id)
			warning_sv_a.push(["JV_SV0091", "Warning if genomic placement with start also contains outer_start and inner_start. Variant Region ID: #{variant_region_id}"])
		end

		# JV_SV0092: Stop and outer/inner stops co-exist
		if !variant_region[:"Inner Stop"].empty? && !variant_region[:Stop].empty? && !variant_region[:"Outer Stop"].empty?
			stop_outer_inner_stop_coexist_region_a.push(variant_region_id)
			warning_sv_a.push(["JV_SV0092", "Warning if genomic placement with stop also contains outer_stop and inner_stop. Variant Region ID: #{variant_region_id}"])
		end

		# min start
		if [variant_region[:"Outer Start"], variant_region[:Start], variant_region[:"Inner Start"]].reject{|e| e.empty? }.map{|e| e.to_i}.min
			start_pos = [variant_region[:"Outer Start"], variant_region[:Start], variant_region[:"Inner Start"]].reject{|e| e.empty? }.map{|e| e.to_i}.min
		end

		# max stop
		if [variant_region[:"Outer Stop"], variant_region[:Stop], variant_region[:"Inner Stop"]].reject{|e| e.empty? }.map{|e| e.to_i}.max
			stop_pos = [variant_region[:"Outer Stop"], variant_region[:Stop], variant_region[:"Inner Stop"]].reject{|e| e.empty? }.map{|e| e.to_i}.max
		end

        ## JV_C0061: Chromosome position larger than chromosome size + 1
		if chr_length != -1
			if (start_pos != -1 && (start_pos > chr_length + 1)) || (stop_pos != -1 && (stop_pos > chr_length + 1))
				pos_outside_chr_region_a.push(variant_region_id)
				variant_region_tsv_log_a.push("#{variant_region[:row].join("\t")}\t# JV_C0061 Error: Chromosome position is larger than chromosome size + 1. Check if the position is correct.")
			end
		end

	end # for variant_region in variant_region_a

	## JV_SV0064: Duplicated Variant Region ID
	error_sv_a.push(["JV_SV0064", "Variant Region ID must be unique. Duplicated Variant Region ID(s): #{duplicated_variant_region_id_a.sort.uniq.size > 4? duplicated_variant_region_id_a.sort.uniq[0, limit_for_etc].join(",") + " etc" : duplicated_variant_region_id_a.sort.uniq.join(",")}"]) unless duplicated_variant_region_id_a.empty?

	## JV_SV0102 Missing Variant Region Type
	unless missing_variant_region_type_a.empty?
		error_sv_a.push(["JV_SV0102", "Variant Region Type is missing. Variant Region ID(s): #{missing_variant_region_type_a.sort.uniq.size > 4? missing_variant_region_type_a.sort.uniq[0, limit_for_etc].join(",") + " etc" : missing_variant_region_type_a.sort.uniq.join(",")}"])
		variant_region_tsv_log_a.push("#{variant_region[:row].join("\t")}\t# V_SV0102 Error: Variant Region Type is missing.")
	end

	## JV_SV0062: Invalid supporting Variant Call ID
	unless (supporting_call_id_a - variant_call_id_h.keys).empty?
		if (supporting_call_id_a - variant_call_id_h.keys).sort.uniq.size < 6
			error_sv_a.push(["JV_SV0062", "Supporting Variant Call ID must refer to a valid Variant Call ID. Invalid Variant Call ID(s): #{(supporting_call_id_a - variant_call_id_h.keys).sort.uniq.map{|e| "#{e}"}.join(",")}"])
		else
			error_sv_a.push(["JV_SV0062", "Supporting Variant Call ID must refer to a valid Variant Call ID. Number of invalid Variant Call ID(s): #{(supporting_call_id_a - variant_call_id_h.keys).sort.uniq.map{|e| "#{e}"}.size}"])
		end
	end

	## JV_SV0056: Variant Call without parent Variant Region
	unless (variant_call_id_h.keys - supporting_call_id_a).empty?
		if (variant_call_id_h.keys - supporting_call_id_a).sort.uniq.size < 6
			warning_sv_a.push(["JV_SV0056", "Variant Call without parent Variant Region. Variant Call ID(s): #{(variant_call_id_h.keys - supporting_call_id_a).sort.uniq.join(",")}"])
		else
			warning_sv_a.push(["JV_SV0056", "Variant Call without parent Variant Region. Number of such calls: #{(variant_call_id_h.keys - supporting_call_id_a).sort.uniq.size}"])
		end
	end

	## JV_SV0061: Invalid supporting Variant Region ID
	unless (supporting_region_id_a - variant_region_id_h.keys).empty?
		if (supporting_region_id_a - variant_region_id_h.keys).sort.uniq.size < 6
			warning_sv_a.push(["JV_SV0061", "Supporting Variant Region ID must refer to a valid Variant Region ID. Variant Region ID(s): #{(supporting_region_id_a - variant_region_id_h.keys).sort.uniq.map{|e| "#{e}"}.join(",")}"])
		else
			warning_sv_a.push(["JV_SV0061", "Supporting Variant Region ID must refer to a valid Variant Region ID. Variant Region ID(s): #{(supporting_region_id_a - variant_region_id_h.keys).sort.uniq.map{|e| "#{e}"}.size}"])
		end
	end

	## Assembly reference check - variant call and region
	## JV_SV0071: Invalid assembly reference
	if translocation_assembly_a.sort.uniq.size == 1
		error_sv_a.push(["JV_SV0071", "Assembly must refer to a valid assembly db name, UCSC name, assembly RefSeq accession, or assembly INSDC accession. Translocation: #{translocation_assembly_a.sort.uniq[0]}"]) if translocation_assembly_a.sort.uniq[0] && !allowed_assembly_a.include?(translocation_assembly_a.sort.uniq[0])
	elsif translocation_assembly_a.sort.uniq.size > 1
		error_sv_a.push(["JV_SV0071", "Assembly must refer to a valid assembly db name, UCSC name, assembly RefSeq accession, or assembly INSDC accession. Translocation: #{translocation_assembly_a.sort.uniq.join(",")}"])
	end

	if variant_call_assembly_a.sort.uniq.size == 1
		error_sv_a.push(["JV_SV0071", "Assembly must refer to a valid assembly db name, UCSC name, assembly RefSeq accession, or assembly INSDC accession. Variant call: #{variant_call_assembly_a.sort.uniq[0]}"]) if variant_call_assembly_a.sort.uniq[0] && !allowed_assembly_a.include?(variant_call_assembly_a.sort.uniq[0])
	elsif variant_call_assembly_a.sort.uniq.size > 1
		error_sv_a.push(["JV_SV0071", "Assembly must refer to a valid assembly db name, UCSC name, assembly RefSeq accession, or assembly INSDC accession. Variant call: #{variant_call_assembly_a.sort.uniq.join(",")}"])
	end

	if variant_region_assembly_a.sort.uniq.size == 1
		error_sv_a.push(["JV_SV0071", "Assembly must refer to a valid assembly db name, UCSC name, assembly RefSeq accession, or assembly INSDC accession. Variant region: #{variant_region_assembly_a.sort.uniq[0]}"]) if variant_region_assembly_a.sort.uniq[0] && !allowed_assembly_a.include?(variant_region_assembly_a.sort.uniq[0])
	elsif variant_region_assembly_a.sort.uniq.size > 1
		error_sv_a.push(["JV_SV0071", "Assembly must refer to a valid assembly db name, UCSC name, assembly RefSeq accession, or assembly INSDC accession. Variant region: #{variant_region_assembly_a.sort.uniq.join(",")}"])
	end

 	# variant call と region で assembly は同じであること
 	if (variant_call_assembly_a + variant_region_assembly_a).sort.uniq.size > 1
		error_sv_a.push(["JV_SV0071", "Assembly must refer to a valid assembly db name, UCSC name, assembly RefSeq accession, or assembly INSDC accession. Variant call and region: #{(variant_call_assembly_a + variant_region_assembly_a).sort.uniq.join(",")}"])
 	end

	## JV_C0057: Invalid value for controlled terms
	error_ignore_sv_a.push(["JV_C0057", "Value is not in controlled terms. Variant Region: #{invalid_value_for_cv_region_a.size} sites, #{invalid_value_for_cv_region_a.size > 4? invalid_value_for_cv_region_a[0, limit_for_etc].join(",") + " etc" : invalid_value_for_cv_region_a.join(",")}"]) unless invalid_value_for_cv_region_a.empty?

	## JV_C0061: Chromosome position larger than chromosome size + 1
	error_common_a.push(["JV_C0061", "Chromosome position is larger than chromosome size + 1. Check if the position is correct. Variant Call: #{pos_outside_chr_call_a.size} sites, #{pos_outside_chr_call_a.size > 4? pos_outside_chr_call_a[0, limit_for_etc].join(",") + " etc" : pos_outside_chr_call_a.join(",")}"]) unless pos_outside_chr_call_a.empty?
	error_common_a.push(["JV_C0061", "Chromosome position is larger than chromosome size + 1. Check if the position is correct. Variant Region: #{pos_outside_chr_region_a.size} sites, #{pos_outside_chr_region_a.size > 4? pos_outside_chr_region_a[0, limit_for_etc].join(",") + " etc" : pos_outside_chr_region_a.join(",")}"]) unless pos_outside_chr_region_a.empty?

	# JV_C0063: Allele count greater than allele number
	error_common_a.push(["JV_C0063", "Allele count is greater than allele number. Variant Call: #{ac_greater_than_an_a.size} sites, #{ac_greater_than_an_a.size > 4? ac_greater_than_an_a[0, limit_for_etc].join(",") + " etc" : ac_greater_than_an_a.join(",")}"]) if ac_greater_than_an_a.size > 0

	## JV_SV0068: Missing assertion_method
	error_ignore_sv_a.push(["JV_SV0068", "Region MUST have an assertion_method. JVar will fill in this field. Variant Region: #{missing_assertion_method_region_a.size} sites, #{missing_assertion_method_region_a.size > 4? missing_assertion_method_region_a[0, limit_for_etc].join(",") + " etc" : missing_assertion_method_region_a.join(",")}"]) unless missing_assertion_method_region_a.empty?

	## JV_SV0050: Inconsistent Variant Call Type and Variant Region Type
	warning_sv_a.push(["JV_SV0050", "Inconsistent Variant Call Type and Variant Region Type. Variant Region: #{inconsistent_type_region_a.size} sites, #{inconsistent_type_region_a.size > 4? inconsistent_type_region_a[0, limit_for_etc].join(",") + " etc" : inconsistent_type_region_a.join(",")}"]) unless inconsistent_type_region_a.empty?

	## JV_SV0051: Mixed Variant Region Type
	warning_sv_a.push(["JV_SV0051", "Warning if variant call is in a variant region with different type UNLESS the region type is 'copy number variation' and the call type is ('copy number gain','copy number loss','deletion', or 'duplication'), OR the region type is 'mobile element insertion' and the call type is ('alu insertion', 'herv insertion', 'line1 insertion', or 'sva insertion'), OR the region type is 'mobile element deletion' and the call type is ('alu deletion', 'herv deletion', 'line1 deletion', or 'sva deletion'), OR the region type is ('translocation' or 'complex chromosomal rearrangement') and the call type is ('interchromosomal translocation' or 'intrachromosomal translocation'). Variant Region: #{mixed_type_region_a.size} sites, #{mixed_type_region_a.size > 4? mixed_type_region_a[0, limit_for_etc].join(",") + " etc" : mixed_type_region_a.join(",")}"]) unless mixed_type_region_a.empty?

	## JV_SV0053: Variant Call is outside of parent Variant Region
	warning_sv_a.push(["JV_SV0053", "Warning if variant call is outside of range of parent variant region, unless region is of type translocation or 'complex chromosomal rearrangement'. Variant Region: #{call_outside_parent_region_a.size} sites, #{call_outside_parent_region_a.size > 4? call_outside_parent_region_a[0, limit_for_etc].join(",") + " etc" : call_outside_parent_region_a.join(",")}"]) unless call_outside_parent_region_a.empty?

	## JV_SV0066: Missing mutation order for complex chromosomal rearrangement and translocation
	error_ignore_sv_a.push(["JV_SV0066", "Variant regions with type 'complex chromosomal rearrangement' and 'translocation' must have Mutation Order in their supporting variant calls with Mutation ID. Variant Region: #{missing_mutation_order_region_a.size} sites, #{missing_mutation_order_region_a.size > 4? missing_mutation_order_region_a[0, limit_for_etc].join(",") + " etc" : missing_mutation_order_region_a.join(",")}"]) unless missing_mutation_order_region_a.empty?

	## JV_SV0065: Missing variant call for region
	error_sv_a.push(["JV_SV0065", "Region MUST have a child variant call. Variant Region: #{missing_mutation_order_region_a.size} sites, #{missing_mutation_order_region_a.size > 4? missing_mutation_order_region_a[0, limit_for_etc].join(",") + " etc" : missing_mutation_order_region_a.join(",")}"]) unless missing_mutation_order_region_a.empty?

	## JV_SV0043: Invalid translocation placements
	error_ignore_sv_a.push(["JV_SV0043", "In translocation calls supporting the same variant region, the chromosome and strand of the To placement must match the chromosome and strand of the From placement of the next variant call (based on Mutation Order). Variant Region: #{invalid_translocation_placement_SV0043_region_a.size} sites, #{invalid_translocation_placement_SV0043_region_a.size > 4? invalid_translocation_placement_SV0043_region_a[0, limit_for_etc].join(",") + " etc" : invalid_translocation_placement_SV0043_region_a.join(",")}"]) unless invalid_translocation_placement_SV0043_region_a.empty?

	## JV_SV0097: Invalid translocation placements
	error_ignore_sv_a.push(["JV_SV0097", "In translocation calls supporting the same variant region, the chromosome placement of the To placement must be less than the chromosome placement of the From placement of the next variant call (based on Mutation Order) if their strand is '+'. Variant Region: #{invalid_translocation_placement_SV0097_region_a.size} sites, #{invalid_translocation_placement_SV0097_region_a.size > 4? invalid_translocation_placement_SV0097_region_a[0, limit_for_etc].join(",") + " etc" : invalid_translocation_placement_SV0097_region_a.join(",")}"]) unless invalid_translocation_placement_SV0097_region_a.empty?

	## JV_SV0098: Invalid translocation placements
	error_ignore_sv_a.push(["JV_SV0098", "In translocation calls supporting the same variant region, the chromosome placement of the To placement must be greater than the chromosome placement of the From placement of the next variant call (based on mutation_order) if their strand is '-'. Variant Region: #{invalid_translocation_placement_SV0098_region_a.size} sites, #{invalid_translocation_placement_SV0098_region_a.size > 4? invalid_translocation_placement_SV0098_region_a[0, limit_for_etc].join(",") + " etc" : invalid_translocation_placement_SV0098_region_a.join(",")}"]) unless invalid_translocation_placement_SV0098_region_a.empty?

	## JV_SV0100: Mixed mutation ID for complex chromosomal rearrangement and translocation
	error_ignore_sv_a.push(["JV_SV0100", "Within a variant region with type 'complex chromosomal rearrangement' and 'translocation', each supporting variant call must have a unique value for Mutation ID. Variant Region: #{mixed_mutation_id_region_a.size} sites, #{mixed_mutation_id_region_a.size > 4? mixed_mutation_id_region_a[0, limit_for_etc].join(",") + " etc" : mixed_mutation_id_region_a.join(",")}"]) unless mixed_mutation_id_region_a.empty?

	## JV_SV0067: Missing serial mutation order number for complex chromosomal rearrangement and translocation
	error_ignore_sv_a.push(["JV_SV0067", "Missing serial mutation order number for complex chromosomal rearrangement and translocation. JVar will assign serial order(s). Variant Region: #{missing_serial_mutation_order_region_a.size} sites, #{missing_serial_mutation_order_region_a.size > 4? missing_serial_mutation_order_region_a[0, limit_for_etc].join(",") + " etc" : missing_serial_mutation_order_region_a.join(",")}"]) unless missing_serial_mutation_order_region_a.empty?

	## JV_SV0069: Copy number gain and loss in the same sample
	warning_sv_a.push(["JV_SV0069", "Warning if region contains calls that have both copy number gain and copy number loss in the same sample. Variant Region: #{copy_number_gain_loss_same_sample_region_a.size} sites, #{copy_number_gain_loss_same_sample_region_a.size > 4? copy_number_gain_loss_same_sample_region_a[0, limit_for_etc].join(",") + " etc" : copy_number_gain_loss_same_sample_region_a.join(",")}"]) unless copy_number_gain_loss_same_sample_region_a.empty?

	## JV_SV0077: Contig accession exists for chromosome accession
	error_sv_a.push(["JV_SV0077", "Genomic placement should not have a contig_accession if there is also a chr_name or chr_accession. Variant Region: #{contig_acc_for_chr_acc_region_a.size} sites, #{contig_acc_for_chr_acc_region_a.size > 4? contig_acc_for_chr_acc_region_a[0, limit_for_etc].join(",") + " etc" : contig_acc_for_chr_acc_region_a.join(",")}"]) unless contig_acc_for_chr_acc_region_a.empty?

	## JV_SV0072: Invalid chromosome reference
	error_sv_a.push(["JV_SV0072", "chr_name or chr_accession must refer to a valid chromosome for the specified assembly, and chr_name can contain 'chr'. Variant Region: #{invalid_chr_ref_region_a.size} sites, #{invalid_chr_ref_region_a.size > 4? invalid_chr_ref_region_a[0, limit_for_etc].join(",") + " etc" : invalid_chr_ref_region_a.join(",")}"]) unless invalid_chr_ref_region_a.empty?

	## JV_SV0074: Invalid contig accession reference
	error_sv_a.push(["JV_SV0074", "Contig_accession must refer to a valid contig belonging to the assembly. Variant Region: #{invalid_contig_acc_ref_region_a.size} sites, #{invalid_contig_acc_ref_region_a.size > 4? invalid_contig_acc_ref_region_a[0, limit_for_etc].join(",") + " etc" : invalid_contig_acc_ref_region_a.join(",")}"]) unless invalid_contig_acc_ref_region_a.empty?

	## JV_SV0076: Missing chromosome/contig accession
	error_sv_a.push(["JV_SV0076", "Genomic placement must contain either a chr_name, chr_accession, or contig_accession unless it is on a novel sequence insertion or translocation. Variant Region: #{missing_chr_contig_acc_region_a.size} sites, #{missing_chr_contig_acc_region_a.size > 4? missing_chr_contig_acc_region_a[0, limit_for_etc].join(",") + " etc" : missing_chr_contig_acc_region_a.join(",")}"]) unless missing_chr_contig_acc_region_a.empty?

	# JV_SV0078: Missing start
	error_ignore_sv_a.push(["JV_SV0078", "Genomic placement must contain either a start, outer_start, or inner_start unless it is a novel sequence insertion, translocation or complex chromosomal rearrangement. Variant Region: #{missing_start_region_a.size} sites, #{missing_start_region_a.size > 4? missing_start_region_a[0, limit_for_etc].join(",") + " etc" : missing_start_region_a.join(",")}"]) unless missing_start_region_a.empty?

	# JV_SV0079: Missing stop
	error_ignore_sv_a.push(["JV_SV0079", "Genomic placement must contain either a stop, outer_stop, or inner_stop unless it is a novel sequence insertion, translocation or complex chromosomal rearrangement. Variant Region: #{missing_stop_region_a.size} sites, #{missing_stop_region_a.size > 4? missing_stop_region_a[0, limit_for_etc].join(",") + " etc" : missing_stop_region_a.join(",")}"]) unless missing_stop_region_a.empty?

	# JV_SV0080: When on same sequence, start must be <= stop
	error_ignore_sv_a.push(["JV_SV0080", "When on same sequence, start must be <= stop. Variant Region: #{invalid_start_stop_region_a.size} sites, #{invalid_start_stop_region_a.size > 4? invalid_start_stop_region_a[0, limit_for_etc].join(",") + " etc" : invalid_start_stop_region_a.join(",")}"]) unless invalid_start_stop_region_a.empty?

	# JV_SV0081: When on same sequence, outer_start must be <= outer_stop
	error_ignore_sv_a.push(["JV_SV0081", "When on same sequence, outer_start must be <= outer_stop. Variant Region: #{invalid_outer_start_outer_stop_region_a.size} sites, #{invalid_outer_start_outer_stop_region_a.size > 4? invalid_outer_start_outer_stop_region_a[0, limit_for_etc].join(",") + " etc" : invalid_outer_start_outer_stop_region_a.join(",")}"]) unless invalid_outer_start_outer_stop_region_a.empty?

	# JV_SV0082: When on same sequence, outer_start must be <= inner_start
	error_ignore_sv_a.push(["JV_SV0082", "When on same sequence, outer_start must be <= inner_start. Variant Region: #{invalid_outer_start_inner_start_region_a.size} sites, #{invalid_outer_start_inner_start_region_a.size > 4? invalid_outer_start_inner_start_region_a[0, limit_for_etc].join(",") + " etc" : invalid_outer_start_inner_start_region_a.join(",")}"]) unless invalid_outer_start_inner_start_region_a.empty?

	# JV_SV0083: When on same sequence, inner_stop must be <= outer_stop
	error_ignore_sv_a.push(["JV_SV0083", "When on same sequence, inner_stop must be <= outer_stop. Variant Region: #{invalid_inner_stop_outer_stop_region_a.size} sites, #{invalid_inner_stop_outer_stop_region_a.size > 4? invalid_inner_stop_outer_stop_region_a[0, limit_for_etc].join(",") + " etc" : invalid_inner_stop_outer_stop_region_a.join(",")}"]) unless invalid_inner_stop_outer_stop_region_a.empty?

	# JV_SV0084: Invalid start and inner stop
	error_ignore_sv_a.push(["JV_SV0084", "When on same sequence, start must be < inner_stop, unless placement contains all of the following: start, stop, outer_start, outer_stop, inner_start and inner_stop. Also, if using confidence intervals, start must be < (stop - ciendleft). Variant Region: #{invalid_start_inner_stop_region_a.size} sites, #{invalid_start_inner_stop_region_a.size > 4? invalid_start_inner_stop_region_a[0, limit_for_etc].join(",") + " etc" : invalid_start_inner_stop_region_a.join(",")}"]) unless invalid_start_inner_stop_region_a.empty?

	# JV_SV0085: Invalid inner start and stop
	error_ignore_sv_a.push(["JV_SV0085", "When on same sequence, inner_start must be < stop, unless placement contains all of the following: start, stop, outer_start, outer_stop, inner_start and inner_stop. Also, if using confidence intervals, (start + ciposright) must be < stop. Variant Region: #{invalid_inner_start_stop_region_a.size} sites, #{invalid_inner_start_stop_region_a.size > 4? invalid_inner_start_stop_region_a[0, limit_for_etc].join(",") + " etc" : invalid_inner_start_stop_region_a.join(",")}"]) unless invalid_inner_start_stop_region_a.empty?

	# JV_SV0086: When on same sequence, inner_start must be <= inner_stop if there are only inner placements
	error_ignore_sv_a.push(["JV_SV0086", "When on same sequence, inner_start must be <= inner_stop if there are only inner placements. Variant Region: #{invalid_inner_start_inner_stop_region_a.size} sites, #{invalid_inner_start_inner_stop_region_a.size > 4? invalid_inner_start_inner_stop_region_a[0, limit_for_etc].join(",") + " etc" : invalid_inner_start_inner_stop_region_a.join(",")}"]) unless invalid_inner_start_inner_stop_region_a.empty?

	# JV_SV0087: Multiple starts
	error_ignore_sv_a.push(["JV_SV0087", "Genomic placement with start must only contain start, or must also contain both outer_start and inner_start. Variant Region: #{multiple_starts_region_a.size} sites, #{multiple_starts_region_a.size > 4? multiple_starts_region_a[0, limit_for_etc].join(",") + " etc" : multiple_starts_region_a.join(",")}"]) unless multiple_starts_region_a.empty?

	# JV_SV0088: Multiple stops
	error_ignore_sv_a.push(["JV_SV0088", "Genomic placement with stop must only contain stop, or must also contain both outer_stop and inner_stop. Variant Region: #{multiple_stops_region_a.size} sites, #{multiple_stops_region_a.size > 4? multiple_stops_region_a[0, limit_for_etc].join(",") + " etc" : multiple_stops_region_a.join(",")}"]) unless multiple_stops_region_a.empty?

	# JV_SV0089: Inconsistent sequence length and start/stop
	error_ignore_sv_a.push(["JV_SV0089", "Error if inner_stop, stop, or outer_stop are beyond the length of the sequence (chromosome or scaffold). Variant Region: #{inconsistent_length_start_stop_region_a.size} sites, #{inconsistent_length_start_stop_region_a.size > 4? inconsistent_length_start_stop_region_a[0, limit_for_etc].join(",") + " etc" : inconsistent_length_start_stop_region_a.join(",")}"]) unless inconsistent_length_start_stop_region_a.empty?

	# JV_SV0090: Inconsistent inner start and stop
	warning_sv_a.push(["JV_SV0090", "Warning if when on same sequence, inner_start > inner_stop and there are also valid outer placements. Variant Region: #{inconsistent_inner_start_stop_region_a.size} sites, #{inconsistent_inner_start_stop_region_a.size > 4? inconsistent_inner_start_stop_region_a[0, limit_for_etc].join(",") + " etc" : inconsistent_inner_start_stop_region_a.join(",")}"]) unless inconsistent_inner_start_stop_region_a.empty?

	# JV_SV0091: Start and outer/inner starts co-exist
	warning_sv_a.push(["JV_SV0091", "Warning if genomic placement with start also contains outer_start and inner_start. Variant Region: #{start_outer_inner_start_coexist_region_a.size} sites, #{start_outer_inner_start_coexist_region_a.size > 4? start_outer_inner_start_coexist_region_a[0, limit_for_etc].join(",") + " etc" : start_outer_inner_start_coexist_region_a.join(",")}"]) unless start_outer_inner_start_coexist_region_a.empty?

	# JV_SV0092: Stop and outer/inner stops co-exist
	warning_sv_a.push(["JV_SV0092", "Warning if genomic placement with stop also contains outer_stop and inner_stop. Variant Region: #{stop_outer_inner_stop_coexist_region_a.size} sites, #{stop_outer_inner_stop_coexist_region_a.size > 4? stop_outer_inner_stop_coexist_region_a[0, limit_for_etc].join(",") + " etc" : stop_outer_inner_stop_coexist_region_a.join(",")}"]) unless stop_outer_inner_stop_coexist_region_a.empty?

	##
	## GENOTYPE_XML
	##
	if gt_xml && sv_genotype_f
		submission << gt_xml.target!
	end

} # SUBMISSION

end # if submission_h["Submission Type"] == "Structural variations"

# Variant Call TSV log
# Excel sheet tsv log
if !all_variant_call_tsv_log_a.empty? && vc_input_filename != "tsv"

	all_variant_call_tsv_log_f = open("#{excel_path}/#{submission_id}.variant_call.tsv.log.txt", "w")

	all_variant_call_tsv_log_f.puts variant_call_sheet_header_a.join("\t")

	all_variant_call_tsv_log_a.each{|line|
		all_variant_call_tsv_log_f.puts line
	}

	all_variant_call_tsv_log_f.close
end

# Variant Region TSV log
unless variant_region_tsv_log_a.empty?

	variant_region_tsv_log_f = open("#{excel_path}/#{submission_id}.variant_region.tsv.log.txt", "w")

	variant_region_tsv_log_f.puts variant_region_sheet_header_a.join("\t")

	variant_region_tsv_log_a.each{|line|
		variant_region_tsv_log_f.puts line
	}

	variant_region_tsv_log_f.close
end

# VCF log file close
# vcf_log_f.close if FileTest.exist?(vcf_log_f)

#
# Validation 結果出力
#

# VCF
vcf_validation_result_s = ""
validation_result_s = ""
snp_validation_result_s = ""
sv_validation_result_s = ""

## SNP/SV Common
unless $ref_check_f
validation_result_s = <<EOS
REF base identity check by samtools was skipped.

EOS
end

validation_result_s += <<EOS
JVar-SNP/SV common validation results
---------------------------------------------
Error
EOS

error_common_a.sort{|a,b| a[0] <=> b[0]}.each{|m| validation_result_s += m.join(": ") + "\n"}

validation_result_s += <<EOS

Error (ignore)
EOS

error_ignore_common_a.sort{|a,b| a[0] <=> b[0]}.each{|m| validation_result_s += m.join(": ") + "\n"}

validation_result_s += <<EOS

Warning
EOS

warning_common_a.sort{|a,b| a[0] <=> b[0]}.each{|m| validation_result_s += m.join(": ") + "\n"}

validation_result_s += <<EOS
---------------------------------------------
EOS

if submission_type == "SNP"
snp_validation_result_s = <<EOS

JVar-SNP validation results
---------------------------------------------
Error
EOS

error_snp_a.sort{|a,b| a[0] <=> b[0]}.each{|m| snp_validation_result_s += m.join(": ") + "\n"}

snp_validation_result_s += <<EOS

Error (ignore)
EOS

error_ignore_snp_a.sort{|a,b| a[0] <=> b[0]}.each{|m| snp_validation_result_s += m.join(": ") + "\n"}

snp_validation_result_s += <<EOS

Warning
EOS

warning_snp_a.sort{|a,b| a[0] <=> b[0]}.each{|m| snp_validation_result_s += m.join(": ") + "\n"}

snp_validation_result_s += <<EOS
---------------------------------------------
EOS
end

if submission_type == "SV"
sv_validation_result_s = <<EOS

JVar-SV validation results
---------------------------------------------
Error
EOS

error_sv_a.sort{|a,b| a[0] <=> b[0]}.each{|m| sv_validation_result_s += m.join(": ") + "\n"}

sv_validation_result_s += <<EOS

Error (ignore)
EOS

error_ignore_sv_a.sort{|a,b| a[0] <=> b[0]}.each{|m| sv_validation_result_s += m.join(": ") + "\n"}

sv_validation_result_s += <<EOS

Warning
EOS

warning_sv_a.sort{|a,b| a[0] <=> b[0]}.each{|m| sv_validation_result_s += m.join(": ") + "\n"}

sv_validation_result_s += <<EOS
---------------------------------------------
EOS

## Variant Call
# tsv
if vcf_file_a.empty? # TSV

sv_vc_validation_result_s = <<EOS

JVar-SV Variant Call validation results (TSV)
---------------------------------------------
Error
EOS

	error_sv_vc_h["tsv"].sort{|a,b| a[0] <=> b[0]}.each{|m| sv_vc_validation_result_s += m.join(": ") + "\n"} if error_sv_vc_h["tsv"]

sv_vc_validation_result_s += <<EOS

Error (ignore)
EOS

	error_ignore_sv_vc_h["tsv"].sort{|a,b| a[0] <=> b[0]}.each{|m| sv_vc_validation_result_s += m.join(": ") + "\n"} if error_ignore_sv_vc_h["tsv"]

sv_vc_validation_result_s += <<EOS

Warning
EOS

	warning_sv_vc_h["tsv"].sort{|a,b| a[0] <=> b[0]}.each{|m| sv_vc_validation_result_s += m.join(": ") + "\n"} if warning_sv_vc_h["tsv"]

sv_vc_validation_result_s += <<EOS
---------------------------------------------

EOS

else # VCF file(s)

sv_vc_validation_result_s = <<EOS

JVar-SV Variant Call validation results
========================================================================
EOS

	for vcf_file in vcf_file_a

sv_vc_validation_result_s += <<EOS

VCF: #{vcf_file}
---------------------------------------------
Error
EOS

		error_sv_vc_h[vcf_file].sort{|a,b| a[0] <=> b[0]}.each{|m| sv_vc_validation_result_s += m.join(": ") + "\n"}

sv_vc_validation_result_s += <<EOS

Error (ignore)
EOS

	error_ignore_sv_vc_h[vcf_file].sort{|a,b| a[0] <=> b[0]}.each{|m| sv_vc_validation_result_s += m.join(": ") + "\n"}

sv_vc_validation_result_s += <<EOS

Warning
EOS

	warning_sv_vc_h[vcf_file].sort{|a,b| a[0] <=> b[0]}.each{|m| sv_vc_validation_result_s += m.join(": ") + "\n"}

sv_vc_validation_result_s += <<EOS
---------------------------------------------
EOS

	end # for vcf_file in vcf_file_a

sv_vc_validation_result_s += <<EOS
========================================================================
EOS

end

	# dbVar xsd validation
	xsd_results_s = ""
	if xsd_f && FileTest.exist?("#{excel_path}/#{submission_id}_dbvar.xml")
		o, e, s = Open3.capture3("#{sin_path}xmllint --schema dbVar.xsd --noout #{excel_path}/#{submission_id}_dbvar.xml")

		xsd_results_s = <<EOS
JVar-SV XML dbVar xsd validation results
---------------------------------------------
#{e.strip}
---------------------------------------------
EOS
	end

end # if submission_type == "SV"


## VCF
if !vcf_snp_a.empty? || !vcf_sv_f.empty?

vcf_validation_result_s = <<EOS

JVar-#{submission_type == "SNP" ? "SNP" : "SV"} VCF validation results
========================================================================
EOS

	for vcf_file in vcf_file_a

vcf_validation_result_s += <<EOS

VCF: #{vcf_file}

Header
---------------------------------------------
Error
EOS

	error_vcf_header_h[vcf_file].sort{|a,b| a[0] <=> b[0]}.each{|m| vcf_validation_result_s += m.join(": ") + "\n"}

vcf_validation_result_s += <<EOS

Error (ignore)
EOS

	error_ignore_vcf_header_h[vcf_file].sort{|a,b| a[0] <=> b[0]}.each{|m| vcf_validation_result_s += m.join(": ") + "\n"}

vcf_validation_result_s += <<EOS

Error (exchange)
EOS

	error_exchange_vcf_header_h[vcf_file].sort{|a,b| a[0] <=> b[0]}.each{|m| vcf_validation_result_s += m.join(": ") + "\n"}

vcf_validation_result_s += <<EOS

Warning
EOS

	warning_vcf_header_h[vcf_file].sort{|a,b| a[0] <=> b[0]}.each{|m| vcf_validation_result_s += m.join(": ") + "\n"}

vcf_validation_result_s += <<EOS
---------------------------------------------

EOS

vcf_validation_result_s += <<EOS
Content
---------------------------------------------
Error
EOS

	error_vcf_content_h[vcf_file].sort{|a,b| a[0] <=> b[0]}.each{|m| vcf_validation_result_s += m.join(": ") + "\n"}

vcf_validation_result_s += <<EOS

Error (ignore)
EOS

	error_ignore_vcf_content_h[vcf_file].sort{|a,b| a[0] <=> b[0]}.each{|m| vcf_validation_result_s += m.join(": ") + "\n"}

vcf_validation_result_s += <<EOS

Error (exchange)
EOS

	error_exchange_vcf_content_h[vcf_file].sort{|a,b| a[0] <=> b[0]}.each{|m| vcf_validation_result_s += m.join(": ") + "\n"}

vcf_validation_result_s += <<EOS

Warning
EOS

	warning_vcf_content_h[vcf_file].sort{|a,b| a[0] <=> b[0]}.each{|m| vcf_validation_result_s += m.join(": ") + "\n"}

vcf_validation_result_s += <<EOS
---------------------------------------------
EOS

	end # for vcf_file in vcf_file_a

vcf_validation_result_s += <<EOS
========================================================================
EOS

end # if !vcf_snp_a.empty? || !vcf_sv_f.empty?

## Assembly にない INSDC fasta を download & index
unless contig_download_a.empty?

	contig_download_s = <<EOS

Download and index reference sequences
---------------------------------------------
EOS

	for command_line in contig_download_a
		contig_download_s += "#{command_line}\n"
	end

end

## validation 結果を出力
validation_result_f = open("#{excel_path}/#{submission_id}_#{submission_type}.log.txt", "w")

## Common
validation_result_f.puts validation_result_s
puts validation_result_s

if submission_type == "SNP"
	validation_result_f.puts snp_validation_result_s
	puts snp_validation_result_s
end

if submission_type == "SV"
	validation_result_f.puts sv_validation_result_s
	puts sv_validation_result_s
end

# Variant Call
if submission_type == "SV"
	validation_result_f.puts sv_vc_validation_result_s
	puts sv_vc_validation_result_s
end

# VCF
if !vcf_snp_a.empty? || !vcf_sv_f.empty?
	validation_result_f.puts vcf_validation_result_s
	puts vcf_validation_result_s
end

# dbVar xsd validation
if xsd_f && !xsd_results_s.empty? && submission_type == "SV"
	validation_result_f.puts xsd_results_s
	puts xsd_results_s
end

# Download contig
unless contig_download_s.empty?
	validation_result_f.puts contig_download_s
	puts contig_download_s
end

=begin

以下の region チェックは call と重複しているので省略。

					## JV_SV0077: Contig accession exists for chromosome accession
					if !variant_region[:Contig].empty? && !variant_region[:Chr].empty?
						contig_acc_for_chr_acc_region_a.push(variant_region_id)
						variant_region_tsv_log_a.push("#{variant_region[:row].join("\t")}\t# JV_SV0077 Error: Contig accession exists for chromosome accession.")
					end

					## JV_SV0072: Invalid chromosome reference
					if !variant_region[:Chr].empty? && !valid_chr_f
						invalid_chr_ref_region_a.push(variant_region_id)
						variant_region_tsv_log_a.push("#{variant_region[:row].join("\t")}\t# JV_SV0072 Error: Contig accession exists for chromosome accession.")
					end

					## JV_SV0074: Invalid contig accession reference
					if !variant_region[:Contig].empty? && !valid_contig_f
						invalid_contig_acc_ref_region_a.push(variant_region_id)
						variant_region_tsv_log_a.push("#{variant_region[:row].join("\t")}\t# JV_SV0074 Error: Contig accession must refer to a valid INSDC accession and version.")
					end

					## JV_SV0076: Missing chromosome/contig accession
					if chr_name.empty? && chr_accession.empty? && contig_accession.empty?
						missing_chr_contig_acc_region_a.push(variant_region_id)
						variant_region_tsv_log_a.push("#{variant_region[:row].join("\t")}\t# JV_SV0076 Error: Genomic placement must contain either a chr_name, chr_accession, or contig_accession unless it is on a novel sequence insertion or translocation.")
					end

=end

