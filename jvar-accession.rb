#! usr/bin/ruby
# -*- coding: utf-8 -*-

require 'rubygems'
require 'roo'
require 'optparse'
require 'net/http'
require 'json'
require 'jsonl'
require 'builder'
require 'nokogiri'
require 'open3'
#sin require '/usr/local/bin/lib/jvar-method.rb'

#
# Bioinformation and DDBJ Center
# Japan Variation Database (JVar)
#
# Submission type: SNP - Generate JVar-SNP TSV (dbSNP TSV)
# Submission type: SV - Generate JVar-SV XML (dbVar XML)
#

# Assign accession numbers and create data for release and dbSNP/dbVar exports.

# Update history
# 2023-07-11 created

### Options
submission_id = ""
vload_id = ""
OptionParser.new{|opt|

	opt.on('-v [VSUB ID]', 'VSUB submission ID'){|v|
		raise "usage: -v JVar submission ID (VSUB000001)" if v.nil? || !(/^VSUB\d{6}$/ =~ v)
		submission_id = v
		puts "JVar Submission ID: #{v}"
	}

	opt.on('-i [vload_id]', 'vload_id'){|i|
		#raise "usage: -l vload_id"
		vload_id = i
		puts "vload_id: #{i}"
	}

	begin
		opt.parse!
	rescue
		puts "Invalid option. #{opt}"
	end

}

# VSUB ない場合はエラー
raise "Specify a valid submission_id." if submission_id.empty?

## 設定
sub_path = "submission"
study_path = "study"
first_study_acc = 1
study_acc_prefix = "dstd"

## SNP or SV
submission_type = ""
if FileTest.exist?("#{sub_path}/#{submission_id}/#{submission_id}_dbsnp.tsv")
	submission_type = "SNP"
elsif FileTest.exist?("#{sub_path}/#{submission_id}/#{submission_id}_dbvar.xml")
	submission_type = "SV"
end

if submission_type == "SV" && (vload_id.nil? || vload_id.empty?)
	puts "Warning: vload_id is missing for dbVar submission."
end

## last number
last_f = open("#{study_path}/last.txt")

snp_first = false
sv_first = false
dstd_a = []
dss_a = []
dsv_a = []
dssv_a = []
first = true

for line in last_f
	
	if first
		first = false
		next
	end

	if line == "\n"
		next
	end

	line_a = line.split("\t")

	valid_line_f = false
	valid_study_f = false
	valid_dss_f = false
	valid_dssv_f = false
	valid_dsv_f = false
	valid_sv_f = false

	duplicated_f = false

	# study
	if line_a[0] =~ /^dstd(\d{1,})$/
		dstd_a.push($1.to_i)
		valid_study_f = true
	end

	# submission ID
	if line_a[1] == submission_id
		duplicated_f = true
	end

	# snp
	if line_a[2] =~ /^dss(\d{1,})-dss(\d{1,})$/
		dss_a.push($2.to_i)
		valid_dss_f = true
	end

	# ssv
	if line_a[3] =~ /^dssv(\d{1,})-dssv(\d{1,})$/
		dssv_a.push($2.to_i)
		valid_dssv_f = true
	end

	# sv
	if line_a[4] =~ /^dsv(\d{1,})-dsv(\d{1,})$/
		dsv_a.push($2.to_i)
		valid_dsv_f = true
	end

	valid_sv_f = true if valid_dssv_f && valid_dsv_f

	# file check
	if !valid_study_f
		raise "Invalid study."
	end

	if duplicated_f
		raise "Duplicated submission ID. Already assigned accessions?: #{submission_id}"
	end

	if valid_dss_f && (valid_dssv_f || valid_dsv_f)
		raise "Invalid: both dss and (dssv or dsv) exist."
	end

	if (valid_dssv_f && !valid_dsv_f) || (!valid_dssv_f && valid_dsv_f)
		raise "Invalid: only dssv or dsv exists."
	end

	if !valid_dss_f && !valid_sv_f
		raise "Invalid SNP and SV."
	end

end

last_f.close

## Next accession
dstd_start = 0
dss_start = 0
dssv_start = 0
dsv_start = 0

dstd_next = 0
dss_next = 0
dssv_next = 0
dsv_next = 0

if dstd_a.empty?
	dstd_next = 1
	dstd_start = 1
else 
	dstd_next = dstd_a.sort[-1] + 1
	dstd_start = dstd_a.sort[-1] + 1
end

if dss_a.empty?
	dss_next = 1
	dss_start = 1
else 
	dss_next = dss_a.sort[-1] + 1
	dss_start = dss_a.sort[-1] + 1
end

if dssv_a.empty?
	dssv_next = 1
	dssv_start = 1
else 
	dssv_next = dssv_a.sort[-1] + 1
	dssv_start = dssv_a.sort[-1] + 1
end

if dsv_a.empty?
	dsv_next = 1
	dsv_start = 1
else 
	dsv_next = dsv_a.sort[-1] + 1
	dsv_start = dsv_a.sort[-1] + 1
end

### Read the JVar submission excel file and output in tsv as JVar metadata files

# open xlsx file
begin
	s = Roo::Excelx.new("#{sub_path}/#{submission_id}/#{submission_id}_#{submission_type}.xlsx")
rescue
	raise "No such file to open."
end

# sheets
object_a = ['Study', 'SampleSet', 'Sample', 'Experiment', 'Dataset', 'Variant Call (SV)', 'Variant Region (SV)']

# array for metadata objects
study_sheet_a = Array.new
sampleset_sheet_a = Array.new
sample_sheet_a = Array.new
experiment_sheet_a = Array.new
dataset_sheet_a = Array.new
variant_call_sheet_a = Array.new
variant_region_sheet_a = Array.new

# open a sheet and put data into an array with line number
for object in object_a

	s.default_sheet = object

	for line_a in s

		# trailing nil を削除、文字列に変換、"" を削除、値を strip
		line_trimmed_a = line_a.reverse.drop_while(&:nil?).map(&:to_s).drop_while(&:empty?).reverse.map{|v| v.strip}

		# コメント行と空のアレイをスキップ
		next if line_trimmed_a[0] =~ /^##/ || line_trimmed_a.empty?

		case object

		when "Study" then
			study_sheet_a.push(line_trimmed_a)
		when "SampleSet" then
			sampleset_sheet_a.push(line_trimmed_a) if line_trimmed_a.size > 1
		when "Sample" then
			sample_sheet_a.push(line_trimmed_a) if line_trimmed_a.size > 1
		when "Experiment" then
			experiment_sheet_a.push(line_trimmed_a) if line_trimmed_a.size > 1
		when "Dataset" then
			if line_trimmed_a.size > 1
				vcf = ""
				if line_trimmed_a[-1] && !line_trimmed_a[-1].empty?
					vcf = "submitted/#{File.basename(line_trimmed_a[-1])}"
					line_trimmed_a[-1] = vcf
				end
				dataset_sheet_a.push(line_trimmed_a)
			end
		when "Variant Call (SV)" then
			variant_call_sheet_a.push(line_trimmed_a) if line_trimmed_a.size > 1
		when "Variant Region (SV)" then			
			variant_region_sheet_a.push(line_trimmed_a) if line_trimmed_a.size > 1
		end

	end

end

## metadata
acc_meta_f = open("#{sub_path}/#{submission_id}/dstd#{dstd_next}.meta.tsv", "w")

acc_meta_f.puts "## Study"
for line in study_sheet_a	
	acc_meta_f.puts line.join("\t")
end

acc_meta_f.puts ""
acc_meta_f.puts "## SampleSet"
for line in sampleset_sheet_a
	acc_meta_f.puts line.join("\t")
end

acc_meta_f.puts ""
acc_meta_f.puts "## Sample"
for line in sample_sheet_a
	acc_meta_f.puts line.join("\t")
end

acc_meta_f.puts ""
acc_meta_f.puts "## Experiment"
for line in experiment_sheet_a
	acc_meta_f.puts line.join("\t")
end

acc_meta_f.puts ""
acc_meta_f.puts "## Dataset"
for line in dataset_sheet_a
	acc_meta_f.puts line.join("\t")
end

acc_meta_f.close

now = Time.now.strftime('%Y-%m-%d_%H_%M')

## SNP VCF
if submission_type == "SNP"

	# dbSNP vcf without accessions
	vcf_a = Dir.glob("#{sub_path}/#{submission_id}/vcf/*vcf")
	`mkdir #{sub_path}/#{submission_id}/dbsnp_vcf`
	
	for vcf in vcf_a
		filename = File.basename(vcf)
		vcf_f = open(vcf)
		
		out_vcf_f = open("#{sub_path}/#{submission_id}/dbsnp_vcf/#{filename.sub(".vcf", "_dbsnp.vcf")}", "w")
		
		info_range = false
		vcf_f.each_line{|line|
			
			if line =~ /^#/
				info_range = true if line =~ /^##INFO=/

				if info_range && line !~ /^##INFO=/
					out_vcf_f.puts '##INFO=<ID=LOCALID,Number=1,Type=String,Description="Submitted local ID">'
					info_range = false
				end

				out_vcf_f.puts line

			else
				line_a = line.split("\t")				
				
				if line_a[7] && line_a[7].empty?
					line_a[7] = "LOCALID=#{line_a[2]}"
				else
					line_a[7] = "#{line_a[7]};LOCALID=#{line_a[2]}"
				end

				line_a[2] = "dss#{dss_next}"
				out_vcf_f.puts line_a.join("\t")

				dss_next += 1
			end
		}
	
		vcf_f.close
		out_vcf_f.close

	end # for vcf in vcf_a

	# record last number
	`cp "#{study_path}/last.txt" "#{study_path}/last_#{now}.txt"`

	last_out_f = open("#{study_path}/last.txt", "a"){|f|
		f.puts "dstd#{dstd_next}\t#{submission_id}\tdss#{dss_start}-dss#{dss_next}\t\t"
		puts "dstd#{dstd_next}\t#{submission_id}\tdss#{dss_start}-dss#{dss_next}\t\t"
	}
	
end # if submission_type == "SNP"

## Variant Call and Region tsv files
if submission_type == "SV"

	# Embed accession numbers to XML
	xml = Nokogiri::XML(open("#{sub_path}/#{submission_id}/#{submission_id}_dbvar.xml"))
	xml.css('SUBMISSION').each{|submission|
		
		# vload_id
		submission.attribute("vload_id").value = vload_id

		# study accession
		submission.css('STUDY').each{|study|
			study.attribute("study_accession").value = "dstd#{dstd_next}"
			study.delete("hold_date")
		}

		# Variant Call
		submission.css('VARIANT_CALL').each{|variant_call|
			variant_call.attribute("variant_call_accession").value = "dssv#{dssv_next}"
			dssv_next += 1
		}

		# Variant Region
		submission.css('VARIANT_REGION').each{|variant_region|
			variant_region.attribute("variant_region_accession").value = "dsv#{dsv_next}"
			dsv_next += 1
		}

	}

	# dbVar XML with accessions
	out_xml_f = open("#{sub_path}/#{submission_id}/dstd#{dstd_next}.dbvar.xml", "w")
	out_xml_f.puts xml
	out_xml_f.close

	## TSV
	# Variant Call
	if variant_call_sheet_a.size > 1
		variant_call_tsv_f = open("#{sub_path}/#{submission_id}/dstd#{dstd_next}.variant_call.tsv", "w")
		for line in variant_call_sheet_a		
			variant_call_tsv_f.puts line.join("\t")
		end
		variant_call_tsv_f.close
	end

	# Variant Region
	if variant_region_sheet_a.size > 1
		variant_region_tsv_f = open("#{sub_path}/#{submission_id}/dstd#{dstd_next}.variant_region.tsv", "w")
		for line in variant_region_sheet_a		
			variant_region_tsv_f.puts line.join("\t")
		end
		variant_region_tsv_f.close
	end

	# record last number
	
	`cp "#{study_path}/last.txt" "#{study_path}/last_#{now}.txt"`

	last_out_f = open("#{study_path}/last.txt", "a"){|f|		
		f.puts "dstd#{dstd_next}\t#{submission_id}\t\tdssv#{dssv_start}-dssv#{dssv_next}\tdsv#{dsv_start}-dsv#{dsv_next}"
		puts "dstd#{dstd_next}\t#{submission_id}\t\tdssv#{dssv_start}-dssv#{dssv_next}\tdsv#{dsv_start}-dsv#{dsv_next}"
	}

end # if submission_type == "SV"

## xsd validation
if FileTest.exist?("#{sub_path}/#{submission_id}/dstd#{dstd_next}.dbvar.xml")
	o, e, s = Open3.capture3("xmllint --schema dbVar.xsd --noout #{submission_id}_dbvar.xml")

	puts ""
	puts "dbVar xsd validation results"
	puts e
end

=begin
=end
