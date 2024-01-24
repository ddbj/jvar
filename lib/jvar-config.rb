#! /usr/bin/env ruby

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

# Configuration objects

# Update history
# 2023-07-25 created

$xref_db_h =
{
  :Archives => ["AE", "dbGaP", "dbSNP", "dbSNP-batch", "DDBJ", "DGV", "EGA", "ENA", "GENBANK", "GENE", "GEO", "SRA", "TRACE", "GEA", "JGA"],
  :Phenotypes => ["HP", "MedGen", "MeSH", "OMIM", "SNOMED", "UMLS"],
  :"Other Resources" => ["CORIELL", "BioProj", "BioSD", "PubMed", "GeneReviews"]
}

$vtype_h =
{
	:"Variant Call Type" =>
	{
		:"complex substitution" => "complex substitution",
		:"copy number gain" => "copy number gain",
		:"copy number loss" => "copy number loss",
		:"copy number variation" => "copy number variation",
		:deletion => "deletion",
		:"mobile element deletion" => "mobile element deletion",
		:"Alu deletion" => "alu deletion",
		:"LINE1 deletion" => "line1 deletion",
		:"SVA deletion" => "sva deletion",
		:"HERV deletion" => "herv deletion",
		:duplication => "duplication",
		:indel => "delins",
		:insertion => "insertion",
		:"interchromosomal translocation" => "interchromosomal translocation",
		:"intrachromosomal translocation" => "intrachromosomal translocation",
		:inversion => "inversion",
		:"mobile element insertion" => "mobile element insertion",
		:"Alu insertion" => "alu insertion",
		:"HERV insertion" => "herv insertion",
		:"LINE1 insertion" => "line1 insertion",
		:"SVA insertion" => "sva insertion",
		:"novel sequence insertion" => "novel sequence insertion",
		:"sequence alteration" => "sequence alteration",
		:"short tandem repeat variation" => "short tandem repeat",
		:"tandem duplication" => "tandem duplication"
	},
	:"Variant Region Type" =>
	{
		:"complex substitution" => "complex substitution",
		:"complex chromosomal rearrangement" => "complex chromosomal rearrangement",
		:"copy number variation" => "copy number variation",
		:indel => "delins",
		:insertion => "insertion",
		:inversion => "inversion",
		:"mobile element insertion" => "mobile element insertion",
		:"mobile element deletion" => "mobile element deletion",
		:"novel sequence insertion" => "novel sequence insertion",
		:"sequence alteration" => "sequence alteration",
		:"short tandem repeat variation" => "short tandem repeat",
		:"tandem duplication" => "tandem duplication",
		:translocation => "translocation"
	}
}

$vtype_so_h =
{
	:"Variant Call Type" =>
	{
		:"complex substitution" => "SO:1000005",
		:"copy number gain" => "SO:0001742",
		:"copy number loss" => "SO:0001743",
		:"copy number variation" => "SO:0001019",
		:deletion => "SO:0000159",
		:"mobile element deletion" => "SO:0002066",
		:"Alu deletion" => "SO:0002070",
		:"LINE1 deletion" => "SO:0002069",
		:"SVA deletion" => "SO:0002068",
		:"HERV deletion" => "SO:0002067",
		:duplication => "SO:0001742",
		:indel => "SO:1000032",
		:insertion => "SO:0000667",
		:"interchromosomal translocation" => "SO:0002060",
		:"intrachromosomal translocation" => "SO:0002061",
		:inversion => "SO:1000036",
		:"mobile element insertion" => "SO:0001837",
		:"Alu insertion" => "SO:0002063",
		:"HERV insertion" => "SO:0002187",
		:"LINE1 insertion" => "SO:0002064",
		:"SVA insertion" => "SO:0002065",
		:"novel sequence insertion" => "SO:0001838",
		:"sequence alteration" => "SO:0001059",
		:"short tandem repeat variation" => "SO:0002096",
		:"tandem duplication" => "SO:1000173"
	},
	:"Variant Region Type" =>
	{
		:"complex substitution" => "SO:1000005",
		:"complex chromosomal rearrangement" => "SO:0002062",
		:"copy number variation" => "SO:0001019",
		:indel => "SO:1000032",
		:insertion => "SO:0000667",
		:inversion => "SO:1000036",
		:"mobile element insertion" => "SO:0001837",
		:"mobile element deletion" => "SO:0002066",
		:"novel sequence insertion" => "SO:0001838",
		:"sequence alteration" => "SO:0001059",
		:"short tandem repeat variation" => "SO:0002096",
		:"tandem duplication" => "SO:1000173",
		:translocation => "SO:0000199"
	}
}

$inapp_method_analysis_types_a =
[
	{:"Method Type" => ["Sequencing"], :"Analysis Type" => ["de novo and local sequence assembly", "de novo sequence assembly", "Local sequence assembly", "One end anchored assembly", "Paired-end mapping", "Read depth", "Sequence alignment", "Split read mapping", "Genotyping", "Read depth and paired-end mapping", "Split read and paired-end mapping"]},
	{:"Method Type" => ["Digital array", "Gene expression array", "MAPH", "qPCR", "ROMA", "RT-PCR"], :"Analysis Type" => ["Probe signal intensity"]},
	{:"Method Type" => ["BAC aCGH", "MLPA", "Oligo aCGH"], :"Analysis Type" => ["Probe signal intensity", "Genotyping"]},
	{:"Method Type" => ["SNP array"], :"Analysis Type" => ["SNP genotyping analysis", "Probe signal intensity", "Other", "Genotyping"]},
	{:"Method Type" => ["Curated"], :"Analysis Type" => ["Curated", "Manual observation"]},
	{:"Method Type" => ["FISH", "Karyotyping"], :"Analysis Type" => ["Probe signal intensity", "Manual observation", "Other", "Genotyping"]},
	{:"Method Type" => ["Multiple complete digestion"], :"Analysis Type" => ["MCD analysis"]},
	{:"Method Type" => ["Optical mapping"], :"Analysis Type" => ["Optical mapping"]},
	{:"Method Type" => ["PCR"], :"Analysis Type" => ["Manual observation", "Other", "Genotyping"]},
	{:"Method Type" => ["Merging"], :"Analysis Type" => ["Merging"]},
	{:"Method Type" => ["MassSpec"], :"Analysis Type" => ["Other"]},
	{:"Method Type" => ["Southern", "Western"], :"Analysis Type" => ["Manual observation"]}
]

$required_fields_error_h =
{
	"Study" => ["Submission Type", "Submitter First Name", "Submitter Email", "Submitter Affiliation"],
	"Sample" => ["Subject ID"],
	"Experiment" => ["Experiment Type", "Method Type"],
	"Assay" => ["Experiment ID"],
	"Variant Call" => ["Variant Call ID"],
	"Variant Region" => ["Variant Region ID"]
}

$required_fields_error_ignore_h =
{
	"Study": ["Hold/Release", "Submitter Last Name", "Study Title", "Study Description", "Study Type", "BioProject Accession"],
	"SampleSet": ["SampleSet Size"],
	"Sample": ["BioSample Accession", "SampleSet ID"],
	"Experiment": ["Analysis Type", "Reference Type", "Reference Value", "Method Description", "Analysis Description"],
	"Assay": ["SampleSet ID", "Number of Chromosomes Sampled", "Assay Description"],
	"Variant Call": ["Variant Call Type", "Experiment ID", "SampleSet ID"],
	"Variant Region": ["Variant Region Type", "Assertion Method"]
}

$variant_region_call_type_h =
{
	:"copy number variation" => ["copy number gain", "copy number loss", "deletion", "duplication"],
	:"mobile element insertion" => ["alu insertion", "herv insertion", "line1 insertion", "sva insertion"],
	:"mobile element deletion" => ["alu deletion", "herv deletion", "line1 deletion", "sva deletion"],
	:"translocation" => ["interchromosomal translocation", "intrachromosomal translocation"],
	:"complex chromosomal rearrangement" => ["interchromosomal translocation", "intrachromosomal translocation"]
}

$variant_call_type_to_region_type_h =
{
	:"complex substitution" => "complex substitution",
	:"copy number gain" => "copy number variation",
	:"copy number loss" => "copy number variation",
	:"copy number variation" => "copy number variation",
	:deletion => "copy number variation",
	:duplication => "copy number variation",
	:indel => "indel",
	:insertion => "insertion",
	:inversion => "inversion",
	:"mobile element deletion" => "mobile element deletion",
	:"Alu deletion" => "mobile element deletion",
	:"HERV deletion" => "mobile element deletion",
	:"LINE1 deletion" => "mobile element deletion",
	:"SVA deletion" => "mobile element deletion",
	:"mobile element insertion" => "mobile element insertion",
	:"Alu insertion" => "mobile element insertion",
	:"HERV insertion" => "mobile element insertion",
	:"LINE1 insertion" => "mobile element insertion",
	:"SVA insertion" => "mobile element insertion",
	:"novel sequence insertion" => "novel sequence insertion",
	:"sequence alteration" => "sequence alteration",
	:"short tandem repeat variation" => "short tandem repeat variation",
	:"tandem duplication" => "tandem duplication"
}

$variant_call_field_a =
[
	"Variant Call ID",
	"Variant Call Type",
	"Experiment ID",
	"SampleSet ID",
	"Assembly",
	"Chr",
	"Contig",
	"Outer Start",
	"Start",
	"Inner Start",
	"Inner Stop",
	"Stop",
	"Outer Stop",
	"Insertion Length",
	"Allele Number",
	"Allele Count",
	"Allele Frequency",
	"Copy Number",
	"Description",
	"Validation",
	"Zygosity",
	"Origin",
	"Phenotype",
	"External Links",
	"Evidence",
	"Sequence",
	"Assembly for Translocation Breakpoint",
	"From Chr",
	"From Coord",
	"From Strand",
	"To Chr",
	"To Coord",
	"To Strand",
	"Mutation ID",
	"Mutation Order",
	"Mutation Molecule",
	"ciposleft",
	"ciposright",
	"ciendleft",
	"ciendright",
	"variant_sequence",
	"reference_copy_number",
	"submitted_genotype",
	"FORMAT"
]

$variant_region_field_a =
[
	"Variant Region ID",
	"Variant Region Type",
	"Assertion Method",
	"Assembly",
	"Chr",
	"Contig",
	"Outer Start",
	"Start",
	"Inner Start",
	"Inner Stop",
	"Stop",
	"Outer Stop",
	"Supporting Variant Call IDs",
	"Supporting Variant Region IDs",
	"Description",
	"Assembly for Translocation Breakpoint",
	"From Chr",
	"From Coord",
	"From Strand",
	"To Chr",
	"To Coord",
	"To Strand"
]

$cv_h =
{
	"Study": {
		"Study Type": ["Case-Control", "Case-Set", "Collection", "Control Set", "Somatic", "Tumor vs. Matched-Normal"]
	},
	"SampleSet": {
		"SampleSet Type": ["Case", "Control"],
		"SampleSet Sex": ["Female", "Male", "Unknown"]
	},
	"Sample": {
		"Subject Sex": ["Female", "Male", "Unknown"],
		"Subject Collection": ["1000 Genomes", "Autism", "CEPH", "HapMap", "HGDP", "NINDS", "OPGP", "PDR"],
		"Subject Age Units": ["Day", "Week", "Month", "Year", "GDay", "GWeek", "GMonth"]
	},
	"Experiment": {
		"Experiment Type": ["Discovery", "Genotyping", "Validation"],
		"Method Type": ["BAC aCGH", "Curated", "Digital array", "FISH", "Gene expression array", "Karyotyping", "MAPH", "MassSpec", "Merging", "Microsatellite genotyping", "MLPA", "Multiple complete digestion", "Oligo aCGH", "Optical mapping", "PCR", "qPCR", "ROMA", "RT-PCR", "Sequencing", "SNP array", "Southern", "Western"],
		"Analysis Type": ["BAC assembly", "Curated", "de novo and local sequence assembly", "de novo sequence assembly", "Genotyping", "Local sequence assembly", "Manual observation", "MCD analysis", "Merging", "One end anchored assembly", "Optical mapping", "Other", "Paired-end mapping", "Probe signal intensity", "Read depth", "Read depth and paired-end mapping", "Sequence alignment", "SNP genotyping analysis", "Split read and paired-end mapping", "Split read mapping"],
		"Reference Type": ["Assembly", "Control tissue", "Other", "Sampleset", "Sample"]
	},
	"Variant Call": {
		"Variant Call Type": ["complex substitution", "copy number gain", "copy number loss", "copy number variation", "deletion", "duplication", "indel", "insertion", "interchromosomal translocation", "intrachromosomal translocation", "inversion", "mobile element deletion", "alu deletion", "herv deletion", "line1 deletion", "sva deletion", "mobile element insertion", "alu insertion", "herv insertion", "line1 insertion", "sva insertion", "novel sequence insertion", "sequence alteration", "short tandem repeat variation", "tandem duplication"],
		"Zygosity": ["Hemizygous", "Heterozygous", "Homozygous"],
		"From Strand": ["+", "-", "not reported"],
		"To Strand": ["+", "-", "not reported"]
	},
	"Variant Region": {
		"Variant Region Type": ["complex substitution", "complex chromosomal rearrangement", "copy number variation", "indel", "insertion", "inversion", "mobile element deletion", "mobile element insertion", "novel sequence insertion", "sequence alteration", "short tandem repeat variation", "tandem duplication", "translocation"]
	}
}

$assembly_a =
[
	{:refseq_assembly => "GCF_000001405.40", :insdc_assembly => "GCA_000001405.29", :grch_version => "GRCh38.p14", :grch => "GRCh38", :ucsc => "hg38"},
	{:refseq_assembly => "GCF_000001405.39", :insdc_assembly => "GCA_000001405.28", :grch_version => "GRCh38.p13"},
	{:refseq_assembly => "GCF_000001405.38", :insdc_assembly => "GCA_000001405.27", :grch_version => "GRCh38.p12"},
	{:refseq_assembly => "GCF_000001405.37", :insdc_assembly => "GCA_000001405.26", :grch_version => "GRCh38.p11"},
	{:refseq_assembly => "GCF_000001405.36", :insdc_assembly => "GCA_000001405.25", :grch_version => "GRCh38.p10"},
	{:refseq_assembly => "GCF_000001405.35", :insdc_assembly => "GCA_000001405.24", :grch_version => "GRCh38.p9"},
	{:refseq_assembly => "GCF_000001405.34", :insdc_assembly => "GCA_000001405.23", :grch_version => "GRCh38.p8"},
	{:refseq_assembly => "GCF_000001405.33", :insdc_assembly => "GCA_000001405.22", :grch_version => "GRCh38.p7"},
	{:refseq_assembly => "GCF_000001405.32", :insdc_assembly => "GCA_000001405.21", :grch_version => "GRCh38.p6"},
	{:refseq_assembly => "GCF_000001405.31", :insdc_assembly => "GCA_000001405.20", :grch_version => "GRCh38.p5"},
	{:refseq_assembly => "GCF_000001405.30", :insdc_assembly => "GCA_000001405.19", :grch_version => "GRCh38.p4"},
	{:refseq_assembly => "GCF_000001405.29", :insdc_assembly => "GCA_000001405.18", :grch_version => "GRCh38.p3"},
	{:refseq_assembly => "GCF_000001405.28", :insdc_assembly => "GCA_000001405.17", :grch_version => "GRCh38.p2"},
	{:refseq_assembly => "GCF_000001405.27", :insdc_assembly => "GCA_000001405.16", :grch_version => "GRCh38.p1"},
	{:refseq_assembly => "GCF_000001405.25", :insdc_assembly => "GCA_000001405.14", :grch_version => "GRCh37.p13", :grch => "GRCh37", :ucsc => "hg19"}
]

$sequence_a = [
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "1","gcCount":"99389779","gcPercent":41.5, :genbankAccession => "CM000663.1", :length => 249250621, :refseqAccession => "NC_000001.10", :role => "assembled-molecule", :ucscStyleName => "chr1",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "2","gcCount":"99767935","gcPercent":40.0, :genbankAccession => "CM000664.1", :length => 243199373, :refseqAccession => "NC_000002.11", :role => "assembled-molecule", :ucscStyleName => "chr2"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "3","gcCount":"90281641","gcPercent":39.5, :genbankAccession => "CM000665.1", :length => 198022430, :refseqAccession => "NC_000003.11", :role => "assembled-molecule", :ucscStyleName => "chr3"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "4","gcCount":"76010384","gcPercent":38.0, :genbankAccession => "CM000666.1", :length => 191154276, :refseqAccession => "NC_000004.11", :role => "assembled-molecule", :ucscStyleName => "chr4",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "5","gcCount":"91886496","gcPercent":39.0, :genbankAccession => "CM000667.1", :length => 180915260, :refseqAccession => "NC_000005.9", :role => "assembled-molecule", :ucscStyleName => "chr5"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "6","gcCount":"67554661","gcPercent":39.5, :genbankAccession => "CM000668.1", :length => 171115067, :refseqAccession => "NC_000006.11", :role => "assembled-molecule", :ucscStyleName => "chr6"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "7","gcCount":"68479909","gcPercent":40.5, :genbankAccession => "CM000669.1", :length => 159138663, :refseqAccession => "NC_000007.13", :role => "assembled-molecule", :ucscStyleName => "chr7",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "8","gcCount":"74996653","gcPercent":40.0, :genbankAccession => "CM000670.1", :length => 146364022, :refseqAccession => "NC_000008.10", :role => "assembled-molecule", :ucscStyleName => "chr8",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "9","gcCount":"51899263","gcPercent":41.0, :genbankAccession => "CM000671.1", :length => 141213431, :refseqAccession => "NC_000009.11", :role => "assembled-molecule", :ucscStyleName => "chr9",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "10","gcCount":"57994424","gcPercent":41.5, :genbankAccession => "CM000672.1", :length => 135534747, :refseqAccession => "NC_000010.10", :role => "assembled-molecule", :ucscStyleName => "chr10"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "11","gcCount":"68290976","gcPercent":41.5, :genbankAccession => "CM000673.1", :length => 135006516, :refseqAccession => "NC_000011.9", :role => "assembled-molecule", :ucscStyleName => "chr11",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "12","gcCount":"56688274","gcPercent":40.5, :genbankAccession => "CM000674.1", :length => 133851895, :refseqAccession => "NC_000012.11", :role => "assembled-molecule", :ucscStyleName => "chr12"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "13","gcCount":"37502167","gcPercent":38.5, :genbankAccession => "CM000675.1", :length => 115169878, :refseqAccession => "NC_000013.10", :role => "assembled-molecule", :ucscStyleName => "chr13"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "14","gcCount":"44149094","gcPercent":40.5, :genbankAccession => "CM000676.1", :length => 107349540, :refseqAccession => "NC_000014.8", :role => "assembled-molecule", :ucscStyleName => "chr14"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "15","gcCount":"45102832","gcPercent":42.0, :genbankAccession => "CM000677.1", :length => 102531392, :refseqAccession => "NC_000015.9", :role => "assembled-molecule", :ucscStyleName => "chr15"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "16","gcCount":"46974148","gcPercent":44.5, :genbankAccession => "CM000678.1", :length => 90354753, :refseqAccession => "NC_000016.9", :role => "assembled-molecule", :ucscStyleName => "chr16"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "17","gcCount":"44185552","gcPercent":45.5, :genbankAccession => "CM000679.1", :length => 81195210, :refseqAccession => "NC_000017.10", :role => "assembled-molecule", :ucscStyleName => "chr17",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "18","gcCount":"38382018","gcPercent":39.5, :genbankAccession => "CM000680.1", :length => 78077248, :refseqAccession => "NC_000018.9", :role => "assembled-molecule", :ucscStyleName => "chr18",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "19","gcCount":"31223717","gcPercent":48.0, :genbankAccession => "CM000681.1", :length => 59128983, :refseqAccession => "NC_000019.9", :role => "assembled-molecule", :ucscStyleName => "chr19",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "20","gcCount":"26416102","gcPercent":44.0, :genbankAccession => "CM000682.1", :length => 63025520, :refseqAccession => "NC_000020.10", :role => "assembled-molecule", :ucscStyleName => "chr20"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "21","gcCount":"16672745","gcPercent":40.5, :genbankAccession => "CM000683.1", :length => 48129895, :refseqAccession => "NC_000021.8", :role => "assembled-molecule", :ucscStyleName => "chr21",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "22","gcCount":"18192559","gcPercent":48.0, :genbankAccession => "CM000684.1", :length => 51304566, :refseqAccession => "NC_000022.10", :role => "assembled-molecule", :ucscStyleName => "chr22"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "X","gcCount":"63349941","gcPercent":39.5, :genbankAccession => "CM000685.1", :length => 155270560, :refseqAccession => "NC_000023.10", :role => "assembled-molecule", :ucscStyleName => "chrX"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Y","gcCount":"10522473","gcPercent":39.5, :genbankAccession => "CM000686.1", :length => 59373566, :refseqAccession => "NC_000024.9", :role => "assembled-molecule", :ucscStyleName => "chrY"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "GL000191.1", :length => 106433, :refseqAccession => "NT_113878.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr1_gl000191_random",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "GL000192.1", :length => 547496, :refseqAccession => "NT_167207.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr1_gl000192_random",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "4", :genbankAccession => "GL000193.1", :length => 189789, :refseqAccession => "NT_113885.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr4_gl000193_random",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "4", :genbankAccession => "GL000194.1", :length => 191469, :refseqAccession => "NT_113888.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr4_gl000194_random",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "7", :genbankAccession => "GL000195.1", :length => 182896, :refseqAccession => "NT_113901.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr7_gl000195_random",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "8", :genbankAccession => "GL000196.1", :length => 38914, :refseqAccession => "NT_113909.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr8_gl000196_random",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "8", :genbankAccession => "GL000197.1", :length => 37175, :refseqAccession => "NT_113907.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr8_gl000197_random",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "9", :genbankAccession => "GL000198.1", :length => 90085, :refseqAccession => "NT_113914.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr9_gl000198_random",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "9", :genbankAccession => "GL000199.1", :length => 169874, :refseqAccession => "NT_113916.2", :role => "unlocalized-scaffold", :ucscStyleName => "chr9_gl000199_random",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "9", :genbankAccession => "GL000200.1", :length => 187035, :refseqAccession => "NT_113915.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr9_gl000200_random",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "9", :genbankAccession => "GL000201.1", :length => 36148, :refseqAccession => "NT_113911.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr9_gl000201_random",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "GL000202.1", :length => 40103, :refseqAccession => "NT_113921.2", :role => "unlocalized-scaffold", :ucscStyleName => "chr11_gl000202_random",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "GL000203.1", :length => 37498, :refseqAccession => "NT_113941.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr17_gl000203_random",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "GL000204.1", :length => 81310, :refseqAccession => "NT_113943.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr17_gl000204_random",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "GL000205.1", :length => 174588, :refseqAccession => "NT_113930.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr17_gl000205_random",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "GL000206.1", :length => 41001, :refseqAccession => "NT_113945.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr17_gl000206_random",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "18", :genbankAccession => "GL000207.1", :length => 4262, :refseqAccession => "NT_113947.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr18_gl000207_random",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "GL000208.1", :length => 92689, :refseqAccession => "NT_113948.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr19_gl000208_random",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "GL000209.1", :length => 159169, :refseqAccession => "NT_113949.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr19_gl000209_random",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "21", :genbankAccession => "GL000210.1", :length => 27682, :refseqAccession => "NT_113950.2", :role => "unlocalized-scaffold", :ucscStyleName => "chr21_gl000210_random",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000211.1", :length => 166566, :refseqAccession => "NT_113961.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_gl000211"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000212.1", :length => 186858, :refseqAccession => "NT_113923.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_gl000212"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000213.1", :length => 164239, :refseqAccession => "NT_167208.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_gl000213"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000214.1", :length => 137718, :refseqAccession => "NT_167209.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_gl000214"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000215.1", :length => 172545, :refseqAccession => "NT_167210.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_gl000215"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000216.1", :length => 172294, :refseqAccession => "NT_167211.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_gl000216"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000217.1", :length => 172149, :refseqAccession => "NT_167212.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_gl000217"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000218.1", :length => 161147, :refseqAccession => "NT_113889.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_gl000218"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000219.1", :length => 179198, :refseqAccession => "NT_167213.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_gl000219"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000220.1", :length => 161802, :refseqAccession => "NT_167214.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_gl000220"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000221.1", :length => 155397, :refseqAccession => "NT_167215.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_gl000221"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000222.1", :length => 186861, :refseqAccession => "NT_167216.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_gl000222"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000223.1", :length => 180455, :refseqAccession => "NT_167217.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_gl000223"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000224.1", :length => 179693, :refseqAccession => "NT_167218.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_gl000224"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000225.1", :length => 211173, :refseqAccession => "NT_167219.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_gl000225"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000226.1", :length => 15008, :refseqAccession => "NT_167220.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_gl000226"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000227.1", :length => 128374, :refseqAccession => "NT_167221.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_gl000227"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000228.1", :length => 129120, :refseqAccession => "NT_167222.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_gl000228"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000229.1", :length => 19913, :refseqAccession => "NT_167223.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_gl000229"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000230.1", :length => 43691, :refseqAccession => "NT_167224.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_gl000230"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000231.1", :length => 27386, :refseqAccession => "NT_167225.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_gl000231"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000232.1", :length => 40652, :refseqAccession => "NT_167226.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_gl000232"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000233.1", :length => 45941, :refseqAccession => "NT_167227.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_gl000233"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000234.1", :length => 40531, :refseqAccession => "NT_167228.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_gl000234"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000235.1", :length => 34474, :refseqAccession => "NT_167229.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_gl000235"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000236.1", :length => 41934, :refseqAccession => "NT_167230.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_gl000236"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000237.1", :length => 45867, :refseqAccession => "NT_167231.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_gl000237"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000238.1", :length => 39939, :refseqAccession => "NT_167232.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_gl000238"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000239.1", :length => 33824, :refseqAccession => "NT_167233.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_gl000239"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000240.1", :length => 41933, :refseqAccession => "NT_167234.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_gl000240"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000241.1", :length => 42152, :refseqAccession => "NT_167235.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_gl000241"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000242.1", :length => 43523, :refseqAccession => "NT_167236.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_gl000242"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000243.1", :length => 43341, :refseqAccession => "NT_167237.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_gl000243"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000244.1", :length => 39929, :refseqAccession => "NT_167238.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_gl000244"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000245.1", :length => 36651, :refseqAccession => "NT_167239.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_gl000245"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000246.1", :length => 38154, :refseqAccession => "NT_167240.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_gl000246"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000247.1", :length => 36422, :refseqAccession => "NT_167241.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_gl000247"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000248.1", :length => 39786, :refseqAccession => "NT_167242.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_gl000248"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000249.1", :length => 38502, :refseqAccession => "NT_167243.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_gl000249"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "GL383516.1", :length => 49316, :refseqAccession => "NW_003315903.1", :role => "fix-patch",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "GL383517.1", :length => 49352, :refseqAccession => "NW_003315904.1", :role => "fix-patch",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "GL949741.1", :length => 151551, :refseqAccession => "NW_003571030.1", :role => "fix-patch",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "JH636052.4", :length => 7283150, :refseqAccession => "NW_003871055.3", :role => "fix-patch",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "JH636053.3", :length => 1676126, :refseqAccession => "NW_003871056.3", :role => "fix-patch",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "JH636054.1", :length => 758378, :refseqAccession => "NW_003871057.1", :role => "fix-patch",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "JH806573.1", :length => 24680, :refseqAccession => "NW_004070863.1", :role => "fix-patch",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "JH806574.2", :length => 22982, :refseqAccession => "NW_004070864.2", :role => "fix-patch",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "JH806575.1", :length => 47409, :refseqAccession => "NW_004070865.1", :role => "fix-patch",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "GL383518.1", :length => 182439, :refseqAccession => "NW_003315905.1", :role => "novel-patch",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "GL383519.1", :length => 110268, :refseqAccession => "NW_003315906.1", :role => "novel-patch",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "GL383520.1", :length => 366579, :refseqAccession => "NW_003315907.1", :role => "novel-patch",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "2", :genbankAccession => "GL877870.2", :length => 66021, :refseqAccession => "NW_003571031.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "2", :genbankAccession => "GL877871.1", :length => 389939, :refseqAccession => "NW_003571032.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "2", :genbankAccession => "KB663603.1", :length => 599580, :refseqAccession => "NW_004504299.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "2", :genbankAccession => "GL383521.1", :length => 143390, :refseqAccession => "NW_003315908.1", :role => "novel-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "2", :genbankAccession => "GL383522.1", :length => 123821, :refseqAccession => "NW_003315909.1", :role => "novel-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "2", :genbankAccession => "GL582966.2", :length => 96131, :refseqAccession => "NW_003571033.2", :role => "novel-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "3", :genbankAccession => "GL383523.1", :length => 171362, :refseqAccession => "NW_003315910.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "3", :genbankAccession => "GL383524.1", :length => 78793, :refseqAccession => "NW_003315911.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "3", :genbankAccession => "GL383525.1", :length => 65063, :refseqAccession => "NW_003315912.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "3", :genbankAccession => "JH159131.1", :length => 393769, :refseqAccession => "NW_003871058.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "3", :genbankAccession => "JH159132.1", :length => 100694, :refseqAccession => "NW_003871059.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "3", :genbankAccession => "KE332495.1", :length => 263861, :refseqAccession => "NW_004775426.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "3", :genbankAccession => "GL383526.1", :length => 180671, :refseqAccession => "NW_003315913.1", :role => "novel-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "3", :genbankAccession => "JH636055.1", :length => 173151, :refseqAccession => "NW_003871060.1", :role => "novel-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "4", :genbankAccession => "GL582967.1", :length => 248177, :refseqAccession => "NW_003571035.1", :role => "fix-patch",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "4", :genbankAccession => "GL877872.1", :length => 297485, :refseqAccession => "NW_003571034.1", :role => "fix-patch",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "4", :genbankAccession => "KE332496.1", :length => 503215, :refseqAccession => "NW_004775427.1", :role => "fix-patch",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "4", :genbankAccession => "GL383527.1", :length => 164536, :refseqAccession => "NW_003315914.1", :role => "novel-patch",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "4", :genbankAccession => "GL383528.1", :length => 376187, :refseqAccession => "NW_003315915.1", :role => "novel-patch",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "4", :genbankAccession => "GL383529.1", :length => 121345, :refseqAccession => "NW_003315916.1", :role => "novel-patch",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "5", :genbankAccession => "JH159133.1", :length => 266316, :refseqAccession => "NW_003871061.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "5", :genbankAccession => "KE332497.1", :length => 543325, :refseqAccession => "NW_004775428.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "5", :genbankAccession => "GL339449.2", :length => 1612928, :refseqAccession => "NW_003315917.2", :role => "novel-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "5", :genbankAccession => "GL383530.1", :length => 101241, :refseqAccession => "NW_003315918.1", :role => "novel-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "5", :genbankAccession => "GL383531.1", :length => 173459, :refseqAccession => "NW_003315919.1", :role => "novel-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "5", :genbankAccession => "GL383532.1", :length => 82728, :refseqAccession => "NW_003315920.1", :role => "novel-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "5", :genbankAccession => "GL949742.1", :length => 226852, :refseqAccession => "NW_003571036.1", :role => "novel-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "6", :genbankAccession => "JH636056.1", :length => 262912, :refseqAccession => "NW_003871062.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "6", :genbankAccession => "JH636057.1", :length => 200195, :refseqAccession => "NW_003871063.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "6", :genbankAccession => "JH806576.1", :length => 273386, :refseqAccession => "NW_004070866.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "6", :genbankAccession => "KB663604.1", :length => 478993, :refseqAccession => "NW_004504300.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "6", :genbankAccession => "KE332498.1", :length => 149443, :refseqAccession => "NW_004775429.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "6", :genbankAccession => "GL383533.1", :length => 124736, :refseqAccession => "NW_003315921.1", :role => "novel-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "6", :genbankAccession => "KB021644.1", :length => 187824, :refseqAccession => "NW_004166862.1", :role => "novel-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "7", :genbankAccession => "GL582968.1", :length => 356330, :refseqAccession => "NW_003571037.1", :role => "fix-patch",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "7", :genbankAccession => "GL582969.1", :length => 251823, :refseqAccession => "NW_003571038.1", :role => "fix-patch",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "7", :genbankAccession => "GL582970.1", :length => 354970, :refseqAccession => "NW_003571039.1", :role => "fix-patch",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "7", :genbankAccession => "GL582971.1", :length => 1284284, :refseqAccession => "NW_003571040.1", :role => "fix-patch",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "7", :genbankAccession => "GL582972.1", :length => 327774, :refseqAccession => "NW_003571041.1", :role => "fix-patch",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "7", :genbankAccession => "JH159134.2", :length => 3821770, :refseqAccession => "NW_003871064.1", :role => "fix-patch",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "7", :genbankAccession => "JH636058.1", :length => 716227, :refseqAccession => "NW_003871065.1", :role => "fix-patch",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "7", :genbankAccession => "KE332499.1", :length => 274521, :refseqAccession => "NW_004775430.1", :role => "fix-patch",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "7", :genbankAccession => "GL383534.2", :length => 119183, :refseqAccession => "NW_003315922.2", :role => "novel-patch",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "8", :genbankAccession => "GL383535.1", :length => 429806, :refseqAccession => "NW_003315923.1", :role => "fix-patch",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "8", :genbankAccession => "GL383536.1", :length => 203777, :refseqAccession => "NW_003315924.1", :role => "fix-patch",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "8", :genbankAccession => "GL949743.1", :length => 608579, :refseqAccession => "NW_003571042.1", :role => "fix-patch",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "8", :genbankAccession => "JH159135.2", :length => 102251, :refseqAccession => "NW_003871066.2", :role => "fix-patch",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "8", :genbankAccession => "KE332500.1", :length => 228602, :refseqAccession => "NW_004775431.1", :role => "fix-patch",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "9", :genbankAccession => "GL339450.1", :length => 330164, :refseqAccession => "NW_003315925.1", :role => "fix-patch",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "9", :genbankAccession => "GL383537.1", :length => 62435, :refseqAccession => "NW_003315926.1", :role => "fix-patch",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "9", :genbankAccession => "GL383538.1", :length => 49281, :refseqAccession => "NW_003315927.1", :role => "fix-patch",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "9", :genbankAccession => "JH636059.1", :length => 295379, :refseqAccession => "NW_003871067.1", :role => "fix-patch",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "9", :genbankAccession => "JH806577.1", :length => 22394, :refseqAccession => "NW_004070867.1", :role => "fix-patch",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "9", :genbankAccession => "JH806578.1", :length => 169437, :refseqAccession => "NW_004070868.1", :role => "fix-patch",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "9", :genbankAccession => "JH806579.1", :length => 211307, :refseqAccession => "NW_004070869.1", :role => "fix-patch",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "9", :genbankAccession => "KB663605.1", :length => 155926, :refseqAccession => "NW_004504301.1", :role => "fix-patch",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "9", :genbankAccession => "GL383539.1", :length => 162988, :refseqAccession => "NW_003315928.1", :role => "novel-patch",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "9", :genbankAccession => "GL383540.1", :length => 71551, :refseqAccession => "NW_003315929.1", :role => "novel-patch",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "9", :genbankAccession => "GL383541.1", :length => 171286, :refseqAccession => "NW_003315930.1", :role => "novel-patch",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "9", :genbankAccession => "GL383542.1", :length => 60032, :refseqAccession => "NW_003315931.1", :role => "novel-patch",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "10", :genbankAccession => "GL383543.1", :length => 392792, :refseqAccession => "NW_003315932.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "10", :genbankAccession => "GL383544.1", :length => 128378, :refseqAccession => "NW_003315933.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "10", :genbankAccession => "GL877873.1", :length => 168465, :refseqAccession => "NW_003571043.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "10", :genbankAccession => "JH591181.2", :length => 2281126, :refseqAccession => "NW_003871068.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "10", :genbankAccession => "JH591182.1", :length => 196262, :refseqAccession => "NW_003871069.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "10", :genbankAccession => "JH591183.1", :length => 177920, :refseqAccession => "NW_003871070.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "10", :genbankAccession => "JH636060.1", :length => 437946, :refseqAccession => "NW_003871071.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "10", :genbankAccession => "JH806580.1", :length => 93149, :refseqAccession => "NW_004070870.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "10", :genbankAccession => "KB663606.1", :length => 305900, :refseqAccession => "NW_004504302.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "10", :genbankAccession => "KE332501.1", :length => 1020827, :refseqAccession => "NW_004775432.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "10", :genbankAccession => "GL383545.1", :length => 179254, :refseqAccession => "NW_003315934.1", :role => "novel-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "10", :genbankAccession => "GL383546.1", :length => 309802, :refseqAccession => "NW_003315935.1", :role => "novel-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "GL582973.1", :length => 321004, :refseqAccession => "NW_003571045.1", :role => "fix-patch",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "GL949744.1", :length => 276448, :refseqAccession => "NW_003571046.1", :role => "fix-patch",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "JH159138.1", :length => 108875, :refseqAccession => "NW_003871076.1", :role => "fix-patch",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "JH159139.1", :length => 120441, :refseqAccession => "NW_003871077.1", :role => "fix-patch",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "JH159140.1", :length => 546435, :refseqAccession => "NW_003871078.1", :role => "fix-patch",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "JH159141.2", :length => 240775, :refseqAccession => "NW_003871079.1", :role => "fix-patch",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "JH159142.2", :length => 326647, :refseqAccession => "NW_003871080.1", :role => "fix-patch",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "JH159143.1", :length => 191402, :refseqAccession => "NW_003871081.1", :role => "fix-patch",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "JH591184.1", :length => 462282, :refseqAccession => "NW_003871075.1", :role => "fix-patch",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "JH591185.1", :length => 167437, :refseqAccession => "NW_003871082.1", :role => "fix-patch",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "JH720443.2", :length => 408430, :refseqAccession => "NW_003871072.2", :role => "fix-patch",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "JH806581.1", :length => 872115, :refseqAccession => "NW_004070871.1", :role => "fix-patch",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "GL383547.1", :length => 154407, :refseqAccession => "NW_003315936.1", :role => "novel-patch",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "JH159136.1", :length => 200998, :refseqAccession => "NW_003871073.1", :role => "novel-patch",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "JH159137.1", :length => 191409, :refseqAccession => "NW_003871074.1", :role => "novel-patch",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "12", :genbankAccession => "GL383548.1", :length => 165247, :refseqAccession => "NW_003315937.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "12", :genbankAccession => "GL582974.1", :length => 163298, :refseqAccession => "NW_003571048.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "12", :genbankAccession => "JH720444.2", :length => 273128, :refseqAccession => "NW_003871083.2", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "12", :genbankAccession => "KB663607.2", :length => 334922, :refseqAccession => "NW_004504303.2", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "12", :genbankAccession => "GL383549.1", :length => 120804, :refseqAccession => "NW_003315938.1", :role => "novel-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "12", :genbankAccession => "GL383550.1", :length => 169178, :refseqAccession => "NW_003315939.1", :role => "novel-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "12", :genbankAccession => "GL383551.1", :length => 184319, :refseqAccession => "NW_003315940.1", :role => "novel-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "12", :genbankAccession => "GL383552.1", :length => 138655, :refseqAccession => "NW_003315941.1", :role => "novel-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "12", :genbankAccession => "GL383553.2", :length => 152874, :refseqAccession => "NW_003315942.2", :role => "novel-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "12", :genbankAccession => "GL877875.1", :length => 167313, :refseqAccession => "NW_003571049.1", :role => "novel-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "12", :genbankAccession => "GL877876.1", :length => 408271, :refseqAccession => "NW_003571050.1", :role => "novel-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "12", :genbankAccession => "GL949745.1", :length => 372609, :refseqAccession => "NW_003571047.1", :role => "novel-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "13", :genbankAccession => "GL582975.1", :length => 34662, :refseqAccession => "NW_003571051.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "14", :genbankAccession => "KB021645.1", :length => 1523386, :refseqAccession => "NW_004166863.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "15", :genbankAccession => "JH720445.1", :length => 170033, :refseqAccession => "NW_003871084.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "15", :genbankAccession => "GL383554.1", :length => 296527, :refseqAccession => "NW_003315943.1", :role => "novel-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "15", :genbankAccession => "GL383555.1", :length => 388773, :refseqAccession => "NW_003315944.1", :role => "novel-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "16", :genbankAccession => "JH720446.1", :length => 97345, :refseqAccession => "NW_003871085.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "16", :genbankAccession => "GL383556.1", :length => 192462, :refseqAccession => "NW_003315945.1", :role => "novel-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "16", :genbankAccession => "GL383557.1", :length => 89672, :refseqAccession => "NW_003315946.1", :role => "novel-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "GL383558.1", :length => 457041, :refseqAccession => "NW_003315947.1", :role => "fix-patch",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "GL383559.2", :length => 338640, :refseqAccession => "NW_003315948.2", :role => "fix-patch",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "GL383560.1", :length => 534288, :refseqAccession => "NW_003315949.1", :role => "fix-patch",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "GL383561.2", :length => 644425, :refseqAccession => "NW_003315950.2", :role => "fix-patch",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "GL383562.1", :length => 45551, :refseqAccession => "NW_003315951.1", :role => "fix-patch",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "GL582976.1", :length => 412535, :refseqAccession => "NW_003571052.1", :role => "fix-patch",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "JH159144.1", :length => 388340, :refseqAccession => "NW_003871088.1", :role => "fix-patch",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "JH159145.1", :length => 194862, :refseqAccession => "NW_003871090.1", :role => "fix-patch",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "JH591186.1", :length => 376223, :refseqAccession => "NW_003871089.1", :role => "fix-patch",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "JH636061.1", :length => 186059, :refseqAccession => "NW_003871087.1", :role => "fix-patch",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "JH720447.1", :length => 454385, :refseqAccession => "NW_003871086.1", :role => "fix-patch",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "JH806582.2", :length => 342635, :refseqAccession => "NW_004070872.2", :role => "fix-patch",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "KB021646.2", :length => 211416, :refseqAccession => "NW_004166864.2", :role => "fix-patch",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "KE332502.1", :length => 341712, :refseqAccession => "NW_004775433.1", :role => "fix-patch",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "GL383563.2", :length => 270261, :refseqAccession => "NW_003315952.2", :role => "novel-patch",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "GL383564.1", :length => 133151, :refseqAccession => "NW_003315953.1", :role => "novel-patch",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "GL383565.1", :length => 223995, :refseqAccession => "NW_003315954.1", :role => "novel-patch",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "GL383566.1", :length => 90219, :refseqAccession => "NW_003315955.1", :role => "novel-patch",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "JH159146.1", :length => 278131, :refseqAccession => "NW_003871091.1", :role => "novel-patch",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "JH159147.1", :length => 70345, :refseqAccession => "NW_003871092.1", :role => "novel-patch",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "JH159148.1", :length => 88070, :refseqAccession => "NW_003871093.1", :role => "novel-patch",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "18", :genbankAccession => "GL383567.1", :length => 289831, :refseqAccession => "NW_003315956.1", :role => "novel-patch",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "18", :genbankAccession => "GL383568.1", :length => 104552, :refseqAccession => "NW_003315957.1", :role => "novel-patch",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "18", :genbankAccession => "GL383569.1", :length => 167950, :refseqAccession => "NW_003315958.1", :role => "novel-patch",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "18", :genbankAccession => "GL383570.1", :length => 164789, :refseqAccession => "NW_003315959.1", :role => "novel-patch",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "18", :genbankAccession => "GL383571.1", :length => 198278, :refseqAccession => "NW_003315960.1", :role => "novel-patch",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "18", :genbankAccession => "GL383572.1", :length => 159547, :refseqAccession => "NW_003315961.1", :role => "novel-patch",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "GL582977.2", :length => 580393, :refseqAccession => "NW_003571053.2", :role => "fix-patch",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "JH159149.1", :length => 245473, :refseqAccession => "NW_003871094.1", :role => "fix-patch",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KB021647.1", :length => 1058686, :refseqAccession => "NW_004166865.1", :role => "fix-patch",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KE332505.1", :length => 579598, :refseqAccession => "NW_004775434.1", :role => "fix-patch",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "GL383573.1", :length => 385657, :refseqAccession => "NW_003315962.1", :role => "novel-patch",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "GL383574.1", :length => 155864, :refseqAccession => "NW_003315963.1", :role => "novel-patch",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "GL383575.2", :length => 170222, :refseqAccession => "NW_003315964.2", :role => "novel-patch",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "GL383576.1", :length => 188024, :refseqAccession => "NW_003315965.1", :role => "novel-patch",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "GL949746.1", :length => 987716, :refseqAccession => "NW_003571054.1", :role => "novel-patch",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "GL949747.1", :length => 729519, :refseqAccession => "NW_003571055.1", :role => "novel-patch",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "GL949748.1", :length => 1064303, :refseqAccession => "NW_003571056.1", :role => "novel-patch",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "GL949749.1", :length => 1091840, :refseqAccession => "NW_003571057.1", :role => "novel-patch",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "GL949750.1", :length => 1066389, :refseqAccession => "NW_003571058.1", :role => "novel-patch",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "GL949751.1", :length => 1002682, :refseqAccession => "NW_003571059.1", :role => "novel-patch",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "GL949752.1", :length => 987100, :refseqAccession => "NW_003571060.1", :role => "novel-patch",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "GL949753.1", :length => 796478, :refseqAccession => "NW_003571061.1", :role => "novel-patch",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "20", :genbankAccession => "GL582979.2", :length => 179899, :refseqAccession => "NW_003571063.2", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "20", :genbankAccession => "JH720448.1", :length => 70483, :refseqAccession => "NW_003871095.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "20", :genbankAccession => "KB663608.1", :length => 283551, :refseqAccession => "NW_004504304.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "20", :genbankAccession => "GL383577.1", :length => 128385, :refseqAccession => "NW_003315966.1", :role => "novel-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "21", :genbankAccession => "KE332506.1", :length => 307252, :refseqAccession => "NW_004775435.1", :role => "fix-patch",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "21", :genbankAccession => "GL383578.1", :length => 63917, :refseqAccession => "NW_003315967.1", :role => "novel-patch",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "21", :genbankAccession => "GL383579.1", :length => 201198, :refseqAccession => "NW_003315968.1", :role => "novel-patch",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "21", :genbankAccession => "GL383580.1", :length => 74652, :refseqAccession => "NW_003315969.1", :role => "novel-patch",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "21", :genbankAccession => "GL383581.1", :length => 116690, :refseqAccession => "NW_003315970.1", :role => "novel-patch",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "22", :genbankAccession => "JH720449.1", :length => 212298, :refseqAccession => "NW_003871096.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "22", :genbankAccession => "JH806583.1", :length => 167183, :refseqAccession => "NW_004070873.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "22", :genbankAccession => "JH806584.1", :length => 70876, :refseqAccession => "NW_004070874.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "22", :genbankAccession => "JH806585.1", :length => 73505, :refseqAccession => "NW_004070875.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "22", :genbankAccession => "JH806586.1", :length => 43543, :refseqAccession => "NW_004070876.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "22", :genbankAccession => "GL383582.2", :length => 162811, :refseqAccession => "NW_003315971.2", :role => "novel-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "22", :genbankAccession => "GL383583.1", :length => 96924, :refseqAccession => "NW_003315972.1", :role => "novel-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "22", :genbankAccession => "KB663609.1", :length => 74013, :refseqAccession => "NW_004504305.1", :role => "novel-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "X", :genbankAccession => "GL877877.2", :length => 284527, :refseqAccession => "NW_003571064.2", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "X", :genbankAccession => "JH159150.3", :length => 3110903, :refseqAccession => "NW_003871103.3", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "X", :genbankAccession => "JH720451.1", :length => 898979, :refseqAccession => "NW_003871098.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "X", :genbankAccession => "JH720452.1", :length => 522319, :refseqAccession => "NW_003871099.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "X", :genbankAccession => "JH720453.1", :length => 1461188, :refseqAccession => "NW_003871100.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "X", :genbankAccession => "JH720454.3", :length => 752267, :refseqAccession => "NW_003871101.3", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "X", :genbankAccession => "JH720455.1", :length => 65034, :refseqAccession => "NW_003871102.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "X", :genbankAccession => "JH806587.1", :length => 4110759, :refseqAccession => "NW_004070877.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "X", :genbankAccession => "JH806588.1", :length => 862483, :refseqAccession => "NW_004070878.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "X", :genbankAccession => "JH806589.1", :length => 270630, :refseqAccession => "NW_004070879.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "X", :genbankAccession => "JH806590.2", :length => 2418393, :refseqAccession => "NW_004070880.2", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "X", :genbankAccession => "JH806591.1", :length => 882083, :refseqAccession => "NW_004070881.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "X", :genbankAccession => "JH806592.1", :length => 835911, :refseqAccession => "NW_004070882.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "X", :genbankAccession => "JH806593.1", :length => 389631, :refseqAccession => "NW_004070883.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "X", :genbankAccession => "JH806594.1", :length => 390496, :refseqAccession => "NW_004070884.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "X", :genbankAccession => "JH806595.1", :length => 444074, :refseqAccession => "NW_004070885.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "X", :genbankAccession => "JH806596.1", :length => 413927, :refseqAccession => "NW_004070886.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "X", :genbankAccession => "JH806597.1", :length => 1045622, :refseqAccession => "NW_004070887.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "X", :genbankAccession => "JH806598.1", :length => 899320, :refseqAccession => "NW_004070888.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "X", :genbankAccession => "JH806599.1", :length => 1214327, :refseqAccession => "NW_004070889.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "X", :genbankAccession => "JH806600.2", :length => 6530008, :refseqAccession => "NW_004070890.2", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "X", :genbankAccession => "JH806601.1", :length => 1389764, :refseqAccession => "NW_004070891.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "X", :genbankAccession => "JH806602.1", :length => 713266, :refseqAccession => "NW_004070892.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "X", :genbankAccession => "JH806603.1", :length => 182949, :refseqAccession => "NW_004070893.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "X", :genbankAccession => "KB021648.1", :length => 469972, :refseqAccession => "NW_004166866.1", :role => "fix-patch"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "6", :genbankAccession => "GL000250.1", :length => 4622290, :refseqAccession => "NT_167244.1", :role => "alt-scaffold", :ucscStyleName => "chr6_apd_hap1"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "ALT_REF_LOCI_2", :assignedMoleculeLocationType => "Chromosome", :chrName => "6", :genbankAccession => "GL000251.1", :length => 4795371, :refseqAccession => "NT_113891.2", :role => "alt-scaffold", :ucscStyleName => "chr6_cox_hap2"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "ALT_REF_LOCI_3", :assignedMoleculeLocationType => "Chromosome", :chrName => "6", :genbankAccession => "GL000252.1", :length => 4610396, :refseqAccession => "NT_167245.1", :role => "alt-scaffold", :ucscStyleName => "chr6_dbb_hap3"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "ALT_REF_LOCI_4", :assignedMoleculeLocationType => "Chromosome", :chrName => "6", :genbankAccession => "GL000253.1", :length => 4683263, :refseqAccession => "NT_167246.1", :role => "alt-scaffold", :ucscStyleName => "chr6_mann_hap4"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "ALT_REF_LOCI_5", :assignedMoleculeLocationType => "Chromosome", :chrName => "6", :genbankAccession => "GL000254.1", :length => 4833398, :refseqAccession => "NT_167247.1", :role => "alt-scaffold", :ucscStyleName => "chr6_mcf_hap5"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "ALT_REF_LOCI_6", :assignedMoleculeLocationType => "Chromosome", :chrName => "6", :genbankAccession => "GL000255.1", :length => 4611984, :refseqAccession => "NT_167248.1", :role => "alt-scaffold", :ucscStyleName => "chr6_qbl_hap6"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "ALT_REF_LOCI_7", :assignedMoleculeLocationType => "Chromosome", :chrName => "6", :genbankAccession => "GL000256.1", :length => 4928567, :refseqAccession => "NT_167249.1", :role => "alt-scaffold", :ucscStyleName => "chr6_ssto_hap7"},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "ALT_REF_LOCI_8", :assignedMoleculeLocationType => "Chromosome", :chrName => "4", :genbankAccession => "GL000257.1", :length => 590426, :refseqAccession => "NT_167250.1", :role => "alt-scaffold", :ucscStyleName => "chr4_ctg9_hap1",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "ALT_REF_LOCI_9", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "GL000258.1", :length => 1680828, :refseqAccession => "NT_167251.1", :role => "alt-scaffold", :ucscStyleName => "chr17_ctg5_hap1",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.25", :assemblyUnit => "non-nuclear", :assignedMoleculeLocationType => "Mitochondrion", :chrName => "MT","gcCount":"7350","gcPercent":44.0, :genbankAccession => "J01415.2", :length => 16569, :refseqAccession => "NC_012920.1", :role => "assembled-molecule", :ucscStyleName => "chrM"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "1","gcCount":"103674491","gcPercent":41.5, :genbankAccession => "CM000663.2", :length => 248956422, :refseqAccession => "NC_000001.11", :role => "assembled-molecule", :ucscStyleName => "chr1",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "2","gcCount":"101284083","gcPercent":40.0, :genbankAccession => "CM000664.2", :length => 242193529, :refseqAccession => "NC_000002.12", :role => "assembled-molecule", :ucscStyleName => "chr2",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "3","gcCount":"91922884","gcPercent":39.5, :genbankAccession => "CM000665.2", :length => 198295559, :refseqAccession => "NC_000003.12", :role => "assembled-molecule", :ucscStyleName => "chr3",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "4","gcCount":"76972588","gcPercent":38.0, :genbankAccession => "CM000666.2", :length => 190214555, :refseqAccession => "NC_000004.12", :role => "assembled-molecule", :ucscStyleName => "chr4",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "5","gcCount":"93718374","gcPercent":39.0, :genbankAccession => "CM000667.2", :length => 181538259, :refseqAccession => "NC_000005.10", :role => "assembled-molecule", :ucscStyleName => "chr5",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "6","gcCount":"68907366","gcPercent":39.5, :genbankAccession => "CM000668.2", :length => 170805979, :refseqAccession => "NC_000006.12", :role => "assembled-molecule", :ucscStyleName => "chr6"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "7","gcCount":"70693857","gcPercent":40.5, :genbankAccession => "CM000669.2", :length => 159345973, :refseqAccession => "NC_000007.14", :role => "assembled-molecule", :ucscStyleName => "chr7"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "8","gcCount":"76166139","gcPercent":40.0, :genbankAccession => "CM000670.2", :length => 145138636, :refseqAccession => "NC_000008.11", :role => "assembled-molecule", :ucscStyleName => "chr8"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "9","gcCount":"52944769","gcPercent":41.0, :genbankAccession => "CM000671.2", :length => 138394717, :refseqAccession => "NC_000009.12", :role => "assembled-molecule", :ucscStyleName => "chr9",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "10","gcCount":"59342366","gcPercent":41.0, :genbankAccession => "CM000672.2", :length => 133797422, :refseqAccession => "NC_000010.11", :role => "assembled-molecule", :ucscStyleName => "chr10"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "11","gcCount":"70204082","gcPercent":41.5, :genbankAccession => "CM000673.2", :length => 135086622, :refseqAccession => "NC_000011.10", :role => "assembled-molecule", :ucscStyleName => "chr11"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "12","gcCount":"58038673","gcPercent":40.5, :genbankAccession => "CM000674.2", :length => 133275309, :refseqAccession => "NC_000012.12", :role => "assembled-molecule", :ucscStyleName => "chr12"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "13","gcCount":"38619357","gcPercent":38.5, :genbankAccession => "CM000675.2", :length => 114364328, :refseqAccession => "NC_000013.11", :role => "assembled-molecule", :ucscStyleName => "chr13"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "14","gcCount":"45815948","gcPercent":40.5, :genbankAccession => "CM000676.2", :length => 107043718, :refseqAccession => "NC_000014.9", :role => "assembled-molecule", :ucscStyleName => "chr14",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "15","gcCount":"46742416","gcPercent":42.0, :genbankAccession => "CM000677.2", :length => 101991189, :refseqAccession => "NC_000015.10", :role => "assembled-molecule", :ucscStyleName => "chr15",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "16","gcCount":"48251436","gcPercent":44.5, :genbankAccession => "CM000678.2", :length => 90338345, :refseqAccession => "NC_000016.10", :role => "assembled-molecule", :ucscStyleName => "chr16",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "17","gcCount":"46714680","gcPercent":45.0, :genbankAccession => "CM000679.2", :length => 83257441, :refseqAccession => "NC_000017.11", :role => "assembled-molecule", :ucscStyleName => "chr17",:unlocalizedCount => 3},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "18","gcCount":"40613699","gcPercent":39.5, :genbankAccession => "CM000680.2", :length => 80373285, :refseqAccession => "NC_000018.10", :role => "assembled-molecule", :ucscStyleName => "chr18"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "19","gcCount":"32693605","gcPercent":47.5, :genbankAccession => "CM000681.2", :length => 58617616, :refseqAccession => "NC_000019.10", :role => "assembled-molecule", :ucscStyleName => "chr19"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "20","gcCount":"28406612","gcPercent":43.5, :genbankAccession => "CM000682.2", :length => 64444167, :refseqAccession => "NC_000020.11", :role => "assembled-molecule", :ucscStyleName => "chr20"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "21","gcCount":"18981353","gcPercent":41.0, :genbankAccession => "CM000683.2", :length => 46709983, :refseqAccession => "NC_000021.9", :role => "assembled-molecule", :ucscStyleName => "chr21"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "22","gcCount":"20315771","gcPercent":47.0, :genbankAccession => "CM000684.2", :length => 50818468, :refseqAccession => "NC_000022.11", :role => "assembled-molecule", :ucscStyleName => "chr22",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "X","gcCount":"67807309","gcPercent":39.5, :genbankAccession => "CM000685.2", :length => 156040895, :refseqAccession => "NC_000023.11", :role => "assembled-molecule", :ucscStyleName => "chrX"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Y","gcCount":"10963787","gcPercent":40.0, :genbankAccession => "CM000686.2", :length => 57227415, :refseqAccession => "NC_000024.10", :role => "assembled-molecule", :ucscStyleName => "chrY",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "KI270706.1", :length => 175055, :refseqAccession => "NT_187361.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr1_KI270706v1_random",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "KI270707.1", :length => 32032, :refseqAccession => "NT_187362.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr1_KI270707v1_random",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "KI270708.1", :length => 127682, :refseqAccession => "NT_187363.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr1_KI270708v1_random",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "KI270709.1", :length => 66860, :refseqAccession => "NT_187364.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr1_KI270709v1_random",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "KI270710.1", :length => 40176, :refseqAccession => "NT_187365.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr1_KI270710v1_random",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "KI270711.1", :length => 42210, :refseqAccession => "NT_187366.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr1_KI270711v1_random",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "KI270712.1", :length => 176043, :refseqAccession => "NT_187367.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr1_KI270712v1_random",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "KI270713.1", :length => 40745, :refseqAccession => "NT_187368.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr1_KI270713v1_random",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "KI270714.1", :length => 41717, :refseqAccession => "NT_187369.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr1_KI270714v1_random",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "2", :genbankAccession => "KI270715.1", :length => 161471, :refseqAccession => "NT_187370.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr2_KI270715v1_random",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "2", :genbankAccession => "KI270716.1", :length => 153799, :refseqAccession => "NT_187371.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr2_KI270716v1_random",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "3", :genbankAccession => "GL000221.1", :length => 155397, :refseqAccession => "NT_167215.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr3_GL000221v1_random",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "4", :genbankAccession => "GL000008.2", :length => 209709, :refseqAccession => "NT_113793.3", :role => "unlocalized-scaffold", :ucscStyleName => "chr4_GL000008v2_random",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "5", :genbankAccession => "GL000208.1", :length => 92689, :refseqAccession => "NT_113948.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr5_GL000208v1_random",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "9", :genbankAccession => "KI270717.1", :length => 40062, :refseqAccession => "NT_187372.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr9_KI270717v1_random",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "9", :genbankAccession => "KI270718.1", :length => 38054, :refseqAccession => "NT_187373.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr9_KI270718v1_random",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "9", :genbankAccession => "KI270719.1", :length => 176845, :refseqAccession => "NT_187374.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr9_KI270719v1_random",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "9", :genbankAccession => "KI270720.1", :length => 39050, :refseqAccession => "NT_187375.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr9_KI270720v1_random",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "14", :genbankAccession => "GL000009.2", :length => 201709, :refseqAccession => "NT_113796.3", :role => "unlocalized-scaffold", :ucscStyleName => "chr14_GL000009v2_random",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "14", :genbankAccession => "GL000194.1", :length => 191469, :refseqAccession => "NT_113888.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr14_GL000194v1_random",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "14", :genbankAccession => "GL000225.1", :length => 211173, :refseqAccession => "NT_167219.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr14_GL000225v1_random",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "14", :genbankAccession => "KI270722.1", :length => 194050, :refseqAccession => "NT_187377.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr14_KI270722v1_random",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "14", :genbankAccession => "KI270723.1", :length => 38115, :refseqAccession => "NT_187378.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr14_KI270723v1_random",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "14", :genbankAccession => "KI270724.1", :length => 39555, :refseqAccession => "NT_187379.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr14_KI270724v1_random",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "14", :genbankAccession => "KI270725.1", :length => 172810, :refseqAccession => "NT_187380.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr14_KI270725v1_random",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "14", :genbankAccession => "KI270726.1", :length => 43739, :refseqAccession => "NT_187381.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr14_KI270726v1_random",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "15", :genbankAccession => "KI270727.1", :length => 448248, :refseqAccession => "NT_187382.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr15_KI270727v1_random",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "16", :genbankAccession => "KI270728.1", :length => 1872759, :refseqAccession => "NT_187383.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr16_KI270728v1_random",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "GL000205.2", :length => 185591, :refseqAccession => "NT_113930.2", :role => "unlocalized-scaffold", :ucscStyleName => "chr17_GL000205v2_random",:unlocalizedCount => 3},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "KI270729.1", :length => 280839, :refseqAccession => "NT_187384.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr17_KI270729v1_random",:unlocalizedCount => 3},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "KI270730.1", :length => 112551, :refseqAccession => "NT_187385.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr17_KI270730v1_random",:unlocalizedCount => 3},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "22", :genbankAccession => "KI270731.1", :length => 150754, :refseqAccession => "NT_187386.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr22_KI270731v1_random",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "22", :genbankAccession => "KI270732.1", :length => 41543, :refseqAccession => "NT_187387.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr22_KI270732v1_random",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "22", :genbankAccession => "KI270733.1", :length => 179772, :refseqAccession => "NT_187388.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr22_KI270733v1_random",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "22", :genbankAccession => "KI270735.1", :length => 42811, :refseqAccession => "NT_187390.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr22_KI270735v1_random",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "22", :genbankAccession => "KI270736.1", :length => 181920, :refseqAccession => "NT_187391.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr22_KI270736v1_random",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "22", :genbankAccession => "KI270737.1", :length => 103838, :refseqAccession => "NT_187392.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr22_KI270737v1_random",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "22", :genbankAccession => "KI270738.1", :length => 99375, :refseqAccession => "NT_187393.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr22_KI270738v1_random",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "22", :genbankAccession => "KI270739.1", :length => 73985, :refseqAccession => "NT_187394.1", :role => "unlocalized-scaffold", :ucscStyleName => "chr22_KI270739v1_random",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Y", :genbankAccession => "KI270740.1", :length => 37240, :refseqAccession => "NT_187395.1", :role => "unlocalized-scaffold", :ucscStyleName => "chrY_KI270740v1_random",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000195.1", :length => 182896, :refseqAccession => "NT_113901.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_GL000195v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000213.1", :length => 164239, :refseqAccession => "NT_167208.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_GL000213v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000214.1", :length => 137718, :refseqAccession => "NT_167209.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_GL000214v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000216.2", :length => 176608, :refseqAccession => "NT_167211.2", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_GL000216v2"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000218.1", :length => 161147, :refseqAccession => "NT_113889.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_GL000218v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000219.1", :length => 179198, :refseqAccession => "NT_167213.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_GL000219v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000220.1", :length => 161802, :refseqAccession => "NT_167214.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_GL000220v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000224.1", :length => 179693, :refseqAccession => "NT_167218.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_GL000224v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "GL000226.1", :length => 15008, :refseqAccession => "NT_167220.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_GL000226v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270302.1", :length => 2274, :refseqAccession => "NT_187396.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270302v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270303.1", :length => 1942, :refseqAccession => "NT_187398.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270303v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270304.1", :length => 2165, :refseqAccession => "NT_187397.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270304v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270305.1", :length => 1472, :refseqAccession => "NT_187399.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270305v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270310.1", :length => 1201, :refseqAccession => "NT_187402.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270310v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270311.1", :length => 12399, :refseqAccession => "NT_187406.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270311v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270312.1", :length => 998, :refseqAccession => "NT_187405.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270312v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270315.1", :length => 2276, :refseqAccession => "NT_187404.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270315v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270316.1", :length => 1444, :refseqAccession => "NT_187403.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270316v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270317.1", :length => 37690, :refseqAccession => "NT_187407.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270317v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270320.1", :length => 4416, :refseqAccession => "NT_187401.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270320v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270322.1", :length => 21476, :refseqAccession => "NT_187400.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270322v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270329.1", :length => 1040, :refseqAccession => "NT_187459.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270329v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270330.1", :length => 1652, :refseqAccession => "NT_187458.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270330v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270333.1", :length => 2699, :refseqAccession => "NT_187461.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270333v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270334.1", :length => 1368, :refseqAccession => "NT_187460.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270334v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270335.1", :length => 1048, :refseqAccession => "NT_187462.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270335v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270336.1", :length => 1026, :refseqAccession => "NT_187465.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270336v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270337.1", :length => 1121, :refseqAccession => "NT_187466.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270337v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270338.1", :length => 1428, :refseqAccession => "NT_187463.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270338v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270340.1", :length => 1428, :refseqAccession => "NT_187464.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270340v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270362.1", :length => 3530, :refseqAccession => "NT_187469.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270362v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270363.1", :length => 1803, :refseqAccession => "NT_187467.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270363v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270364.1", :length => 2855, :refseqAccession => "NT_187468.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270364v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270366.1", :length => 8320, :refseqAccession => "NT_187470.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270366v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270371.1", :length => 2805, :refseqAccession => "NT_187494.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270371v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270372.1", :length => 1650, :refseqAccession => "NT_187491.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270372v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270373.1", :length => 1451, :refseqAccession => "NT_187492.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270373v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270374.1", :length => 2656, :refseqAccession => "NT_187490.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270374v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270375.1", :length => 2378, :refseqAccession => "NT_187493.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270375v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270376.1", :length => 1136, :refseqAccession => "NT_187489.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270376v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270378.1", :length => 1048, :refseqAccession => "NT_187471.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270378v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270379.1", :length => 1045, :refseqAccession => "NT_187472.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270379v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270381.1", :length => 1930, :refseqAccession => "NT_187486.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270381v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270382.1", :length => 4215, :refseqAccession => "NT_187488.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270382v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270383.1", :length => 1750, :refseqAccession => "NT_187482.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270383v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270384.1", :length => 1658, :refseqAccession => "NT_187484.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270384v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270385.1", :length => 990, :refseqAccession => "NT_187487.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270385v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270386.1", :length => 1788, :refseqAccession => "NT_187480.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270386v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270387.1", :length => 1537, :refseqAccession => "NT_187475.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270387v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270388.1", :length => 1216, :refseqAccession => "NT_187478.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270388v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270389.1", :length => 1298, :refseqAccession => "NT_187473.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270389v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270390.1", :length => 2387, :refseqAccession => "NT_187474.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270390v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270391.1", :length => 1484, :refseqAccession => "NT_187481.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270391v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270392.1", :length => 971, :refseqAccession => "NT_187485.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270392v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270393.1", :length => 1308, :refseqAccession => "NT_187483.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270393v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270394.1", :length => 970, :refseqAccession => "NT_187479.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270394v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270395.1", :length => 1143, :refseqAccession => "NT_187476.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270395v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270396.1", :length => 1880, :refseqAccession => "NT_187477.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270396v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270411.1", :length => 2646, :refseqAccession => "NT_187409.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270411v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270412.1", :length => 1179, :refseqAccession => "NT_187408.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270412v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270414.1", :length => 2489, :refseqAccession => "NT_187410.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270414v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270417.1", :length => 2043, :refseqAccession => "NT_187415.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270417v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270418.1", :length => 2145, :refseqAccession => "NT_187412.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270418v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270419.1", :length => 1029, :refseqAccession => "NT_187411.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270419v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270420.1", :length => 2321, :refseqAccession => "NT_187413.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270420v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270422.1", :length => 1445, :refseqAccession => "NT_187416.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270422v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270423.1", :length => 981, :refseqAccession => "NT_187417.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270423v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270424.1", :length => 2140, :refseqAccession => "NT_187414.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270424v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270425.1", :length => 1884, :refseqAccession => "NT_187418.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270425v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270429.1", :length => 1361, :refseqAccession => "NT_187419.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270429v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270435.1", :length => 92983, :refseqAccession => "NT_187424.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270435v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270438.1", :length => 112505, :refseqAccession => "NT_187425.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270438v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270442.1", :length => 392061, :refseqAccession => "NT_187420.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270442v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270448.1", :length => 7992, :refseqAccession => "NT_187495.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270448v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270465.1", :length => 1774, :refseqAccession => "NT_187422.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270465v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270466.1", :length => 1233, :refseqAccession => "NT_187421.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270466v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270467.1", :length => 3920, :refseqAccession => "NT_187423.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270467v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270468.1", :length => 4055, :refseqAccession => "NT_187426.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270468v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270507.1", :length => 5353, :refseqAccession => "NT_187437.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270507v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270508.1", :length => 1951, :refseqAccession => "NT_187430.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270508v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270509.1", :length => 2318, :refseqAccession => "NT_187428.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270509v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270510.1", :length => 2415, :refseqAccession => "NT_187427.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270510v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270511.1", :length => 8127, :refseqAccession => "NT_187435.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270511v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270512.1", :length => 22689, :refseqAccession => "NT_187432.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270512v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270515.1", :length => 6361, :refseqAccession => "NT_187436.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270515v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270516.1", :length => 1300, :refseqAccession => "NT_187431.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270516v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270517.1", :length => 3253, :refseqAccession => "NT_187438.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270517v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270518.1", :length => 2186, :refseqAccession => "NT_187429.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270518v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270519.1", :length => 138126, :refseqAccession => "NT_187433.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270519v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270521.1", :length => 7642, :refseqAccession => "NT_187496.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270521v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270522.1", :length => 5674, :refseqAccession => "NT_187434.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270522v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270528.1", :length => 2983, :refseqAccession => "NT_187440.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270528v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270529.1", :length => 1899, :refseqAccession => "NT_187439.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270529v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270530.1", :length => 2168, :refseqAccession => "NT_187441.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270530v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270538.1", :length => 91309, :refseqAccession => "NT_187443.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270538v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270539.1", :length => 993, :refseqAccession => "NT_187442.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270539v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270544.1", :length => 1202, :refseqAccession => "NT_187444.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270544v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270548.1", :length => 1599, :refseqAccession => "NT_187445.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270548v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270579.1", :length => 31033, :refseqAccession => "NT_187450.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270579v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270580.1", :length => 1553, :refseqAccession => "NT_187448.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270580v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270581.1", :length => 7046, :refseqAccession => "NT_187449.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270581v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270582.1", :length => 6504, :refseqAccession => "NT_187454.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270582v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270583.1", :length => 1400, :refseqAccession => "NT_187446.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270583v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270584.1", :length => 4513, :refseqAccession => "NT_187453.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270584v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270587.1", :length => 2969, :refseqAccession => "NT_187447.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270587v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270588.1", :length => 6158, :refseqAccession => "NT_187455.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270588v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270589.1", :length => 44474, :refseqAccession => "NT_187451.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270589v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270590.1", :length => 4685, :refseqAccession => "NT_187452.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270590v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270591.1", :length => 5796, :refseqAccession => "NT_187457.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270591v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270593.1", :length => 3041, :refseqAccession => "NT_187456.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270593v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270741.1", :length => 157432, :refseqAccession => "NT_187497.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270741v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270742.1", :length => 186739, :refseqAccession => "NT_187513.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270742v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270743.1", :length => 210658, :refseqAccession => "NT_187498.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270743v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270744.1", :length => 168472, :refseqAccession => "NT_187499.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270744v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270745.1", :length => 41891, :refseqAccession => "NT_187500.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270745v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270746.1", :length => 66486, :refseqAccession => "NT_187501.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270746v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270747.1", :length => 198735, :refseqAccession => "NT_187502.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270747v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270748.1", :length => 93321, :refseqAccession => "NT_187503.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270748v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270749.1", :length => 158759, :refseqAccession => "NT_187504.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270749v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270750.1", :length => 148850, :refseqAccession => "NT_187505.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270750v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270751.1", :length => 150742, :refseqAccession => "NT_187506.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270751v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270753.1", :length => 62944, :refseqAccession => "NT_187508.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270753v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270754.1", :length => 40191, :refseqAccession => "NT_187509.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270754v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270755.1", :length => 36723, :refseqAccession => "NT_187510.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270755v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270756.1", :length => 79590, :refseqAccession => "NT_187511.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270756v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "Primary Assembly", :assignedMoleculeLocationType => "Chromosome", :chrName => "Un", :genbankAccession => "KI270757.1", :length => 71251, :refseqAccession => "NT_187512.1", :role => "unplaced-scaffold", :ucscStyleName => "chrUn_KI270757v1"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "KN196472.1", :length => 186494, :refseqAccession => "NW_009646194.1", :role => "fix-patch", :ucscStyleName => "chr1_KN196472v1_fix",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "KN196473.1", :length => 166200, :refseqAccession => "NW_009646195.1", :role => "fix-patch", :ucscStyleName => "chr1_KN196473v1_fix",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "KN196474.1", :length => 122022, :refseqAccession => "NW_009646196.1", :role => "fix-patch", :ucscStyleName => "chr1_KN196474v1_fix",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "KN538360.1", :length => 460100, :refseqAccession => "NW_011332687.1", :role => "fix-patch", :ucscStyleName => "chr1_KN538360v1_fix",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "KN538361.1", :length => 305542, :refseqAccession => "NW_011332688.1", :role => "fix-patch", :ucscStyleName => "chr1_KN538361v1_fix",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "KQ031383.1", :length => 467143, :refseqAccession => "NW_012132914.1", :role => "fix-patch", :ucscStyleName => "chr1_KQ031383v1_fix",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "KZ208906.1", :length => 330031, :refseqAccession => "NW_018654708.1", :role => "fix-patch", :ucscStyleName => "chr1_KZ208906v1_fix",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "KZ559100.1", :length => 44955, :refseqAccession => "NW_019805487.1", :role => "fix-patch", :ucscStyleName => "chr1_KZ559100v1_fix",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "MU273333.1", :length => 1572686, :refseqAccession => "NW_025791756.1", :role => "fix-patch", :ucscStyleName => "chr1_MU273333v1_fix",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "MU273334.1", :length => 210426, :refseqAccession => "NW_025791757.1", :role => "fix-patch", :ucscStyleName => "chr1_MU273334v1_fix",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "MU273335.1", :length => 211934, :refseqAccession => "NW_025791758.1", :role => "fix-patch", :ucscStyleName => "chr1_MU273335v1_fix",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "MU273336.1", :length => 250447, :refseqAccession => "NW_025791759.1", :role => "fix-patch", :ucscStyleName => "chr1_MU273336v1_fix",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "KQ458382.1", :length => 141019, :refseqAccession => "NW_014040925.1", :role => "novel-patch", :ucscStyleName => "chr1_KQ458382v1_alt",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "KQ458383.1", :length => 349938, :refseqAccession => "NW_014040926.1", :role => "novel-patch", :ucscStyleName => "chr1_KQ458383v1_alt",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "KQ458384.1", :length => 212205, :refseqAccession => "NW_014040927.1", :role => "novel-patch", :ucscStyleName => "chr1_KQ458384v1_alt",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "KQ983255.1", :length => 278659, :refseqAccession => "NW_015495298.1", :role => "novel-patch", :ucscStyleName => "chr1_KQ983255v1_alt",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "KV880763.1", :length => 551020, :refseqAccession => "NW_017852928.1", :role => "novel-patch", :ucscStyleName => "chr1_KV880763v1_alt",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "KZ208904.1", :length => 166136, :refseqAccession => "NW_018654706.1", :role => "novel-patch", :ucscStyleName => "chr1_KZ208904v1_alt",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "KZ208905.1", :length => 140355, :refseqAccession => "NW_018654707.1", :role => "novel-patch", :ucscStyleName => "chr1_KZ208905v1_alt",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "MU273330.1", :length => 516764, :refseqAccession => "NW_025791753.1", :role => "novel-patch", :ucscStyleName => "chr1_MU273330v1_alt",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "MU273331.1", :length => 847441, :refseqAccession => "NW_025791754.1", :role => "novel-patch", :ucscStyleName => "chr1_MU273331v1_alt",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "MU273332.1", :length => 335159, :refseqAccession => "NW_025791755.1", :role => "novel-patch", :ucscStyleName => "chr1_MU273332v1_alt",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "2", :genbankAccession => "KN538362.1", :length => 208149, :refseqAccession => "NW_011332689.1", :role => "fix-patch", :ucscStyleName => "chr2_KN538362v1_fix",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "2", :genbankAccession => "KN538363.1", :length => 365499, :refseqAccession => "NW_011332690.1", :role => "fix-patch", :ucscStyleName => "chr2_KN538363v1_fix",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "2", :genbankAccession => "KQ031384.1", :length => 481245, :refseqAccession => "NW_012132915.1", :role => "fix-patch", :ucscStyleName => "chr2_KQ031384v1_fix",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "2", :genbankAccession => "ML143341.1", :length => 145975, :refseqAccession => "NW_021159987.1", :role => "fix-patch", :ucscStyleName => "chr2_ML143341v1_fix",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "2", :genbankAccession => "ML143342.1", :length => 84043, :refseqAccession => "NW_021159988.1", :role => "fix-patch", :ucscStyleName => "chr2_ML143342v1_fix",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "2", :genbankAccession => "MU273341.1", :length => 120381, :refseqAccession => "NW_025791764.1", :role => "fix-patch", :ucscStyleName => "chr2_MU273341v1_fix",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "2", :genbankAccession => "MU273342.1", :length => 955087, :refseqAccession => "NW_025791765.1", :role => "fix-patch", :ucscStyleName => "chr2_MU273342v1_fix",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "2", :genbankAccession => "MU273343.1", :length => 489404, :refseqAccession => "NW_025791766.1", :role => "fix-patch", :ucscStyleName => "chr2_MU273343v1_fix",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "2", :genbankAccession => "MU273344.1", :length => 244725, :refseqAccession => "NW_025791767.1", :role => "fix-patch", :ucscStyleName => "chr2_MU273344v1_fix",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "2", :genbankAccession => "MU273345.1", :length => 174385, :refseqAccession => "NW_025791768.1", :role => "fix-patch", :ucscStyleName => "chr2_MU273345v1_fix",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "2", :genbankAccession => "KQ983256.1", :length => 535088, :refseqAccession => "NW_015495299.1", :role => "novel-patch", :ucscStyleName => "chr2_KQ983256v1_alt",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "2", :genbankAccession => "KZ208907.1", :length => 181658, :refseqAccession => "NW_018654709.1", :role => "novel-patch", :ucscStyleName => "chr2_KZ208907v1_alt",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "2", :genbankAccession => "KZ208908.1", :length => 140361, :refseqAccession => "NW_018654710.1", :role => "novel-patch", :ucscStyleName => "chr2_KZ208908v1_alt",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "2", :genbankAccession => "MU273337.1", :length => 431782, :refseqAccession => "NW_025791760.1", :role => "novel-patch", :ucscStyleName => "chr2_MU273337v1_alt",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "2", :genbankAccession => "MU273338.1", :length => 535251, :refseqAccession => "NW_025791761.1", :role => "novel-patch", :ucscStyleName => "chr2_MU273338v1_alt",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "2", :genbankAccession => "MU273339.1", :length => 500581, :refseqAccession => "NW_025791762.1", :role => "novel-patch", :ucscStyleName => "chr2_MU273339v1_alt",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "2", :genbankAccession => "MU273340.1", :length => 284971, :refseqAccession => "NW_025791763.1", :role => "novel-patch", :ucscStyleName => "chr2_MU273340v1_alt",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "3", :genbankAccession => "KN196475.1", :length => 451168, :refseqAccession => "NW_009646197.1", :role => "fix-patch", :ucscStyleName => "chr3_KN196475v1_fix",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "3", :genbankAccession => "KN196476.1", :length => 305979, :refseqAccession => "NW_009646198.1", :role => "fix-patch", :ucscStyleName => "chr3_KN196476v1_fix",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "3", :genbankAccession => "KN538364.1", :length => 415308, :refseqAccession => "NW_011332691.1", :role => "fix-patch", :ucscStyleName => "chr3_KN538364v1_fix",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "3", :genbankAccession => "KQ031385.1", :length => 373699, :refseqAccession => "NW_012132916.1", :role => "fix-patch", :ucscStyleName => "chr3_KQ031385v1_fix",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "3", :genbankAccession => "KQ031386.1", :length => 165718, :refseqAccession => "NW_012132917.1", :role => "fix-patch", :ucscStyleName => "chr3_KQ031386v1_fix",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "3", :genbankAccession => "KV766192.1", :length => 411654, :refseqAccession => "NW_017363813.1", :role => "fix-patch", :ucscStyleName => "chr3_KV766192v1_fix",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "3", :genbankAccession => "KZ559104.1", :length => 105527, :refseqAccession => "NW_019805491.1", :role => "fix-patch", :ucscStyleName => "chr3_KZ559104v1_fix",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "3", :genbankAccession => "MU273346.1", :length => 469342, :refseqAccession => "NW_025791769.1", :role => "fix-patch", :ucscStyleName => "chr3_MU273346v1_fix",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "3", :genbankAccession => "MU273347.1", :length => 301310, :refseqAccession => "NW_025791770.1", :role => "fix-patch", :ucscStyleName => "chr3_MU273347v1_fix",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "3", :genbankAccession => "MU273348.1", :length => 475876, :refseqAccession => "NW_025791771.1", :role => "fix-patch", :ucscStyleName => "chr3_MU273348v1_fix",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "3", :genbankAccession => "KZ208909.1", :length => 175849, :refseqAccession => "NW_018654711.1", :role => "novel-patch", :ucscStyleName => "chr3_KZ208909v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "3", :genbankAccession => "KZ559101.1", :length => 164041, :refseqAccession => "NW_019805488.1", :role => "novel-patch", :ucscStyleName => "chr3_KZ559101v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "3", :genbankAccession => "KZ559102.1", :length => 197752, :refseqAccession => "NW_019805489.1", :role => "novel-patch", :ucscStyleName => "chr3_KZ559102v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "3", :genbankAccession => "KZ559103.1", :length => 302885, :refseqAccession => "NW_019805490.1", :role => "novel-patch", :ucscStyleName => "chr3_KZ559103v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "3", :genbankAccession => "KZ559105.1", :length => 195063, :refseqAccession => "NW_019805492.1", :role => "novel-patch", :ucscStyleName => "chr3_KZ559105v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "3", :genbankAccession => "ML143343.1", :length => 215443, :refseqAccession => "NW_021159989.1", :role => "novel-patch", :ucscStyleName => "chr3_ML143343v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "4", :genbankAccession => "KQ983257.1", :length => 230434, :refseqAccession => "NW_015495300.1", :role => "fix-patch", :ucscStyleName => "chr4_KQ983257v1_fix",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "4", :genbankAccession => "ML143344.1", :length => 235734, :refseqAccession => "NW_021159990.1", :role => "fix-patch", :ucscStyleName => "chr4_ML143344v1_fix",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "4", :genbankAccession => "ML143345.1", :length => 341066, :refseqAccession => "NW_021159991.1", :role => "fix-patch", :ucscStyleName => "chr4_ML143345v1_fix",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "4", :genbankAccession => "ML143346.1", :length => 53476, :refseqAccession => "NW_021159992.1", :role => "fix-patch", :ucscStyleName => "chr4_ML143346v1_fix",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "4", :genbankAccession => "ML143347.1", :length => 176674, :refseqAccession => "NW_021159993.1", :role => "fix-patch", :ucscStyleName => "chr4_ML143347v1_fix",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "4", :genbankAccession => "ML143348.1", :length => 125549, :refseqAccession => "NW_021159994.1", :role => "fix-patch", :ucscStyleName => "chr4_ML143348v1_fix",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "4", :genbankAccession => "ML143349.1", :length => 276109, :refseqAccession => "NW_021159995.1", :role => "fix-patch", :ucscStyleName => "chr4_ML143349v1_fix",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "4", :genbankAccession => "MU273350.1", :length => 113364, :refseqAccession => "NW_025791773.1", :role => "fix-patch", :ucscStyleName => "chr4_MU273350v1_fix",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "4", :genbankAccession => "MU273351.1", :length => 205691, :refseqAccession => "NW_025791774.1", :role => "fix-patch", :ucscStyleName => "chr4_MU273351v1_fix",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "4", :genbankAccession => "KQ090013.1", :length => 90922, :refseqAccession => "NW_013171799.1", :role => "novel-patch", :ucscStyleName => "chr4_KQ090013v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "4", :genbankAccession => "KQ090014.1", :length => 163749, :refseqAccession => "NW_013171800.1", :role => "novel-patch", :ucscStyleName => "chr4_KQ090014v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "4", :genbankAccession => "KQ090015.1", :length => 236512, :refseqAccession => "NW_013171801.1", :role => "novel-patch", :ucscStyleName => "chr4_KQ090015v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "4", :genbankAccession => "KQ983258.1", :length => 205407, :refseqAccession => "NW_015495301.1", :role => "novel-patch", :ucscStyleName => "chr4_KQ983258v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "4", :genbankAccession => "KV766193.1", :length => 420675, :refseqAccession => "NW_017363814.1", :role => "novel-patch", :ucscStyleName => "chr4_KV766193v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "4", :genbankAccession => "MU273349.1", :length => 308682, :refseqAccession => "NW_025791772.1", :role => "novel-patch", :ucscStyleName => "chr4_MU273349v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "5", :genbankAccession => "KV575244.1", :length => 673059, :refseqAccession => "NW_016107298.1", :role => "fix-patch", :ucscStyleName => "chr5_KV575244v1_fix",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "5", :genbankAccession => "ML143350.1", :length => 89956, :refseqAccession => "NW_021159996.1", :role => "fix-patch", :ucscStyleName => "chr5_ML143350v1_fix",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "5", :genbankAccession => "MU273352.1", :length => 34400, :refseqAccession => "NW_025791775.1", :role => "fix-patch", :ucscStyleName => "chr5_MU273352v1_fix",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "5", :genbankAccession => "MU273353.1", :length => 208405, :refseqAccession => "NW_025791776.1", :role => "fix-patch", :ucscStyleName => "chr5_MU273353v1_fix",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "5", :genbankAccession => "MU273354.1", :length => 2101585, :refseqAccession => "NW_025791777.1", :role => "fix-patch", :ucscStyleName => "chr5_MU273354v1_fix",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "5", :genbankAccession => "MU273355.1", :length => 508332, :refseqAccession => "NW_025791778.1", :role => "fix-patch", :ucscStyleName => "chr5_MU273355v1_fix",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "5", :genbankAccession => "KN196477.1", :length => 139087, :refseqAccession => "NW_009646199.1", :role => "novel-patch", :ucscStyleName => "chr5_KN196477v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "5", :genbankAccession => "KV575243.1", :length => 362221, :refseqAccession => "NW_016107297.1", :role => "novel-patch", :ucscStyleName => "chr5_KV575243v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "5", :genbankAccession => "KZ208910.1", :length => 135987, :refseqAccession => "NW_018654712.1", :role => "novel-patch", :ucscStyleName => "chr5_KZ208910v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "5", :genbankAccession => "MU273356.1", :length => 302485, :refseqAccession => "NW_025791779.1", :role => "novel-patch", :ucscStyleName => "chr5_MU273356v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "6", :genbankAccession => "KN196478.1", :length => 268330, :refseqAccession => "NW_009646200.1", :role => "fix-patch", :ucscStyleName => "chr6_KN196478v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "6", :genbankAccession => "KQ031387.1", :length => 320750, :refseqAccession => "NW_012132918.1", :role => "fix-patch", :ucscStyleName => "chr6_KQ031387v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "6", :genbankAccession => "KQ090016.1", :length => 245716, :refseqAccession => "NW_013171802.1", :role => "fix-patch", :ucscStyleName => "chr6_KQ090016v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "6", :genbankAccession => "KV766194.1", :length => 139427, :refseqAccession => "NW_017363815.1", :role => "fix-patch", :ucscStyleName => "chr6_KV766194v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "6", :genbankAccession => "KZ208911.1", :length => 242796, :refseqAccession => "NW_018654713.1", :role => "fix-patch", :ucscStyleName => "chr6_KZ208911v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "6", :genbankAccession => "ML143351.1", :length => 73265, :refseqAccession => "NW_021159997.1", :role => "fix-patch", :ucscStyleName => "chr6_ML143351v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "6", :genbankAccession => "KQ090017.1", :length => 82315, :refseqAccession => "NW_013171803.1", :role => "novel-patch", :ucscStyleName => "chr6_KQ090017v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "6", :genbankAccession => "MU273357.1", :length => 383128, :refseqAccession => "NW_025791780.1", :role => "novel-patch", :ucscStyleName => "chr6_MU273357v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "7", :genbankAccession => "KQ031388.1", :length => 179932, :refseqAccession => "NW_012132919.1", :role => "fix-patch", :ucscStyleName => "chr7_KQ031388v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "7", :genbankAccession => "KV880764.1", :length => 142129, :refseqAccession => "NW_017852929.1", :role => "fix-patch", :ucscStyleName => "chr7_KV880764v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "7", :genbankAccession => "KV880765.1", :length => 468267, :refseqAccession => "NW_017852930.1", :role => "fix-patch", :ucscStyleName => "chr7_KV880765v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "7", :genbankAccession => "KZ208912.1", :length => 589656, :refseqAccession => "NW_018654714.1", :role => "fix-patch", :ucscStyleName => "chr7_KZ208912v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "7", :genbankAccession => "ML143352.1", :length => 254759, :refseqAccession => "NW_021159998.1", :role => "fix-patch", :ucscStyleName => "chr7_ML143352v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "7", :genbankAccession => "KZ208913.1", :length => 680662, :refseqAccession => "NW_018654715.1", :role => "novel-patch", :ucscStyleName => "chr7_KZ208913v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "7", :genbankAccession => "KZ559106.1", :length => 172555, :refseqAccession => "NW_019805493.1", :role => "novel-patch", :ucscStyleName => "chr7_KZ559106v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "7", :genbankAccession => "MU273358.1", :length => 464417, :refseqAccession => "NW_025791781.1", :role => "novel-patch", :ucscStyleName => "chr7_MU273358v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "8", :genbankAccession => "KV880766.1", :length => 156998, :refseqAccession => "NW_017852931.1", :role => "fix-patch", :ucscStyleName => "chr8_KV880766v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "8", :genbankAccession => "KV880767.1", :length => 265876, :refseqAccession => "NW_017852932.1", :role => "fix-patch", :ucscStyleName => "chr8_KV880767v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "8", :genbankAccession => "KZ208914.1", :length => 165120, :refseqAccession => "NW_018654716.1", :role => "fix-patch", :ucscStyleName => "chr8_KZ208914v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "8", :genbankAccession => "KZ208915.1", :length => 6367528, :refseqAccession => "NW_018654717.1", :role => "fix-patch", :ucscStyleName => "chr8_KZ208915v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "8", :genbankAccession => "MU273359.1", :length => 150302, :refseqAccession => "NW_025791782.1", :role => "fix-patch", :ucscStyleName => "chr8_MU273359v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "8", :genbankAccession => "MU273360.1", :length => 39290, :refseqAccession => "NW_025791783.1", :role => "fix-patch", :ucscStyleName => "chr8_MU273360v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "8", :genbankAccession => "MU273361.1", :length => 106905, :refseqAccession => "NW_025791784.1", :role => "fix-patch", :ucscStyleName => "chr8_MU273361v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "8", :genbankAccession => "MU273362.1", :length => 429744, :refseqAccession => "NW_025791785.1", :role => "fix-patch", :ucscStyleName => "chr8_MU273362v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "8", :genbankAccession => "MU273363.1", :length => 207371, :refseqAccession => "NW_025791786.1", :role => "fix-patch", :ucscStyleName => "chr8_MU273363v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "8", :genbankAccession => "KZ559107.1", :length => 103072, :refseqAccession => "NW_019805494.1", :role => "novel-patch", :ucscStyleName => "chr8_KZ559107v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "9", :genbankAccession => "KN196479.1", :length => 330164, :refseqAccession => "NW_009646201.1", :role => "fix-patch", :ucscStyleName => "chr9_KN196479v1_fix",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "9", :genbankAccession => "ML143353.1", :length => 25408, :refseqAccession => "NW_021159999.1", :role => "fix-patch", :ucscStyleName => "chr9_ML143353v1_fix",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "9", :genbankAccession => "MU273364.1", :length => 340717, :refseqAccession => "NW_025791787.1", :role => "fix-patch", :ucscStyleName => "chr9_MU273364v1_fix",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "9", :genbankAccession => "MU273365.1", :length => 482250, :refseqAccession => "NW_025791788.1", :role => "fix-patch", :ucscStyleName => "chr9_MU273365v1_fix",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "9", :genbankAccession => "MU273366.1", :length => 569668, :refseqAccession => "NW_025791789.1", :role => "fix-patch", :ucscStyleName => "chr9_MU273366v1_fix",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "9", :genbankAccession => "KQ090018.1", :length => 163882, :refseqAccession => "NW_013171804.1", :role => "novel-patch", :ucscStyleName => "chr9_KQ090018v1_alt",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "9", :genbankAccession => "KQ090019.1", :length => 134099, :refseqAccession => "NW_013171805.1", :role => "novel-patch", :ucscStyleName => "chr9_KQ090019v1_alt",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "10", :genbankAccession => "KN196480.1", :length => 277797, :refseqAccession => "NW_009646202.1", :role => "fix-patch", :ucscStyleName => "chr10_KN196480v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "10", :genbankAccession => "KN538365.1", :length => 14347, :refseqAccession => "NW_011332692.1", :role => "fix-patch", :ucscStyleName => "chr10_KN538365v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "10", :genbankAccession => "KN538366.1", :length => 85284, :refseqAccession => "NW_011332693.1", :role => "fix-patch", :ucscStyleName => "chr10_KN538366v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "10", :genbankAccession => "KN538367.1", :length => 420164, :refseqAccession => "NW_011332694.1", :role => "fix-patch", :ucscStyleName => "chr10_KN538367v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "10", :genbankAccession => "KQ090021.1", :length => 264545, :refseqAccession => "NW_013171807.1", :role => "fix-patch", :ucscStyleName => "chr10_KQ090021v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "10", :genbankAccession => "ML143354.1", :length => 454963, :refseqAccession => "NW_021160000.1", :role => "fix-patch", :ucscStyleName => "chr10_ML143354v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "10", :genbankAccession => "ML143355.1", :length => 292944, :refseqAccession => "NW_021160001.1", :role => "fix-patch", :ucscStyleName => "chr10_ML143355v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "10", :genbankAccession => "MU273367.1", :length => 196262, :refseqAccession => "NW_025791790.1", :role => "fix-patch", :ucscStyleName => "chr10_MU273367v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "10", :genbankAccession => "KQ090020.1", :length => 185507, :refseqAccession => "NW_013171806.1", :role => "novel-patch", :ucscStyleName => "chr10_KQ090020v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "KN196481.1", :length => 108875, :refseqAccession => "NW_009646203.1", :role => "fix-patch", :ucscStyleName => "chr11_KN196481v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "KQ090022.1", :length => 181958, :refseqAccession => "NW_013171808.1", :role => "fix-patch", :ucscStyleName => "chr11_KQ090022v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "KQ759759.2", :length => 204999, :refseqAccession => "NW_015148966.2", :role => "fix-patch", :ucscStyleName => "chr11_KQ759759v2_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "KV766195.1", :length => 140877, :refseqAccession => "NW_017363816.1", :role => "fix-patch", :ucscStyleName => "chr11_KV766195v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "KZ559108.1", :length => 305244, :refseqAccession => "NW_019805495.1", :role => "fix-patch", :ucscStyleName => "chr11_KZ559108v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "KZ559109.1", :length => 279644, :refseqAccession => "NW_019805496.1", :role => "fix-patch", :ucscStyleName => "chr11_KZ559109v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "ML143356.1", :length => 45257, :refseqAccession => "NW_021160002.1", :role => "fix-patch", :ucscStyleName => "chr11_ML143356v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "ML143357.1", :length => 165419, :refseqAccession => "NW_021160003.1", :role => "fix-patch", :ucscStyleName => "chr11_ML143357v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "ML143358.1", :length => 270122, :refseqAccession => "NW_021160004.1", :role => "fix-patch", :ucscStyleName => "chr11_ML143358v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "ML143359.1", :length => 217075, :refseqAccession => "NW_021160005.1", :role => "fix-patch", :ucscStyleName => "chr11_ML143359v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "ML143360.1", :length => 170928, :refseqAccession => "NW_021160006.1", :role => "fix-patch", :ucscStyleName => "chr11_ML143360v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "MU273369.1", :length => 434831, :refseqAccession => "NW_025791792.1", :role => "fix-patch", :ucscStyleName => "chr11_MU273369v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "MU273370.1", :length => 344606, :refseqAccession => "NW_025791793.1", :role => "fix-patch", :ucscStyleName => "chr11_MU273370v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "MU273371.1", :length => 122722, :refseqAccession => "NW_025791794.1", :role => "fix-patch", :ucscStyleName => "chr11_MU273371v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "KN538368.1", :length => 203552, :refseqAccession => "NW_011332695.1", :role => "novel-patch", :ucscStyleName => "chr11_KN538368v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "KZ559110.1", :length => 301637, :refseqAccession => "NW_019805497.1", :role => "novel-patch", :ucscStyleName => "chr11_KZ559110v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "KZ559111.1", :length => 181167, :refseqAccession => "NW_019805498.1", :role => "novel-patch", :ucscStyleName => "chr11_KZ559111v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "MU273368.1", :length => 261194, :refseqAccession => "NW_025791791.1", :role => "novel-patch", :ucscStyleName => "chr11_MU273368v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "12", :genbankAccession => "KN196482.1", :length => 211377, :refseqAccession => "NW_009646204.1", :role => "fix-patch", :ucscStyleName => "chr12_KN196482v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "12", :genbankAccession => "KN538369.1", :length => 541038, :refseqAccession => "NW_011332696.1", :role => "fix-patch", :ucscStyleName => "chr12_KN538369v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "12", :genbankAccession => "KN538370.1", :length => 86533, :refseqAccession => "NW_011332697.1", :role => "fix-patch", :ucscStyleName => "chr12_KN538370v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "12", :genbankAccession => "KQ759760.1", :length => 315610, :refseqAccession => "NW_015148967.1", :role => "fix-patch", :ucscStyleName => "chr12_KQ759760v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "12", :genbankAccession => "KZ208916.1", :length => 1046838, :refseqAccession => "NW_018654718.1", :role => "fix-patch", :ucscStyleName => "chr12_KZ208916v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "12", :genbankAccession => "KZ208917.1", :length => 64689, :refseqAccession => "NW_018654719.1", :role => "fix-patch", :ucscStyleName => "chr12_KZ208917v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "12", :genbankAccession => "ML143361.1", :length => 297568, :refseqAccession => "NW_021160007.1", :role => "fix-patch", :ucscStyleName => "chr12_ML143361v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "12", :genbankAccession => "ML143362.1", :length => 192531, :refseqAccession => "NW_021160008.1", :role => "fix-patch", :ucscStyleName => "chr12_ML143362v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "12", :genbankAccession => "MU273372.1", :length => 104537, :refseqAccession => "NW_025791795.1", :role => "fix-patch", :ucscStyleName => "chr12_MU273372v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "12", :genbankAccession => "KQ090023.1", :length => 109323, :refseqAccession => "NW_013171809.1", :role => "novel-patch", :ucscStyleName => "chr12_KQ090023v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "12", :genbankAccession => "KZ208918.1", :length => 174808, :refseqAccession => "NW_018654720.1", :role => "novel-patch", :ucscStyleName => "chr12_KZ208918v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "12", :genbankAccession => "KZ559112.1", :length => 154139, :refseqAccession => "NW_019805499.1", :role => "novel-patch", :ucscStyleName => "chr12_KZ559112v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "13", :genbankAccession => "KN196483.1", :length => 35455, :refseqAccession => "NW_009646205.1", :role => "fix-patch", :ucscStyleName => "chr13_KN196483v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "13", :genbankAccession => "KN538371.1", :length => 206320, :refseqAccession => "NW_011332698.1", :role => "fix-patch", :ucscStyleName => "chr13_KN538371v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "13", :genbankAccession => "KN538372.1", :length => 356766, :refseqAccession => "NW_011332699.1", :role => "fix-patch", :ucscStyleName => "chr13_KN538372v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "13", :genbankAccession => "KN538373.1", :length => 148762, :refseqAccession => "NW_011332700.1", :role => "fix-patch", :ucscStyleName => "chr13_KN538373v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "13", :genbankAccession => "ML143363.1", :length => 7309, :refseqAccession => "NW_021160009.1", :role => "fix-patch", :ucscStyleName => "chr13_ML143363v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "13", :genbankAccession => "ML143364.1", :length => 158944, :refseqAccession => "NW_021160010.1", :role => "fix-patch", :ucscStyleName => "chr13_ML143364v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "13", :genbankAccession => "ML143365.1", :length => 65394, :refseqAccession => "NW_021160011.1", :role => "fix-patch", :ucscStyleName => "chr13_ML143365v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "13", :genbankAccession => "ML143366.1", :length => 409912, :refseqAccession => "NW_021160012.1", :role => "fix-patch", :ucscStyleName => "chr13_ML143366v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "13", :genbankAccession => "KQ090024.1", :length => 168146, :refseqAccession => "NW_013171810.1", :role => "novel-patch", :ucscStyleName => "chr13_KQ090024v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "13", :genbankAccession => "KQ090025.1", :length => 123480, :refseqAccession => "NW_013171811.1", :role => "novel-patch", :ucscStyleName => "chr13_KQ090025v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "14", :genbankAccession => "KZ208920.1", :length => 690932, :refseqAccession => "NW_018654722.1", :role => "fix-patch", :ucscStyleName => "chr14_KZ208920v1_fix",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "14", :genbankAccession => "ML143367.1", :length => 399183, :refseqAccession => "NW_021160013.1", :role => "fix-patch", :ucscStyleName => "chr14_ML143367v1_fix",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "14", :genbankAccession => "MU273373.1", :length => 722645, :refseqAccession => "NW_025791796.1", :role => "fix-patch", :ucscStyleName => "chr14_MU273373v1_fix",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "14", :genbankAccession => "KZ208919.1", :length => 171798, :refseqAccession => "NW_018654721.1", :role => "novel-patch", :ucscStyleName => "chr14_KZ208919v1_alt",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "14", :genbankAccession => "ML143368.1", :length => 264228, :refseqAccession => "NW_021160014.1", :role => "novel-patch", :ucscStyleName => "chr14_ML143368v1_alt",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "15", :genbankAccession => "KN538374.1", :length => 4998962, :refseqAccession => "NW_011332701.1", :role => "fix-patch", :ucscStyleName => "chr15_KN538374v1_fix",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "15", :genbankAccession => "ML143369.1", :length => 97763, :refseqAccession => "NW_021160015.1", :role => "fix-patch", :ucscStyleName => "chr15_ML143369v1_fix",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "15", :genbankAccession => "ML143370.1", :length => 369264, :refseqAccession => "NW_021160016.1", :role => "fix-patch", :ucscStyleName => "chr15_ML143370v1_fix",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "15", :genbankAccession => "ML143371.1", :length => 5500449, :refseqAccession => "NW_021160017.1", :role => "fix-patch", :ucscStyleName => "chr15_ML143371v1_fix",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "15", :genbankAccession => "ML143372.1", :length => 396515, :refseqAccession => "NW_021160018.1", :role => "fix-patch", :ucscStyleName => "chr15_ML143372v1_fix",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "15", :genbankAccession => "MU273374.1", :length => 1154574, :refseqAccession => "NW_025791797.1", :role => "fix-patch", :ucscStyleName => "chr15_MU273374v1_fix",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "15", :genbankAccession => "KQ031389.1", :length => 2365364, :refseqAccession => "NW_012132920.1", :role => "novel-patch", :ucscStyleName => "chr15_KQ031389v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "15", :genbankAccession => "MU273375.1", :length => 204007, :refseqAccession => "NW_025791798.1", :role => "novel-patch", :ucscStyleName => "chr15_MU273375v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "16", :genbankAccession => "KV880768.1", :length => 1927115, :refseqAccession => "NW_017852933.1", :role => "fix-patch", :ucscStyleName => "chr16_KV880768v1_fix",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "16", :genbankAccession => "KZ559113.1", :length => 480415, :refseqAccession => "NW_019805500.1", :role => "fix-patch", :ucscStyleName => "chr16_KZ559113v1_fix",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "16", :genbankAccession => "ML143373.1", :length => 270967, :refseqAccession => "NW_021160019.1", :role => "fix-patch", :ucscStyleName => "chr16_ML143373v1_fix",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "16", :genbankAccession => "MU273376.1", :length => 87715, :refseqAccession => "NW_025791799.1", :role => "fix-patch", :ucscStyleName => "chr16_MU273376v1_fix",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "16", :genbankAccession => "MU273377.1", :length => 334997, :refseqAccession => "NW_025791800.1", :role => "fix-patch", :ucscStyleName => "chr16_MU273377v1_fix",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "16", :genbankAccession => "KQ031390.1", :length => 169136, :refseqAccession => "NW_012132921.1", :role => "novel-patch", :ucscStyleName => "chr16_KQ031390v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "16", :genbankAccession => "KQ090026.1", :length => 59016, :refseqAccession => "NW_013171812.1", :role => "novel-patch", :ucscStyleName => "chr16_KQ090026v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "16", :genbankAccession => "KQ090027.1", :length => 267463, :refseqAccession => "NW_013171813.1", :role => "novel-patch", :ucscStyleName => "chr16_KQ090027v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "16", :genbankAccession => "KZ208921.1", :length => 78609, :refseqAccession => "NW_018654723.1", :role => "novel-patch", :ucscStyleName => "chr16_KZ208921v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "KV575245.1", :length => 154723, :refseqAccession => "NW_016107299.1", :role => "fix-patch", :ucscStyleName => "chr17_KV575245v1_fix",:unlocalizedCount => 3},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "KV766196.1", :length => 281919, :refseqAccession => "NW_017363817.1", :role => "fix-patch", :ucscStyleName => "chr17_KV766196v1_fix",:unlocalizedCount => 3},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "ML143374.1", :length => 137908, :refseqAccession => "NW_021160020.1", :role => "fix-patch", :ucscStyleName => "chr17_ML143374v1_fix",:unlocalizedCount => 3},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "ML143375.1", :length => 56695, :refseqAccession => "NW_021160021.1", :role => "fix-patch", :ucscStyleName => "chr17_ML143375v1_fix",:unlocalizedCount => 3},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "MU273379.1", :length => 234878, :refseqAccession => "NW_025791802.1", :role => "fix-patch", :ucscStyleName => "chr17_MU273379v1_fix",:unlocalizedCount => 3},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "MU273380.1", :length => 538541, :refseqAccession => "NW_025791803.1", :role => "fix-patch", :ucscStyleName => "chr17_MU273380v1_fix",:unlocalizedCount => 3},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "MU273381.1", :length => 144689, :refseqAccession => "NW_025791804.1", :role => "fix-patch", :ucscStyleName => "chr17_MU273381v1_fix",:unlocalizedCount => 3},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "MU273382.1", :length => 187626, :refseqAccession => "NW_025791805.1", :role => "fix-patch", :ucscStyleName => "chr17_MU273382v1_fix",:unlocalizedCount => 3},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "MU273383.1", :length => 172609, :refseqAccession => "NW_025791806.1", :role => "fix-patch", :ucscStyleName => "chr17_MU273383v1_fix",:unlocalizedCount => 3},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "KV766197.1", :length => 246895, :refseqAccession => "NW_017363818.1", :role => "novel-patch", :ucscStyleName => "chr17_KV766197v1_alt",:unlocalizedCount => 3},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "KV766198.1", :length => 276292, :refseqAccession => "NW_017363819.1", :role => "novel-patch", :ucscStyleName => "chr17_KV766198v1_alt",:unlocalizedCount => 3},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "KZ559114.1", :length => 116753, :refseqAccession => "NW_019805501.1", :role => "novel-patch", :ucscStyleName => "chr17_KZ559114v1_alt",:unlocalizedCount => 3},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "MU273378.1", :length => 372839, :refseqAccession => "NW_025791801.1", :role => "novel-patch", :ucscStyleName => "chr17_MU273378v1_alt",:unlocalizedCount => 3},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "18", :genbankAccession => "KQ090028.1", :length => 407387, :refseqAccession => "NW_013171814.1", :role => "fix-patch", :ucscStyleName => "chr18_KQ090028v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "18", :genbankAccession => "KZ208922.1", :length => 93070, :refseqAccession => "NW_018654724.1", :role => "fix-patch", :ucscStyleName => "chr18_KZ208922v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "18", :genbankAccession => "KZ559115.1", :length => 230843, :refseqAccession => "NW_019805502.1", :role => "fix-patch", :ucscStyleName => "chr18_KZ559115v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "18", :genbankAccession => "KQ458385.1", :length => 205101, :refseqAccession => "NW_014040928.1", :role => "novel-patch", :ucscStyleName => "chr18_KQ458385v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "18", :genbankAccession => "KZ559116.1", :length => 163186, :refseqAccession => "NW_019805503.1", :role => "novel-patch", :ucscStyleName => "chr18_KZ559116v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KN196484.1", :length => 370917, :refseqAccession => "NW_009646206.1", :role => "fix-patch", :ucscStyleName => "chr19_KN196484v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KQ458386.1", :length => 405389, :refseqAccession => "NW_014040929.1", :role => "fix-patch", :ucscStyleName => "chr19_KQ458386v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "ML143376.1", :length => 493165, :refseqAccession => "NW_021160022.1", :role => "fix-patch", :ucscStyleName => "chr19_ML143376v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "MU273384.1", :length => 333754, :refseqAccession => "NW_025791807.1", :role => "fix-patch", :ucscStyleName => "chr19_MU273384v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "MU273385.1", :length => 137818, :refseqAccession => "NW_025791808.1", :role => "fix-patch", :ucscStyleName => "chr19_MU273385v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "MU273386.1", :length => 226166, :refseqAccession => "NW_025791809.1", :role => "fix-patch", :ucscStyleName => "chr19_MU273386v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KV575246.1", :length => 163926, :refseqAccession => "NW_016107300.1", :role => "novel-patch", :ucscStyleName => "chr19_KV575246v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KV575247.1", :length => 170206, :refseqAccession => "NW_016107301.1", :role => "novel-patch", :ucscStyleName => "chr19_KV575247v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KV575248.1", :length => 168131, :refseqAccession => "NW_016107302.1", :role => "novel-patch", :ucscStyleName => "chr19_KV575248v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KV575249.1", :length => 293522, :refseqAccession => "NW_016107303.1", :role => "novel-patch", :ucscStyleName => "chr19_KV575249v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KV575250.1", :length => 241058, :refseqAccession => "NW_016107304.1", :role => "novel-patch", :ucscStyleName => "chr19_KV575250v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KV575251.1", :length => 159285, :refseqAccession => "NW_016107305.1", :role => "novel-patch", :ucscStyleName => "chr19_KV575251v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KV575252.1", :length => 178197, :refseqAccession => "NW_016107306.1", :role => "novel-patch", :ucscStyleName => "chr19_KV575252v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KV575253.1", :length => 166713, :refseqAccession => "NW_016107307.1", :role => "novel-patch", :ucscStyleName => "chr19_KV575253v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KV575254.1", :length => 99845, :refseqAccession => "NW_016107308.1", :role => "novel-patch", :ucscStyleName => "chr19_KV575254v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KV575255.1", :length => 161095, :refseqAccession => "NW_016107309.1", :role => "novel-patch", :ucscStyleName => "chr19_KV575255v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KV575256.1", :length => 223118, :refseqAccession => "NW_016107310.1", :role => "novel-patch", :ucscStyleName => "chr19_KV575256v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KV575257.1", :length => 100553, :refseqAccession => "NW_016107311.1", :role => "novel-patch", :ucscStyleName => "chr19_KV575257v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KV575258.1", :length => 156965, :refseqAccession => "NW_016107312.1", :role => "novel-patch", :ucscStyleName => "chr19_KV575258v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KV575259.1", :length => 171263, :refseqAccession => "NW_016107313.1", :role => "novel-patch", :ucscStyleName => "chr19_KV575259v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KV575260.1", :length => 145691, :refseqAccession => "NW_016107314.1", :role => "novel-patch", :ucscStyleName => "chr19_KV575260v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "MU273387.1", :length => 89211, :refseqAccession => "NW_025791810.1", :role => "novel-patch", :ucscStyleName => "chr19_MU273387v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "20", :genbankAccession => "MU273388.1", :length => 273725, :refseqAccession => "NW_025791811.1", :role => "fix-patch", :ucscStyleName => "chr20_MU273388v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "20", :genbankAccession => "MU273389.1", :length => 355731, :refseqAccession => "NW_025791812.1", :role => "fix-patch", :ucscStyleName => "chr20_MU273389v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "21", :genbankAccession => "ML143377.1", :length => 519485, :refseqAccession => "NW_021160023.1", :role => "fix-patch", :ucscStyleName => "chr21_ML143377v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "21", :genbankAccession => "MU273390.1", :length => 336752, :refseqAccession => "NW_025791813.1", :role => "fix-patch", :ucscStyleName => "chr21_MU273390v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "21", :genbankAccession => "MU273391.1", :length => 1020778, :refseqAccession => "NW_025791814.1", :role => "fix-patch", :ucscStyleName => "chr21_MU273391v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "21", :genbankAccession => "MU273392.1", :length => 189707, :refseqAccession => "NW_025791815.1", :role => "fix-patch", :ucscStyleName => "chr21_MU273392v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "22", :genbankAccession => "KQ759762.2", :length => 101040, :refseqAccession => "NW_015148969.2", :role => "fix-patch", :ucscStyleName => "chr22_KQ759762v2_fix",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "22", :genbankAccession => "ML143378.1", :length => 461303, :refseqAccession => "NW_021160024.1", :role => "fix-patch", :ucscStyleName => "chr22_ML143378v1_fix",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "22", :genbankAccession => "ML143379.1", :length => 12295, :refseqAccession => "NW_021160025.1", :role => "fix-patch", :ucscStyleName => "chr22_ML143379v1_fix",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "22", :genbankAccession => "ML143380.1", :length => 412368, :refseqAccession => "NW_021160026.1", :role => "fix-patch", :ucscStyleName => "chr22_ML143380v1_fix",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "22", :genbankAccession => "KN196485.1", :length => 156562, :refseqAccession => "NW_009646207.1", :role => "novel-patch", :ucscStyleName => "chr22_KN196485v1_alt",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "22", :genbankAccession => "KN196486.1", :length => 153027, :refseqAccession => "NW_009646208.1", :role => "novel-patch", :ucscStyleName => "chr22_KN196486v1_alt",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "22", :genbankAccession => "KQ458387.1", :length => 155930, :refseqAccession => "NW_014040930.1", :role => "novel-patch", :ucscStyleName => "chr22_KQ458387v1_alt",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "22", :genbankAccession => "KQ458388.1", :length => 174749, :refseqAccession => "NW_014040931.1", :role => "novel-patch", :ucscStyleName => "chr22_KQ458388v1_alt",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "22", :genbankAccession => "KQ759761.1", :length => 145162, :refseqAccession => "NW_015148968.1", :role => "novel-patch", :ucscStyleName => "chr22_KQ759761v1_alt",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "X", :genbankAccession => "ML143381.1", :length => 403128, :refseqAccession => "NW_021160027.1", :role => "fix-patch", :ucscStyleName => "chrX_ML143381v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "X", :genbankAccession => "ML143382.1", :length => 28824, :refseqAccession => "NW_021160028.1", :role => "fix-patch", :ucscStyleName => "chrX_ML143382v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "X", :genbankAccession => "ML143383.1", :length => 68192, :refseqAccession => "NW_021160029.1", :role => "fix-patch", :ucscStyleName => "chrX_ML143383v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "X", :genbankAccession => "ML143384.1", :length => 14678, :refseqAccession => "NW_021160030.1", :role => "fix-patch", :ucscStyleName => "chrX_ML143384v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "X", :genbankAccession => "ML143385.1", :length => 17435, :refseqAccession => "NW_021160031.1", :role => "fix-patch", :ucscStyleName => "chrX_ML143385v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "X", :genbankAccession => "MU273393.1", :length => 68810, :refseqAccession => "NW_025791816.1", :role => "fix-patch", :ucscStyleName => "chrX_MU273393v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "X", :genbankAccession => "MU273394.1", :length => 140567, :refseqAccession => "NW_025791817.1", :role => "fix-patch", :ucscStyleName => "chrX_MU273394v1_fix"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "X", :genbankAccession => "KV766199.1", :length => 188004, :refseqAccession => "NW_017363820.1", :role => "novel-patch", :ucscStyleName => "chrX_KV766199v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "X", :genbankAccession => "MU273395.1", :length => 619716, :refseqAccession => "NW_025791818.1", :role => "novel-patch", :ucscStyleName => "chrX_MU273395v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "X", :genbankAccession => "MU273396.1", :length => 294119, :refseqAccession => "NW_025791819.1", :role => "novel-patch", :ucscStyleName => "chrX_MU273396v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "X", :genbankAccession => "MU273397.1", :length => 330493, :refseqAccession => "NW_025791820.1", :role => "novel-patch", :ucscStyleName => "chrX_MU273397v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "Y", :genbankAccession => "KN196487.1", :length => 101150, :refseqAccession => "NW_009646209.1", :role => "fix-patch", :ucscStyleName => "chrY_KN196487v1_fix",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "Y", :genbankAccession => "KZ208923.1", :length => 48370, :refseqAccession => "NW_018654725.1", :role => "fix-patch", :ucscStyleName => "chrY_KZ208923v1_fix",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "Y", :genbankAccession => "KZ208924.1", :length => 209722, :refseqAccession => "NW_018654726.1", :role => "fix-patch", :ucscStyleName => "chrY_KZ208924v1_fix",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "PATCHES", :assignedMoleculeLocationType => "Chromosome", :chrName => "Y", :genbankAccession => "MU273398.1", :length => 865743, :refseqAccession => "NW_025791821.1", :role => "fix-patch", :ucscStyleName => "chrY_MU273398v1_fix",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "GL383518.1", :length => 182439, :refseqAccession => "NW_003315905.1", :role => "alt-scaffold", :ucscStyleName => "chr1_GL383518v1_alt",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "GL383519.1", :length => 110268, :refseqAccession => "NW_003315906.1", :role => "alt-scaffold", :ucscStyleName => "chr1_GL383519v1_alt",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "GL383520.2", :length => 366580, :refseqAccession => "NW_003315907.2", :role => "alt-scaffold", :ucscStyleName => "chr1_GL383520v2_alt",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "KI270759.1", :length => 425601, :refseqAccession => "NT_187516.1", :role => "alt-scaffold", :ucscStyleName => "chr1_KI270759v1_alt",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "KI270760.1", :length => 109528, :refseqAccession => "NT_187514.1", :role => "alt-scaffold", :ucscStyleName => "chr1_KI270760v1_alt",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "KI270761.1", :length => 165834, :refseqAccession => "NT_187518.1", :role => "alt-scaffold", :ucscStyleName => "chr1_KI270761v1_alt",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "KI270762.1", :length => 354444, :refseqAccession => "NT_187515.1", :role => "alt-scaffold", :ucscStyleName => "chr1_KI270762v1_alt",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "KI270763.1", :length => 911658, :refseqAccession => "NT_187519.1", :role => "alt-scaffold", :ucscStyleName => "chr1_KI270763v1_alt",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "KI270764.1", :length => 50258, :refseqAccession => "NT_187521.1", :role => "alt-scaffold", :ucscStyleName => "chr1_KI270764v1_alt",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "KI270765.1", :length => 185285, :refseqAccession => "NT_187520.1", :role => "alt-scaffold", :ucscStyleName => "chr1_KI270765v1_alt",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "KI270766.1", :length => 256271, :refseqAccession => "NT_187517.1", :role => "alt-scaffold", :ucscStyleName => "chr1_KI270766v1_alt",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "2", :genbankAccession => "GL383521.1", :length => 143390, :refseqAccession => "NW_003315908.1", :role => "alt-scaffold", :ucscStyleName => "chr2_GL383521v1_alt",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "2", :genbankAccession => "GL383522.1", :length => 123821, :refseqAccession => "NW_003315909.1", :role => "alt-scaffold", :ucscStyleName => "chr2_GL383522v1_alt",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "2", :genbankAccession => "GL582966.2", :length => 96131, :refseqAccession => "NW_003571033.2", :role => "alt-scaffold", :ucscStyleName => "chr2_GL582966v2_alt",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "2", :genbankAccession => "KI270767.1", :length => 161578, :refseqAccession => "NT_187523.1", :role => "alt-scaffold", :ucscStyleName => "chr2_KI270767v1_alt",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "2", :genbankAccession => "KI270768.1", :length => 110099, :refseqAccession => "NT_187528.1", :role => "alt-scaffold", :ucscStyleName => "chr2_KI270768v1_alt",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "2", :genbankAccession => "KI270769.1", :length => 120616, :refseqAccession => "NT_187522.1", :role => "alt-scaffold", :ucscStyleName => "chr2_KI270769v1_alt",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "2", :genbankAccession => "KI270770.1", :length => 136240, :refseqAccession => "NT_187525.1", :role => "alt-scaffold", :ucscStyleName => "chr2_KI270770v1_alt",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "2", :genbankAccession => "KI270771.1", :length => 110395, :refseqAccession => "NT_187530.1", :role => "alt-scaffold", :ucscStyleName => "chr2_KI270771v1_alt",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "2", :genbankAccession => "KI270772.1", :length => 133041, :refseqAccession => "NT_187524.1", :role => "alt-scaffold", :ucscStyleName => "chr2_KI270772v1_alt",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "2", :genbankAccession => "KI270773.1", :length => 70887, :refseqAccession => "NT_187526.1", :role => "alt-scaffold", :ucscStyleName => "chr2_KI270773v1_alt",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "2", :genbankAccession => "KI270774.1", :length => 223625, :refseqAccession => "NT_187529.1", :role => "alt-scaffold", :ucscStyleName => "chr2_KI270774v1_alt",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "2", :genbankAccession => "KI270775.1", :length => 138019, :refseqAccession => "NT_187531.1", :role => "alt-scaffold", :ucscStyleName => "chr2_KI270775v1_alt",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "2", :genbankAccession => "KI270776.1", :length => 174166, :refseqAccession => "NT_187527.1", :role => "alt-scaffold", :ucscStyleName => "chr2_KI270776v1_alt",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "3", :genbankAccession => "GL383526.1", :length => 180671, :refseqAccession => "NW_003315913.1", :role => "alt-scaffold", :ucscStyleName => "chr3_GL383526v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "3", :genbankAccession => "JH636055.2", :length => 173151, :refseqAccession => "NW_003871060.2", :role => "alt-scaffold", :ucscStyleName => "chr3_JH636055v2_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "3", :genbankAccession => "KI270777.1", :length => 173649, :refseqAccession => "NT_187533.1", :role => "alt-scaffold", :ucscStyleName => "chr3_KI270777v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "3", :genbankAccession => "KI270778.1", :length => 248252, :refseqAccession => "NT_187536.1", :role => "alt-scaffold", :ucscStyleName => "chr3_KI270778v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "3", :genbankAccession => "KI270779.1", :length => 205312, :refseqAccession => "NT_187532.1", :role => "alt-scaffold", :ucscStyleName => "chr3_KI270779v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "3", :genbankAccession => "KI270780.1", :length => 224108, :refseqAccession => "NT_187537.1", :role => "alt-scaffold", :ucscStyleName => "chr3_KI270780v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "3", :genbankAccession => "KI270781.1", :length => 113034, :refseqAccession => "NT_187538.1", :role => "alt-scaffold", :ucscStyleName => "chr3_KI270781v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "3", :genbankAccession => "KI270782.1", :length => 162429, :refseqAccession => "NT_187534.1", :role => "alt-scaffold", :ucscStyleName => "chr3_KI270782v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "3", :genbankAccession => "KI270783.1", :length => 109187, :refseqAccession => "NT_187535.1", :role => "alt-scaffold", :ucscStyleName => "chr3_KI270783v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "3", :genbankAccession => "KI270784.1", :length => 184404, :refseqAccession => "NT_187539.1", :role => "alt-scaffold", :ucscStyleName => "chr3_KI270784v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "4", :genbankAccession => "GL000257.2", :length => 586476, :refseqAccession => "NT_167250.2", :role => "alt-scaffold", :ucscStyleName => "chr4_GL000257v2_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "4", :genbankAccession => "GL383527.1", :length => 164536, :refseqAccession => "NW_003315914.1", :role => "alt-scaffold", :ucscStyleName => "chr4_GL383527v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "4", :genbankAccession => "GL383528.1", :length => 376187, :refseqAccession => "NW_003315915.1", :role => "alt-scaffold", :ucscStyleName => "chr4_GL383528v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "4", :genbankAccession => "KI270785.1", :length => 119912, :refseqAccession => "NT_187542.1", :role => "alt-scaffold", :ucscStyleName => "chr4_KI270785v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "4", :genbankAccession => "KI270786.1", :length => 244096, :refseqAccession => "NT_187543.1", :role => "alt-scaffold", :ucscStyleName => "chr4_KI270786v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "4", :genbankAccession => "KI270787.1", :length => 111943, :refseqAccession => "NT_187541.1", :role => "alt-scaffold", :ucscStyleName => "chr4_KI270787v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "4", :genbankAccession => "KI270788.1", :length => 158965, :refseqAccession => "NT_187544.1", :role => "alt-scaffold", :ucscStyleName => "chr4_KI270788v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "4", :genbankAccession => "KI270789.1", :length => 205944, :refseqAccession => "NT_187545.1", :role => "alt-scaffold", :ucscStyleName => "chr4_KI270789v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "4", :genbankAccession => "KI270790.1", :length => 220246, :refseqAccession => "NT_187540.1", :role => "alt-scaffold", :ucscStyleName => "chr4_KI270790v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "5", :genbankAccession => "GL339449.2", :length => 1612928, :refseqAccession => "NW_003315917.2", :role => "alt-scaffold", :ucscStyleName => "chr5_GL339449v2_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "5", :genbankAccession => "GL383530.1", :length => 101241, :refseqAccession => "NW_003315918.1", :role => "alt-scaffold", :ucscStyleName => "chr5_GL383530v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "5", :genbankAccession => "GL383531.1", :length => 173459, :refseqAccession => "NW_003315919.1", :role => "alt-scaffold", :ucscStyleName => "chr5_GL383531v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "5", :genbankAccession => "GL383532.1", :length => 82728, :refseqAccession => "NW_003315920.1", :role => "alt-scaffold", :ucscStyleName => "chr5_GL383532v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "5", :genbankAccession => "GL949742.1", :length => 226852, :refseqAccession => "NW_003571036.1", :role => "alt-scaffold", :ucscStyleName => "chr5_GL949742v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "5", :genbankAccession => "KI270791.1", :length => 195710, :refseqAccession => "NT_187547.1", :role => "alt-scaffold", :ucscStyleName => "chr5_KI270791v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "5", :genbankAccession => "KI270792.1", :length => 179043, :refseqAccession => "NT_187548.1", :role => "alt-scaffold", :ucscStyleName => "chr5_KI270792v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "5", :genbankAccession => "KI270793.1", :length => 126136, :refseqAccession => "NT_187550.1", :role => "alt-scaffold", :ucscStyleName => "chr5_KI270793v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "5", :genbankAccession => "KI270794.1", :length => 164558, :refseqAccession => "NT_187551.1", :role => "alt-scaffold", :ucscStyleName => "chr5_KI270794v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "5", :genbankAccession => "KI270795.1", :length => 131892, :refseqAccession => "NT_187546.1", :role => "alt-scaffold", :ucscStyleName => "chr5_KI270795v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "5", :genbankAccession => "KI270796.1", :length => 172708, :refseqAccession => "NT_187549.1", :role => "alt-scaffold", :ucscStyleName => "chr5_KI270796v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "6", :genbankAccession => "GL000250.2", :length => 4672374, :refseqAccession => "NT_167244.2", :role => "alt-scaffold", :ucscStyleName => "chr6_GL000250v2_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "6", :genbankAccession => "GL383533.1", :length => 124736, :refseqAccession => "NW_003315921.1", :role => "alt-scaffold", :ucscStyleName => "chr6_GL383533v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "6", :genbankAccession => "KB021644.2", :length => 185823, :refseqAccession => "NW_004166862.2", :role => "alt-scaffold", :ucscStyleName => "chr6_KB021644v2_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "6", :genbankAccession => "KI270797.1", :length => 197536, :refseqAccession => "NT_187552.1", :role => "alt-scaffold", :ucscStyleName => "chr6_KI270797v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "6", :genbankAccession => "KI270798.1", :length => 271782, :refseqAccession => "NT_187553.1", :role => "alt-scaffold", :ucscStyleName => "chr6_KI270798v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "6", :genbankAccession => "KI270799.1", :length => 152148, :refseqAccession => "NT_187554.1", :role => "alt-scaffold", :ucscStyleName => "chr6_KI270799v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "6", :genbankAccession => "KI270800.1", :length => 175808, :refseqAccession => "NT_187555.1", :role => "alt-scaffold", :ucscStyleName => "chr6_KI270800v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "6", :genbankAccession => "KI270801.1", :length => 870480, :refseqAccession => "NT_187556.1", :role => "alt-scaffold", :ucscStyleName => "chr6_KI270801v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "6", :genbankAccession => "KI270802.1", :length => 75005, :refseqAccession => "NT_187557.1", :role => "alt-scaffold", :ucscStyleName => "chr6_KI270802v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "7", :genbankAccession => "GL383534.2", :length => 119183, :refseqAccession => "NW_003315922.2", :role => "alt-scaffold", :ucscStyleName => "chr7_GL383534v2_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "7", :genbankAccession => "KI270803.1", :length => 1111570, :refseqAccession => "NT_187562.1", :role => "alt-scaffold", :ucscStyleName => "chr7_KI270803v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "7", :genbankAccession => "KI270804.1", :length => 157952, :refseqAccession => "NT_187558.1", :role => "alt-scaffold", :ucscStyleName => "chr7_KI270804v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "7", :genbankAccession => "KI270805.1", :length => 209988, :refseqAccession => "NT_187560.1", :role => "alt-scaffold", :ucscStyleName => "chr7_KI270805v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "7", :genbankAccession => "KI270806.1", :length => 158166, :refseqAccession => "NT_187559.1", :role => "alt-scaffold", :ucscStyleName => "chr7_KI270806v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "7", :genbankAccession => "KI270807.1", :length => 126434, :refseqAccession => "NT_187563.1", :role => "alt-scaffold", :ucscStyleName => "chr7_KI270807v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "7", :genbankAccession => "KI270808.1", :length => 271455, :refseqAccession => "NT_187564.1", :role => "alt-scaffold", :ucscStyleName => "chr7_KI270808v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "7", :genbankAccession => "KI270809.1", :length => 209586, :refseqAccession => "NT_187561.1", :role => "alt-scaffold", :ucscStyleName => "chr7_KI270809v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "8", :genbankAccession => "KI270810.1", :length => 374415, :refseqAccession => "NT_187567.1", :role => "alt-scaffold", :ucscStyleName => "chr8_KI270810v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "8", :genbankAccession => "KI270811.1", :length => 292436, :refseqAccession => "NT_187565.1", :role => "alt-scaffold", :ucscStyleName => "chr8_KI270811v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "8", :genbankAccession => "KI270812.1", :length => 282736, :refseqAccession => "NT_187568.1", :role => "alt-scaffold", :ucscStyleName => "chr8_KI270812v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "8", :genbankAccession => "KI270813.1", :length => 300230, :refseqAccession => "NT_187570.1", :role => "alt-scaffold", :ucscStyleName => "chr8_KI270813v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "8", :genbankAccession => "KI270814.1", :length => 141812, :refseqAccession => "NT_187566.1", :role => "alt-scaffold", :ucscStyleName => "chr8_KI270814v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "8", :genbankAccession => "KI270815.1", :length => 132244, :refseqAccession => "NT_187569.1", :role => "alt-scaffold", :ucscStyleName => "chr8_KI270815v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "8", :genbankAccession => "KI270816.1", :length => 305841, :refseqAccession => "NT_187571.1", :role => "alt-scaffold", :ucscStyleName => "chr8_KI270816v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "8", :genbankAccession => "KI270817.1", :length => 158983, :refseqAccession => "NT_187573.1", :role => "alt-scaffold", :ucscStyleName => "chr8_KI270817v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "8", :genbankAccession => "KI270818.1", :length => 145606, :refseqAccession => "NT_187572.1", :role => "alt-scaffold", :ucscStyleName => "chr8_KI270818v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "8", :genbankAccession => "KI270819.1", :length => 133535, :refseqAccession => "NT_187574.1", :role => "alt-scaffold", :ucscStyleName => "chr8_KI270819v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "8", :genbankAccession => "KI270820.1", :length => 36640, :refseqAccession => "NT_187575.1", :role => "alt-scaffold", :ucscStyleName => "chr8_KI270820v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "8", :genbankAccession => "KI270821.1", :length => 985506, :refseqAccession => "NT_187576.1", :role => "alt-scaffold", :ucscStyleName => "chr8_KI270821v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "8", :genbankAccession => "KI270822.1", :length => 624492, :refseqAccession => "NT_187577.1", :role => "alt-scaffold", :ucscStyleName => "chr8_KI270822v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "9", :genbankAccession => "GL383539.1", :length => 162988, :refseqAccession => "NW_003315928.1", :role => "alt-scaffold", :ucscStyleName => "chr9_GL383539v1_alt",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "9", :genbankAccession => "GL383540.1", :length => 71551, :refseqAccession => "NW_003315929.1", :role => "alt-scaffold", :ucscStyleName => "chr9_GL383540v1_alt",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "9", :genbankAccession => "GL383541.1", :length => 171286, :refseqAccession => "NW_003315930.1", :role => "alt-scaffold", :ucscStyleName => "chr9_GL383541v1_alt",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "9", :genbankAccession => "GL383542.1", :length => 60032, :refseqAccession => "NW_003315931.1", :role => "alt-scaffold", :ucscStyleName => "chr9_GL383542v1_alt",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "9", :genbankAccession => "KI270823.1", :length => 439082, :refseqAccession => "NT_187578.1", :role => "alt-scaffold", :ucscStyleName => "chr9_KI270823v1_alt",:unlocalizedCount => 4},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "10", :genbankAccession => "GL383545.1", :length => 179254, :refseqAccession => "NW_003315934.1", :role => "alt-scaffold", :ucscStyleName => "chr10_GL383545v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "10", :genbankAccession => "GL383546.1", :length => 309802, :refseqAccession => "NW_003315935.1", :role => "alt-scaffold", :ucscStyleName => "chr10_GL383546v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "10", :genbankAccession => "KI270824.1", :length => 181496, :refseqAccession => "NT_187579.1", :role => "alt-scaffold", :ucscStyleName => "chr10_KI270824v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "GL383547.1", :length => 154407, :refseqAccession => "NW_003315936.1", :role => "alt-scaffold", :ucscStyleName => "chr11_GL383547v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "JH159136.1", :length => 200998, :refseqAccession => "NW_003871073.1", :role => "alt-scaffold", :ucscStyleName => "chr11_JH159136v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "JH159137.1", :length => 191409, :refseqAccession => "NW_003871074.1", :role => "alt-scaffold", :ucscStyleName => "chr11_JH159137v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "KI270826.1", :length => 186169, :refseqAccession => "NT_187581.1", :role => "alt-scaffold", :ucscStyleName => "chr11_KI270826v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "KI270827.1", :length => 67707, :refseqAccession => "NT_187582.1", :role => "alt-scaffold", :ucscStyleName => "chr11_KI270827v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "KI270829.1", :length => 204059, :refseqAccession => "NT_187583.1", :role => "alt-scaffold", :ucscStyleName => "chr11_KI270829v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "KI270830.1", :length => 177092, :refseqAccession => "NT_187584.1", :role => "alt-scaffold", :ucscStyleName => "chr11_KI270830v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "KI270831.1", :length => 296895, :refseqAccession => "NT_187585.1", :role => "alt-scaffold", :ucscStyleName => "chr11_KI270831v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "KI270832.1", :length => 210133, :refseqAccession => "NT_187586.1", :role => "alt-scaffold", :ucscStyleName => "chr11_KI270832v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "12", :genbankAccession => "GL383549.1", :length => 120804, :refseqAccession => "NW_003315938.1", :role => "alt-scaffold", :ucscStyleName => "chr12_GL383549v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "12", :genbankAccession => "GL383550.2", :length => 169178, :refseqAccession => "NW_003315939.2", :role => "alt-scaffold", :ucscStyleName => "chr12_GL383550v2_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "12", :genbankAccession => "GL383551.1", :length => 184319, :refseqAccession => "NW_003315940.1", :role => "alt-scaffold", :ucscStyleName => "chr12_GL383551v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "12", :genbankAccession => "GL383552.1", :length => 138655, :refseqAccession => "NW_003315941.1", :role => "alt-scaffold", :ucscStyleName => "chr12_GL383552v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "12", :genbankAccession => "GL383553.2", :length => 152874, :refseqAccession => "NW_003315942.2", :role => "alt-scaffold", :ucscStyleName => "chr12_GL383553v2_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "12", :genbankAccession => "GL877875.1", :length => 167313, :refseqAccession => "NW_003571049.1", :role => "alt-scaffold", :ucscStyleName => "chr12_GL877875v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "12", :genbankAccession => "GL877876.1", :length => 408271, :refseqAccession => "NW_003571050.1", :role => "alt-scaffold", :ucscStyleName => "chr12_GL877876v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "12", :genbankAccession => "KI270833.1", :length => 76061, :refseqAccession => "NT_187589.1", :role => "alt-scaffold", :ucscStyleName => "chr12_KI270833v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "12", :genbankAccession => "KI270834.1", :length => 119498, :refseqAccession => "NT_187590.1", :role => "alt-scaffold", :ucscStyleName => "chr12_KI270834v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "12", :genbankAccession => "KI270835.1", :length => 238139, :refseqAccession => "NT_187587.1", :role => "alt-scaffold", :ucscStyleName => "chr12_KI270835v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "12", :genbankAccession => "KI270836.1", :length => 56134, :refseqAccession => "NT_187591.1", :role => "alt-scaffold", :ucscStyleName => "chr12_KI270836v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "12", :genbankAccession => "KI270837.1", :length => 40090, :refseqAccession => "NT_187588.1", :role => "alt-scaffold", :ucscStyleName => "chr12_KI270837v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "13", :genbankAccession => "KI270838.1", :length => 306913, :refseqAccession => "NT_187592.1", :role => "alt-scaffold", :ucscStyleName => "chr13_KI270838v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "13", :genbankAccession => "KI270839.1", :length => 180306, :refseqAccession => "NT_187593.1", :role => "alt-scaffold", :ucscStyleName => "chr13_KI270839v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "13", :genbankAccession => "KI270840.1", :length => 191684, :refseqAccession => "NT_187594.1", :role => "alt-scaffold", :ucscStyleName => "chr13_KI270840v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "13", :genbankAccession => "KI270841.1", :length => 169134, :refseqAccession => "NT_187595.1", :role => "alt-scaffold", :ucscStyleName => "chr13_KI270841v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "13", :genbankAccession => "KI270842.1", :length => 37287, :refseqAccession => "NT_187596.1", :role => "alt-scaffold", :ucscStyleName => "chr13_KI270842v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "13", :genbankAccession => "KI270843.1", :length => 103832, :refseqAccession => "NT_187597.1", :role => "alt-scaffold", :ucscStyleName => "chr13_KI270843v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "14", :genbankAccession => "KI270844.1", :length => 322166, :refseqAccession => "NT_187598.1", :role => "alt-scaffold", :ucscStyleName => "chr14_KI270844v1_alt",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "14", :genbankAccession => "KI270845.1", :length => 180703, :refseqAccession => "NT_187599.1", :role => "alt-scaffold", :ucscStyleName => "chr14_KI270845v1_alt",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "14", :genbankAccession => "KI270846.1", :length => 1351393, :refseqAccession => "NT_187600.1", :role => "alt-scaffold", :ucscStyleName => "chr14_KI270846v1_alt",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "14", :genbankAccession => "KI270847.1", :length => 1511111, :refseqAccession => "NT_187601.1", :role => "alt-scaffold", :ucscStyleName => "chr14_KI270847v1_alt",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "15", :genbankAccession => "GL383554.1", :length => 296527, :refseqAccession => "NW_003315943.1", :role => "alt-scaffold", :ucscStyleName => "chr15_GL383554v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "15", :genbankAccession => "GL383555.2", :length => 388773, :refseqAccession => "NW_003315944.2", :role => "alt-scaffold", :ucscStyleName => "chr15_GL383555v2_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "15", :genbankAccession => "KI270848.1", :length => 327382, :refseqAccession => "NT_187603.1", :role => "alt-scaffold", :ucscStyleName => "chr15_KI270848v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "15", :genbankAccession => "KI270849.1", :length => 244917, :refseqAccession => "NT_187605.1", :role => "alt-scaffold", :ucscStyleName => "chr15_KI270849v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "15", :genbankAccession => "KI270850.1", :length => 430880, :refseqAccession => "NT_187606.1", :role => "alt-scaffold", :ucscStyleName => "chr15_KI270850v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "15", :genbankAccession => "KI270851.1", :length => 263054, :refseqAccession => "NT_187604.1", :role => "alt-scaffold", :ucscStyleName => "chr15_KI270851v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "15", :genbankAccession => "KI270852.1", :length => 478999, :refseqAccession => "NT_187602.1", :role => "alt-scaffold", :ucscStyleName => "chr15_KI270852v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "16", :genbankAccession => "GL383556.1", :length => 192462, :refseqAccession => "NW_003315945.1", :role => "alt-scaffold", :ucscStyleName => "chr16_GL383556v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "16", :genbankAccession => "GL383557.1", :length => 89672, :refseqAccession => "NW_003315946.1", :role => "alt-scaffold", :ucscStyleName => "chr16_GL383557v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "16", :genbankAccession => "KI270853.1", :length => 2659700, :refseqAccession => "NT_187607.1", :role => "alt-scaffold", :ucscStyleName => "chr16_KI270853v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "16", :genbankAccession => "KI270854.1", :length => 134193, :refseqAccession => "NT_187610.1", :role => "alt-scaffold", :ucscStyleName => "chr16_KI270854v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "16", :genbankAccession => "KI270855.1", :length => 232857, :refseqAccession => "NT_187608.1", :role => "alt-scaffold", :ucscStyleName => "chr16_KI270855v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "16", :genbankAccession => "KI270856.1", :length => 63982, :refseqAccession => "NT_187609.1", :role => "alt-scaffold", :ucscStyleName => "chr16_KI270856v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "GL000258.2", :length => 1821992, :refseqAccession => "NT_167251.2", :role => "alt-scaffold", :ucscStyleName => "chr17_GL000258v2_alt",:unlocalizedCount => 3},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "GL383563.3", :length => 375691, :refseqAccession => "NW_003315952.3", :role => "alt-scaffold", :ucscStyleName => "chr17_GL383563v3_alt",:unlocalizedCount => 3},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "GL383564.2", :length => 133151, :refseqAccession => "NW_003315953.2", :role => "alt-scaffold", :ucscStyleName => "chr17_GL383564v2_alt",:unlocalizedCount => 3},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "GL383565.1", :length => 223995, :refseqAccession => "NW_003315954.1", :role => "alt-scaffold", :ucscStyleName => "chr17_GL383565v1_alt",:unlocalizedCount => 3},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "GL383566.1", :length => 90219, :refseqAccession => "NW_003315955.1", :role => "alt-scaffold", :ucscStyleName => "chr17_GL383566v1_alt",:unlocalizedCount => 3},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "JH159146.1", :length => 278131, :refseqAccession => "NW_003871091.1", :role => "alt-scaffold", :ucscStyleName => "chr17_JH159146v1_alt",:unlocalizedCount => 3},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "JH159147.1", :length => 70345, :refseqAccession => "NW_003871092.1", :role => "alt-scaffold", :ucscStyleName => "chr17_JH159147v1_alt",:unlocalizedCount => 3},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "KI270857.1", :length => 2877074, :refseqAccession => "NT_187614.1", :role => "alt-scaffold", :ucscStyleName => "chr17_KI270857v1_alt",:unlocalizedCount => 3},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "KI270858.1", :length => 235827, :refseqAccession => "NT_187615.1", :role => "alt-scaffold", :ucscStyleName => "chr17_KI270858v1_alt",:unlocalizedCount => 3},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "KI270859.1", :length => 108763, :refseqAccession => "NT_187616.1", :role => "alt-scaffold", :ucscStyleName => "chr17_KI270859v1_alt",:unlocalizedCount => 3},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "KI270860.1", :length => 178921, :refseqAccession => "NT_187612.1", :role => "alt-scaffold", :ucscStyleName => "chr17_KI270860v1_alt",:unlocalizedCount => 3},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "KI270861.1", :length => 196688, :refseqAccession => "NT_187611.1", :role => "alt-scaffold", :ucscStyleName => "chr17_KI270861v1_alt",:unlocalizedCount => 3},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "KI270862.1", :length => 391357, :refseqAccession => "NT_187613.1", :role => "alt-scaffold", :ucscStyleName => "chr17_KI270862v1_alt",:unlocalizedCount => 3},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "18", :genbankAccession => "GL383567.1", :length => 289831, :refseqAccession => "NW_003315956.1", :role => "alt-scaffold", :ucscStyleName => "chr18_GL383567v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "18", :genbankAccession => "GL383568.1", :length => 104552, :refseqAccession => "NW_003315957.1", :role => "alt-scaffold", :ucscStyleName => "chr18_GL383568v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "18", :genbankAccession => "GL383569.1", :length => 167950, :refseqAccession => "NW_003315958.1", :role => "alt-scaffold", :ucscStyleName => "chr18_GL383569v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "18", :genbankAccession => "GL383570.1", :length => 164789, :refseqAccession => "NW_003315959.1", :role => "alt-scaffold", :ucscStyleName => "chr18_GL383570v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "18", :genbankAccession => "GL383571.1", :length => 198278, :refseqAccession => "NW_003315960.1", :role => "alt-scaffold", :ucscStyleName => "chr18_GL383571v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "18", :genbankAccession => "GL383572.1", :length => 159547, :refseqAccession => "NW_003315961.1", :role => "alt-scaffold", :ucscStyleName => "chr18_GL383572v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "18", :genbankAccession => "KI270863.1", :length => 167999, :refseqAccession => "NT_187617.1", :role => "alt-scaffold", :ucscStyleName => "chr18_KI270863v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "18", :genbankAccession => "KI270864.1", :length => 111737, :refseqAccession => "NT_187618.1", :role => "alt-scaffold", :ucscStyleName => "chr18_KI270864v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "GL383573.1", :length => 385657, :refseqAccession => "NW_003315962.1", :role => "alt-scaffold", :ucscStyleName => "chr19_GL383573v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "GL383574.1", :length => 155864, :refseqAccession => "NW_003315963.1", :role => "alt-scaffold", :ucscStyleName => "chr19_GL383574v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "GL383575.2", :length => 170222, :refseqAccession => "NW_003315964.2", :role => "alt-scaffold", :ucscStyleName => "chr19_GL383575v2_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "GL383576.1", :length => 188024, :refseqAccession => "NW_003315965.1", :role => "alt-scaffold", :ucscStyleName => "chr19_GL383576v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "GL949746.1", :length => 987716, :refseqAccession => "NW_003571054.1", :role => "alt-scaffold", :ucscStyleName => "chr19_GL949746v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KI270865.1", :length => 52969, :refseqAccession => "NT_187621.1", :role => "alt-scaffold", :ucscStyleName => "chr19_KI270865v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KI270866.1", :length => 43156, :refseqAccession => "NT_187619.1", :role => "alt-scaffold", :ucscStyleName => "chr19_KI270866v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KI270867.1", :length => 233762, :refseqAccession => "NT_187620.1", :role => "alt-scaffold", :ucscStyleName => "chr19_KI270867v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KI270868.1", :length => 61734, :refseqAccession => "NT_187622.1", :role => "alt-scaffold", :ucscStyleName => "chr19_KI270868v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "20", :genbankAccession => "GL383577.2", :length => 128386, :refseqAccession => "NW_003315966.2", :role => "alt-scaffold", :ucscStyleName => "chr20_GL383577v2_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "20", :genbankAccession => "KI270869.1", :length => 118774, :refseqAccession => "NT_187623.1", :role => "alt-scaffold", :ucscStyleName => "chr20_KI270869v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "20", :genbankAccession => "KI270870.1", :length => 183433, :refseqAccession => "NT_187624.1", :role => "alt-scaffold", :ucscStyleName => "chr20_KI270870v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "20", :genbankAccession => "KI270871.1", :length => 58661, :refseqAccession => "NT_187625.1", :role => "alt-scaffold", :ucscStyleName => "chr20_KI270871v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "21", :genbankAccession => "GL383578.2", :length => 63917, :refseqAccession => "NW_003315967.2", :role => "alt-scaffold", :ucscStyleName => "chr21_GL383578v2_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "21", :genbankAccession => "GL383579.2", :length => 201197, :refseqAccession => "NW_003315968.2", :role => "alt-scaffold", :ucscStyleName => "chr21_GL383579v2_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "21", :genbankAccession => "GL383580.2", :length => 74653, :refseqAccession => "NW_003315969.2", :role => "alt-scaffold", :ucscStyleName => "chr21_GL383580v2_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "21", :genbankAccession => "GL383581.2", :length => 116689, :refseqAccession => "NW_003315970.2", :role => "alt-scaffold", :ucscStyleName => "chr21_GL383581v2_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "21", :genbankAccession => "KI270872.1", :length => 82692, :refseqAccession => "NT_187626.1", :role => "alt-scaffold", :ucscStyleName => "chr21_KI270872v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "21", :genbankAccession => "KI270873.1", :length => 143900, :refseqAccession => "NT_187627.1", :role => "alt-scaffold", :ucscStyleName => "chr21_KI270873v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "21", :genbankAccession => "KI270874.1", :length => 166743, :refseqAccession => "NT_187628.1", :role => "alt-scaffold", :ucscStyleName => "chr21_KI270874v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "22", :genbankAccession => "GL383582.2", :length => 162811, :refseqAccession => "NW_003315971.2", :role => "alt-scaffold", :ucscStyleName => "chr22_GL383582v2_alt",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "22", :genbankAccession => "GL383583.2", :length => 96924, :refseqAccession => "NW_003315972.2", :role => "alt-scaffold", :ucscStyleName => "chr22_GL383583v2_alt",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "22", :genbankAccession => "KI270875.1", :length => 259914, :refseqAccession => "NT_187629.1", :role => "alt-scaffold", :ucscStyleName => "chr22_KI270875v1_alt",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "22", :genbankAccession => "KI270876.1", :length => 263666, :refseqAccession => "NT_187630.1", :role => "alt-scaffold", :ucscStyleName => "chr22_KI270876v1_alt",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "22", :genbankAccession => "KI270877.1", :length => 101331, :refseqAccession => "NT_187631.1", :role => "alt-scaffold", :ucscStyleName => "chr22_KI270877v1_alt",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "22", :genbankAccession => "KI270878.1", :length => 186262, :refseqAccession => "NT_187632.1", :role => "alt-scaffold", :ucscStyleName => "chr22_KI270878v1_alt",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "22", :genbankAccession => "KI270879.1", :length => 304135, :refseqAccession => "NT_187633.1", :role => "alt-scaffold", :ucscStyleName => "chr22_KI270879v1_alt",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "X", :genbankAccession => "KI270880.1", :length => 284869, :refseqAccession => "NT_187634.1", :role => "alt-scaffold", :ucscStyleName => "chrX_KI270880v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_1", :assignedMoleculeLocationType => "Chromosome", :chrName => "X", :genbankAccession => "KI270881.1", :length => 144206, :refseqAccession => "NT_187635.1", :role => "alt-scaffold", :ucscStyleName => "chrX_KI270881v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_2", :assignedMoleculeLocationType => "Chromosome", :chrName => "1", :genbankAccession => "KI270892.1", :length => 162212, :refseqAccession => "NT_187646.1", :role => "alt-scaffold", :ucscStyleName => "chr1_KI270892v1_alt",:unlocalizedCount => 9},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_2", :assignedMoleculeLocationType => "Chromosome", :chrName => "2", :genbankAccession => "KI270893.1", :length => 161218, :refseqAccession => "NT_187647.1", :role => "alt-scaffold", :ucscStyleName => "chr2_KI270893v1_alt",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_2", :assignedMoleculeLocationType => "Chromosome", :chrName => "2", :genbankAccession => "KI270894.1", :length => 214158, :refseqAccession => "NT_187648.1", :role => "alt-scaffold", :ucscStyleName => "chr2_KI270894v1_alt",:unlocalizedCount => 2},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_2", :assignedMoleculeLocationType => "Chromosome", :chrName => "3", :genbankAccession => "KI270895.1", :length => 162896, :refseqAccession => "NT_187649.1", :role => "alt-scaffold", :ucscStyleName => "chr3_KI270895v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_2", :assignedMoleculeLocationType => "Chromosome", :chrName => "4", :genbankAccession => "KI270896.1", :length => 378547, :refseqAccession => "NT_187650.1", :role => "alt-scaffold", :ucscStyleName => "chr4_KI270896v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_2", :assignedMoleculeLocationType => "Chromosome", :chrName => "5", :genbankAccession => "KI270897.1", :length => 1144418, :refseqAccession => "NT_187651.1", :role => "alt-scaffold", :ucscStyleName => "chr5_KI270897v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_2", :assignedMoleculeLocationType => "Chromosome", :chrName => "5", :genbankAccession => "KI270898.1", :length => 130957, :refseqAccession => "NT_187652.1", :role => "alt-scaffold", :ucscStyleName => "chr5_KI270898v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_2", :assignedMoleculeLocationType => "Chromosome", :chrName => "6", :genbankAccession => "GL000251.2", :length => 4795265, :refseqAccession => "NT_113891.3", :role => "alt-scaffold", :ucscStyleName => "chr6_GL000251v2_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_2", :assignedMoleculeLocationType => "Chromosome", :chrName => "7", :genbankAccession => "KI270899.1", :length => 190869, :refseqAccession => "NT_187653.1", :role => "alt-scaffold", :ucscStyleName => "chr7_KI270899v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_2", :assignedMoleculeLocationType => "Chromosome", :chrName => "8", :genbankAccession => "KI270900.1", :length => 318687, :refseqAccession => "NT_187654.1", :role => "alt-scaffold", :ucscStyleName => "chr8_KI270900v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_2", :assignedMoleculeLocationType => "Chromosome", :chrName => "8", :genbankAccession => "KI270901.1", :length => 136959, :refseqAccession => "NT_187655.1", :role => "alt-scaffold", :ucscStyleName => "chr8_KI270901v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_2", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "KI270902.1", :length => 106711, :refseqAccession => "NT_187656.1", :role => "alt-scaffold", :ucscStyleName => "chr11_KI270902v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_2", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "KI270903.1", :length => 214625, :refseqAccession => "NT_187657.1", :role => "alt-scaffold", :ucscStyleName => "chr11_KI270903v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_2", :assignedMoleculeLocationType => "Chromosome", :chrName => "12", :genbankAccession => "KI270904.1", :length => 572349, :refseqAccession => "NT_187658.1", :role => "alt-scaffold", :ucscStyleName => "chr12_KI270904v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_2", :assignedMoleculeLocationType => "Chromosome", :chrName => "15", :genbankAccession => "KI270905.1", :length => 5161414, :refseqAccession => "NT_187660.1", :role => "alt-scaffold", :ucscStyleName => "chr15_KI270905v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_2", :assignedMoleculeLocationType => "Chromosome", :chrName => "15", :genbankAccession => "KI270906.1", :length => 196384, :refseqAccession => "NT_187659.1", :role => "alt-scaffold", :ucscStyleName => "chr15_KI270906v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_2", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "JH159148.1", :length => 88070, :refseqAccession => "NW_003871093.1", :role => "alt-scaffold", :ucscStyleName => "chr17_JH159148v1_alt",:unlocalizedCount => 3},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_2", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "KI270907.1", :length => 137721, :refseqAccession => "NT_187662.1", :role => "alt-scaffold", :ucscStyleName => "chr17_KI270907v1_alt",:unlocalizedCount => 3},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_2", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "KI270908.1", :length => 1423190, :refseqAccession => "NT_187663.1", :role => "alt-scaffold", :ucscStyleName => "chr17_KI270908v1_alt",:unlocalizedCount => 3},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_2", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "KI270909.1", :length => 325800, :refseqAccession => "NT_187661.1", :role => "alt-scaffold", :ucscStyleName => "chr17_KI270909v1_alt",:unlocalizedCount => 3},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_2", :assignedMoleculeLocationType => "Chromosome", :chrName => "17", :genbankAccession => "KI270910.1", :length => 157099, :refseqAccession => "NT_187664.1", :role => "alt-scaffold", :ucscStyleName => "chr17_KI270910v1_alt",:unlocalizedCount => 3},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_2", :assignedMoleculeLocationType => "Chromosome", :chrName => "18", :genbankAccession => "KI270911.1", :length => 157710, :refseqAccession => "NT_187666.1", :role => "alt-scaffold", :ucscStyleName => "chr18_KI270911v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_2", :assignedMoleculeLocationType => "Chromosome", :chrName => "18", :genbankAccession => "KI270912.1", :length => 174061, :refseqAccession => "NT_187665.1", :role => "alt-scaffold", :ucscStyleName => "chr18_KI270912v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_2", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "GL949747.2", :length => 729520, :refseqAccession => "NW_003571055.2", :role => "alt-scaffold", :ucscStyleName => "chr19_GL949747v2_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_2", :assignedMoleculeLocationType => "Chromosome", :chrName => "22", :genbankAccession => "KB663609.1", :length => 74013, :refseqAccession => "NW_004504305.1", :role => "alt-scaffold", :ucscStyleName => "chr22_KB663609v1_alt",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_2", :assignedMoleculeLocationType => "Chromosome", :chrName => "X", :genbankAccession => "KI270913.1", :length => 274009, :refseqAccession => "NT_187667.1", :role => "alt-scaffold", :ucscStyleName => "chrX_KI270913v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_3", :assignedMoleculeLocationType => "Chromosome", :chrName => "3", :genbankAccession => "KI270924.1", :length => 166540, :refseqAccession => "NT_187678.1", :role => "alt-scaffold", :ucscStyleName => "chr3_KI270924v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_3", :assignedMoleculeLocationType => "Chromosome", :chrName => "4", :genbankAccession => "KI270925.1", :length => 555799, :refseqAccession => "NT_187679.1", :role => "alt-scaffold", :ucscStyleName => "chr4_KI270925v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_3", :assignedMoleculeLocationType => "Chromosome", :chrName => "6", :genbankAccession => "GL000252.2", :length => 4604811, :refseqAccession => "NT_167245.2", :role => "alt-scaffold", :ucscStyleName => "chr6_GL000252v2_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_3", :assignedMoleculeLocationType => "Chromosome", :chrName => "8", :genbankAccession => "KI270926.1", :length => 229282, :refseqAccession => "NT_187680.1", :role => "alt-scaffold", :ucscStyleName => "chr8_KI270926v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_3", :assignedMoleculeLocationType => "Chromosome", :chrName => "11", :genbankAccession => "KI270927.1", :length => 218612, :refseqAccession => "NT_187681.1", :role => "alt-scaffold", :ucscStyleName => "chr11_KI270927v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_3", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "GL949748.2", :length => 1064304, :refseqAccession => "NW_003571056.2", :role => "alt-scaffold", :ucscStyleName => "chr19_GL949748v2_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_3", :assignedMoleculeLocationType => "Chromosome", :chrName => "22", :genbankAccession => "KI270928.1", :length => 176103, :refseqAccession => "NT_187682.1", :role => "alt-scaffold", :ucscStyleName => "chr22_KI270928v1_alt",:unlocalizedCount => 8},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_4", :assignedMoleculeLocationType => "Chromosome", :chrName => "3", :genbankAccession => "KI270934.1", :length => 163458, :refseqAccession => "NT_187688.1", :role => "alt-scaffold", :ucscStyleName => "chr3_KI270934v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_4", :assignedMoleculeLocationType => "Chromosome", :chrName => "6", :genbankAccession => "GL000253.2", :length => 4677643, :refseqAccession => "NT_167246.2", :role => "alt-scaffold", :ucscStyleName => "chr6_GL000253v2_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_4", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "GL949749.2", :length => 1091841, :refseqAccession => "NW_003571057.2", :role => "alt-scaffold", :ucscStyleName => "chr19_GL949749v2_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_5", :assignedMoleculeLocationType => "Chromosome", :chrName => "3", :genbankAccession => "KI270935.1", :length => 197351, :refseqAccession => "NT_187689.1", :role => "alt-scaffold", :ucscStyleName => "chr3_KI270935v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_5", :assignedMoleculeLocationType => "Chromosome", :chrName => "6", :genbankAccession => "GL000254.2", :length => 4827813, :refseqAccession => "NT_167247.2", :role => "alt-scaffold", :ucscStyleName => "chr6_GL000254v2_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_5", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "GL949750.2", :length => 1066390, :refseqAccession => "NW_003571058.2", :role => "alt-scaffold", :ucscStyleName => "chr19_GL949750v2_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_6", :assignedMoleculeLocationType => "Chromosome", :chrName => "3", :genbankAccession => "KI270936.1", :length => 164170, :refseqAccession => "NT_187690.1", :role => "alt-scaffold", :ucscStyleName => "chr3_KI270936v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_6", :assignedMoleculeLocationType => "Chromosome", :chrName => "6", :genbankAccession => "GL000255.2", :length => 4606388, :refseqAccession => "NT_167248.2", :role => "alt-scaffold", :ucscStyleName => "chr6_GL000255v2_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_6", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "GL949751.2", :length => 1002683, :refseqAccession => "NW_003571059.2", :role => "alt-scaffold", :ucscStyleName => "chr19_GL949751v2_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_7", :assignedMoleculeLocationType => "Chromosome", :chrName => "3", :genbankAccession => "KI270937.1", :length => 165607, :refseqAccession => "NT_187691.1", :role => "alt-scaffold", :ucscStyleName => "chr3_KI270937v1_alt",:unlocalizedCount => 1},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_7", :assignedMoleculeLocationType => "Chromosome", :chrName => "6", :genbankAccession => "GL000256.2", :length => 4929269, :refseqAccession => "NT_167249.2", :role => "alt-scaffold", :ucscStyleName => "chr6_GL000256v2_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_7", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "GL949752.1", :length => 987100, :refseqAccession => "NW_003571060.1", :role => "alt-scaffold", :ucscStyleName => "chr19_GL949752v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_8", :assignedMoleculeLocationType => "Chromosome", :chrName => "6", :genbankAccession => "KI270758.1", :length => 76752, :refseqAccession => "NT_187692.1", :role => "alt-scaffold", :ucscStyleName => "chr6_KI270758v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_8", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "GL949753.2", :length => 796479, :refseqAccession => "NW_003571061.2", :role => "alt-scaffold", :ucscStyleName => "chr19_GL949753v2_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_9", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KI270938.1", :length => 1066800, :refseqAccession => "NT_187693.1", :role => "alt-scaffold", :ucscStyleName => "chr19_KI270938v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_10", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KI270882.1", :length => 248807, :refseqAccession => "NT_187636.1", :role => "alt-scaffold", :ucscStyleName => "chr19_KI270882v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_11", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KI270883.1", :length => 170399, :refseqAccession => "NT_187637.1", :role => "alt-scaffold", :ucscStyleName => "chr19_KI270883v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_12", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KI270884.1", :length => 157053, :refseqAccession => "NT_187638.1", :role => "alt-scaffold", :ucscStyleName => "chr19_KI270884v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_13", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KI270885.1", :length => 171027, :refseqAccession => "NT_187639.1", :role => "alt-scaffold", :ucscStyleName => "chr19_KI270885v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_14", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KI270886.1", :length => 204239, :refseqAccession => "NT_187640.1", :role => "alt-scaffold", :ucscStyleName => "chr19_KI270886v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_15", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KI270887.1", :length => 209512, :refseqAccession => "NT_187641.1", :role => "alt-scaffold", :ucscStyleName => "chr19_KI270887v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_16", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KI270888.1", :length => 155532, :refseqAccession => "NT_187642.1", :role => "alt-scaffold", :ucscStyleName => "chr19_KI270888v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_17", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KI270889.1", :length => 170698, :refseqAccession => "NT_187643.1", :role => "alt-scaffold", :ucscStyleName => "chr19_KI270889v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_18", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KI270890.1", :length => 184499, :refseqAccession => "NT_187644.1", :role => "alt-scaffold", :ucscStyleName => "chr19_KI270890v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_19", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KI270891.1", :length => 170680, :refseqAccession => "NT_187645.1", :role => "alt-scaffold", :ucscStyleName => "chr19_KI270891v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_20", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KI270914.1", :length => 205194, :refseqAccession => "NT_187668.1", :role => "alt-scaffold", :ucscStyleName => "chr19_KI270914v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_21", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KI270915.1", :length => 170665, :refseqAccession => "NT_187669.1", :role => "alt-scaffold", :ucscStyleName => "chr19_KI270915v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_22", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KI270916.1", :length => 184516, :refseqAccession => "NT_187670.1", :role => "alt-scaffold", :ucscStyleName => "chr19_KI270916v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_23", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KI270917.1", :length => 190932, :refseqAccession => "NT_187671.1", :role => "alt-scaffold", :ucscStyleName => "chr19_KI270917v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_24", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KI270918.1", :length => 123111, :refseqAccession => "NT_187672.1", :role => "alt-scaffold", :ucscStyleName => "chr19_KI270918v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_25", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KI270919.1", :length => 170701, :refseqAccession => "NT_187673.1", :role => "alt-scaffold", :ucscStyleName => "chr19_KI270919v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_26", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KI270920.1", :length => 198005, :refseqAccession => "NT_187674.1", :role => "alt-scaffold", :ucscStyleName => "chr19_KI270920v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_27", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KI270921.1", :length => 282224, :refseqAccession => "NT_187675.1", :role => "alt-scaffold", :ucscStyleName => "chr19_KI270921v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_28", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KI270922.1", :length => 187935, :refseqAccession => "NT_187676.1", :role => "alt-scaffold", :ucscStyleName => "chr19_KI270922v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_29", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KI270923.1", :length => 189352, :refseqAccession => "NT_187677.1", :role => "alt-scaffold", :ucscStyleName => "chr19_KI270923v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_30", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KI270929.1", :length => 186203, :refseqAccession => "NT_187683.1", :role => "alt-scaffold", :ucscStyleName => "chr19_KI270929v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_31", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KI270930.1", :length => 200773, :refseqAccession => "NT_187684.1", :role => "alt-scaffold", :ucscStyleName => "chr19_KI270930v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_32", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KI270931.1", :length => 170148, :refseqAccession => "NT_187685.1", :role => "alt-scaffold", :ucscStyleName => "chr19_KI270931v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_33", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KI270932.1", :length => 215732, :refseqAccession => "NT_187686.1", :role => "alt-scaffold", :ucscStyleName => "chr19_KI270932v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_34", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "KI270933.1", :length => 170537, :refseqAccession => "NT_187687.1", :role => "alt-scaffold", :ucscStyleName => "chr19_KI270933v1_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "ALT_REF_LOCI_35", :assignedMoleculeLocationType => "Chromosome", :chrName => "19", :genbankAccession => "GL000209.2", :length => 177381, :refseqAccession => "NT_113949.2", :role => "alt-scaffold", :ucscStyleName => "chr19_GL000209v2_alt"},
	{:assemblyAccession => "GCF_000001405.40", :assemblyUnit => "non-nuclear", :assignedMoleculeLocationType => "Mitochondrion", :chrName => "MT","gcCount":"7350","gcPercent":44.0, :genbankAccession => "J01415.2", :length => 16569, :refseqAccession => "NC_012920.1", :role => "assembled-molecule", :ucscStyleName => "chrM"}
]

### 1000 Genomes etc
## BioSamples from PRJNA28889 https://ncbi.nlm.nih.gov/bioproject/28889
$defined_samples_h =
{
	:HG02525 =>
	{
		:biosample_accession => "SAMN01780187",
		:sex => "female",
		:population_code => "HG02525"
	},
	:HG02524 =>
	{
		:biosample_accession => "SAMN01780186",
		:sex => "male",
		:population_code => "HG02524"
	},
	:HG04303 =>
	{
		:biosample_accession => "SAMN01780185",
		:sex => "female",
		:population_code => "HG04303"
	},
	:HG04302 =>
	{
		:biosample_accession => "SAMN01780184",
		:sex => "male",
		:population_code => "HG04302"
	},
	:HG04301 =>
	{
		:biosample_accession => "SAMN01780183",
		:sex => "female",
		:population_code => "HG04301"
	},
	:HG02218 =>
	{
		:biosample_accession => "SAMN01761637",
		:sex => "female",
		:population_code => "HG02218"
	},
	:HG02219 =>
	{
		:biosample_accession => "SAMN01761636",
		:sex => "male",
		:population_code => "HG02219"
	},
	:HG01786 =>
	{
		:biosample_accession => "SAMN01761634",
		:sex => "female",
		:population_code => "HG01786"
	},
	:HG01785 =>
	{
		:biosample_accession => "SAMN01761633",
		:sex => "male",
		:population_code => "HG01785"
	},
	:HG01768 =>
	{
		:biosample_accession => "SAMN01761631",
		:sex => "female",
		:population_code => "HG01768"
	},
	:HG01767 =>
	{
		:biosample_accession => "SAMN01761630",
		:sex => "male",
		:population_code => "HG01767"
	},
	:HG01766 =>
	{
		:biosample_accession => "SAMN01761628",
		:sex => "female",
		:population_code => "HG01766"
	},
	:HG01765 =>
	{
		:biosample_accession => "SAMN01761627",
		:sex => "male",
		:population_code => "HG01765"
	},
	:HG00304 =>
	{
		:biosample_accession => "SAMN01761624",
		:sex => "female",
		:population_code => "HG00304"
	},
	:HG00303 =>
	{
		:biosample_accession => "SAMN01761623",
		:sex => "male",
		:population_code => "HG00303"
	},
	:HG00302 =>
	{
		:biosample_accession => "SAMN01761622",
		:sex => "female",
		:population_code => "HG00302"
	},
	:HG00290 =>
	{
		:biosample_accession => "SAMN01761613",
		:sex => "male",
		:population_code => "HG00290"
	},
	:HG00288 =>
	{
		:biosample_accession => "SAMN01761612",
		:sex => "female",
		:population_code => "HG00288"
	},
	:HG03967 =>
	{
		:biosample_accession => "SAMN01761603",
		:sex => "male",
		:population_code => "HG03967"
	},
	:HG03871 =>
	{
		:biosample_accession => "SAMN01761602",
		:sex => "male",
		:population_code => "HG03871"
	},
	:HG03868 =>
	{
		:biosample_accession => "SAMN01761601",
		:sex => "female",
		:population_code => "HG03868"
	},
	:HG04070 =>
	{
		:biosample_accession => "SAMN01761600",
		:sex => "female",
		:population_code => "HG04070"
	},
	:HG03965 =>
	{
		:biosample_accession => "SAMN01761599",
		:sex => "male",
		:population_code => "HG03965"
	},
	:HG03875 =>
	{
		:biosample_accession => "SAMN01761598",
		:sex => "male",
		:population_code => "HG03875"
	},
	:HG04238 =>
	{
		:biosample_accession => "SAMN01761597",
		:sex => "male",
		:population_code => "HG04238"
	},
	:HG04235 =>
	{
		:biosample_accession => "SAMN01761596",
		:sex => "male",
		:population_code => "HG04235"
	},
	:HG04225 =>
	{
		:biosample_accession => "SAMN01761595",
		:sex => "male",
		:population_code => "HG04225"
	},
	:HG04219 =>
	{
		:biosample_accession => "SAMN01761594",
		:sex => "male",
		:population_code => "HG04219"
	},
	:HG04239 =>
	{
		:biosample_accession => "SAMN01761593",
		:sex => "male",
		:population_code => "HG04239"
	},
	:HG04216 =>
	{
		:biosample_accession => "SAMN01761592",
		:sex => "female",
		:population_code => "HG04216"
	},
	:HG04214 =>
	{
		:biosample_accession => "SAMN01761591",
		:sex => "female",
		:population_code => "HG04214"
	},
	:HG04222 =>
	{
		:biosample_accession => "SAMN01761590",
		:sex => "male",
		:population_code => "HG04222"
	},
	:HG04212 =>
	{
		:biosample_accession => "SAMN01761589",
		:sex => "female",
		:population_code => "HG04212"
	},
	:HG04211 =>
	{
		:biosample_accession => "SAMN01761588",
		:sex => "male",
		:population_code => "HG04211"
	},
	:HG04202 =>
	{
		:biosample_accession => "SAMN01761587",
		:sex => "female",
		:population_code => "HG04202"
	},
	:HG04206 =>
	{
		:biosample_accession => "SAMN01761586",
		:sex => "male",
		:population_code => "HG04206"
	},
	:HG04200 =>
	{
		:biosample_accession => "SAMN01761584",
		:sex => "female",
		:population_code => "HG04200"
	},
	:HG04198 =>
	{
		:biosample_accession => "SAMN01761583",
		:sex => "male",
		:population_code => "HG04198"
	},
	:HG04209 =>
	{
		:biosample_accession => "SAMN01761582",
		:sex => "female",
		:population_code => "HG04209"
	},
	:HG03778 =>
	{
		:biosample_accession => "SAMN01761581",
		:sex => "male",
		:population_code => "HG03778"
	},
	:HG04098 =>
	{
		:biosample_accession => "SAMN01761580",
		:sex => "male",
		:population_code => "HG04098"
	},
	:HG04096 =>
	{
		:biosample_accession => "SAMN01761579",
		:sex => "male",
		:population_code => "HG04096"
	},
	:HG04094 =>
	{
		:biosample_accession => "SAMN01761578",
		:sex => "male",
		:population_code => "HG04094"
	},
	:HG04080 =>
	{
		:biosample_accession => "SAMN01761577",
		:sex => "male",
		:population_code => "HG04080"
	},
	:HG04076 =>
	{
		:biosample_accession => "SAMN01761576",
		:sex => "female",
		:population_code => "HG04076"
	},
	:HG04059 =>
	{
		:biosample_accession => "SAMN01761575",
		:sex => "female",
		:population_code => "HG04059"
	},
	:HG04058 =>
	{
		:biosample_accession => "SAMN01761574",
		:sex => "male",
		:population_code => "HG04058"
	},
	:HG04062 =>
	{
		:biosample_accession => "SAMN01761573",
		:sex => "female",
		:population_code => "HG04062"
	},
	:HG04061 =>
	{
		:biosample_accession => "SAMN01761572",
		:sex => "male",
		:population_code => "HG04061"
	},
	:HG04054 =>
	{
		:biosample_accession => "SAMN01761571",
		:sex => "female",
		:population_code => "HG04054"
	},
	:HG04056 =>
	{
		:biosample_accession => "SAMN01761570",
		:sex => "male",
		:population_code => "HG04056"
	},
	:HG04055 =>
	{
		:biosample_accession => "SAMN01761569",
		:sex => "male",
		:population_code => "HG04055"
	},
	:HG04053 =>
	{
		:biosample_accession => "SAMN01761568",
		:sex => "male",
		:population_code => "HG04053"
	},
	:HG04050 =>
	{
		:biosample_accession => "SAMN01761567",
		:sex => "female",
		:population_code => "HG04050"
	},
	:HG04090 =>
	{
		:biosample_accession => "SAMN01761566",
		:sex => "female",
		:population_code => "HG04090"
	},
	:HG04060 =>
	{
		:biosample_accession => "SAMN01761565",
		:sex => "male",
		:population_code => "HG04060"
	},
	:HG04023 =>
	{
		:biosample_accession => "SAMN01761564",
		:sex => "male",
		:population_code => "HG04023"
	},
	:HG04024 =>
	{
		:biosample_accession => "SAMN01761563",
		:sex => "female",
		:population_code => "HG04024"
	},
	:HG03969 =>
	{
		:biosample_accession => "SAMN01761562",
		:sex => "male",
		:population_code => "HG03969"
	},
	:HG03866 =>
	{
		:biosample_accession => "SAMN01761561",
		:sex => "male",
		:population_code => "HG03866"
	},
	:HG04001 =>
	{
		:biosample_accession => "SAMN01761560",
		:sex => "female",
		:population_code => "HG04001"
	},
	:HG03774 =>
	{
		:biosample_accession => "SAMN01761559",
		:sex => "female",
		:population_code => "HG03774"
	},
	:HG04106 =>
	{
		:biosample_accession => "SAMN01761535",
		:sex => "female",
		:population_code => "HG04106"
	},
	:HG04107 =>
	{
		:biosample_accession => "SAMN01761534",
		:sex => "male",
		:population_code => "HG04107"
	},
	:HG04047 =>
	{
		:biosample_accession => "SAMN01761533",
		:sex => "female",
		:population_code => "HG04047"
	},
	:HG04039 =>
	{
		:biosample_accession => "SAMN01761532",
		:sex => "male",
		:population_code => "HG04039"
	},
	:HG04038 =>
	{
		:biosample_accession => "SAMN01761531",
		:sex => "female",
		:population_code => "HG04038"
	},
	:HG04003 =>
	{
		:biosample_accession => "SAMN01761530",
		:sex => "male",
		:population_code => "HG04003"
	},
	:HG03998 =>
	{
		:biosample_accession => "SAMN01761529",
		:sex => "male",
		:population_code => "HG03998"
	},
	:HG03989 =>
	{
		:biosample_accession => "SAMN01761528",
		:sex => "female",
		:population_code => "HG03989"
	},
	:HG03988 =>
	{
		:biosample_accession => "SAMN01761527",
		:sex => "male",
		:population_code => "HG03988"
	},
	:HG03985 =>
	{
		:biosample_accession => "SAMN01761526",
		:sex => "male",
		:population_code => "HG03985"
	},
	:HG03991 =>
	{
		:biosample_accession => "SAMN01761525",
		:sex => "male",
		:population_code => "HG03991"
	},
	:HG03990 =>
	{
		:biosample_accession => "SAMN01761524",
		:sex => "male",
		:population_code => "HG03990"
	},
	:HG04114 =>
	{
		:biosample_accession => "SAMN01761523",
		:sex => "male",
		:population_code => "HG04114"
	},
	:HG03955 =>
	{
		:biosample_accession => "SAMN01761522",
		:sex => "female",
		:population_code => "HG03955"
	},
	:HG03945 =>
	{
		:biosample_accession => "SAMN01761521",
		:sex => "female",
		:population_code => "HG03945"
	},
	:HG04227 =>
	{
		:biosample_accession => "SAMN01761519",
		:sex => "female",
		:population_code => "HG04227"
	},
	:HG04229 =>
	{
		:biosample_accession => "SAMN01761518",
		:sex => "male",
		:population_code => "HG04229"
	},
	:HG04075 =>
	{
		:biosample_accession => "SAMN01761516",
		:sex => "female",
		:population_code => "HG04075"
	},
	:HG04127 =>
	{
		:biosample_accession => "SAMN01761515",
		:sex => "male",
		:population_code => "HG04127"
	},
	:HG04210 =>
	{
		:biosample_accession => "SAMN01761513",
		:sex => "male",
		:population_code => "HG04210"
	},
	:HG04100 =>
	{
		:biosample_accession => "SAMN01761511",
		:sex => "male",
		:population_code => "HG04100"
	},
	:HG03854 =>
	{
		:biosample_accession => "SAMN01761509",
		:sex => "male",
		:population_code => "HG03854"
	},
	:HG03857 =>
	{
		:biosample_accession => "SAMN01761508",
		:sex => "female",
		:population_code => "HG03857"
	},
	:HG03951 =>
	{
		:biosample_accession => "SAMN01761506",
		:sex => "female",
		:population_code => "HG03951"
	},
	:HG03899 =>
	{
		:biosample_accession => "SAMN01761503",
		:sex => "male",
		:population_code => "HG03899"
	},
	:HG03995 =>
	{
		:biosample_accession => "SAMN01761501",
		:sex => "female",
		:population_code => "HG03995"
	},
	:HG04195 =>
	{
		:biosample_accession => "SAMN01761497",
		:sex => "female",
		:population_code => "HG04195"
	},
	:HG04194 =>
	{
		:biosample_accession => "SAMN01761496",
		:sex => "male",
		:population_code => "HG04194"
	},
	:HG04189 =>
	{
		:biosample_accession => "SAMN01761495",
		:sex => "female",
		:population_code => "HG04189"
	},
	:HG04188 =>
	{
		:biosample_accession => "SAMN01761494",
		:sex => "male",
		:population_code => "HG04188"
	},
	:HG04177 =>
	{
		:biosample_accession => "SAMN01761493",
		:sex => "female",
		:population_code => "HG04177"
	},
	:HG04176 =>
	{
		:biosample_accession => "SAMN01761492",
		:sex => "male",
		:population_code => "HG04176"
	},
	:HG04171 =>
	{
		:biosample_accession => "SAMN01761491",
		:sex => "female",
		:population_code => "HG04171"
	},
	:HG04164 =>
	{
		:biosample_accession => "SAMN01761490",
		:sex => "male",
		:population_code => "HG04164"
	},
	:HG04162 =>
	{
		:biosample_accession => "SAMN01761489",
		:sex => "female",
		:population_code => "HG04162"
	},
	:HG04161 =>
	{
		:biosample_accession => "SAMN01761488",
		:sex => "male",
		:population_code => "HG04161"
	},
	:HG04153 =>
	{
		:biosample_accession => "SAMN01761487",
		:sex => "female",
		:population_code => "HG04153"
	},
	:HG04152 =>
	{
		:biosample_accession => "SAMN01761486",
		:sex => "male",
		:population_code => "HG04152"
	},
	:HG04144 =>
	{
		:biosample_accession => "SAMN01761485",
		:sex => "female",
		:population_code => "HG04144"
	},
	:HG04128 =>
	{
		:biosample_accession => "SAMN01761484",
		:sex => "male",
		:population_code => "HG04128"
	},
	:HG03920 =>
	{
		:biosample_accession => "SAMN01761483",
		:sex => "male",
		:population_code => "HG03920"
	},
	:HG03917 =>
	{
		:biosample_accession => "SAMN01761482",
		:sex => "male",
		:population_code => "HG03917"
	},
	:HG03611 =>
	{
		:biosample_accession => "SAMN01761481",
		:sex => "female",
		:population_code => "HG03611"
	},
	:HG03604 =>
	{
		:biosample_accession => "SAMN01761480",
		:sex => "female",
		:population_code => "HG03604"
	},
	:HG03603 =>
	{
		:biosample_accession => "SAMN01761479",
		:sex => "male",
		:population_code => "HG03603"
	},
	:HG03600 =>
	{
		:biosample_accession => "SAMN01761477",
		:sex => "male",
		:population_code => "HG03600"
	},
	:HG04180 =>
	{
		:biosample_accession => "SAMN01761475",
		:sex => "female",
		:population_code => "HG04180"
	},
	:HG03922 =>
	{
		:biosample_accession => "SAMN01761473",
		:sex => "female",
		:population_code => "HG03922"
	},
	:HG03901 =>
	{
		:biosample_accession => "SAMN01761471",
		:sex => "female",
		:population_code => "HG03901"
	},
	:HG03821 =>
	{
		:biosample_accession => "SAMN01761469",
		:sex => "male",
		:population_code => "HG03821"
	},
	:HG03811 =>
	{
		:biosample_accession => "SAMN01761467",
		:sex => "female",
		:population_code => "HG03811"
	},
	:HG04183 =>
	{
		:biosample_accession => "SAMN01761465",
		:sex => "female",
		:population_code => "HG04183"
	},
	:HG04182 =>
	{
		:biosample_accession => "SAMN01761464",
		:sex => "male",
		:population_code => "HG04182"
	},
	:HG04174 =>
	{
		:biosample_accession => "SAMN01761462",
		:sex => "female",
		:population_code => "HG04174"
	},
	:HG04173 =>
	{
		:biosample_accession => "SAMN01761461",
		:sex => "male",
		:population_code => "HG04173"
	},
	:HG04141 =>
	{
		:biosample_accession => "SAMN01761459",
		:sex => "female",
		:population_code => "HG04141"
	},
	:HG04140 =>
	{
		:biosample_accession => "SAMN01761458",
		:sex => "male",
		:population_code => "HG04140"
	},
	:HG04135 =>
	{
		:biosample_accession => "SAMN01761456",
		:sex => "female",
		:population_code => "HG04135"
	},
	:HG04134 =>
	{
		:biosample_accession => "SAMN01761455",
		:sex => "male",
		:population_code => "HG04134"
	},
	:HG04132 =>
	{
		:biosample_accession => "SAMN01761453",
		:sex => "female",
		:population_code => "HG04132"
	},
	:HG04131 =>
	{
		:biosample_accession => "SAMN01761452",
		:sex => "male",
		:population_code => "HG04131"
	},
	:HG04191 =>
	{
		:biosample_accession => "SAMN01761450",
		:sex => "male",
		:population_code => "HG04191"
	},
	:HG04185 =>
	{
		:biosample_accession => "SAMN01761448",
		:sex => "male",
		:population_code => "HG04185"
	},
	:HG04158 =>
	{
		:biosample_accession => "SAMN01761446",
		:sex => "male",
		:population_code => "HG04158"
	},
	:HG04150 =>
	{
		:biosample_accession => "SAMN01761444",
		:sex => "female",
		:population_code => "HG04150"
	},
	:HG04147 =>
	{
		:biosample_accession => "SAMN01761442",
		:sex => "female",
		:population_code => "HG04147"
	},
	:HG03929 =>
	{
		:biosample_accession => "SAMN01761441",
		:sex => "male",
		:population_code => "HG03929"
	},
	:HG03904 =>
	{
		:biosample_accession => "SAMN01761439",
		:sex => "female",
		:population_code => "HG03904"
	},
	:HG03663 =>
	{
		:biosample_accession => "SAMN01761437",
		:sex => "male",
		:population_code => "HG03663"
	},
	:HG03660 =>
	{
		:biosample_accession => "SAMN01761436",
		:sex => "male",
		:population_code => "HG03660"
	},
	:HG03631 =>
	{
		:biosample_accession => "SAMN01761435",
		:sex => "female",
		:population_code => "HG03631"
	},
	:HG03629 =>
	{
		:biosample_accession => "SAMN01761434",
		:sex => "male",
		:population_code => "HG03629"
	},
	:HG03621 =>
	{
		:biosample_accession => "SAMN01761433",
		:sex => "male",
		:population_code => "HG03621"
	},
	:HG03022 =>
	{
		:biosample_accession => "SAMN01761432",
		:sex => "female",
		:population_code => "HG03022"
	},
	:HG03019 =>
	{
		:biosample_accession => "SAMN01761431",
		:sex => "female",
		:population_code => "HG03019"
	},
	:HG03018 =>
	{
		:biosample_accession => "SAMN01761430",
		:sex => "male",
		:population_code => "HG03018"
	},
	:HG02781 =>
	{
		:biosample_accession => "SAMN01761429",
		:sex => "female",
		:population_code => "HG02781"
	},
	:HG02780 =>
	{
		:biosample_accession => "SAMN01761428",
		:sex => "male",
		:population_code => "HG02780"
	},
	:HG02731 =>
	{
		:biosample_accession => "SAMN01761427",
		:sex => "female",
		:population_code => "HG02731"
	},
	:HG02694 =>
	{
		:biosample_accession => "SAMN01761426",
		:sex => "female",
		:population_code => "HG02694"
	},
	:HG01590 =>
	{
		:biosample_accession => "SAMN01761425",
		:sex => "female",
		:population_code => "HG01590"
	},
	:HG01589 =>
	{
		:biosample_accession => "SAMN01761424",
		:sex => "male",
		:population_code => "HG01589"
	},
	:HG01586 =>
	{
		:biosample_accession => "SAMN01761423",
		:sex => "male",
		:population_code => "HG01586"
	},
	:HG01583 =>
	{
		:biosample_accession => "SAMN01761422",
		:sex => "male",
		:population_code => "HG01583"
	},
	:HG03767 =>
	{
		:biosample_accession => "SAMN01761420",
		:sex => "male",
		:population_code => "HG03767"
	},
	:HG03765 =>
	{
		:biosample_accession => "SAMN01761418",
		:sex => "female",
		:population_code => "HG03765"
	},
	:HG03656 =>
	{
		:biosample_accession => "SAMN01761416",
		:sex => "female",
		:population_code => "HG03656"
	},
	:HG03636 =>
	{
		:biosample_accession => "SAMN01761414",
		:sex => "male",
		:population_code => "HG03636"
	},
	:HG03021 =>
	{
		:biosample_accession => "SAMN01761412",
		:sex => "male",
		:population_code => "HG03021"
	},
	:HG02778 =>
	{
		:biosample_accession => "SAMN01761410",
		:sex => "female",
		:population_code => "HG02778"
	},
	:HG02597 =>
	{
		:biosample_accession => "SAMN01761408",
		:sex => "male",
		:population_code => "HG02597"
	},
	:HG01593 =>
	{
		:biosample_accession => "SAMN01761406",
		:sex => "female",
		:population_code => "HG01593"
	},
	:HG03762 =>
	{
		:biosample_accession => "SAMN01761404",
		:sex => "female",
		:population_code => "HG03762"
	},
	:HG03761 =>
	{
		:biosample_accession => "SAMN01761403",
		:sex => "male",
		:population_code => "HG03761"
	},
	:HG03706 =>
	{
		:biosample_accession => "SAMN01761401",
		:sex => "female",
		:population_code => "HG03706"
	},
	:HG03705 =>
	{
		:biosample_accession => "SAMN01761400",
		:sex => "male",
		:population_code => "HG03705"
	},
	:HG03653 =>
	{
		:biosample_accession => "SAMN01761398",
		:sex => "female",
		:population_code => "HG03653"
	},
	:HG03652 =>
	{
		:biosample_accession => "SAMN01761397",
		:sex => "male",
		:population_code => "HG03652"
	},
	:HG03650 =>
	{
		:biosample_accession => "SAMN01761395",
		:sex => "female",
		:population_code => "HG03650"
	},
	:HG03649 =>
	{
		:biosample_accession => "SAMN01761394",
		:sex => "male",
		:population_code => "HG03649"
	},
	:HG03640 =>
	{
		:biosample_accession => "SAMN01761392",
		:sex => "female",
		:population_code => "HG03640"
	},
	:HG03639 =>
	{
		:biosample_accession => "SAMN01761391",
		:sex => "male",
		:population_code => "HG03639"
	},
	:HG03625 =>
	{
		:biosample_accession => "SAMN01761389",
		:sex => "female",
		:population_code => "HG03625"
	},
	:HG03624 =>
	{
		:biosample_accession => "SAMN01761388",
		:sex => "male",
		:population_code => "HG03624"
	},
	:HG03229 =>
	{
		:biosample_accession => "SAMN01761386",
		:sex => "female",
		:population_code => "HG03229"
	},
	:HG03228 =>
	{
		:biosample_accession => "SAMN01761385",
		:sex => "male",
		:population_code => "HG03228"
	},
	:HG02793 =>
	{
		:biosample_accession => "SAMN01761383",
		:sex => "female",
		:population_code => "HG02793"
	},
	:HG02792 =>
	{
		:biosample_accession => "SAMN01761382",
		:sex => "male",
		:population_code => "HG02792"
	},
	:HG02775 =>
	{
		:biosample_accession => "SAMN01761380",
		:sex => "female",
		:population_code => "HG02775"
	},
	:HG02774 =>
	{
		:biosample_accession => "SAMN01761379",
		:sex => "male",
		:population_code => "HG02774"
	},
	:HG02737 =>
	{
		:biosample_accession => "SAMN01761377",
		:sex => "female",
		:population_code => "HG02737"
	},
	:HG02736 =>
	{
		:biosample_accession => "SAMN01761376",
		:sex => "male",
		:population_code => "HG02736"
	},
	:HG02700 =>
	{
		:biosample_accession => "SAMN01761374",
		:sex => "female",
		:population_code => "HG02700"
	},
	:HG02699 =>
	{
		:biosample_accession => "SAMN01761373",
		:sex => "male",
		:population_code => "HG02699"
	},
	:HG02691 =>
	{
		:biosample_accession => "SAMN01761371",
		:sex => "female",
		:population_code => "HG02691"
	},
	:HG02690 =>
	{
		:biosample_accession => "SAMN01761370",
		:sex => "male",
		:population_code => "HG02690"
	},
	:HG02682 =>
	{
		:biosample_accession => "SAMN01761368",
		:sex => "female",
		:population_code => "HG02682"
	},
	:HG02681 =>
	{
		:biosample_accession => "SAMN01761367",
		:sex => "male",
		:population_code => "HG02681"
	},
	:HG02652 =>
	{
		:biosample_accession => "SAMN01761365",
		:sex => "female",
		:population_code => "HG02652"
	},
	:HG02651 =>
	{
		:biosample_accession => "SAMN01761364",
		:sex => "male",
		:population_code => "HG02651"
	},
	:HG02649 =>
	{
		:biosample_accession => "SAMN01761362",
		:sex => "female",
		:population_code => "HG02649"
	},
	:HG02648 =>
	{
		:biosample_accession => "SAMN01761361",
		:sex => "male",
		:population_code => "HG02648"
	},
	:HG02494 =>
	{
		:biosample_accession => "SAMN01761359",
		:sex => "female",
		:population_code => "HG02494"
	},
	:HG02493 =>
	{
		:biosample_accession => "SAMN01761358",
		:sex => "male",
		:population_code => "HG02493"
	},
	:HG03521 =>
	{
		:biosample_accession => "SAMN01761354",
		:sex => "male",
		:population_code => "HG03521"
	},
	:HG03520 =>
	{
		:biosample_accession => "SAMN01761353",
		:sex => "female",
		:population_code => "HG03520"
	},
	:HG03518 =>
	{
		:biosample_accession => "SAMN01761351",
		:sex => "male",
		:population_code => "HG03518"
	},
	:HG03517 =>
	{
		:biosample_accession => "SAMN01761350",
		:sex => "female",
		:population_code => "HG03517"
	},
	:HG03511 =>
	{
		:biosample_accession => "SAMN01761348",
		:sex => "female",
		:population_code => "HG03511"
	},
	:HG03508 =>
	{
		:biosample_accession => "SAMN01761346",
		:sex => "female",
		:population_code => "HG03508"
	},
	:HG03499 =>
	{
		:biosample_accession => "SAMN01761345",
		:sex => "female",
		:population_code => "HG03499"
	},
	:HG03493 =>
	{
		:biosample_accession => "SAMN01761344",
		:sex => "female",
		:population_code => "HG03493"
	},
	:HG03373 =>
	{
		:biosample_accession => "SAMN01761342",
		:sex => "male",
		:population_code => "HG03373"
	},
	:HG03372 =>
	{
		:biosample_accession => "SAMN01761341",
		:sex => "female",
		:population_code => "HG03372"
	},
	:HG03363 =>
	{
		:biosample_accession => "SAMN01761339",
		:sex => "female",
		:population_code => "HG03363"
	},
	:HG03361 =>
	{
		:biosample_accession => "SAMN01761337",
		:sex => "male",
		:population_code => "HG03361"
	},
	:HG03354 =>
	{
		:biosample_accession => "SAMN01761336",
		:sex => "female",
		:population_code => "HG03354"
	},
	:HG03352 =>
	{
		:biosample_accession => "SAMN01761335",
		:sex => "male",
		:population_code => "HG03352"
	},
	:HG03351 =>
	{
		:biosample_accession => "SAMN01761334",
		:sex => "female",
		:population_code => "HG03351"
	},
	:HG03339 =>
	{
		:biosample_accession => "SAMN01761331",
		:sex => "female",
		:population_code => "HG03339"
	},
	:HG03313 =>
	{
		:biosample_accession => "SAMN01761329",
		:sex => "male",
		:population_code => "HG03313"
	},
	:HG03312 =>
	{
		:biosample_accession => "SAMN01761328",
		:sex => "female",
		:population_code => "HG03312"
	},
	:HG03311 =>
	{
		:biosample_accession => "SAMN01761327",
		:sex => "male",
		:population_code => "HG03311"
	},
	:HG03309 =>
	{
		:biosample_accession => "SAMN01761325",
		:sex => "female",
		:population_code => "HG03309"
	},
	:HG03304 =>
	{
		:biosample_accession => "SAMN01761323",
		:sex => "male",
		:population_code => "HG03304"
	},
	:HG03303 =>
	{
		:biosample_accession => "SAMN01761322",
		:sex => "female",
		:population_code => "HG03303"
	},
	:HG03298 =>
	{
		:biosample_accession => "SAMN01761320",
		:sex => "male",
		:population_code => "HG03298"
	},
	:HG03297 =>
	{
		:biosample_accession => "SAMN01761319",
		:sex => "female",
		:population_code => "HG03297"
	},
	:HG03265 =>
	{
		:biosample_accession => "SAMN01761316",
		:sex => "male",
		:population_code => "HG03265"
	},
	:HG03202 =>
	{
		:biosample_accession => "SAMN01761312",
		:sex => "male",
		:population_code => "HG03202"
	},
	:HG03193 =>
	{
		:biosample_accession => "SAMN01761310",
		:sex => "male",
		:population_code => "HG03193"
	},
	:HG03190 =>
	{
		:biosample_accession => "SAMN01761308",
		:sex => "male",
		:population_code => "HG03190"
	},
	:HG03189 =>
	{
		:biosample_accession => "SAMN01761307",
		:sex => "female",
		:population_code => "HG03189"
	},
	:HG03175 =>
	{
		:biosample_accession => "SAMN01761304",
		:sex => "male",
		:population_code => "HG03175"
	},
	:HG03166 =>
	{
		:biosample_accession => "SAMN01761302",
		:sex => "male",
		:population_code => "HG03166"
	},
	:HG03157 =>
	{
		:biosample_accession => "SAMN01761300",
		:sex => "male",
		:population_code => "HG03157"
	},
	:HG03139 =>
	{
		:biosample_accession => "SAMN01761295",
		:sex => "male",
		:population_code => "HG03139"
	},
	:HG03127 =>
	{
		:biosample_accession => "SAMN01761293",
		:sex => "male",
		:population_code => "HG03127"
	},
	:HG03126 =>
	{
		:biosample_accession => "SAMN01761292",
		:sex => "female",
		:population_code => "HG03126"
	},
	:HG03112 =>
	{
		:biosample_accession => "SAMN01761290",
		:sex => "male",
		:population_code => "HG03112"
	},
	:HG03111 =>
	{
		:biosample_accession => "SAMN01761289",
		:sex => "female",
		:population_code => "HG03111"
	},
	:HG03105 =>
	{
		:biosample_accession => "SAMN01761287",
		:sex => "female",
		:population_code => "HG03105"
	},
	:HG03103 =>
	{
		:biosample_accession => "SAMN01761285",
		:sex => "male",
		:population_code => "HG03103"
	},
	:HG02981 =>
	{
		:biosample_accession => "SAMN01761284",
		:sex => "male",
		:population_code => "HG02981"
	},
	:HG02979 =>
	{
		:biosample_accession => "SAMN01761282",
		:sex => "female",
		:population_code => "HG02979"
	},
	:HG02968 =>
	{
		:biosample_accession => "SAMN01761280",
		:sex => "male",
		:population_code => "HG02968"
	},
	:HG02965 =>
	{
		:biosample_accession => "SAMN01761278",
		:sex => "male",
		:population_code => "HG02965"
	},
	:HG02964 =>
	{
		:biosample_accession => "SAMN01761277",
		:sex => "female",
		:population_code => "HG02964"
	},
	:HG02941 =>
	{
		:biosample_accession => "SAMN01761274",
		:sex => "male",
		:population_code => "HG02941"
	},
	:HG02938 =>
	{
		:biosample_accession => "SAMN01761272",
		:sex => "male",
		:population_code => "HG02938"
	},
	:HG03582 =>
	{
		:biosample_accession => "SAMN01761268",
		:sex => "male",
		:population_code => "HG03582"
	},
	:HG03574 =>
	{
		:biosample_accession => "SAMN01761267",
		:sex => "male",
		:population_code => "HG03574"
	},
	:HG03567 =>
	{
		:biosample_accession => "SAMN01761266",
		:sex => "female",
		:population_code => "HG03567"
	},
	:HG03566 =>
	{
		:biosample_accession => "SAMN01761265",
		:sex => "female",
		:population_code => "HG03566"
	},
	:HG03558 =>
	{
		:biosample_accession => "SAMN01761264",
		:sex => "female",
		:population_code => "HG03558"
	},
	:HG03549 =>
	{
		:biosample_accession => "SAMN01761263",
		:sex => "female",
		:population_code => "HG03549"
	},
	:HG03462 =>
	{
		:biosample_accession => "SAMN01761262",
		:sex => "male",
		:population_code => "HG03462"
	},
	:HG03457 =>
	{
		:biosample_accession => "SAMN01761261",
		:sex => "male",
		:population_code => "HG03457"
	},
	:HG03454 =>
	{
		:biosample_accession => "SAMN01761260",
		:sex => "male",
		:population_code => "HG03454"
	},
	:HG03432 =>
	{
		:biosample_accession => "SAMN01761259",
		:sex => "male",
		:population_code => "HG03432"
	},
	:HG03408 =>
	{
		:biosample_accession => "SAMN01761258",
		:sex => "male",
		:population_code => "HG03408"
	},
	:HG03394 =>
	{
		:biosample_accession => "SAMN01761255",
		:sex => "male",
		:population_code => "HG03394"
	},
	:HG03393 =>
	{
		:biosample_accession => "SAMN01761254",
		:sex => "female",
		:population_code => "HG03393"
	},
	:HG03383 =>
	{
		:biosample_accession => "SAMN01761251",
		:sex => "female",
		:population_code => "HG03383"
	},
	:HG03382 =>
	{
		:biosample_accession => "SAMN01761250",
		:sex => "male",
		:population_code => "HG03382"
	},
	:HG03378 =>
	{
		:biosample_accession => "SAMN01761248",
		:sex => "female",
		:population_code => "HG03378"
	},
	:HG03225 =>
	{
		:biosample_accession => "SAMN01761247",
		:sex => "male",
		:population_code => "HG03225"
	},
	:HG03224 =>
	{
		:biosample_accession => "SAMN01761246",
		:sex => "male",
		:population_code => "HG03224"
	},
	:HG03095 =>
	{
		:biosample_accession => "SAMN01761245",
		:sex => "female",
		:population_code => "HG03095"
	},
	:HG03091 =>
	{
		:biosample_accession => "SAMN01761244",
		:sex => "female",
		:population_code => "HG03091"
	},
	:HG03086 =>
	{
		:biosample_accession => "SAMN01761243",
		:sex => "female",
		:population_code => "HG03086"
	},
	:HG03082 =>
	{
		:biosample_accession => "SAMN01761242",
		:sex => "female",
		:population_code => "HG03082"
	},
	:HG03079 =>
	{
		:biosample_accession => "SAMN01761240",
		:sex => "female",
		:population_code => "HG03079"
	},
	:HG03077 =>
	{
		:biosample_accession => "SAMN01761239",
		:sex => "male",
		:population_code => "HG03077"
	},
	:HG03074 =>
	{
		:biosample_accession => "SAMN01761238",
		:sex => "male",
		:population_code => "HG03074"
	},
	:HG03073 =>
	{
		:biosample_accession => "SAMN01761237",
		:sex => "female",
		:population_code => "HG03073"
	},
	:HG03064 =>
	{
		:biosample_accession => "SAMN01761235",
		:sex => "female",
		:population_code => "HG03064"
	},
	:HG03063 =>
	{
		:biosample_accession => "SAMN01761234",
		:sex => "male",
		:population_code => "HG03063"
	},
	:HG03060 =>
	{
		:biosample_accession => "SAMN01761232",
		:sex => "male",
		:population_code => "HG03060"
	},
	:HG03054 =>
	{
		:biosample_accession => "SAMN01761229",
		:sex => "male",
		:population_code => "HG03054"
	},
	:HG02983 =>
	{
		:biosample_accession => "SAMN01761226",
		:sex => "female",
		:population_code => "HG02983"
	},
	:HG02982 =>
	{
		:biosample_accession => "SAMN01761225",
		:sex => "male",
		:population_code => "HG02982"
	},
	:HG02882 =>
	{
		:biosample_accession => "SAMN01761223",
		:sex => "female",
		:population_code => "HG02882"
	},
	:HG02881 =>
	{
		:biosample_accession => "SAMN01761222",
		:sex => "male",
		:population_code => "HG02881"
	},
	:HG02879 =>
	{
		:biosample_accession => "SAMN01761220",
		:sex => "female",
		:population_code => "HG02879"
	},
	:HG02878 =>
	{
		:biosample_accession => "SAMN01761219",
		:sex => "male",
		:population_code => "HG02878"
	},
	:HG02870 =>
	{
		:biosample_accession => "SAMN01761217",
		:sex => "female",
		:population_code => "HG02870"
	},
	:HG02869 =>
	{
		:biosample_accession => "SAMN01761216",
		:sex => "male",
		:population_code => "HG02869"
	},
	:HG02763 =>
	{
		:biosample_accession => "SAMN01761214",
		:sex => "female",
		:population_code => "HG02763"
	},
	:HG02762 =>
	{
		:biosample_accession => "SAMN01761213",
		:sex => "male",
		:population_code => "HG02762"
	},
	:HG02760 =>
	{
		:biosample_accession => "SAMN01761211",
		:sex => "female",
		:population_code => "HG02760"
	},
	:HG02759 =>
	{
		:biosample_accession => "SAMN01761210",
		:sex => "male",
		:population_code => "HG02759"
	},
	:HG02568 =>
	{
		:biosample_accession => "SAMN01761208",
		:sex => "female",
		:population_code => "HG02568"
	},
	:HG02567 =>
	{
		:biosample_accession => "SAMN01761207",
		:sex => "male",
		:population_code => "HG02567"
	},
	:HG04118 =>
	{
		:biosample_accession => "SAMN01096806",
		:sex => "female",
		:population_code => "HG04118"
	},
	:HG04093 =>
	{
		:biosample_accession => "SAMN01096805",
		:sex => "male",
		:population_code => "HG04093"
	},
	:HG04063 =>
	{
		:biosample_accession => "SAMN01096804",
		:sex => "female",
		:population_code => "HG04063"
	},
	:HG04022 =>
	{
		:biosample_accession => "SAMN01096803",
		:sex => "male",
		:population_code => "HG04022"
	},
	:HG04015 =>
	{
		:biosample_accession => "SAMN01096802",
		:sex => "male",
		:population_code => "HG04015"
	},
	:HG04014 =>
	{
		:biosample_accession => "SAMN01096801",
		:sex => "female",
		:population_code => "HG04014"
	},
	:HG04020 =>
	{
		:biosample_accession => "SAMN01096800",
		:sex => "male",
		:population_code => "HG04020"
	},
	:HG04025 =>
	{
		:biosample_accession => "SAMN01096799",
		:sex => "female",
		:population_code => "HG04025"
	},
	:HG04019 =>
	{
		:biosample_accession => "SAMN01096798",
		:sex => "male",
		:population_code => "HG04019"
	},
	:HG03720 =>
	{
		:biosample_accession => "SAMN01096797",
		:sex => "male",
		:population_code => "HG03720"
	},
	:HG03968 =>
	{
		:biosample_accession => "SAMN01096796",
		:sex => "female",
		:population_code => "HG03968"
	},
	:HG03960 =>
	{
		:biosample_accession => "SAMN01096795",
		:sex => "male",
		:population_code => "HG03960"
	},
	:HG03963 =>
	{
		:biosample_accession => "SAMN01096793",
		:sex => "male",
		:population_code => "HG03963"
	},
	:HG03867 =>
	{
		:biosample_accession => "SAMN01096792",
		:sex => "male",
		:population_code => "HG03867"
	},
	:HG03870 =>
	{
		:biosample_accession => "SAMN01096791",
		:sex => "male",
		:population_code => "HG03870"
	},
	:HG03872 =>
	{
		:biosample_accession => "SAMN01096790",
		:sex => "male",
		:population_code => "HG03872"
	},
	:HG03863 =>
	{
		:biosample_accession => "SAMN01096789",
		:sex => "female",
		:population_code => "HG03863"
	},
	:HG03861 =>
	{
		:biosample_accession => "SAMN01096788",
		:sex => "female",
		:population_code => "HG03861"
	},
	:HG03873 =>
	{
		:biosample_accession => "SAMN01096787",
		:sex => "female",
		:population_code => "HG03873"
	},
	:HG03782 =>
	{
		:biosample_accession => "SAMN01096785",
		:sex => "female",
		:population_code => "HG03782"
	},
	:HG03792 =>
	{
		:biosample_accession => "SAMN01096784",
		:sex => "male",
		:population_code => "HG03792"
	},
	:HG03790 =>
	{
		:biosample_accession => "SAMN01096783",
		:sex => "male",
		:population_code => "HG03790"
	},
	:HG03785 =>
	{
		:biosample_accession => "SAMN01096782",
		:sex => "male",
		:population_code => "HG03785"
	},
	:HG03777 =>
	{
		:biosample_accession => "SAMN01096781",
		:sex => "male",
		:population_code => "HG03777"
	},
	:HG03779 =>
	{
		:biosample_accession => "SAMN01096780",
		:sex => "male",
		:population_code => "HG03779"
	},
	:HG03742 =>
	{
		:biosample_accession => "SAMN01096779",
		:sex => "male",
		:population_code => "HG03742"
	},
	:HG03723 =>
	{
		:biosample_accession => "SAMN01096778",
		:sex => "female",
		:population_code => "HG03723"
	},
	:HG04018 =>
	{
		:biosample_accession => "SAMN01096777",
		:sex => "female",
		:population_code => "HG04018"
	},
	:HG03718 =>
	{
		:biosample_accession => "SAMN01096776",
		:sex => "male",
		:population_code => "HG03718"
	},
	:HG03780 =>
	{
		:biosample_accession => "SAMN01096774",
		:sex => "female",
		:population_code => "HG03780"
	},
	:HG03972 =>
	{
		:biosample_accession => "SAMN01096773",
		:sex => "female",
		:population_code => "HG03972"
	},
	:HG03977 =>
	{
		:biosample_accession => "SAMN01096772",
		:sex => "female",
		:population_code => "HG03977"
	},
	:HG04099 =>
	{
		:biosample_accession => "SAMN01096770",
		:sex => "female",
		:population_code => "HG04099"
	},
	:HG04042 =>
	{
		:biosample_accession => "SAMN01096768",
		:sex => "female",
		:population_code => "HG04042"
	},
	:HG04037 =>
	{
		:biosample_accession => "SAMN01096767",
		:sex => "female",
		:population_code => "HG04037"
	},
	:HG04029 =>
	{
		:biosample_accession => "SAMN01096766",
		:sex => "female",
		:population_code => "HG04029"
	},
	:HG04035 =>
	{
		:biosample_accession => "SAMN01096765",
		:sex => "female",
		:population_code => "HG04035"
	},
	:HG03982 =>
	{
		:biosample_accession => "SAMN01096764",
		:sex => "male",
		:population_code => "HG03982"
	},
	:HG03949 =>
	{
		:biosample_accession => "SAMN01096763",
		:sex => "female",
		:population_code => "HG03949"
	},
	:HG03953 =>
	{
		:biosample_accession => "SAMN01096762",
		:sex => "male",
		:population_code => "HG03953"
	},
	:HG03947 =>
	{
		:biosample_accession => "SAMN01096761",
		:sex => "female",
		:population_code => "HG03947"
	},
	:HG04033 =>
	{
		:biosample_accession => "SAMN01096759",
		:sex => "male",
		:population_code => "HG04033"
	},
	:HG03890 =>
	{
		:biosample_accession => "SAMN01096758",
		:sex => "male",
		:population_code => "HG03890"
	},
	:HG03895 =>
	{
		:biosample_accession => "SAMN01096757",
		:sex => "female",
		:population_code => "HG03895"
	},
	:HG03856 =>
	{
		:biosample_accession => "SAMN01096756",
		:sex => "male",
		:population_code => "HG03856"
	},
	:HG03851 =>
	{
		:biosample_accession => "SAMN01096755",
		:sex => "male",
		:population_code => "HG03851"
	},
	:HG03848 =>
	{
		:biosample_accession => "SAMN01096754",
		:sex => "male",
		:population_code => "HG03848"
	},
	:HG03847 =>
	{
		:biosample_accession => "SAMN01096753",
		:sex => "male",
		:population_code => "HG03847"
	},
	:HG03845 =>
	{
		:biosample_accession => "SAMN01096752",
		:sex => "male",
		:population_code => "HG03845"
	},
	:HG03846 =>
	{
		:biosample_accession => "SAMN01096751",
		:sex => "male",
		:population_code => "HG03846"
	},
	:HG03837 =>
	{
		:biosample_accession => "SAMN01096750",
		:sex => "male",
		:population_code => "HG03837"
	},
	:HG03836 =>
	{
		:biosample_accession => "SAMN01096749",
		:sex => "female",
		:population_code => "HG03836"
	},
	:HG03760 =>
	{
		:biosample_accession => "SAMN01096748",
		:sex => "female",
		:population_code => "HG03760"
	},
	:HG03753 =>
	{
		:biosample_accession => "SAMN01096747",
		:sex => "male",
		:population_code => "HG03753"
	},
	:HG03752 =>
	{
		:biosample_accession => "SAMN01096746",
		:sex => "female",
		:population_code => "HG03752"
	},
	:HG03745 =>
	{
		:biosample_accession => "SAMN01096745",
		:sex => "male",
		:population_code => "HG03745"
	},
	:HG03744 =>
	{
		:biosample_accession => "SAMN01096744",
		:sex => "male",
		:population_code => "HG03744"
	},
	:HG03738 =>
	{
		:biosample_accession => "SAMN01096743",
		:sex => "male",
		:population_code => "HG03738"
	},
	:HG03736 =>
	{
		:biosample_accession => "SAMN01096742",
		:sex => "female",
		:population_code => "HG03736"
	},
	:HG03733 =>
	{
		:biosample_accession => "SAMN01096741",
		:sex => "female",
		:population_code => "HG03733"
	},
	:HG03711 =>
	{
		:biosample_accession => "SAMN01096740",
		:sex => "male",
		:population_code => "HG03711"
	},
	:HG03698 =>
	{
		:biosample_accession => "SAMN01096739",
		:sex => "female",
		:population_code => "HG03698"
	},
	:HG03697 =>
	{
		:biosample_accession => "SAMN01096738",
		:sex => "male",
		:population_code => "HG03697"
	},
	:HG03696 =>
	{
		:biosample_accession => "SAMN01096736",
		:sex => "male",
		:population_code => "HG03696"
	},
	:HG03695 =>
	{
		:biosample_accession => "SAMN01096735",
		:sex => "male",
		:population_code => "HG03695"
	},
	:HG03694 =>
	{
		:biosample_accession => "SAMN01096734",
		:sex => "male",
		:population_code => "HG03694"
	},
	:HG03691 =>
	{
		:biosample_accession => "SAMN01096733",
		:sex => "male",
		:population_code => "HG03691"
	},
	:HG03690 =>
	{
		:biosample_accession => "SAMN01096732",
		:sex => "female",
		:population_code => "HG03690"
	},
	:HG03689 =>
	{
		:biosample_accession => "SAMN01096731",
		:sex => "female",
		:population_code => "HG03689"
	},
	:HG03687 =>
	{
		:biosample_accession => "SAMN01096730",
		:sex => "male",
		:population_code => "HG03687"
	},
	:HG03686 =>
	{
		:biosample_accession => "SAMN01096729",
		:sex => "male",
		:population_code => "HG03686"
	},
	:HG03685 =>
	{
		:biosample_accession => "SAMN01096728",
		:sex => "male",
		:population_code => "HG03685"
	},
	:HG03681 =>
	{
		:biosample_accession => "SAMN01096727",
		:sex => "male",
		:population_code => "HG03681"
	},
	:HG03680 =>
	{
		:biosample_accession => "SAMN01096726",
		:sex => "male",
		:population_code => "HG03680"
	},
	:HG03672 =>
	{
		:biosample_accession => "SAMN01096725",
		:sex => "male",
		:population_code => "HG03672"
	},
	:HG03999 =>
	{
		:biosample_accession => "SAMN01096724",
		:sex => "male",
		:population_code => "HG03999"
	},
	:HG03645 =>
	{
		:biosample_accession => "SAMN01096723",
		:sex => "female",
		:population_code => "HG03645"
	},
	:HG03646 =>
	{
		:biosample_accession => "SAMN01096722",
		:sex => "male",
		:population_code => "HG03646"
	},
	:HG03944 =>
	{
		:biosample_accession => "SAMN01096720",
		:sex => "female",
		:population_code => "HG03944"
	},
	:HG03897 =>
	{
		:biosample_accession => "SAMN01096719",
		:sex => "female",
		:population_code => "HG03897"
	},
	:HG03894 =>
	{
		:biosample_accession => "SAMN01096718",
		:sex => "female",
		:population_code => "HG03894"
	},
	:HG03850 =>
	{
		:biosample_accession => "SAMN01096717",
		:sex => "male",
		:population_code => "HG03850"
	},
	:HG03842 =>
	{
		:biosample_accession => "SAMN01096716",
		:sex => "female",
		:population_code => "HG03842"
	},
	:HG03755 =>
	{
		:biosample_accession => "SAMN01096715",
		:sex => "male",
		:population_code => "HG03755"
	},
	:HG03598 =>
	{
		:biosample_accession => "SAMN01096713",
		:sex => "female",
		:population_code => "HG03598"
	},
	:HG04192 =>
	{
		:biosample_accession => "SAMN01096712",
		:sex => "female",
		:population_code => "HG04192"
	},
	:HG04186 =>
	{
		:biosample_accession => "SAMN01096711",
		:sex => "female",
		:population_code => "HG04186"
	},
	:HG03593 =>
	{
		:biosample_accession => "SAMN01096710",
		:sex => "male",
		:population_code => "HG03593"
	},
	:HG04159 =>
	{
		:biosample_accession => "SAMN01096709",
		:sex => "female",
		:population_code => "HG04159"
	},
	:HG04149 =>
	{
		:biosample_accession => "SAMN01096708",
		:sex => "male",
		:population_code => "HG04149"
	},
	:HG03589 =>
	{
		:biosample_accession => "SAMN01096706",
		:sex => "female",
		:population_code => "HG03589"
	},
	:HG04146 =>
	{
		:biosample_accession => "SAMN01096705",
		:sex => "male",
		:population_code => "HG04146"
	},
	:HG03934 =>
	{
		:biosample_accession => "SAMN01096704",
		:sex => "female",
		:population_code => "HG03934"
	},
	:HG03937 =>
	{
		:biosample_accession => "SAMN01096702",
		:sex => "female",
		:population_code => "HG03937"
	},
	:HG03585 =>
	{
		:biosample_accession => "SAMN01096700",
		:sex => "male",
		:population_code => "HG03585"
	},
	:HG03931 =>
	{
		:biosample_accession => "SAMN01096699",
		:sex => "female",
		:population_code => "HG03931"
	},
	:HG03928 =>
	{
		:biosample_accession => "SAMN01096697",
		:sex => "female",
		:population_code => "HG03928"
	},
	:HG03919 =>
	{
		:biosample_accession => "SAMN01096696",
		:sex => "female",
		:population_code => "HG03919"
	},
	:HG03916 =>
	{
		:biosample_accession => "SAMN01096695",
		:sex => "female",
		:population_code => "HG03916"
	},
	:HG03910 =>
	{
		:biosample_accession => "SAMN01096694",
		:sex => "female",
		:population_code => "HG03910"
	},
	:HG03911 =>
	{
		:biosample_accession => "SAMN01096693",
		:sex => "male",
		:population_code => "HG03911"
	},
	:HG03905 =>
	{
		:biosample_accession => "SAMN01096692",
		:sex => "male",
		:population_code => "HG03905"
	},
	:HG03012 =>
	{
		:biosample_accession => "SAMN01096691",
		:sex => "male",
		:population_code => "HG03012"
	},
	:HG03902 =>
	{
		:biosample_accession => "SAMN01096690",
		:sex => "male",
		:population_code => "HG03902"
	},
	:HG03817 =>
	{
		:biosample_accession => "SAMN01096689",
		:sex => "female",
		:population_code => "HG03817"
	},
	:HG03812 =>
	{
		:biosample_accession => "SAMN01096688",
		:sex => "male",
		:population_code => "HG03812"
	},
	:HG03009 =>
	{
		:biosample_accession => "SAMN01096687",
		:sex => "male",
		:population_code => "HG03009"
	},
	:HG03808 =>
	{
		:biosample_accession => "SAMN01096686",
		:sex => "female",
		:population_code => "HG03808"
	},
	:HG03809 =>
	{
		:biosample_accession => "SAMN01096685",
		:sex => "male",
		:population_code => "HG03809"
	},
	:HG03595 =>
	{
		:biosample_accession => "SAMN01096683",
		:sex => "female",
		:population_code => "HG03595"
	},
	:HG03594 =>
	{
		:biosample_accession => "SAMN01096682",
		:sex => "male",
		:population_code => "HG03594"
	},
	:HG03925 =>
	{
		:biosample_accession => "SAMN01096680",
		:sex => "female",
		:population_code => "HG03925"
	},
	:HG03926 =>
	{
		:biosample_accession => "SAMN01096679",
		:sex => "male",
		:population_code => "HG03926"
	},
	:HG03907 =>
	{
		:biosample_accession => "SAMN01096677",
		:sex => "female",
		:population_code => "HG03907"
	},
	:HG03908 =>
	{
		:biosample_accession => "SAMN01096676",
		:sex => "male",
		:population_code => "HG03908"
	},
	:HG03805 =>
	{
		:biosample_accession => "SAMN01096674",
		:sex => "female",
		:population_code => "HG03805"
	},
	:HG03806 =>
	{
		:biosample_accession => "SAMN01096673",
		:sex => "male",
		:population_code => "HG03806"
	},
	:HG03607 =>
	{
		:biosample_accession => "SAMN01096671",
		:sex => "female",
		:population_code => "HG03607"
	},
	:HG03606 =>
	{
		:biosample_accession => "SAMN01096670",
		:sex => "male",
		:population_code => "HG03606"
	},
	:HG03794 =>
	{
		:biosample_accession => "SAMN01096665",
		:sex => "male",
		:population_code => "HG03794"
	},
	:HG03701 =>
	{
		:biosample_accession => "SAMN01096664",
		:sex => "male",
		:population_code => "HG03701"
	},
	:HG03699 =>
	{
		:biosample_accession => "SAMN01096663",
		:sex => "male",
		:population_code => "HG03699"
	},
	:HG03700 =>
	{
		:biosample_accession => "SAMN01096662",
		:sex => "female",
		:population_code => "HG03700"
	},
	:HG03239 =>
	{
		:biosample_accession => "SAMN01096661",
		:sex => "female",
		:population_code => "HG03239"
	},
	:HG03238 =>
	{
		:biosample_accession => "SAMN01096660",
		:sex => "female",
		:population_code => "HG03238"
	},
	:HG03237 =>
	{
		:biosample_accession => "SAMN01096659",
		:sex => "male",
		:population_code => "HG03237"
	},
	:HG03250 =>
	{
		:biosample_accession => "SAMN01096657",
		:sex => "female",
		:population_code => "HG03250"
	},
	:HG03249 =>
	{
		:biosample_accession => "SAMN01096656",
		:sex => "male",
		:population_code => "HG03249"
	},
	:HG03034 =>
	{
		:biosample_accession => "SAMN01096654",
		:sex => "female",
		:population_code => "HG03034"
	},
	:HG03033 =>
	{
		:biosample_accession => "SAMN01096653",
		:sex => "male",
		:population_code => "HG03033"
	},
	:HG02410 =>
	{
		:biosample_accession => "SAMN01091165",
		:sex => "male",
		:population_code => "HG02410"
	},
	:HG02408 =>
	{
		:biosample_accession => "SAMN01091164",
		:sex => "male",
		:population_code => "HG02408"
	},
	:HG02405 =>
	{
		:biosample_accession => "SAMN01091163",
		:sex => "male",
		:population_code => "HG02405"
	},
	:HG02358 =>
	{
		:biosample_accession => "SAMN01091162",
		:sex => "male",
		:population_code => "HG02358"
	},
	:HG02176 =>
	{
		:biosample_accession => "SAMN01091161",
		:sex => "female",
		:population_code => "HG02176"
	},
	:HG02173 =>
	{
		:biosample_accession => "SAMN01091160",
		:sex => "female",
		:population_code => "HG02173"
	},
	:HG02170 =>
	{
		:biosample_accession => "SAMN01091159",
		:sex => "female",
		:population_code => "HG02170"
	},
	:HG02169 =>
	{
		:biosample_accession => "SAMN01091158",
		:sex => "female",
		:population_code => "HG02169"
	},
	:HG02168 =>
	{
		:biosample_accession => "SAMN01091157",
		:sex => "female",
		:population_code => "HG02168"
	},
	:HG02425 =>
	{
		:biosample_accession => "SAMN01091155",
		:sex => "female",
		:population_code => "HG02425"
	},
	:HG02415 =>
	{
		:biosample_accession => "SAMN01091154",
		:sex => "F",
		:population_code => "HG02415"
	},
	:HG02348 =>
	{
		:biosample_accession => "SAMN01091153",
		:sex => "female",
		:population_code => "HG02348"
	},
	:HG02347 =>
	{
		:biosample_accession => "SAMN01091152",
		:sex => "M",
		:population_code => "HG02347"
	},
	:HG02345 =>
	{
		:biosample_accession => "SAMN01091151",
		:sex => "female",
		:population_code => "HG02345"
	},
	:HG02344 =>
	{
		:biosample_accession => "SAMN01091150",
		:sex => "M",
		:population_code => "HG02344"
	},
	:HG02312 =>
	{
		:biosample_accession => "SAMN01091149",
		:sex => "female",
		:population_code => "HG02312"
	},
	:HG02304 =>
	{
		:biosample_accession => "SAMN01091148",
		:sex => "male",
		:population_code => "HG02304"
	},
	:HG02288 =>
	{
		:biosample_accession => "SAMN01091147",
		:sex => "M",
		:population_code => "HG02288"
	},
	:HG02275 =>
	{
		:biosample_accession => "SAMN01091146",
		:sex => "female",
		:population_code => "HG02275"
	},
	:HG02274 =>
	{
		:biosample_accession => "SAMN01091145",
		:sex => "male",
		:population_code => "HG02274"
	},
	:HG02266 =>
	{
		:biosample_accession => "SAMN01091144",
		:sex => "female",
		:population_code => "HG02266"
	},
	:HG02265 =>
	{
		:biosample_accession => "SAMN01091143",
		:sex => "male",
		:population_code => "HG02265"
	},
	:HG02262 =>
	{
		:biosample_accession => "SAMN01091142",
		:sex => "male",
		:population_code => "HG02262"
	},
	:HG02253 =>
	{
		:biosample_accession => "SAMN01091141",
		:sex => "male",
		:population_code => "HG02253"
	},
	:HG02252 =>
	{
		:biosample_accession => "SAMN01091140",
		:sex => "female",
		:population_code => "HG02252"
	},
	:HG02150 =>
	{
		:biosample_accession => "SAMN01091139",
		:sex => "male",
		:population_code => "HG02150"
	},
	:HG02102 =>
	{
		:biosample_accession => "SAMN01091138",
		:sex => "female",
		:population_code => "HG02102"
	},
	:HG02006 =>
	{
		:biosample_accession => "SAMN01091137",
		:sex => "female",
		:population_code => "HG02006"
	},
	:HG01995 =>
	{
		:biosample_accession => "SAMN01091136",
		:sex => "F",
		:population_code => "HG01995"
	},
	:HG01965 =>
	{
		:biosample_accession => "SAMN01091135",
		:sex => "female",
		:population_code => "HG01965"
	},
	:HG01961 =>
	{
		:biosample_accession => "SAMN01091134",
		:sex => "male",
		:population_code => "HG01961"
	},
	:HG01556 =>
	{
		:biosample_accession => "SAMN01091133",
		:sex => "male",
		:population_code => "HG01556"
	},
	:HG01486 =>
	{
		:biosample_accession => "SAMN01091132",
		:sex => "female",
		:population_code => "HG01486"
	},
	:HG01485 =>
	{
		:biosample_accession => "SAMN01091131",
		:sex => "male",
		:population_code => "HG01485"
	},
	:HG01483 =>
	{
		:biosample_accession => "SAMN01091130",
		:sex => "F",
		:population_code => "HG01483"
	},
	:HG01482 =>
	{
		:biosample_accession => "SAMN01091129",
		:sex => "M",
		:population_code => "HG01482"
	},
	:HG01480 =>
	{
		:biosample_accession => "SAMN01091128",
		:sex => "F",
		:population_code => "HG01480"
	},
	:HG01479 =>
	{
		:biosample_accession => "SAMN01091127",
		:sex => "male",
		:population_code => "HG01479"
	},
	:HG01477 =>
	{
		:biosample_accession => "SAMN01091126",
		:sex => "F",
		:population_code => "HG01477"
	},
	:HG01474 =>
	{
		:biosample_accession => "SAMN01091125",
		:sex => "female",
		:population_code => "HG01474"
	},
	:HG01473 =>
	{
		:biosample_accession => "SAMN01091124",
		:sex => "M",
		:population_code => "HG01473"
	},
	:HG01471 =>
	{
		:biosample_accession => "SAMN01091123",
		:sex => "F",
		:population_code => "HG01471"
	},
	:HG01468 =>
	{
		:biosample_accession => "SAMN01091122",
		:sex => "female",
		:population_code => "HG01468"
	},
	:HG01459 =>
	{
		:biosample_accession => "SAMN01091121",
		:sex => "female",
		:population_code => "HG01459"
	},
	:HG01453 =>
	{
		:biosample_accession => "SAMN01091120",
		:sex => "F",
		:population_code => "HG01453"
	},
	:HG01452 =>
	{
		:biosample_accession => "SAMN01091119",
		:sex => "M",
		:population_code => "HG01452"
	},
	:HG01447 =>
	{
		:biosample_accession => "SAMN01091118",
		:sex => "female",
		:population_code => "HG01447"
	},
	:HG01444 =>
	{
		:biosample_accession => "SAMN01091117",
		:sex => "female",
		:population_code => "HG01444"
	},
	:HG01443 =>
	{
		:biosample_accession => "SAMN01091116",
		:sex => "male",
		:population_code => "HG01443"
	},
	:HG01435 =>
	{
		:biosample_accession => "SAMN01091115",
		:sex => "female",
		:population_code => "HG01435"
	},
	:HG01432 =>
	{
		:biosample_accession => "SAMN01091114",
		:sex => "female",
		:population_code => "HG01432"
	},
	:HG01431 =>
	{
		:biosample_accession => "SAMN01091113",
		:sex => "male",
		:population_code => "HG01431"
	},
	:HG01372 =>
	{
		:biosample_accession => "SAMN01091112",
		:sex => "female",
		:population_code => "HG01372"
	},
	:HG01369 =>
	{
		:biosample_accession => "SAMN01091111",
		:sex => "female",
		:population_code => "HG01369"
	},
	:HG01363 =>
	{
		:biosample_accession => "SAMN01091110",
		:sex => "female",
		:population_code => "HG01363"
	},
	:HG01362 =>
	{
		:biosample_accession => "SAMN01091109",
		:sex => "male",
		:population_code => "HG01362"
	},
	:HG01284 =>
	{
		:biosample_accession => "SAMN01091108",
		:sex => "female",
		:population_code => "HG01284"
	},
	:HG01281 =>
	{
		:biosample_accession => "SAMN01091107",
		:sex => "female",
		:population_code => "HG01281"
	},
	:HG01280 =>
	{
		:biosample_accession => "SAMN01091106",
		:sex => "male",
		:population_code => "HG01280"
	},
	:HG01269 =>
	{
		:biosample_accession => "SAMN01091105",
		:sex => "female",
		:population_code => "HG01269"
	},
	:HG01142 =>
	{
		:biosample_accession => "SAMN01091103",
		:sex => "male",
		:population_code => "HG01142"
	},
	:HG01131 =>
	{
		:biosample_accession => "SAMN01091102",
		:sex => "female",
		:population_code => "HG01131"
	},
	:HG01130 =>
	{
		:biosample_accession => "SAMN01091101",
		:sex => "male",
		:population_code => "HG01130"
	},
	:HG01122 =>
	{
		:biosample_accession => "SAMN01091100",
		:sex => "female",
		:population_code => "HG01122"
	},
	:HG01121 =>
	{
		:biosample_accession => "SAMN01091099",
		:sex => "male",
		:population_code => "HG01121"
	},
	:HG01119 =>
	{
		:biosample_accession => "SAMN01091098",
		:sex => "female",
		:population_code => "HG01119"
	},
	:HG01412 =>
	{
		:biosample_accession => "SAMN01091096",
		:sex => "male",
		:population_code => "HG01412"
	},
	:HG01405 =>
	{
		:biosample_accession => "SAMN01091095",
		:sex => "male",
		:population_code => "HG01405"
	},
	:HG01398 =>
	{
		:biosample_accession => "SAMN01091094",
		:sex => "male",
		:population_code => "HG01398"
	},
	:HG01308 =>
	{
		:biosample_accession => "SAMN01091093",
		:sex => "male",
		:population_code => "HG01308"
	},
	:HG01305 =>
	{
		:biosample_accession => "SAMN01091092",
		:sex => "male",
		:population_code => "HG01305"
	},
	:HG01286 =>
	{
		:biosample_accession => "SAMN01091091",
		:sex => "male",
		:population_code => "HG01286"
	},
	:HG01200 =>
	{
		:biosample_accession => "SAMN01091090",
		:sex => "male",
		:population_code => "HG01200"
	},
	:HG01195 =>
	{
		:biosample_accession => "SAMN01091089",
		:sex => "F",
		:population_code => "HG01195"
	},
	:HG01164 =>
	{
		:biosample_accession => "SAMN01091088",
		:sex => "male",
		:population_code => "HG01164"
	},
	:HG01162 =>
	{
		:biosample_accession => "SAMN01091087",
		:sex => "female",
		:population_code => "HG01162"
	},
	:HG01161 =>
	{
		:biosample_accession => "SAMN01091086",
		:sex => "male",
		:population_code => "HG01161"
	},
	:HG01092 =>
	{
		:biosample_accession => "SAMN01091085",
		:sex => "female",
		:population_code => "HG01092"
	},
	:HG01077 =>
	{
		:biosample_accession => "SAMN01091084",
		:sex => "female",
		:population_code => "HG01077"
	},
	:HG01064 =>
	{
		:biosample_accession => "SAMN01091083",
		:sex => "female",
		:population_code => "HG01064"
	},
	:HG01063 =>
	{
		:biosample_accession => "SAMN01091082",
		:sex => "male",
		:population_code => "HG01063"
	},
	:HG01058 =>
	{
		:biosample_accession => "SAMN01091081",
		:sex => "female",
		:population_code => "HG01058"
	},
	:HG00743 =>
	{
		:biosample_accession => "SAMN01091080",
		:sex => "female",
		:population_code => "HG00743"
	},
	:HG00742 =>
	{
		:biosample_accession => "SAMN01091079",
		:sex => "male",
		:population_code => "HG00742"
	},
	:HG01414 =>
	{
		:biosample_accession => "SAMN01091078",
		:sex => "female",
		:population_code => "HG01414"
	},
	:HG01413 =>
	{
		:biosample_accession => "SAMN01091077",
		:sex => "male",
		:population_code => "HG01413"
	},
	:HG01403 =>
	{
		:biosample_accession => "SAMN01091076",
		:sex => "female",
		:population_code => "HG01403"
	},
	:HG01402 =>
	{
		:biosample_accession => "SAMN01091075",
		:sex => "male",
		:population_code => "HG01402"
	},
	:HG01396 =>
	{
		:biosample_accession => "SAMN01091074",
		:sex => "female",
		:population_code => "HG01396"
	},
	:HG01395 =>
	{
		:biosample_accession => "SAMN01091073",
		:sex => "male",
		:population_code => "HG01395"
	},
	:HG01393 =>
	{
		:biosample_accession => "SAMN01091072",
		:sex => "female",
		:population_code => "HG01393"
	},
	:HG01392 =>
	{
		:biosample_accession => "SAMN01091071",
		:sex => "male",
		:population_code => "HG01392"
	},
	:HG01326 =>
	{
		:biosample_accession => "SAMN01091070",
		:sex => "female",
		:population_code => "HG01326"
	},
	:HG01325 =>
	{
		:biosample_accession => "SAMN01091069",
		:sex => "male",
		:population_code => "HG01325"
	},
	:HG01323 =>
	{
		:biosample_accession => "SAMN01091068",
		:sex => "female",
		:population_code => "HG01323"
	},
	:HG01322 =>
	{
		:biosample_accession => "SAMN01091067",
		:sex => "M",
		:population_code => "HG01322"
	},
	:HG01312 =>
	{
		:biosample_accession => "SAMN01091066",
		:sex => "female",
		:population_code => "HG01312"
	},
	:HG01311 =>
	{
		:biosample_accession => "SAMN01091065",
		:sex => "male",
		:population_code => "HG01311"
	},
	:HG01303 =>
	{
		:biosample_accession => "SAMN01091064",
		:sex => "female",
		:population_code => "HG01303"
	},
	:HG01302 =>
	{
		:biosample_accession => "SAMN01091063",
		:sex => "male",
		:population_code => "HG01302"
	},
	:HG01089 =>
	{
		:biosample_accession => "SAMN01091062",
		:sex => "female",
		:population_code => "HG01089"
	},
	:HG01088 =>
	{
		:biosample_accession => "SAMN01091061",
		:sex => "male",
		:population_code => "HG01088"
	},
	:HG02580 =>
	{
		:biosample_accession => "SAMN01091060",
		:sex => "female",
		:population_code => "HG02580"
	},
	:HG02577 =>
	{
		:biosample_accession => "SAMN01091059",
		:sex => "female",
		:population_code => "HG02577"
	},
	:HG02558 =>
	{
		:biosample_accession => "SAMN01091058",
		:sex => "female",
		:population_code => "HG02558"
	},
	:HG02557 =>
	{
		:biosample_accession => "SAMN01091057",
		:sex => "male",
		:population_code => "HG02557"
	},
	:HG02555 =>
	{
		:biosample_accession => "SAMN01091056",
		:sex => "female",
		:population_code => "HG02555"
	},
	:HG02554 =>
	{
		:biosample_accession => "SAMN01091055",
		:sex => "male",
		:population_code => "HG02554"
	},
	:HG02549 =>
	{
		:biosample_accession => "SAMN01091054",
		:sex => "female",
		:population_code => "HG02549"
	},
	:HG02546 =>
	{
		:biosample_accession => "SAMN01091053",
		:sex => "female",
		:population_code => "HG02546"
	},
	:HG02545 =>
	{
		:biosample_accession => "SAMN01091052",
		:sex => "male",
		:population_code => "HG02545"
	},
	:HG02541 =>
	{
		:biosample_accession => "SAMN01091051",
		:sex => "male",
		:population_code => "HG02541"
	},
	:HG02536 =>
	{
		:biosample_accession => "SAMN01091050",
		:sex => "male",
		:population_code => "HG02536"
	},
	:HG02505 =>
	{
		:biosample_accession => "SAMN01091049",
		:sex => "female",
		:population_code => "HG02505"
	},
	:HG02502 =>
	{
		:biosample_accession => "SAMN01091048",
		:sex => "female",
		:population_code => "HG02502"
	},
	:HG02501 =>
	{
		:biosample_accession => "SAMN01091047",
		:sex => "male",
		:population_code => "HG02501"
	},
	:HG02481 =>
	{
		:biosample_accession => "SAMN01091046",
		:sex => "male",
		:population_code => "HG02481"
	},
	:HG02477 =>
	{
		:biosample_accession => "SAMN01091045",
		:sex => "female",
		:population_code => "HG02477"
	},
	:HG02476 =>
	{
		:biosample_accession => "SAMN01091044",
		:sex => "female",
		:population_code => "HG02476"
	},
	:HG02455 =>
	{
		:biosample_accession => "SAMN01091043",
		:sex => "male",
		:population_code => "HG02455"
	},
	:HG02439 =>
	{
		:biosample_accession => "SAMN01091042",
		:sex => "male",
		:population_code => "HG02439"
	},
	:HG04026 =>
	{
		:biosample_accession => "SAMN01091041",
		:sex => "female",
		:population_code => "HG04026"
	},
	:HG04017 =>
	{
		:biosample_accession => "SAMN01091040",
		:sex => "male",
		:population_code => "HG04017"
	},
	:HG04002 =>
	{
		:biosample_accession => "SAMN01091039",
		:sex => "male",
		:population_code => "HG04002"
	},
	:HG03973 =>
	{
		:biosample_accession => "SAMN01091038",
		:sex => "female",
		:population_code => "HG03973"
	},
	:HG03976 =>
	{
		:biosample_accession => "SAMN01091037",
		:sex => "male",
		:population_code => "HG03976"
	},
	:HG03974 =>
	{
		:biosample_accession => "SAMN01091036",
		:sex => "male",
		:population_code => "HG03974"
	},
	:HG03971 =>
	{
		:biosample_accession => "SAMN01091035",
		:sex => "male",
		:population_code => "HG03971"
	},
	:HG03978 =>
	{
		:biosample_accession => "SAMN01091034",
		:sex => "male",
		:population_code => "HG03978"
	},
	:HG03874 =>
	{
		:biosample_accession => "SAMN01091032",
		:sex => "female",
		:population_code => "HG03874"
	},
	:HG03862 =>
	{
		:biosample_accession => "SAMN01091031",
		:sex => "female",
		:population_code => "HG03862"
	},
	:HG03869 =>
	{
		:biosample_accession => "SAMN01091030",
		:sex => "male",
		:population_code => "HG03869"
	},
	:HG03864 =>
	{
		:biosample_accession => "SAMN01091029",
		:sex => "male",
		:population_code => "HG03864"
	},
	:HG03789 =>
	{
		:biosample_accession => "SAMN01091028",
		:sex => "female",
		:population_code => "HG03789"
	},
	:HG03788 =>
	{
		:biosample_accession => "SAMN01091027",
		:sex => "male",
		:population_code => "HG03788"
	},
	:HG03787 =>
	{
		:biosample_accession => "SAMN01091026",
		:sex => "female",
		:population_code => "HG03787"
	},
	:HG03784 =>
	{
		:biosample_accession => "SAMN01091025",
		:sex => "female",
		:population_code => "HG03784"
	},
	:HG03786 =>
	{
		:biosample_accession => "SAMN01091024",
		:sex => "male",
		:population_code => "HG03786"
	},
	:HG03772 =>
	{
		:biosample_accession => "SAMN01091023",
		:sex => "female",
		:population_code => "HG03772"
	},
	:HG03773 =>
	{
		:biosample_accession => "SAMN01091022",
		:sex => "male",
		:population_code => "HG03773"
	},
	:HG03775 =>
	{
		:biosample_accession => "SAMN01091021",
		:sex => "male",
		:population_code => "HG03775"
	},
	:HG03781 =>
	{
		:biosample_accession => "SAMN01091020",
		:sex => "female",
		:population_code => "HG03781"
	},
	:HG03882 =>
	{
		:biosample_accession => "SAMN01091019",
		:sex => "female",
		:population_code => "HG03882"
	},
	:HG03770 =>
	{
		:biosample_accession => "SAMN01091018",
		:sex => "female",
		:population_code => "HG03770"
	},
	:HG03771 =>
	{
		:biosample_accession => "SAMN01091017",
		:sex => "male",
		:population_code => "HG03771"
	},
	:HG03731 =>
	{
		:biosample_accession => "SAMN01091016",
		:sex => "female",
		:population_code => "HG03731"
	},
	:HG03729 =>
	{
		:biosample_accession => "SAMN01091015",
		:sex => "male",
		:population_code => "HG03729"
	},
	:HG03721 =>
	{
		:biosample_accession => "SAMN01091014",
		:sex => "female",
		:population_code => "HG03721"
	},
	:HG03727 =>
	{
		:biosample_accession => "SAMN01091013",
		:sex => "male",
		:population_code => "HG03727"
	},
	:HG03730 =>
	{
		:biosample_accession => "SAMN01091012",
		:sex => "female",
		:population_code => "HG03730"
	},
	:HG03722 =>
	{
		:biosample_accession => "SAMN01091010",
		:sex => "female",
		:population_code => "HG03722"
	},
	:HG03725 =>
	{
		:biosample_accession => "SAMN01091009",
		:sex => "male",
		:population_code => "HG03725"
	},
	:HG03717 =>
	{
		:biosample_accession => "SAMN01091008",
		:sex => "female",
		:population_code => "HG03717"
	},
	:HG03714 =>
	{
		:biosample_accession => "SAMN01091007",
		:sex => "female",
		:population_code => "HG03714"
	},
	:HG03716 =>
	{
		:biosample_accession => "SAMN01091006",
		:sex => "male",
		:population_code => "HG03716"
	},
	:HG03715 =>
	{
		:biosample_accession => "SAMN01091005",
		:sex => "male",
		:population_code => "HG03715"
	},
	:HG03713 =>
	{
		:biosample_accession => "SAMN01091004",
		:sex => "male",
		:population_code => "HG03713"
	},
	:HG03943 =>
	{
		:biosample_accession => "SAMN01091003",
		:sex => "male",
		:population_code => "HG03943"
	},
	:HG03900 =>
	{
		:biosample_accession => "SAMN01091002",
		:sex => "male",
		:population_code => "HG03900"
	},
	:HG03898 =>
	{
		:biosample_accession => "SAMN01091001",
		:sex => "female",
		:population_code => "HG03898"
	},
	:HG03896 =>
	{
		:biosample_accession => "SAMN01091000",
		:sex => "male",
		:population_code => "HG03896"
	},
	:HG03986 =>
	{
		:biosample_accession => "SAMN01090999",
		:sex => "female",
		:population_code => "HG03986"
	},
	:HG03887 =>
	{
		:biosample_accession => "SAMN01090998",
		:sex => "male",
		:population_code => "HG03887"
	},
	:HG03858 =>
	{
		:biosample_accession => "SAMN01090997",
		:sex => "female",
		:population_code => "HG03858"
	},
	:HG03950 =>
	{
		:biosample_accession => "SAMN01090996",
		:sex => "male",
		:population_code => "HG03950"
	},
	:HG03849 =>
	{
		:biosample_accession => "SAMN01090995",
		:sex => "female",
		:population_code => "HG03849"
	},
	:HG03838 =>
	{
		:biosample_accession => "SAMN01090994",
		:sex => "female",
		:population_code => "HG03838"
	},
	:HG04006 =>
	{
		:biosample_accession => "SAMN01090993",
		:sex => "male",
		:population_code => "HG04006"
	},
	:HG03844 =>
	{
		:biosample_accession => "SAMN01090992",
		:sex => "male",
		:population_code => "HG03844"
	},
	:HG03756 =>
	{
		:biosample_accession => "SAMN01090991",
		:sex => "female",
		:population_code => "HG03756"
	},
	:HG03754 =>
	{
		:biosample_accession => "SAMN01090990",
		:sex => "female",
		:population_code => "HG03754"
	},
	:HG03750 =>
	{
		:biosample_accession => "SAMN01090989",
		:sex => "male",
		:population_code => "HG03750"
	},
	:HG03888 =>
	{
		:biosample_accession => "SAMN01090988",
		:sex => "female",
		:population_code => "HG03888"
	},
	:HG03746 =>
	{
		:biosample_accession => "SAMN01090987",
		:sex => "male",
		:population_code => "HG03746"
	},
	:HG03757 =>
	{
		:biosample_accession => "SAMN01090986",
		:sex => "female",
		:population_code => "HG03757"
	},
	:HG03743 =>
	{
		:biosample_accession => "SAMN01090985",
		:sex => "male",
		:population_code => "HG03743"
	},
	:HG03884 =>
	{
		:biosample_accession => "SAMN01090984",
		:sex => "female",
		:population_code => "HG03884"
	},
	:HG03741 =>
	{
		:biosample_accession => "SAMN01090983",
		:sex => "female",
		:population_code => "HG03741"
	},
	:HG03740 =>
	{
		:biosample_accession => "SAMN01090982",
		:sex => "male",
		:population_code => "HG03740"
	},
	:HG03693 =>
	{
		:biosample_accession => "SAMN01090981",
		:sex => "male",
		:population_code => "HG03693"
	},
	:HG03692 =>
	{
		:biosample_accession => "SAMN01090980",
		:sex => "female",
		:population_code => "HG03692"
	},
	:HG03886 =>
	{
		:biosample_accession => "SAMN01090978",
		:sex => "female",
		:population_code => "HG03886"
	},
	:HG03885 =>
	{
		:biosample_accession => "SAMN01090977",
		:sex => "male",
		:population_code => "HG03885"
	},
	:HG03684 =>
	{
		:biosample_accession => "SAMN01090975",
		:sex => "female",
		:population_code => "HG03684"
	},
	:HG03948 =>
	{
		:biosample_accession => "SAMN01090973",
		:sex => "female",
		:population_code => "HG03948"
	},
	:HG03673 =>
	{
		:biosample_accession => "SAMN01090972",
		:sex => "female",
		:population_code => "HG03673"
	},
	:HG03642 =>
	{
		:biosample_accession => "SAMN01090971",
		:sex => "female",
		:population_code => "HG03642"
	},
	:HG03679 =>
	{
		:biosample_accession => "SAMN01090970",
		:sex => "male",
		:population_code => "HG03679"
	},
	:HG03643 =>
	{
		:biosample_accession => "SAMN01090969",
		:sex => "female",
		:population_code => "HG03643"
	},
	:HG03644 =>
	{
		:biosample_accession => "SAMN01090968",
		:sex => "male",
		:population_code => "HG03644"
	},
	:HG04156 =>
	{
		:biosample_accession => "SAMN01090966",
		:sex => "female",
		:population_code => "HG04156"
	},
	:HG04155 =>
	{
		:biosample_accession => "SAMN01090965",
		:sex => "male",
		:population_code => "HG04155"
	},
	:HG03940 =>
	{
		:biosample_accession => "SAMN01090964",
		:sex => "female",
		:population_code => "HG03940"
	},
	:HG03941 =>
	{
		:biosample_accession => "SAMN01090963",
		:sex => "male",
		:population_code => "HG03941"
	},
	:HG03913 =>
	{
		:biosample_accession => "SAMN01090961",
		:sex => "female",
		:population_code => "HG03913"
	},
	:HG03914 =>
	{
		:biosample_accession => "SAMN01090960",
		:sex => "male",
		:population_code => "HG03914"
	},
	:HG03832 =>
	{
		:biosample_accession => "SAMN01090958",
		:sex => "female",
		:population_code => "HG03832"
	},
	:HG03833 =>
	{
		:biosample_accession => "SAMN01090957",
		:sex => "male",
		:population_code => "HG03833"
	},
	:HG03829 =>
	{
		:biosample_accession => "SAMN01090956",
		:sex => "female",
		:population_code => "HG03829"
	},
	:HG03830 =>
	{
		:biosample_accession => "SAMN01090955",
		:sex => "male",
		:population_code => "HG03830"
	},
	:HG03826 =>
	{
		:biosample_accession => "SAMN01090953",
		:sex => "female",
		:population_code => "HG03826"
	},
	:HG03823 =>
	{
		:biosample_accession => "SAMN01090951",
		:sex => "female",
		:population_code => "HG03823"
	},
	:HG03824 =>
	{
		:biosample_accession => "SAMN01090950",
		:sex => "male",
		:population_code => "HG03824"
	},
	:HG03814 =>
	{
		:biosample_accession => "SAMN01090949",
		:sex => "female",
		:population_code => "HG03814"
	},
	:HG03815 =>
	{
		:biosample_accession => "SAMN01090948",
		:sex => "male",
		:population_code => "HG03815"
	},
	:HG03802 =>
	{
		:biosample_accession => "SAMN01090946",
		:sex => "female",
		:population_code => "HG03802"
	},
	:HG03803 =>
	{
		:biosample_accession => "SAMN01090945",
		:sex => "male",
		:population_code => "HG03803"
	},
	:HG03799 =>
	{
		:biosample_accession => "SAMN01090944",
		:sex => "female",
		:population_code => "HG03799"
	},
	:HG03800 =>
	{
		:biosample_accession => "SAMN01090943",
		:sex => "male",
		:population_code => "HG03800"
	},
	:HG03796 =>
	{
		:biosample_accession => "SAMN01090941",
		:sex => "female",
		:population_code => "HG03796"
	},
	:HG03797 =>
	{
		:biosample_accession => "SAMN01090940",
		:sex => "male",
		:population_code => "HG03797"
	},
	:HG03793 =>
	{
		:biosample_accession => "SAMN01090939",
		:sex => "female",
		:population_code => "HG03793"
	},
	:HG03616 =>
	{
		:biosample_accession => "SAMN01090937",
		:sex => "female",
		:population_code => "HG03616"
	},
	:HG03615 =>
	{
		:biosample_accession => "SAMN01090936",
		:sex => "male",
		:population_code => "HG03615"
	},
	:HG03007 =>
	{
		:biosample_accession => "SAMN01090934",
		:sex => "female",
		:population_code => "HG03007"
	},
	:HG03006 =>
	{
		:biosample_accession => "SAMN01090933",
		:sex => "male",
		:population_code => "HG03006"
	},
	:HG03710 =>
	{
		:biosample_accession => "SAMN01090932",
		:sex => "male",
		:population_code => "HG03710"
	},
	:HG03709 =>
	{
		:biosample_accession => "SAMN01090931",
		:sex => "female",
		:population_code => "HG03709"
	},
	:HG03708 =>
	{
		:biosample_accession => "SAMN01090930",
		:sex => "male",
		:population_code => "HG03708"
	},
	:HG03704 =>
	{
		:biosample_accession => "SAMN01090929",
		:sex => "female",
		:population_code => "HG03704"
	},
	:HG03703 =>
	{
		:biosample_accession => "SAMN01090928",
		:sex => "female",
		:population_code => "HG03703"
	},
	:HG03702 =>
	{
		:biosample_accession => "SAMN01090927",
		:sex => "male",
		:population_code => "HG03702"
	},
	:HG03017 =>
	{
		:biosample_accession => "SAMN01090926",
		:sex => "male",
		:population_code => "HG03017"
	},
	:HG03016 =>
	{
		:biosample_accession => "SAMN01090925",
		:sex => "female",
		:population_code => "HG03016"
	},
	:HG03015 =>
	{
		:biosample_accession => "SAMN01090924",
		:sex => "male",
		:population_code => "HG03015"
	},
	:HG03669 =>
	{
		:biosample_accession => "SAMN01090923",
		:sex => "female",
		:population_code => "HG03669"
	},
	:HG03668 =>
	{
		:biosample_accession => "SAMN01090922",
		:sex => "female",
		:population_code => "HG03668"
	},
	:HG03667 =>
	{
		:biosample_accession => "SAMN01090921",
		:sex => "male",
		:population_code => "HG03667"
	},
	:HG03635 =>
	{
		:biosample_accession => "SAMN01090920",
		:sex => "female",
		:population_code => "HG03635"
	},
	:HG03634 =>
	{
		:biosample_accession => "SAMN01090919",
		:sex => "female",
		:population_code => "HG03634"
	},
	:HG03633 =>
	{
		:biosample_accession => "SAMN01090918",
		:sex => "male",
		:population_code => "HG03633"
	},
	:HG03620 =>
	{
		:biosample_accession => "SAMN01090917",
		:sex => "female",
		:population_code => "HG03620"
	},
	:HG03619 =>
	{
		:biosample_accession => "SAMN01090916",
		:sex => "female",
		:population_code => "HG03619"
	},
	:HG03618 =>
	{
		:biosample_accession => "SAMN01090915",
		:sex => "male",
		:population_code => "HG03618"
	},
	:HG03492 =>
	{
		:biosample_accession => "SAMN01090914",
		:sex => "male",
		:population_code => "HG03492"
	},
	:HG03491 =>
	{
		:biosample_accession => "SAMN01090913",
		:sex => "female",
		:population_code => "HG03491"
	},
	:HG03490 =>
	{
		:biosample_accession => "SAMN01090912",
		:sex => "male",
		:population_code => "HG03490"
	},
	:HG03489 =>
	{
		:biosample_accession => "SAMN01090911",
		:sex => "male",
		:population_code => "HG03489"
	},
	:HG03488 =>
	{
		:biosample_accession => "SAMN01090910",
		:sex => "female",
		:population_code => "HG03488"
	},
	:HG03487 =>
	{
		:biosample_accession => "SAMN01090909",
		:sex => "male",
		:population_code => "HG03487"
	},
	:HG03236 =>
	{
		:biosample_accession => "SAMN01090908",
		:sex => "female",
		:population_code => "HG03236"
	},
	:HG03235 =>
	{
		:biosample_accession => "SAMN01090907",
		:sex => "female",
		:population_code => "HG03235"
	},
	:HG03234 =>
	{
		:biosample_accession => "SAMN01090906",
		:sex => "male",
		:population_code => "HG03234"
	},
	:HG03306 =>
	{
		:biosample_accession => "SAMN01090904",
		:sex => "female",
		:population_code => "HG03306"
	},
	:HG03307 =>
	{
		:biosample_accession => "SAMN01090903",
		:sex => "male",
		:population_code => "HG03307"
	},
	:HG03369 =>
	{
		:biosample_accession => "SAMN01090901",
		:sex => "female",
		:population_code => "HG03369"
	},
	:HG03370 =>
	{
		:biosample_accession => "SAMN01090900",
		:sex => "male",
		:population_code => "HG03370"
	},
	:HG03342 =>
	{
		:biosample_accession => "SAMN01090898",
		:sex => "female",
		:population_code => "HG03342"
	},
	:HG03343 =>
	{
		:biosample_accession => "SAMN01090897",
		:sex => "male",
		:population_code => "HG03343"
	},
	:HG03198 =>
	{
		:biosample_accession => "SAMN01090895",
		:sex => "female",
		:population_code => "HG03198"
	},
	:HG03199 =>
	{
		:biosample_accession => "SAMN01090894",
		:sex => "male",
		:population_code => "HG03199"
	},
	:HG03195 =>
	{
		:biosample_accession => "SAMN01090892",
		:sex => "female",
		:population_code => "HG03195"
	},
	:HG03196 =>
	{
		:biosample_accession => "SAMN01090891",
		:sex => "male",
		:population_code => "HG03196"
	},
	:HG03171 =>
	{
		:biosample_accession => "SAMN01090889",
		:sex => "female",
		:population_code => "HG03171"
	},
	:HG03172 =>
	{
		:biosample_accession => "SAMN01090888",
		:sex => "male",
		:population_code => "HG03172"
	},
	:HG03168 =>
	{
		:biosample_accession => "SAMN01090886",
		:sex => "female",
		:population_code => "HG03168"
	},
	:HG03169 =>
	{
		:biosample_accession => "SAMN01090885",
		:sex => "male",
		:population_code => "HG03169"
	},
	:HG03162 =>
	{
		:biosample_accession => "SAMN01090883",
		:sex => "female",
		:population_code => "HG03162"
	},
	:HG03163 =>
	{
		:biosample_accession => "SAMN01090882",
		:sex => "male",
		:population_code => "HG03163"
	},
	:HG03159 =>
	{
		:biosample_accession => "SAMN01090880",
		:sex => "female",
		:population_code => "HG03159"
	},
	:HG03160 =>
	{
		:biosample_accession => "SAMN01090879",
		:sex => "male",
		:population_code => "HG03160"
	},
	:HG03129 =>
	{
		:biosample_accession => "SAMN01090877",
		:sex => "female",
		:population_code => "HG03129"
	},
	:HG03130 =>
	{
		:biosample_accession => "SAMN01090876",
		:sex => "male",
		:population_code => "HG03130"
	},
	:HG03117 =>
	{
		:biosample_accession => "SAMN01090874",
		:sex => "female",
		:population_code => "HG03117"
	},
	:HG03118 =>
	{
		:biosample_accession => "SAMN01090873",
		:sex => "male",
		:population_code => "HG03118"
	},
	:HG02976 =>
	{
		:biosample_accession => "SAMN01090871",
		:sex => "female",
		:population_code => "HG02976"
	},
	:HG02977 =>
	{
		:biosample_accession => "SAMN01090870",
		:sex => "male",
		:population_code => "HG02977"
	},
	:HG02952 =>
	{
		:biosample_accession => "SAMN01090868",
		:sex => "female",
		:population_code => "HG02952"
	},
	:HG02953 =>
	{
		:biosample_accession => "SAMN01090867",
		:sex => "male",
		:population_code => "HG02953"
	},
	:HG02970 =>
	{
		:biosample_accession => "SAMN01090865",
		:sex => "female",
		:population_code => "HG02970"
	},
	:HG02971 =>
	{
		:biosample_accession => "SAMN01090864",
		:sex => "male",
		:population_code => "HG02971"
	},
	:HG02946 =>
	{
		:biosample_accession => "SAMN01090862",
		:sex => "female",
		:population_code => "HG02946"
	},
	:HG02947 =>
	{
		:biosample_accession => "SAMN01090861",
		:sex => "male",
		:population_code => "HG02947"
	},
	:"HG03366 " =>
	{
		:biosample_accession => "SAMN01090859",
		:sex => "female",
		:population_code => "HG03366 "
	},
	:HG03367 =>
	{
		:biosample_accession => "SAMN01090858",
		:sex => "male",
		:population_code => "HG03367"
	},
	:HG03300 =>
	{
		:biosample_accession => "SAMN01090856",
		:sex => "female",
		:population_code => "HG03300"
	},
	:HG03301 =>
	{
		:biosample_accession => "SAMN01090855",
		:sex => "male",
		:population_code => "HG03301"
	},
	:HG03294 =>
	{
		:biosample_accession => "SAMN01090853",
		:sex => "female",
		:population_code => "HG03294"
	},
	:HG03295 =>
	{
		:biosample_accession => "SAMN01090852",
		:sex => "male",
		:population_code => "HG03295"
	},
	:HG03291 =>
	{
		:biosample_accession => "SAMN01090850",
		:sex => "female",
		:population_code => "HG03291"
	},
	:HG03279 =>
	{
		:biosample_accession => "SAMN01090847",
		:sex => "female",
		:population_code => "HG03279"
	},
	:HG03280 =>
	{
		:biosample_accession => "SAMN01090846",
		:sex => "male",
		:population_code => "HG03280"
	},
	:HG03270 =>
	{
		:biosample_accession => "SAMN01090844",
		:sex => "female",
		:population_code => "HG03270"
	},
	:HG03271 =>
	{
		:biosample_accession => "SAMN01090843",
		:sex => "male",
		:population_code => "HG03271"
	},
	:HG03267 =>
	{
		:biosample_accession => "SAMN01090841",
		:sex => "female",
		:population_code => "HG03267"
	},
	:HG03268 =>
	{
		:biosample_accession => "SAMN01090840",
		:sex => "male",
		:population_code => "HG03268"
	},
	:HG03514 =>
	{
		:biosample_accession => "SAMN01090838",
		:sex => "female",
		:population_code => "HG03514"
	},
	:HG03515 =>
	{
		:biosample_accession => "SAMN01090837",
		:sex => "male",
		:population_code => "HG03515"
	},
	:HG03583 =>
	{
		:biosample_accession => "SAMN01090834",
		:sex => "female",
		:population_code => "HG03583"
	},
	:HG03578 =>
	{
		:biosample_accession => "SAMN01090832",
		:sex => "female",
		:population_code => "HG03578"
	},
	:HG03577 =>
	{
		:biosample_accession => "SAMN01090831",
		:sex => "male",
		:population_code => "HG03577"
	},
	:HG03575 =>
	{
		:biosample_accession => "SAMN01090829",
		:sex => "female",
		:population_code => "HG03575"
	},
	:HG03572 =>
	{
		:biosample_accession => "SAMN01090828",
		:sex => "female",
		:population_code => "HG03572"
	},
	:HG03571 =>
	{
		:biosample_accession => "SAMN01090827",
		:sex => "male",
		:population_code => "HG03571"
	},
	:HG03569 =>
	{
		:biosample_accession => "SAMN01090826",
		:sex => "female",
		:population_code => "HG03569"
	},
	:HG03565 =>
	{
		:biosample_accession => "SAMN01090825",
		:sex => "male",
		:population_code => "HG03565"
	},
	:HG03563 =>
	{
		:biosample_accession => "SAMN01090823",
		:sex => "female",
		:population_code => "HG03563"
	},
	:HG03559 =>
	{
		:biosample_accession => "SAMN01090822",
		:sex => "male",
		:population_code => "HG03559"
	},
	:HG03455 =>
	{
		:biosample_accession => "SAMN01090820",
		:sex => "female",
		:population_code => "HG03455"
	},
	:HG03431 =>
	{
		:biosample_accession => "SAMN01090819",
		:sex => "female",
		:population_code => "HG03431"
	},
	:HG03391 =>
	{
		:biosample_accession => "SAMN01090818",
		:sex => "male",
		:population_code => "HG03391"
	},
	:HG03557 =>
	{
		:biosample_accession => "SAMN01090817",
		:sex => "female",
		:population_code => "HG03557"
	},
	:HG03556 =>
	{
		:biosample_accession => "SAMN01090816",
		:sex => "male",
		:population_code => "HG03556"
	},
	:HG03548 =>
	{
		:biosample_accession => "SAMN01090815",
		:sex => "female",
		:population_code => "HG03548"
	},
	:HG03547 =>
	{
		:biosample_accession => "SAMN01090814",
		:sex => "male",
		:population_code => "HG03547"
	},
	:HG03485 =>
	{
		:biosample_accession => "SAMN01090812",
		:sex => "female",
		:population_code => "HG03485"
	},
	:HG03484 =>
	{
		:biosample_accession => "SAMN01090811",
		:sex => "male",
		:population_code => "HG03484"
	},
	:HG03476 =>
	{
		:biosample_accession => "SAMN01090809",
		:sex => "female",
		:population_code => "HG03476"
	},
	:HG03458 =>
	{
		:biosample_accession => "SAMN01090807",
		:sex => "female",
		:population_code => "HG03458"
	},
	:HG03449 =>
	{
		:biosample_accession => "SAMN01090805",
		:sex => "female",
		:population_code => "HG03449"
	},
	:HG03437 =>
	{
		:biosample_accession => "SAMN01090803",
		:sex => "female",
		:population_code => "HG03437"
	},
	:HG03436 =>
	{
		:biosample_accession => "SAMN01090802",
		:sex => "male",
		:population_code => "HG03436"
	},
	:HG03410 =>
	{
		:biosample_accession => "SAMN01090800",
		:sex => "female",
		:population_code => "HG03410"
	},
	:HG03076 =>
	{
		:biosample_accession => "SAMN01090799",
		:sex => "female",
		:population_code => "HG03076"
	},
	:HG03072 =>
	{
		:biosample_accession => "SAMN01090798",
		:sex => "male",
		:population_code => "HG03072"
	},
	:HG03069 =>
	{
		:biosample_accession => "SAMN01090797",
		:sex => "male",
		:population_code => "HG03069"
	},
	:HG03066 =>
	{
		:biosample_accession => "SAMN01090796",
		:sex => "male",
		:population_code => "HG03066"
	},
	:HG03479 =>
	{
		:biosample_accession => "SAMN01090794",
		:sex => "female",
		:population_code => "HG03479"
	},
	:HG03478 =>
	{
		:biosample_accession => "SAMN01090793",
		:sex => "male",
		:population_code => "HG03478"
	},
	:HG03461 =>
	{
		:biosample_accession => "SAMN01090792",
		:sex => "female",
		:population_code => "HG03461"
	},
	:HG03460 =>
	{
		:biosample_accession => "SAMN01090791",
		:sex => "male",
		:population_code => "HG03460"
	},
	:HG03446 =>
	{
		:biosample_accession => "SAMN01090790",
		:sex => "female",
		:population_code => "HG03446"
	},
	:HG03445 =>
	{
		:biosample_accession => "SAMN01090789",
		:sex => "male",
		:population_code => "HG03445"
	},
	:HG03442 =>
	{
		:biosample_accession => "SAMN01090788",
		:sex => "male",
		:population_code => "HG03442"
	},
	:HG03439 =>
	{
		:biosample_accession => "SAMN01090787",
		:sex => "male",
		:population_code => "HG03439"
	},
	:HG03433 =>
	{
		:biosample_accession => "SAMN01090786",
		:sex => "male",
		:population_code => "HG03433"
	},
	:HG03428 =>
	{
		:biosample_accession => "SAMN01090785",
		:sex => "female",
		:population_code => "HG03428"
	},
	:HG03061 =>
	{
		:biosample_accession => "SAMN01090784",
		:sex => "female",
		:population_code => "HG03061"
	},
	:HG03419 =>
	{
		:biosample_accession => "SAMN01090783",
		:sex => "female",
		:population_code => "HG03419"
	},
	:HG03401 =>
	{
		:biosample_accession => "SAMN01090781",
		:sex => "female",
		:population_code => "HG03401"
	},
	:HG03388 =>
	{
		:biosample_accession => "SAMN01090780",
		:sex => "male",
		:population_code => "HG03388"
	},
	:HG03385 =>
	{
		:biosample_accession => "SAMN01090779",
		:sex => "male",
		:population_code => "HG03385"
	},
	:HG03380 =>
	{
		:biosample_accession => "SAMN01090778",
		:sex => "female",
		:population_code => "HG03380"
	},
	:HG03376 =>
	{
		:biosample_accession => "SAMN01090777",
		:sex => "male",
		:population_code => "HG03376"
	},
	:HG03055 =>
	{
		:biosample_accession => "SAMN01090776",
		:sex => "female",
		:population_code => "HG03055"
	},
	:HG03212 =>
	{
		:biosample_accession => "SAMN01090775",
		:sex => "female",
		:population_code => "HG03212"
	},
	:HG03209 =>
	{
		:biosample_accession => "SAMN01090774",
		:sex => "male",
		:population_code => "HG03209"
	},
	:HG03088 =>
	{
		:biosample_accession => "SAMN01090773",
		:sex => "female",
		:population_code => "HG03088"
	},
	:HG03081 =>
	{
		:biosample_accession => "SAMN01090772",
		:sex => "male",
		:population_code => "HG03081"
	},
	:HG03398 =>
	{
		:biosample_accession => "SAMN01090771",
		:sex => "female",
		:population_code => "HG03398"
	},
	:HG03473 =>
	{
		:biosample_accession => "SAMN01090769",
		:sex => "female",
		:population_code => "HG03473"
	},
	:HG03470 =>
	{
		:biosample_accession => "SAMN01090768",
		:sex => "female",
		:population_code => "HG03470"
	},
	:HG02855 =>
	{
		:biosample_accession => "SAMN01090764",
		:sex => "female",
		:population_code => "HG02855"
	},
	:HG02854 =>
	{
		:biosample_accession => "SAMN01090763",
		:sex => "male",
		:population_code => "HG02854"
	},
	:HG02820 =>
	{
		:biosample_accession => "SAMN01090761",
		:sex => "female",
		:population_code => "HG02820"
	},
	:HG02819 =>
	{
		:biosample_accession => "SAMN01090760",
		:sex => "male",
		:population_code => "HG02819"
	},
	:HG03539 =>
	{
		:biosample_accession => "SAMN01090758",
		:sex => "female",
		:population_code => "HG03539"
	},
	:HG03538 =>
	{
		:biosample_accession => "SAMN01090757",
		:sex => "male",
		:population_code => "HG03538"
	},
	:HG03247 =>
	{
		:biosample_accession => "SAMN01090755",
		:sex => "female",
		:population_code => "HG03247"
	},
	:HG03246 =>
	{
		:biosample_accession => "SAMN01090754",
		:sex => "male",
		:population_code => "HG03246"
	},
	:HG03241 =>
	{
		:biosample_accession => "SAMN01090752",
		:sex => "female",
		:population_code => "HG03241"
	},
	:HG03240 =>
	{
		:biosample_accession => "SAMN01090751",
		:sex => "male",
		:population_code => "HG03240"
	},
	:"HG03025 " =>
	{
		:biosample_accession => "SAMN01090749",
		:sex => "female",
		:population_code => "HG03025 "
	},
	:HG03024 =>
	{
		:biosample_accession => "SAMN01090748",
		:sex => "male",
		:population_code => "HG03024"
	},
	:HG00675 =>
	{
		:biosample_accession => "SAMN01036855",
		:sex => "female",
		:population_code => "HG00675"
	},
	:HG00674 =>
	{
		:biosample_accession => "SAMN01036854",
		:sex => "male",
		:population_code => "HG00674"
	},
	:HG00632 =>
	{
		:biosample_accession => "SAMN01036852",
		:sex => "female",
		:population_code => "HG00632"
	},
	:HG00631 =>
	{
		:biosample_accession => "SAMN01036851",
		:sex => "male",
		:population_code => "HG00631"
	},
	:HG00623 =>
	{
		:biosample_accession => "SAMN01036849",
		:sex => "female",
		:population_code => "HG00623"
	},
	:HG00622 =>
	{
		:biosample_accession => "SAMN01036848",
		:sex => "male",
		:population_code => "HG00622"
	},
	:HG00729 =>
	{
		:biosample_accession => "SAMN01036846",
		:sex => "female",
		:population_code => "HG00729"
	},
	:HG00728 =>
	{
		:biosample_accession => "SAMN01036845",
		:sex => "male",
		:population_code => "HG00728"
	},
	:HG00599 =>
	{
		:biosample_accession => "SAMN01036843",
		:sex => "female",
		:population_code => "HG00599"
	},
	:HG00598 =>
	{
		:biosample_accession => "SAMN01036842",
		:sex => "male",
		:population_code => "HG00598"
	},
	:HG00410 =>
	{
		:biosample_accession => "SAMN01036840",
		:sex => "female",
		:population_code => "HG00410"
	},
	:HG00409 =>
	{
		:biosample_accession => "SAMN01036839",
		:sex => "male",
		:population_code => "HG00409"
	},
	:HG02791 =>
	{
		:biosample_accession => "SAMN01036838",
		:sex => "male",
		:population_code => "HG02791"
	},
	:HG02790 =>
	{
		:biosample_accession => "SAMN01036837",
		:sex => "female",
		:population_code => "HG02790"
	},
	:HG02789 =>
	{
		:biosample_accession => "SAMN01036836",
		:sex => "male",
		:population_code => "HG02789"
	},
	:HG02787 =>
	{
		:biosample_accession => "SAMN01036834",
		:sex => "female",
		:population_code => "HG02787"
	},
	:HG02786 =>
	{
		:biosample_accession => "SAMN01036833",
		:sex => "male",
		:population_code => "HG02786"
	},
	:HG02785 =>
	{
		:biosample_accession => "SAMN01036832",
		:sex => "female",
		:population_code => "HG02785"
	},
	:HG02784 =>
	{
		:biosample_accession => "SAMN01036831",
		:sex => "female",
		:population_code => "HG02784"
	},
	:HG02783 =>
	{
		:biosample_accession => "SAMN01036830",
		:sex => "male",
		:population_code => "HG02783"
	},
	:HG02729 =>
	{
		:biosample_accession => "SAMN01036829",
		:sex => "male",
		:population_code => "HG02729"
	},
	:HG02728 =>
	{
		:biosample_accession => "SAMN01036828",
		:sex => "female",
		:population_code => "HG02728"
	},
	:HG02727 =>
	{
		:biosample_accession => "SAMN01036827",
		:sex => "male",
		:population_code => "HG02727"
	},
	:HG02726 =>
	{
		:biosample_accession => "SAMN01036826",
		:sex => "female",
		:population_code => "HG02726"
	},
	:HG02725 =>
	{
		:biosample_accession => "SAMN01036825",
		:sex => "female",
		:population_code => "HG02725"
	},
	:HG02724 =>
	{
		:biosample_accession => "SAMN01036824",
		:sex => "male",
		:population_code => "HG02724"
	},
	:HG03135 =>
	{
		:biosample_accession => "SAMN01036822",
		:sex => "female",
		:population_code => "HG03135"
	},
	:HG03136 =>
	{
		:biosample_accession => "SAMN01036821",
		:sex => "male",
		:population_code => "HG03136"
	},
	:HG03132 =>
	{
		:biosample_accession => "SAMN01036819",
		:sex => "female",
		:population_code => "HG03132"
	},
	:HG03133 =>
	{
		:biosample_accession => "SAMN01036818",
		:sex => "male",
		:population_code => "HG03133"
	},
	:HG03123 =>
	{
		:biosample_accession => "SAMN01036816",
		:sex => "female",
		:population_code => "HG03123"
	},
	:HG03124 =>
	{
		:biosample_accession => "SAMN01036815",
		:sex => "male",
		:population_code => "HG03124"
	},
	:HG03120 =>
	{
		:biosample_accession => "SAMN01036813",
		:sex => "male",
		:population_code => "HG03120"
	},
	:HG03121 =>
	{
		:biosample_accession => "SAMN01036812",
		:sex => "female",
		:population_code => "HG03121"
	},
	:HG03114 =>
	{
		:biosample_accession => "SAMN01036810",
		:sex => "female",
		:population_code => "HG03114"
	},
	:HG03115 =>
	{
		:biosample_accession => "SAMN01036809",
		:sex => "male",
		:population_code => "HG03115"
	},
	:HG03108 =>
	{
		:biosample_accession => "SAMN01036807",
		:sex => "female",
		:population_code => "HG03108"
	},
	:HG03109 =>
	{
		:biosample_accession => "SAMN01036806",
		:sex => "male",
		:population_code => "HG03109"
	},
	:HG03099 =>
	{
		:biosample_accession => "SAMN01036804",
		:sex => "female",
		:population_code => "HG03099"
	},
	:HG03100 =>
	{
		:biosample_accession => "SAMN01036803",
		:sex => "male",
		:population_code => "HG03100"
	},
	:HG02973 =>
	{
		:biosample_accession => "SAMN01036801",
		:sex => "male",
		:population_code => "HG02973"
	},
	:HG02974 =>
	{
		:biosample_accession => "SAMN01036800",
		:sex => "female",
		:population_code => "HG02974"
	},
	:HG02943 =>
	{
		:biosample_accession => "SAMN01036798",
		:sex => "female",
		:population_code => "HG02943"
	},
	:HG02944 =>
	{
		:biosample_accession => "SAMN01036797",
		:sex => "male",
		:population_code => "HG02944"
	},
	:HG02922 =>
	{
		:biosample_accession => "SAMN01036795",
		:sex => "female",
		:population_code => "HG02922"
	},
	:HG02923 =>
	{
		:biosample_accession => "SAMN01036794",
		:sex => "male",
		:population_code => "HG02923"
	},
	:HG03472 =>
	{
		:biosample_accession => "SAMN01036793",
		:sex => "male",
		:population_code => "HG03472"
	},
	:HG03469 =>
	{
		:biosample_accession => "SAMN01036792",
		:sex => "male",
		:population_code => "HG03469"
	},
	:HG03464 =>
	{
		:biosample_accession => "SAMN01036791",
		:sex => "female",
		:population_code => "HG03464"
	},
	:HG03452 =>
	{
		:biosample_accession => "SAMN01036789",
		:sex => "female",
		:population_code => "HG03452"
	},
	:HG03451 =>
	{
		:biosample_accession => "SAMN01036788",
		:sex => "male",
		:population_code => "HG03451"
	},
	:HG03397 =>
	{
		:biosample_accession => "SAMN01036787",
		:sex => "male",
		:population_code => "HG03397"
	},
	:HG03097 =>
	{
		:biosample_accession => "SAMN01036785",
		:sex => "female",
		:population_code => "HG03097"
	},
	:HG03096 =>
	{
		:biosample_accession => "SAMN01036784",
		:sex => "male",
		:population_code => "HG03096"
	},
	:HG03085 =>
	{
		:biosample_accession => "SAMN01036783",
		:sex => "female",
		:population_code => "HG03085"
	},
	:HG03084 =>
	{
		:biosample_accession => "SAMN01036782",
		:sex => "male",
		:population_code => "HG03084"
	},
	:HG03078 =>
	{
		:biosample_accession => "SAMN01036781",
		:sex => "male",
		:population_code => "HG03078"
	},
	:HG03058 =>
	{
		:biosample_accession => "SAMN01036780",
		:sex => "female",
		:population_code => "HG03058"
	},
	:HG03057 =>
	{
		:biosample_accession => "SAMN01036779",
		:sex => "male",
		:population_code => "HG03057"
	},
	:HG03052 =>
	{
		:biosample_accession => "SAMN01036778",
		:sex => "female",
		:population_code => "HG03052"
	},
	:HG02891 =>
	{
		:biosample_accession => "SAMN01036776",
		:sex => "female",
		:population_code => "HG02891"
	},
	:HG02890 =>
	{
		:biosample_accession => "SAMN01036775",
		:sex => "male",
		:population_code => "HG02890"
	},
	:HG02885 =>
	{
		:biosample_accession => "SAMN01036773",
		:sex => "female",
		:population_code => "HG02885"
	},
	:HG02884 =>
	{
		:biosample_accession => "SAMN01036772",
		:sex => "male",
		:population_code => "HG02884"
	},
	:HG02861 =>
	{
		:biosample_accession => "SAMN01036770",
		:sex => "female",
		:population_code => "HG02861"
	},
	:HG02860 =>
	{
		:biosample_accession => "SAMN01036769",
		:sex => "male",
		:population_code => "HG02860"
	},
	:HG02837 =>
	{
		:biosample_accession => "SAMN01036767",
		:sex => "female",
		:population_code => "HG02837"
	},
	:HG02836 =>
	{
		:biosample_accession => "SAMN01036766",
		:sex => "male",
		:population_code => "HG02836"
	},
	:HG02817 =>
	{
		:biosample_accession => "SAMN01036764",
		:sex => "female",
		:population_code => "HG02817"
	},
	:HG02816 =>
	{
		:biosample_accession => "SAMN01036763",
		:sex => "male",
		:population_code => "HG02816"
	},
	:HG02757 =>
	{
		:biosample_accession => "SAMN01036761",
		:sex => "female",
		:population_code => "HG02757"
	},
	:HG02756 =>
	{
		:biosample_accession => "SAMN01036760",
		:sex => "male",
		:population_code => "HG02756"
	},
	:HG03259 =>
	{
		:biosample_accession => "SAMN01036758",
		:sex => "female",
		:population_code => "HG03259"
	},
	:HG03258 =>
	{
		:biosample_accession => "SAMN01036757",
		:sex => "male",
		:population_code => "HG03258"
	},
	:HG03049 =>
	{
		:biosample_accession => "SAMN01036755",
		:sex => "female",
		:population_code => "HG03049"
	},
	:HG03048 =>
	{
		:biosample_accession => "SAMN01036754",
		:sex => "male",
		:population_code => "HG03048"
	},
	:HG03046 =>
	{
		:biosample_accession => "SAMN01036752",
		:sex => "female",
		:population_code => "HG03046"
	},
	:HG03045 =>
	{
		:biosample_accession => "SAMN01036751",
		:sex => "male",
		:population_code => "HG03045"
	},
	:HG03040 =>
	{
		:biosample_accession => "SAMN01036749",
		:sex => "female",
		:population_code => "HG03040"
	},
	:HG03039 =>
	{
		:biosample_accession => "SAMN01036748",
		:sex => "male",
		:population_code => "HG03039"
	},
	:HG03028 =>
	{
		:biosample_accession => "SAMN01036746",
		:sex => "female",
		:population_code => "HG03028"
	},
	:HG03027 =>
	{
		:biosample_accession => "SAMN01036745",
		:sex => "male",
		:population_code => "HG03027"
	},
	:HG02896 =>
	{
		:biosample_accession => "SAMN01036743",
		:sex => "female",
		:population_code => "HG02896"
	},
	:HG02895 =>
	{
		:biosample_accession => "SAMN01036742",
		:sex => "male",
		:population_code => "HG02895"
	},
	:HG02888 =>
	{
		:biosample_accession => "SAMN01036740",
		:sex => "female",
		:population_code => "HG02888"
	},
	:HG02887 =>
	{
		:biosample_accession => "SAMN01036739",
		:sex => "male",
		:population_code => "HG02887"
	},
	:HG02852 =>
	{
		:biosample_accession => "SAMN01036737",
		:sex => "female",
		:population_code => "HG02852"
	},
	:HG02851 =>
	{
		:biosample_accession => "SAMN01036736",
		:sex => "male",
		:population_code => "HG02851"
	},
	:HG02840 =>
	{
		:biosample_accession => "SAMN01036734",
		:sex => "female",
		:population_code => "HG02840"
	},
	:HG02839 =>
	{
		:biosample_accession => "SAMN01036733",
		:sex => "male",
		:population_code => "HG02839"
	},
	:HG02814 =>
	{
		:biosample_accession => "SAMN01036731",
		:sex => "female",
		:population_code => "HG02814"
	},
	:HG02813 =>
	{
		:biosample_accession => "SAMN01036730",
		:sex => "male",
		:population_code => "HG02813"
	},
	:HG02811 =>
	{
		:biosample_accession => "SAMN01036728",
		:sex => "female",
		:population_code => "HG02811"
	},
	:HG02810 =>
	{
		:biosample_accession => "SAMN01036727",
		:sex => "male",
		:population_code => "HG02810"
	},
	:HG02808 =>
	{
		:biosample_accession => "SAMN01036725",
		:sex => "female",
		:population_code => "HG02808"
	},
	:HG02807 =>
	{
		:biosample_accession => "SAMN01036724",
		:sex => "male",
		:population_code => "HG02807"
	},
	:HG02805 =>
	{
		:biosample_accession => "SAMN01036722",
		:sex => "female",
		:population_code => "HG02805"
	},
	:HG02804 =>
	{
		:biosample_accession => "SAMN01036721",
		:sex => "male",
		:population_code => "HG02804"
	},
	:HG02799 =>
	{
		:biosample_accession => "SAMN01036719",
		:sex => "female",
		:population_code => "HG02799"
	},
	:HG02798 =>
	{
		:biosample_accession => "SAMN01036718",
		:sex => "male",
		:population_code => "HG02798"
	},
	:HG02772 =>
	{
		:biosample_accession => "SAMN01036716",
		:sex => "female",
		:population_code => "HG02772"
	},
	:HG02771 =>
	{
		:biosample_accession => "SAMN01036715",
		:sex => "male",
		:population_code => "HG02771"
	},
	:HG02769 =>
	{
		:biosample_accession => "SAMN01036713",
		:sex => "female",
		:population_code => "HG02769"
	},
	:HG02768 =>
	{
		:biosample_accession => "SAMN01036712",
		:sex => "male",
		:population_code => "HG02768"
	},
	:HG02716 =>
	{
		:biosample_accession => "SAMN01036710",
		:sex => "female",
		:population_code => "HG02716"
	},
	:HG02715 =>
	{
		:biosample_accession => "SAMN01036709",
		:sex => "male",
		:population_code => "HG02715"
	},
	:"HG02635 " =>
	{
		:biosample_accession => "SAMN01036707",
		:sex => "female",
		:population_code => "HG02635 "
	},
	:HG02634 =>
	{
		:biosample_accession => "SAMN01036706",
		:sex => "male",
		:population_code => "HG02634"
	},
	:HG02611 =>
	{
		:biosample_accession => "SAMN01036704",
		:sex => "female",
		:population_code => "HG02611"
	},
	:HG02610 =>
	{
		:biosample_accession => "SAMN01036703",
		:sex => "male",
		:population_code => "HG02610"
	},
	:NA12892 =>
	{
		:biosample_accession => "SAMN00801914",
		:sex => "female",
		:population_code => "NA12892"
	},
	:NA12891 =>
	{
		:biosample_accession => "SAMN00801912",
		:sex => "male",
		:population_code => "NA12891"
	},
	:NA12890 =>
	{
		:biosample_accession => "SAMN00801910",
		:sex => "female",
		:population_code => "NA12890"
	},
	:NA12889 =>
	{
		:biosample_accession => "SAMN00801908",
		:sex => "male",
		:population_code => "NA12889"
	},
	:NA12878 =>
	{
		:biosample_accession => "SAMN00801888",
		:sex => "female",
		:population_code => "NA12878"
	},
	:NA12874 =>
	{
		:biosample_accession => "SAMN00801880",
		:sex => "male",
		:population_code => "NA12874"
	},
	:NA12873 =>
	{
		:biosample_accession => "SAMN00801878",
		:sex => "female",
		:population_code => "NA12873"
	},
	:NA12872 =>
	{
		:biosample_accession => "SAMN00801876",
		:sex => "male",
		:population_code => "NA12872"
	},
	:NA12843 =>
	{
		:biosample_accession => "SAMN00801830",
		:sex => "female",
		:population_code => "NA12843"
	},
	:NA12842 =>
	{
		:biosample_accession => "SAMN00801828",
		:sex => "male",
		:population_code => "NA12842"
	},
	:NA12830 =>
	{
		:biosample_accession => "SAMN00801804",
		:sex => "female",
		:population_code => "NA12830"
	},
	:NA12829 =>
	{
		:biosample_accession => "SAMN00801802",
		:sex => "male",
		:population_code => "NA12829"
	},
	:NA12828 =>
	{
		:biosample_accession => "SAMN00801800",
		:sex => "female",
		:population_code => "NA12828"
	},
	:NA12827 =>
	{
		:biosample_accession => "SAMN00801798",
		:sex => "male",
		:population_code => "NA12827"
	},
	:NA12815 =>
	{
		:biosample_accession => "SAMN00801774",
		:sex => "female",
		:population_code => "NA12815"
	},
	:NA12814 =>
	{
		:biosample_accession => "SAMN00801772",
		:sex => "male",
		:population_code => "NA12814"
	},
	:NA12813 =>
	{
		:biosample_accession => "SAMN00801770",
		:sex => "female",
		:population_code => "NA12813"
	},
	:NA12812 =>
	{
		:biosample_accession => "SAMN00801768",
		:sex => "male",
		:population_code => "NA12812"
	},
	:NA12778 =>
	{
		:biosample_accession => "SAMN00801738",
		:sex => "female",
		:population_code => "NA12778"
	},
	:NA12777 =>
	{
		:biosample_accession => "SAMN00801736",
		:sex => "male",
		:population_code => "NA12777"
	},
	:NA12776 =>
	{
		:biosample_accession => "SAMN00801734",
		:sex => "female",
		:population_code => "NA12776"
	},
	:NA12775 =>
	{
		:biosample_accession => "SAMN00801732",
		:sex => "male",
		:population_code => "NA12775"
	},
	:NA12763 =>
	{
		:biosample_accession => "SAMN00801708",
		:sex => "female",
		:population_code => "NA12763"
	},
	:NA12762 =>
	{
		:biosample_accession => "SAMN00801706",
		:sex => "male",
		:population_code => "NA12762"
	},
	:NA12761 =>
	{
		:biosample_accession => "SAMN00801704",
		:sex => "female",
		:population_code => "NA12761"
	},
	:NA12760 =>
	{
		:biosample_accession => "SAMN00801702",
		:sex => "male",
		:population_code => "NA12760"
	},
	:NA12751 =>
	{
		:biosample_accession => "SAMN00801684",
		:sex => "female",
		:population_code => "NA12751"
	},
	:NA12750 =>
	{
		:biosample_accession => "SAMN00801682",
		:sex => "male",
		:population_code => "NA12750"
	},
	:NA12749 =>
	{
		:biosample_accession => "SAMN00801680",
		:sex => "female",
		:population_code => "NA12749"
	},
	:NA12748 =>
	{
		:biosample_accession => "SAMN00801678",
		:sex => "male",
		:population_code => "NA12748"
	},
	:NA12718 =>
	{
		:biosample_accession => "SAMN00801650",
		:sex => "female",
		:population_code => "NA12718"
	},
	:NA12717 =>
	{
		:biosample_accession => "SAMN00801648",
		:sex => "female",
		:population_code => "NA12717"
	},
	:NA12716 =>
	{
		:biosample_accession => "SAMN00801646",
		:sex => "male",
		:population_code => "NA12716"
	},
	:NA12546 =>
	{
		:biosample_accession => "SAMN00801602",
		:sex => "male",
		:population_code => "NA12546"
	},
	:NA12489 =>
	{
		:biosample_accession => "SAMN00801582",
		:sex => "female",
		:population_code => "NA12489"
	},
	:NA12414 =>
	{
		:biosample_accession => "SAMN00801509",
		:sex => "female",
		:population_code => "NA12414"
	},
	:NA12413 =>
	{
		:biosample_accession => "SAMN00801507",
		:sex => "male",
		:population_code => "NA12413"
	},
	:NA12400 =>
	{
		:biosample_accession => "SAMN00801487",
		:sex => "female",
		:population_code => "NA12400"
	},
	:NA12399 =>
	{
		:biosample_accession => "SAMN00801485",
		:sex => "male",
		:population_code => "NA12399"
	},
	:NA12383 =>
	{
		:biosample_accession => "SAMN00801457",
		:sex => "female",
		:population_code => "NA12383"
	},
	:NA12348 =>
	{
		:biosample_accession => "SAMN00801434",
		:sex => "female",
		:population_code => "NA12348"
	},
	:NA12347 =>
	{
		:biosample_accession => "SAMN00801432",
		:sex => "male",
		:population_code => "NA12347"
	},
	:NA12342 =>
	{
		:biosample_accession => "SAMN00801422",
		:sex => "male",
		:population_code => "NA12342"
	},
	:NA12341 =>
	{
		:biosample_accession => "SAMN00801420",
		:sex => "female",
		:population_code => "NA12341"
	},
	:NA12340 =>
	{
		:biosample_accession => "SAMN00801418",
		:sex => "male",
		:population_code => "NA12340"
	},
	:NA12287 =>
	{
		:biosample_accession => "SAMN00801380",
		:sex => "female",
		:population_code => "NA12287"
	},
	:NA12286 =>
	{
		:biosample_accession => "SAMN00801378",
		:sex => "male",
		:population_code => "NA12286"
	},
	:NA12283 =>
	{
		:biosample_accession => "SAMN00801372",
		:sex => "female",
		:population_code => "NA12283"
	},
	:NA12282 =>
	{
		:biosample_accession => "SAMN00801370",
		:sex => "male",
		:population_code => "NA12282"
	},
	:NA12275 =>
	{
		:biosample_accession => "SAMN00801356",
		:sex => "female",
		:population_code => "NA12275"
	},
	:NA12273 =>
	{
		:biosample_accession => "SAMN00801352",
		:sex => "female",
		:population_code => "NA12273"
	},
	:NA12272 =>
	{
		:biosample_accession => "SAMN00801350",
		:sex => "male",
		:population_code => "NA12272"
	},
	:NA12249 =>
	{
		:biosample_accession => "SAMN00801317",
		:sex => "female",
		:population_code => "NA12249"
	},
	:NA12234 =>
	{
		:biosample_accession => "SAMN00801290",
		:sex => "female",
		:population_code => "NA12234"
	},
	:NA12156 =>
	{
		:biosample_accession => "SAMN00801241",
		:sex => "female",
		:population_code => "NA12156"
	},
	:NA12155 =>
	{
		:biosample_accession => "SAMN00801239",
		:sex => "male",
		:population_code => "NA12155"
	},
	:NA12154 =>
	{
		:biosample_accession => "SAMN00801237",
		:sex => "male",
		:population_code => "NA12154"
	},
	:NA12144 =>
	{
		:biosample_accession => "SAMN00801217",
		:sex => "male",
		:population_code => "NA12144"
	},
	:NA12058 =>
	{
		:biosample_accession => "SAMN00801126",
		:sex => "female",
		:population_code => "NA12058"
	},
	:NA12046 =>
	{
		:biosample_accession => "SAMN00801105",
		:sex => "female",
		:population_code => "NA12046"
	},
	:NA12045 =>
	{
		:biosample_accession => "SAMN00801103",
		:sex => "male",
		:population_code => "NA12045"
	},
	:NA12044 =>
	{
		:biosample_accession => "SAMN00801101",
		:sex => "female",
		:population_code => "NA12044"
	},
	:NA12043 =>
	{
		:biosample_accession => "SAMN00801099",
		:sex => "male",
		:population_code => "NA12043"
	},
	:NA12006 =>
	{
		:biosample_accession => "SAMN00801055",
		:sex => "female",
		:population_code => "NA12006"
	},
	:NA12005 =>
	{
		:biosample_accession => "SAMN00801053",
		:sex => "male",
		:population_code => "NA12005"
	},
	:NA12004 =>
	{
		:biosample_accession => "SAMN00801051",
		:sex => "female",
		:population_code => "NA12004"
	},
	:NA12003 =>
	{
		:biosample_accession => "SAMN00801049",
		:sex => "male",
		:population_code => "NA12003"
	},
	:NA11995 =>
	{
		:biosample_accession => "SAMN00801033",
		:sex => "female",
		:population_code => "NA11995"
	},
	:NA11994 =>
	{
		:biosample_accession => "SAMN00801031",
		:sex => "male",
		:population_code => "NA11994"
	},
	:NA11993 =>
	{
		:biosample_accession => "SAMN00801029",
		:sex => "female",
		:population_code => "NA11993"
	},
	:NA11992 =>
	{
		:biosample_accession => "SAMN00801027",
		:sex => "male",
		:population_code => "NA11992"
	},
	:NA11933 =>
	{
		:biosample_accession => "SAMN00800975",
		:sex => "female",
		:population_code => "NA11933"
	},
	:NA11932 =>
	{
		:biosample_accession => "SAMN00800973",
		:sex => "male",
		:population_code => "NA11932"
	},
	:NA11931 =>
	{
		:biosample_accession => "SAMN00800971",
		:sex => "female",
		:population_code => "NA11931"
	},
	:NA11930 =>
	{
		:biosample_accession => "SAMN00800969",
		:sex => "male",
		:population_code => "NA11930"
	},
	:NA11920 =>
	{
		:biosample_accession => "SAMN00800949",
		:sex => "female",
		:population_code => "NA11920"
	},
	:NA11919 =>
	{
		:biosample_accession => "SAMN00800947",
		:sex => "male",
		:population_code => "NA11919"
	},
	:NA11918 =>
	{
		:biosample_accession => "SAMN00800945",
		:sex => "female",
		:population_code => "NA11918"
	},
	:NA11894 =>
	{
		:biosample_accession => "SAMN00800913",
		:sex => "female",
		:population_code => "NA11894"
	},
	:NA11893 =>
	{
		:biosample_accession => "SAMN00800911",
		:sex => "male",
		:population_code => "NA11893"
	},
	:NA11892 =>
	{
		:biosample_accession => "SAMN00800909",
		:sex => "female",
		:population_code => "NA11892"
	},
	:NA11881 =>
	{
		:biosample_accession => "SAMN00800891",
		:sex => "male",
		:population_code => "NA11881"
	},
	:NA11843 =>
	{
		:biosample_accession => "SAMN00800857",
		:sex => "male",
		:population_code => "NA11843"
	},
	:NA11840 =>
	{
		:biosample_accession => "SAMN00800852",
		:sex => "female",
		:population_code => "NA11840"
	},
	:NA11832 =>
	{
		:biosample_accession => "SAMN00800837",
		:sex => "female",
		:population_code => "NA11832"
	},
	:NA11831 =>
	{
		:biosample_accession => "SAMN00800835",
		:sex => "male",
		:population_code => "NA11831"
	},
	:NA11830 =>
	{
		:biosample_accession => "SAMN00800833",
		:sex => "female",
		:population_code => "NA11830"
	},
	:NA11829 =>
	{
		:biosample_accession => "SAMN00800831",
		:sex => "male",
		:population_code => "NA11829"
	},
	:NA10851 =>
	{
		:biosample_accession => "SAMN00800266",
		:sex => "male",
		:population_code => "NA10851"
	},
	:NA10847 =>
	{
		:biosample_accession => "SAMN00800258",
		:sex => "female",
		:population_code => "NA10847"
	},
	:NA07357 =>
	{
		:biosample_accession => "SAMN00797419",
		:sex => "male",
		:population_code => "NA07357"
	},
	:NA07347 =>
	{
		:biosample_accession => "SAMN00797406",
		:sex => "male",
		:population_code => "NA07347"
	},
	:NA07346 =>
	{
		:biosample_accession => "SAMN00797404",
		:sex => "female",
		:population_code => "NA07346"
	},
	:NA07056 =>
	{
		:biosample_accession => "SAMN00797164",
		:sex => "female",
		:population_code => "NA07056"
	},
	:NA07051 =>
	{
		:biosample_accession => "SAMN00797154",
		:sex => "male",
		:population_code => "NA07051"
	},
	:NA07048 =>
	{
		:biosample_accession => "SAMN00797148",
		:sex => "male",
		:population_code => "NA07048"
	},
	:NA07037 =>
	{
		:biosample_accession => "SAMN00797126",
		:sex => "female",
		:population_code => "NA07037"
	},
	:NA07000 =>
	{
		:biosample_accession => "SAMN00797054",
		:sex => "female",
		:population_code => "NA07000"
	},
	:NA06994 =>
	{
		:biosample_accession => "SAMN00797044",
		:sex => "male",
		:population_code => "NA06994"
	},
	:NA06989 =>
	{
		:biosample_accession => "SAMN00797031",
		:sex => "female",
		:population_code => "NA06989"
	},
	:NA06986 =>
	{
		:biosample_accession => "SAMN00797025",
		:sex => "male",
		:population_code => "NA06986"
	},
	:NA06985 =>
	{
		:biosample_accession => "SAMN00797023",
		:sex => "female",
		:population_code => "NA06985"
	},
	:NA06984 =>
	{
		:biosample_accession => "SAMN00797021",
		:sex => "male",
		:population_code => "NA06984"
	},
	:HG02735 =>
	{
		:biosample_accession => "SAMN00780019",
		:sex => "male",
		:population_code => "HG02735"
	},
	:HG02734 =>
	{
		:biosample_accession => "SAMN00780018",
		:sex => "female",
		:population_code => "HG02734"
	},
	:HG02733 =>
	{
		:biosample_accession => "SAMN00780017",
		:sex => "male",
		:population_code => "HG02733"
	},
	:HG02698 =>
	{
		:biosample_accession => "SAMN00780016",
		:sex => "male",
		:population_code => "HG02698"
	},
	:HG02697 =>
	{
		:biosample_accession => "SAMN00780015",
		:sex => "female",
		:population_code => "HG02697"
	},
	:HG02696 =>
	{
		:biosample_accession => "SAMN00780014",
		:sex => "male",
		:population_code => "HG02696"
	},
	:HG02689 =>
	{
		:biosample_accession => "SAMN00780013",
		:sex => "male",
		:population_code => "HG02689"
	},
	:HG02688 =>
	{
		:biosample_accession => "SAMN00780012",
		:sex => "female",
		:population_code => "HG02688"
	},
	:HG02687 =>
	{
		:biosample_accession => "SAMN00780011",
		:sex => "male",
		:population_code => "HG02687"
	},
	:HG02686 =>
	{
		:biosample_accession => "SAMN00780010",
		:sex => "male",
		:population_code => "HG02686"
	},
	:HG02685 =>
	{
		:biosample_accession => "SAMN00780009",
		:sex => "female",
		:population_code => "HG02685"
	},
	:HG02684 =>
	{
		:biosample_accession => "SAMN00780008",
		:sex => "male",
		:population_code => "HG02684"
	},
	:HG02662 =>
	{
		:biosample_accession => "SAMN00780007",
		:sex => "female",
		:population_code => "HG02662"
	},
	:HG02661 =>
	{
		:biosample_accession => "SAMN00780006",
		:sex => "female",
		:population_code => "HG02661"
	},
	:HG02660 =>
	{
		:biosample_accession => "SAMN00780005",
		:sex => "male",
		:population_code => "HG02660"
	},
	:HG02659 =>
	{
		:biosample_accession => "SAMN00780004",
		:sex => "female",
		:population_code => "HG02659"
	},
	:HG02658 =>
	{
		:biosample_accession => "SAMN00780003",
		:sex => "female",
		:population_code => "HG02658"
	},
	:HG02657 =>
	{
		:biosample_accession => "SAMN00780002",
		:sex => "male",
		:population_code => "HG02657"
	},
	:HG02656 =>
	{
		:biosample_accession => "SAMN00780001",
		:sex => "male",
		:population_code => "HG02656"
	},
	:HG02655 =>
	{
		:biosample_accession => "SAMN00780000",
		:sex => "female",
		:population_code => "HG02655"
	},
	:HG02654 =>
	{
		:biosample_accession => "SAMN00779999",
		:sex => "male",
		:population_code => "HG02654"
	},
	:HG02605 =>
	{
		:biosample_accession => "SAMN00779998",
		:sex => "female",
		:population_code => "HG02605"
	},
	:HG02604 =>
	{
		:biosample_accession => "SAMN00779997",
		:sex => "female",
		:population_code => "HG02604"
	},
	:HG02603 =>
	{
		:biosample_accession => "SAMN00779996",
		:sex => "male",
		:population_code => "HG02603"
	},
	:HG02602 =>
	{
		:biosample_accession => "SAMN00779995",
		:sex => "male",
		:population_code => "HG02602"
	},
	:HG02601 =>
	{
		:biosample_accession => "SAMN00779994",
		:sex => "female",
		:population_code => "HG02601"
	},
	:HG02600 =>
	{
		:biosample_accession => "SAMN00779993",
		:sex => "male",
		:population_code => "HG02600"
	},
	:HG02492 =>
	{
		:biosample_accession => "SAMN00779992",
		:sex => "male",
		:population_code => "HG02492"
	},
	:HG02491 =>
	{
		:biosample_accession => "SAMN00779991",
		:sex => "female",
		:population_code => "HG02491"
	},
	:HG02490 =>
	{
		:biosample_accession => "SAMN00779990",
		:sex => "male",
		:population_code => "HG02490"
	},
	:HG02722 =>
	{
		:biosample_accession => "SAMN00779988",
		:sex => "female",
		:population_code => "HG02722"
	},
	:HG02721 =>
	{
		:biosample_accession => "SAMN00779987",
		:sex => "male",
		:population_code => "HG02721"
	},
	:HG02703 =>
	{
		:biosample_accession => "SAMN00779985",
		:sex => "female",
		:population_code => "HG02703"
	},
	:HG02702 =>
	{
		:biosample_accession => "SAMN00779984",
		:sex => "male",
		:population_code => "HG02702"
	},
	:HG02679 =>
	{
		:biosample_accession => "SAMN00779982",
		:sex => "female",
		:population_code => "HG02679"
	},
	:HG02678 =>
	{
		:biosample_accession => "SAMN00779981",
		:sex => "male",
		:population_code => "HG02678"
	},
	:HG02676 =>
	{
		:biosample_accession => "SAMN00779979",
		:sex => "female",
		:population_code => "HG02676"
	},
	:HG02675 =>
	{
		:biosample_accession => "SAMN00779978",
		:sex => "male",
		:population_code => "HG02675"
	},
	:HG02667 =>
	{
		:biosample_accession => "SAMN00779976",
		:sex => "female",
		:population_code => "HG02667"
	},
	:HG02666 =>
	{
		:biosample_accession => "SAMN00779975",
		:sex => "male",
		:population_code => "HG02666"
	},
	:HG02646 =>
	{
		:biosample_accession => "SAMN00779973",
		:sex => "female",
		:population_code => "HG02646"
	},
	:HG02645 =>
	{
		:biosample_accession => "SAMN00779972",
		:sex => "male",
		:population_code => "HG02645"
	},
	:HG02643 =>
	{
		:biosample_accession => "SAMN00779970",
		:sex => "female",
		:population_code => "HG02643"
	},
	:HG02642 =>
	{
		:biosample_accession => "SAMN00779969",
		:sex => "male",
		:population_code => "HG02642"
	},
	:HG02629 =>
	{
		:biosample_accession => "SAMN00779967",
		:sex => "female",
		:population_code => "HG02629"
	},
	:HG02628 =>
	{
		:biosample_accession => "SAMN00779966",
		:sex => "male",
		:population_code => "HG02628"
	},
	:HG02624 =>
	{
		:biosample_accession => "SAMN00779964",
		:sex => "female",
		:population_code => "HG02624"
	},
	:HG02623 =>
	{
		:biosample_accession => "SAMN00779963",
		:sex => "male",
		:population_code => "HG02623"
	},
	:HG02621 =>
	{
		:biosample_accession => "SAMN00779961",
		:sex => "female",
		:population_code => "HG02621"
	},
	:HG02620 =>
	{
		:biosample_accession => "SAMN00779960",
		:sex => "male",
		:population_code => "HG02620"
	},
	:HG02614 =>
	{
		:biosample_accession => "SAMN00779958",
		:sex => "female",
		:population_code => "HG02614"
	},
	:HG02613 =>
	{
		:biosample_accession => "SAMN00779957",
		:sex => "male",
		:population_code => "HG02613"
	},
	:HG02595 =>
	{
		:biosample_accession => "SAMN00779955",
		:sex => "female",
		:population_code => "HG02595"
	},
	:HG02594 =>
	{
		:biosample_accession => "SAMN00779954",
		:sex => "male",
		:population_code => "HG02594"
	},
	:HG02589 =>
	{
		:biosample_accession => "SAMN00779952",
		:sex => "female",
		:population_code => "HG02589"
	},
	:HG02588 =>
	{
		:biosample_accession => "SAMN00779951",
		:sex => "male",
		:population_code => "HG02588"
	},
	:HG02586 =>
	{
		:biosample_accession => "SAMN00779949",
		:sex => "female",
		:population_code => "HG02586"
	},
	:HG02585 =>
	{
		:biosample_accession => "SAMN00779948",
		:sex => "male",
		:population_code => "HG02585"
	},
	:HG02583 =>
	{
		:biosample_accession => "SAMN00779946",
		:sex => "female",
		:population_code => "HG02583"
	},
	:HG02582 =>
	{
		:biosample_accession => "SAMN00779945",
		:sex => "male",
		:population_code => "HG02582"
	},
	:HG02574 =>
	{
		:biosample_accession => "SAMN00779943",
		:sex => "female",
		:population_code => "HG02574"
	},
	:HG02573 =>
	{
		:biosample_accession => "SAMN00779942",
		:sex => "male",
		:population_code => "HG02573"
	},
	:HG02571 =>
	{
		:biosample_accession => "SAMN00779940",
		:sex => "female",
		:population_code => "HG02571"
	},
	:HG02570 =>
	{
		:biosample_accession => "SAMN00779939",
		:sex => "male",
		:population_code => "HG02570"
	},
	:HG02562 =>
	{
		:biosample_accession => "SAMN00779937",
		:sex => "female",
		:population_code => "HG02562"
	},
	:HG02561 =>
	{
		:biosample_accession => "SAMN00779936",
		:sex => "male",
		:population_code => "HG02561"
	},
	:HG02465 =>
	{
		:biosample_accession => "SAMN00779934",
		:sex => "female",
		:population_code => "HG02465"
	},
	:HG02464 =>
	{
		:biosample_accession => "SAMN00779933",
		:sex => "male",
		:population_code => "HG02464"
	},
	:HG02462 =>
	{
		:biosample_accession => "SAMN00779931",
		:sex => "female",
		:population_code => "HG02462"
	},
	:HG02461 =>
	{
		:biosample_accession => "SAMN00779930",
		:sex => "male",
		:population_code => "HG02461"
	},
	:HG02522 =>
	{
		:biosample_accession => "SAMN00630274",
		:sex => "female",
		:population_code => "HG02522"
	},
	:HG02521 =>
	{
		:biosample_accession => "SAMN00630273",
		:sex => "male",
		:population_code => "HG02521"
	},
	:HG02513 =>
	{
		:biosample_accession => "SAMN00630271",
		:sex => "female",
		:population_code => "HG02513"
	},
	:HG02512 =>
	{
		:biosample_accession => "SAMN00630270",
		:sex => "male",
		:population_code => "HG02512"
	},
	:HG02136 =>
	{
		:biosample_accession => "SAMN00630268",
		:sex => "female",
		:population_code => "HG02136"
	},
	:HG02137 =>
	{
		:biosample_accession => "SAMN00630267",
		:sex => "male",
		:population_code => "HG02137"
	},
	:HG02130 =>
	{
		:biosample_accession => "SAMN00630265",
		:sex => "female",
		:population_code => "HG02130"
	},
	:HG02131 =>
	{
		:biosample_accession => "SAMN00630264",
		:sex => "male",
		:population_code => "HG02131"
	},
	:HG02116 =>
	{
		:biosample_accession => "SAMN00630263",
		:sex => "male",
		:population_code => "HG02116"
	},
	:HG02067 =>
	{
		:biosample_accession => "SAMN00630262",
		:sex => "male",
		:population_code => "HG02067"
	},
	:HG02064 =>
	{
		:biosample_accession => "SAMN00630261",
		:sex => "male",
		:population_code => "HG02064"
	},
	:HG02060 =>
	{
		:biosample_accession => "SAMN00630259",
		:sex => "female",
		:population_code => "HG02060"
	},
	:HG02061 =>
	{
		:biosample_accession => "SAMN00630258",
		:sex => "male",
		:population_code => "HG02061"
	},
	:HG02046 =>
	{
		:biosample_accession => "SAMN00630257",
		:sex => "female",
		:population_code => "HG02046"
	},
	:HG02047 =>
	{
		:biosample_accession => "SAMN00630256",
		:sex => "male",
		:population_code => "HG02047"
	},
	:HG02040 =>
	{
		:biosample_accession => "SAMN00630255",
		:sex => "male",
		:population_code => "HG02040"
	},
	:HG02035 =>
	{
		:biosample_accession => "SAMN00630254",
		:sex => "male",
		:population_code => "HG02035"
	},
	:HG02537 =>
	{
		:biosample_accession => "SAMN00630253",
		:sex => "female",
		:population_code => "HG02537"
	},
	:HG02508 =>
	{
		:biosample_accession => "SAMN00630252",
		:sex => "female",
		:population_code => "HG02508"
	},
	:HG02497 =>
	{
		:biosample_accession => "SAMN00630251",
		:sex => "female",
		:population_code => "HG02497"
	},
	:HG02496 =>
	{
		:biosample_accession => "SAMN00630250",
		:sex => "male",
		:population_code => "HG02496"
	},
	:HG02511 =>
	{
		:biosample_accession => "SAMN00630249",
		:sex => "female",
		:population_code => "HG02511"
	},
	:HG02485 =>
	{
		:biosample_accession => "SAMN00630247",
		:sex => "female",
		:population_code => "HG02485"
	},
	:HG02484 =>
	{
		:biosample_accession => "SAMN00630246",
		:sex => "male",
		:population_code => "HG02484"
	},
	:HG02479 =>
	{
		:biosample_accession => "SAMN00630244",
		:sex => "female",
		:population_code => "HG02479"
	},
	:HG02478 =>
	{
		:biosample_accession => "SAMN00630243",
		:sex => "male",
		:population_code => "HG02478"
	},
	:HG02471 =>
	{
		:biosample_accession => "SAMN00630242",
		:sex => "female",
		:population_code => "HG02471"
	},
	:HG02470 =>
	{
		:biosample_accession => "SAMN00630241",
		:sex => "male",
		:population_code => "HG02470"
	},
	:HG02450 =>
	{
		:biosample_accession => "SAMN00630239",
		:sex => "female",
		:population_code => "HG02450"
	},
	:HG02449 =>
	{
		:biosample_accession => "SAMN00630238",
		:sex => "male",
		:population_code => "HG02449"
	},
	:HG02489 =>
	{
		:biosample_accession => "SAMN00630237",
		:sex => "male",
		:population_code => "HG02489"
	},
	:HG02445 =>
	{
		:biosample_accession => "SAMN00630236",
		:sex => "male",
		:population_code => "HG02445"
	},
	:HG02442 =>
	{
		:biosample_accession => "SAMN00630235",
		:sex => "male",
		:population_code => "HG02442"
	},
	:HG02433 =>
	{
		:biosample_accession => "SAMN00630234",
		:sex => "male",
		:population_code => "HG02433"
	},
	:HG02436 =>
	{
		:biosample_accession => "SAMN00630233",
		:sex => "male",
		:population_code => "HG02436"
	},
	:HG02429 =>
	{
		:biosample_accession => "SAMN00630232",
		:sex => "male",
		:population_code => "HG02429"
	},
	:HG02427 =>
	{
		:biosample_accession => "SAMN00630230",
		:sex => "female",
		:population_code => "HG02427"
	},
	:HG02420 =>
	{
		:biosample_accession => "SAMN00630229",
		:sex => "male",
		:population_code => "HG02420"
	},
	:HG02419 =>
	{
		:biosample_accession => "SAMN00630228",
		:sex => "female",
		:population_code => "HG02419"
	},
	:HG02343 =>
	{
		:biosample_accession => "SAMN00630227",
		:sex => "male",
		:population_code => "HG02343"
	},
	:HG02339 =>
	{
		:biosample_accession => "SAMN00630226",
		:sex => "female",
		:population_code => "HG02339"
	},
	:HG02330 =>
	{
		:biosample_accession => "SAMN00630225",
		:sex => "male",
		:population_code => "HG02330"
	},
	:HG02334 =>
	{
		:biosample_accession => "SAMN00630224",
		:sex => "male",
		:population_code => "HG02334"
	},
	:HG02337 =>
	{
		:biosample_accession => "SAMN00630223",
		:sex => "female",
		:population_code => "HG02337"
	},
	:HG02325 =>
	{
		:biosample_accession => "SAMN00630222",
		:sex => "female",
		:population_code => "HG02325"
	},
	:HG02323 =>
	{
		:biosample_accession => "SAMN00630221",
		:sex => "male",
		:population_code => "HG02323"
	},
	:HG02322 =>
	{
		:biosample_accession => "SAMN00630220",
		:sex => "female",
		:population_code => "HG02322"
	},
	:HG02284 =>
	{
		:biosample_accession => "SAMN00630219",
		:sex => "male",
		:population_code => "HG02284"
	},
	:HG02309 =>
	{
		:biosample_accession => "SAMN00630218",
		:sex => "female",
		:population_code => "HG02309"
	},
	:HG02283 =>
	{
		:biosample_accession => "SAMN00630217",
		:sex => "male",
		:population_code => "HG02283"
	},
	:HG02308 =>
	{
		:biosample_accession => "SAMN00630215",
		:sex => "female",
		:population_code => "HG02308"
	},
	:HG02307 =>
	{
		:biosample_accession => "SAMN00630214",
		:sex => "male",
		:population_code => "HG02307"
	},
	:HG02144 =>
	{
		:biosample_accession => "SAMN00630212",
		:sex => "female",
		:population_code => "HG02144"
	},
	:HG02143 =>
	{
		:biosample_accession => "SAMN00630211",
		:sex => "male",
		:population_code => "HG02143"
	},
	:HG02111 =>
	{
		:biosample_accession => "SAMN00630210",
		:sex => "female",
		:population_code => "HG02111"
	},
	:HG02108 =>
	{
		:biosample_accession => "SAMN00630209",
		:sex => "female",
		:population_code => "HG02108"
	},
	:HG02107 =>
	{
		:biosample_accession => "SAMN00630208",
		:sex => "male",
		:population_code => "HG02107"
	},
	:HG02332 =>
	{
		:biosample_accession => "SAMN00630207",
		:sex => "male",
		:population_code => "HG02332"
	},
	:HG02095 =>
	{
		:biosample_accession => "SAMN00630206",
		:sex => "female",
		:population_code => "HG02095"
	},
	:HG02052 =>
	{
		:biosample_accession => "SAMN00630205",
		:sex => "female",
		:population_code => "HG02052"
	},
	:HG02051 =>
	{
		:biosample_accession => "SAMN00630204",
		:sex => "male",
		:population_code => "HG02051"
	},
	:HG01989 =>
	{
		:biosample_accession => "SAMN00630202",
		:sex => "female",
		:population_code => "HG01989"
	},
	:HG01988 =>
	{
		:biosample_accession => "SAMN00630201",
		:sex => "male",
		:population_code => "HG01988"
	},
	:HG01985 =>
	{
		:biosample_accession => "SAMN00630200",
		:sex => "female",
		:population_code => "HG01985"
	},
	:HG01896 =>
	{
		:biosample_accession => "SAMN00630198",
		:sex => "female",
		:population_code => "HG01896"
	},
	:HG02013 =>
	{
		:biosample_accession => "SAMN00630197",
		:sex => "male",
		:population_code => "HG02013"
	},
	:HG01880 =>
	{
		:biosample_accession => "SAMN00630195",
		:sex => "female",
		:population_code => "HG01880"
	},
	:HG01879 =>
	{
		:biosample_accession => "SAMN00630194",
		:sex => "male",
		:population_code => "HG01879"
	},
	:HG02232 =>
	{
		:biosample_accession => "SAMN00619035",
		:sex => "female",
		:population_code => "HG02232"
	},
	:HG02233 =>
	{
		:biosample_accession => "SAMN00619034",
		:sex => "male",
		:population_code => "HG02233"
	},
	:HG02409 =>
	{
		:biosample_accession => "SAMN00263067",
		:sex => "male",
		:population_code => "HG02409"
	},
	:HG02407 =>
	{
		:biosample_accession => "SAMN00263066",
		:sex => "male",
		:population_code => "HG02407"
	},
	:HG02406 =>
	{
		:biosample_accession => "SAMN00263065",
		:sex => "male",
		:population_code => "HG02406"
	},
	:HG02402 =>
	{
		:biosample_accession => "SAMN00263064",
		:sex => "male",
		:population_code => "HG02402"
	},
	:HG02401 =>
	{
		:biosample_accession => "SAMN00263063",
		:sex => "male",
		:population_code => "HG02401"
	},
	:HG02399 =>
	{
		:biosample_accession => "SAMN00263062",
		:sex => "male",
		:population_code => "HG02399"
	},
	:HG02398 =>
	{
		:biosample_accession => "SAMN00263061",
		:sex => "male",
		:population_code => "HG02398"
	},
	:HG02395 =>
	{
		:biosample_accession => "SAMN00263060",
		:sex => "male",
		:population_code => "HG02395"
	},
	:HG02392 =>
	{
		:biosample_accession => "SAMN00263059",
		:sex => "male",
		:population_code => "HG02392"
	},
	:HG02391 =>
	{
		:biosample_accession => "SAMN00263058",
		:sex => "male",
		:population_code => "HG02391"
	},
	:HG02390 =>
	{
		:biosample_accession => "SAMN00263057",
		:sex => "male",
		:population_code => "HG02390"
	},
	:HG02389 =>
	{
		:biosample_accession => "SAMN00263056",
		:sex => "male",
		:population_code => "HG02389"
	},
	:HG02388 =>
	{
		:biosample_accession => "SAMN00263055",
		:sex => "male",
		:population_code => "HG02388"
	},
	:HG02387 =>
	{
		:biosample_accession => "SAMN00263054",
		:sex => "male",
		:population_code => "HG02387"
	},
	:HG02386 =>
	{
		:biosample_accession => "SAMN00263053",
		:sex => "male",
		:population_code => "HG02386"
	},
	:HG02385 =>
	{
		:biosample_accession => "SAMN00263052",
		:sex => "male",
		:population_code => "HG02385"
	},
	:HG02384 =>
	{
		:biosample_accession => "SAMN00263051",
		:sex => "male",
		:population_code => "HG02384"
	},
	:HG02383 =>
	{
		:biosample_accession => "SAMN00263050",
		:sex => "male",
		:population_code => "HG02383"
	},
	:HG02382 =>
	{
		:biosample_accession => "SAMN00263049",
		:sex => "male",
		:population_code => "HG02382"
	},
	:HG02381 =>
	{
		:biosample_accession => "SAMN00263048",
		:sex => "male",
		:population_code => "HG02381"
	},
	:HG02380 =>
	{
		:biosample_accession => "SAMN00263047",
		:sex => "male",
		:population_code => "HG02380"
	},
	:HG02379 =>
	{
		:biosample_accession => "SAMN00263046",
		:sex => "male",
		:population_code => "HG02379"
	},
	:HG02377 =>
	{
		:biosample_accession => "SAMN00263045",
		:sex => "male",
		:population_code => "HG02377"
	},
	:HG02375 =>
	{
		:biosample_accession => "SAMN00263044",
		:sex => "male",
		:population_code => "HG02375"
	},
	:HG02374 =>
	{
		:biosample_accession => "SAMN00263043",
		:sex => "male",
		:population_code => "HG02374"
	},
	:HG02372 =>
	{
		:biosample_accession => "SAMN00263042",
		:sex => "male",
		:population_code => "HG02372"
	},
	:HG02371 =>
	{
		:biosample_accession => "SAMN00263041",
		:sex => "male",
		:population_code => "HG02371"
	},
	:HG02367 =>
	{
		:biosample_accession => "SAMN00263040",
		:sex => "male",
		:population_code => "HG02367"
	},
	:HG02364 =>
	{
		:biosample_accession => "SAMN00263039",
		:sex => "male",
		:population_code => "HG02364"
	},
	:HG02363 =>
	{
		:biosample_accession => "SAMN00263038",
		:sex => "male",
		:population_code => "HG02363"
	},
	:HG02360 =>
	{
		:biosample_accession => "SAMN00263037",
		:sex => "male",
		:population_code => "HG02360"
	},
	:HG02356 =>
	{
		:biosample_accession => "SAMN00263036",
		:sex => "male",
		:population_code => "HG02356"
	},
	:HG02355 =>
	{
		:biosample_accession => "SAMN00263035",
		:sex => "male",
		:population_code => "HG02355"
	},
	:HG02353 =>
	{
		:biosample_accession => "SAMN00263034",
		:sex => "male",
		:population_code => "HG02353"
	},
	:HG02351 =>
	{
		:biosample_accession => "SAMN00263033",
		:sex => "male",
		:population_code => "HG02351"
	},
	:HG02250 =>
	{
		:biosample_accession => "SAMN00263032",
		:sex => "male",
		:population_code => "HG02250"
	},
	:HG02050 =>
	{
		:biosample_accession => "SAMN00263031",
		:sex => "male",
		:population_code => "HG02050"
	},
	:HG02031 =>
	{
		:biosample_accession => "SAMN00263029",
		:sex => "female",
		:population_code => "HG02031"
	},
	:HG02032 =>
	{
		:biosample_accession => "SAMN00263028",
		:sex => "male",
		:population_code => "HG02032"
	},
	:HG02239 =>
	{
		:biosample_accession => "SAMN00263026",
		:sex => "female",
		:population_code => "HG02239"
	},
	:HG02238 =>
	{
		:biosample_accession => "SAMN00263025",
		:sex => "male",
		:population_code => "HG02238"
	},
	:HG02230 =>
	{
		:biosample_accession => "SAMN00263023",
		:sex => "female",
		:population_code => "HG02230"
	},
	:HG02231 =>
	{
		:biosample_accession => "SAMN00263022",
		:sex => "male",
		:population_code => "HG02231"
	},
	:HG02223 =>
	{
		:biosample_accession => "SAMN00263020",
		:sex => "female",
		:population_code => "HG02223"
	},
	:HG02224 =>
	{
		:biosample_accession => "SAMN00263019",
		:sex => "male",
		:population_code => "HG02224"
	},
	:HG01697 =>
	{
		:biosample_accession => "SAMN00263017",
		:sex => "female",
		:population_code => "HG01697"
	},
	:HG01699 =>
	{
		:biosample_accession => "SAMN00263016",
		:sex => "male",
		:population_code => "HG01699"
	},
	:HG02298 =>
	{
		:biosample_accession => "SAMN00263014",
		:sex => "female",
		:population_code => "HG02298"
	},
	:HG02299 =>
	{
		:biosample_accession => "SAMN00263013",
		:sex => "male",
		:population_code => "HG02299"
	},
	:HG02292 =>
	{
		:biosample_accession => "SAMN00263011",
		:sex => "female",
		:population_code => "HG02292"
	},
	:HG02291 =>
	{
		:biosample_accession => "SAMN00263010",
		:sex => "male",
		:population_code => "HG02291"
	},
	:HG02278 =>
	{
		:biosample_accession => "SAMN00263008",
		:sex => "female",
		:population_code => "HG02278"
	},
	:HG02277 =>
	{
		:biosample_accession => "SAMN00263007",
		:sex => "male",
		:population_code => "HG02277"
	},
	:HG02272 =>
	{
		:biosample_accession => "SAMN00263005",
		:sex => "female",
		:population_code => "HG02272"
	},
	:HG02271 =>
	{
		:biosample_accession => "SAMN00263004",
		:sex => "male",
		:population_code => "HG02271"
	},
	:HG02260 =>
	{
		:biosample_accession => "SAMN00263002",
		:sex => "female",
		:population_code => "HG02260"
	},
	:HG02259 =>
	{
		:biosample_accession => "SAMN00263001",
		:sex => "male",
		:population_code => "HG02259"
	},
	:HG02147 =>
	{
		:biosample_accession => "SAMN00262999",
		:sex => "female",
		:population_code => "HG02147"
	},
	:HG02146 =>
	{
		:biosample_accession => "SAMN00262998",
		:sex => "male",
		:population_code => "HG02146"
	},
	:HG01983 =>
	{
		:biosample_accession => "SAMN00262996",
		:sex => "female",
		:population_code => "HG01983"
	},
	:HG01982 =>
	{
		:biosample_accession => "SAMN00262995",
		:sex => "male",
		:population_code => "HG01982"
	},
	:HG01894 =>
	{
		:biosample_accession => "SAMN00262993",
		:sex => "female",
		:population_code => "HG01894"
	},
	:HG01912 =>
	{
		:biosample_accession => "SAMN00262992",
		:sex => "male",
		:population_code => "HG01912"
	},
	:HG02318 =>
	{
		:biosample_accession => "SAMN00262990",
		:sex => "female",
		:population_code => "HG02318"
	},
	:HG02317 =>
	{
		:biosample_accession => "SAMN00262989",
		:sex => "male",
		:population_code => "HG02317"
	},
	:HG02282 =>
	{
		:biosample_accession => "SAMN00262987",
		:sex => "female",
		:population_code => "HG02282"
	},
	:HG02281 =>
	{
		:biosample_accession => "SAMN00262986",
		:sex => "male",
		:population_code => "HG02281"
	},
	:HG02315 =>
	{
		:biosample_accession => "SAMN00262984",
		:sex => "female",
		:population_code => "HG02315"
	},
	:HG02314 =>
	{
		:biosample_accession => "SAMN00262983",
		:sex => "male",
		:population_code => "HG02314"
	},
	:HG02256 =>
	{
		:biosample_accession => "SAMN00262981",
		:sex => "female",
		:population_code => "HG02256"
	},
	:HG02255 =>
	{
		:biosample_accession => "SAMN00262980",
		:sex => "male",
		:population_code => "HG02255"
	},
	:HG02054 =>
	{
		:biosample_accession => "SAMN00262978",
		:sex => "female",
		:population_code => "HG02054"
	},
	:HG02053 =>
	{
		:biosample_accession => "SAMN00262977",
		:sex => "male",
		:population_code => "HG02053"
	},
	:HG02012 =>
	{
		:biosample_accession => "SAMN00262975",
		:sex => "female",
		:population_code => "HG02012"
	},
	:HG01990 =>
	{
		:biosample_accession => "SAMN00262974",
		:sex => "male",
		:population_code => "HG01990"
	},
	:HG01958 =>
	{
		:biosample_accession => "SAMN00262972",
		:sex => "female",
		:population_code => "HG01958"
	},
	:HG01986 =>
	{
		:biosample_accession => "SAMN00262971",
		:sex => "male",
		:population_code => "HG01986"
	},
	:HG01915 =>
	{
		:biosample_accession => "SAMN00262969",
		:sex => "female",
		:population_code => "HG01915"
	},
	:HG01914 =>
	{
		:biosample_accession => "SAMN00262968",
		:sex => "male",
		:population_code => "HG01914"
	},
	:HG02397 =>
	{
		:biosample_accession => "SAMN00255156",
		:sex => "male",
		:population_code => "HG02397"
	},
	:HG02396 =>
	{
		:biosample_accession => "SAMN00255155",
		:sex => "male",
		:population_code => "HG02396"
	},
	:HG02394 =>
	{
		:biosample_accession => "SAMN00255154",
		:sex => "male",
		:population_code => "HG02394"
	},
	:HG02373 =>
	{
		:biosample_accession => "SAMN00255153",
		:sex => "male",
		:population_code => "HG02373"
	},
	:HG02127 =>
	{
		:biosample_accession => "SAMN00255151",
		:sex => "female",
		:population_code => "HG02127"
	},
	:HG02128 =>
	{
		:biosample_accession => "SAMN00255150",
		:sex => "male",
		:population_code => "HG02128"
	},
	:HG02121 =>
	{
		:biosample_accession => "SAMN00255148",
		:sex => "female",
		:population_code => "HG02121"
	},
	:HG02122 =>
	{
		:biosample_accession => "SAMN00255147",
		:sex => "male",
		:population_code => "HG02122"
	},
	:HG02141 =>
	{
		:biosample_accession => "SAMN00255146",
		:sex => "male",
		:population_code => "HG02141"
	},
	:HG02113 =>
	{
		:biosample_accession => "SAMN00255145",
		:sex => "female",
		:population_code => "HG02113"
	},
	:HG02235 =>
	{
		:biosample_accession => "SAMN00255143",
		:sex => "female",
		:population_code => "HG02235"
	},
	:HG02236 =>
	{
		:biosample_accession => "SAMN00255142",
		:sex => "male",
		:population_code => "HG02236"
	},
	:HG02220 =>
	{
		:biosample_accession => "SAMN00255140",
		:sex => "female",
		:population_code => "HG02220"
	},
	:HG02221 =>
	{
		:biosample_accession => "SAMN00255139",
		:sex => "male",
		:population_code => "HG02221"
	},
	:HG01784 =>
	{
		:biosample_accession => "SAMN00255137",
		:sex => "female",
		:population_code => "HG01784"
	},
	:HG01783 =>
	{
		:biosample_accession => "SAMN00255136",
		:sex => "male",
		:population_code => "HG01783"
	},
	:HG02301 =>
	{
		:biosample_accession => "SAMN00255134",
		:sex => "female",
		:population_code => "HG02301"
	},
	:HG02302 =>
	{
		:biosample_accession => "SAMN00255133",
		:sex => "male",
		:population_code => "HG02302"
	},
	:HG02286 =>
	{
		:biosample_accession => "SAMN00255131",
		:sex => "female",
		:population_code => "HG02286"
	},
	:HG02285 =>
	{
		:biosample_accession => "SAMN00255130",
		:sex => "male",
		:population_code => "HG02285"
	},
	:HG02010 =>
	{
		:biosample_accession => "SAMN00255128",
		:sex => "female",
		:population_code => "HG02010"
	},
	:HG02009 =>
	{
		:biosample_accession => "SAMN00255127",
		:sex => "male",
		:population_code => "HG02009"
	},
	:HG01889 =>
	{
		:biosample_accession => "SAMN00255125",
		:sex => "female",
		:population_code => "HG01889"
	},
	:HG01890 =>
	{
		:biosample_accession => "SAMN00255124",
		:sex => "male",
		:population_code => "HG01890"
	},
	:HG01886 =>
	{
		:biosample_accession => "SAMN00255122",
		:sex => "female",
		:population_code => "HG01886"
	},
	:HG02014 =>
	{
		:biosample_accession => "SAMN00255121",
		:sex => "male",
		:population_code => "HG02014"
	},
	:HG01956 =>
	{
		:biosample_accession => "SAMN00255119",
		:sex => "female",
		:population_code => "HG01956"
	},
	:HG01885 =>
	{
		:biosample_accession => "SAMN00255118",
		:sex => "male",
		:population_code => "HG01885"
	},
	:HG01883 =>
	{
		:biosample_accession => "SAMN00255116",
		:sex => "female",
		:population_code => "HG01883"
	},
	:HG01882 =>
	{
		:biosample_accession => "SAMN00255115",
		:sex => "male",
		:population_code => "HG01882"
	},
	:HG02215 =>
	{
		:biosample_accession => "SAMN00249949",
		:sex => "female",
		:population_code => "HG02215"
	},
	:HG01791 =>
	{
		:biosample_accession => "SAMN00249948",
		:sex => "male",
		:population_code => "HG01791"
	},
	:HG01790 =>
	{
		:biosample_accession => "SAMN00249947",
		:sex => "female",
		:population_code => "HG01790"
	},
	:HG01789 =>
	{
		:biosample_accession => "SAMN00249946",
		:sex => "male",
		:population_code => "HG01789"
	},
	:HG02190 =>
	{
		:biosample_accession => "SAMN00249945",
		:sex => "female",
		:population_code => "HG02190"
	},
	:HG02189 =>
	{
		:biosample_accession => "SAMN00249944",
		:sex => "female",
		:population_code => "HG02189"
	},
	:HG02188 =>
	{
		:biosample_accession => "SAMN00249943",
		:sex => "female",
		:population_code => "HG02188"
	},
	:HG02187 =>
	{
		:biosample_accession => "SAMN00249942",
		:sex => "female",
		:population_code => "HG02187"
	},
	:HG02186 =>
	{
		:biosample_accession => "SAMN00249941",
		:sex => "female",
		:population_code => "HG02186"
	},
	:HG02185 =>
	{
		:biosample_accession => "SAMN00249940",
		:sex => "female",
		:population_code => "HG02185"
	},
	:HG02184 =>
	{
		:biosample_accession => "SAMN00249939",
		:sex => "female",
		:population_code => "HG02184"
	},
	:HG02182 =>
	{
		:biosample_accession => "SAMN00249938",
		:sex => "female",
		:population_code => "HG02182"
	},
	:HG02181 =>
	{
		:biosample_accession => "SAMN00249937",
		:sex => "female",
		:population_code => "HG02181"
	},
	:HG02180 =>
	{
		:biosample_accession => "SAMN00249936",
		:sex => "female",
		:population_code => "HG02180"
	},
	:HG02179 =>
	{
		:biosample_accession => "SAMN00249935",
		:sex => "female",
		:population_code => "HG02179"
	},
	:HG02178 =>
	{
		:biosample_accession => "SAMN00249934",
		:sex => "female",
		:population_code => "HG02178"
	},
	:HG02166 =>
	{
		:biosample_accession => "SAMN00249933",
		:sex => "female",
		:population_code => "HG02166"
	},
	:HG02165 =>
	{
		:biosample_accession => "SAMN00249932",
		:sex => "female",
		:population_code => "HG02165"
	},
	:HG02164 =>
	{
		:biosample_accession => "SAMN00249931",
		:sex => "female",
		:population_code => "HG02164"
	},
	:HG02156 =>
	{
		:biosample_accession => "SAMN00249930",
		:sex => "female",
		:population_code => "HG02156"
	},
	:HG02155 =>
	{
		:biosample_accession => "SAMN00249929",
		:sex => "female",
		:population_code => "HG02155"
	},
	:HG02154 =>
	{
		:biosample_accession => "SAMN00249928",
		:sex => "female",
		:population_code => "HG02154"
	},
	:HG02153 =>
	{
		:biosample_accession => "SAMN00249927",
		:sex => "female",
		:population_code => "HG02153"
	},
	:HG02152 =>
	{
		:biosample_accession => "SAMN00249926",
		:sex => "female",
		:population_code => "HG02152"
	},
	:HG01817 =>
	{
		:biosample_accession => "SAMN00249925",
		:sex => "female",
		:population_code => "HG01817"
	},
	:HG01816 =>
	{
		:biosample_accession => "SAMN00249924",
		:sex => "male",
		:population_code => "HG01816"
	},
	:HG01815 =>
	{
		:biosample_accession => "SAMN00249923",
		:sex => "female",
		:population_code => "HG01815"
	},
	:HG02151 =>
	{
		:biosample_accession => "SAMN00249922",
		:sex => "female",
		:population_code => "HG02151"
	},
	:HG01813 =>
	{
		:biosample_accession => "SAMN00249921",
		:sex => "female",
		:population_code => "HG01813"
	},
	:HG01812 =>
	{
		:biosample_accession => "SAMN00249920",
		:sex => "female",
		:population_code => "HG01812"
	},
	:HG01811 =>
	{
		:biosample_accession => "SAMN00249919",
		:sex => "male",
		:population_code => "HG01811"
	},
	:HG01810 =>
	{
		:biosample_accession => "SAMN00249918",
		:sex => "male",
		:population_code => "HG01810"
	},
	:HG01809 =>
	{
		:biosample_accession => "SAMN00249917",
		:sex => "female",
		:population_code => "HG01809"
	},
	:HG01808 =>
	{
		:biosample_accession => "SAMN00249916",
		:sex => "female",
		:population_code => "HG01808"
	},
	:HG01807 =>
	{
		:biosample_accession => "SAMN00249915",
		:sex => "female",
		:population_code => "HG01807"
	},
	:HG01806 =>
	{
		:biosample_accession => "SAMN00249914",
		:sex => "female",
		:population_code => "HG01806"
	},
	:HG01805 =>
	{
		:biosample_accession => "SAMN00249913",
		:sex => "female",
		:population_code => "HG01805"
	},
	:HG01804 =>
	{
		:biosample_accession => "SAMN00249912",
		:sex => "female",
		:population_code => "HG01804"
	},
	:HG01802 =>
	{
		:biosample_accession => "SAMN00249911",
		:sex => "female",
		:population_code => "HG01802"
	},
	:HG01801 =>
	{
		:biosample_accession => "SAMN00249910",
		:sex => "female",
		:population_code => "HG01801"
	},
	:HG01800 =>
	{
		:biosample_accession => "SAMN00249909",
		:sex => "female",
		:population_code => "HG01800"
	},
	:HG01799 =>
	{
		:biosample_accession => "SAMN00249908",
		:sex => "female",
		:population_code => "HG01799"
	},
	:HG01798 =>
	{
		:biosample_accession => "SAMN00249907",
		:sex => "female",
		:population_code => "HG01798"
	},
	:HG01797 =>
	{
		:biosample_accession => "SAMN00249906",
		:sex => "female",
		:population_code => "HG01797"
	},
	:HG01796 =>
	{
		:biosample_accession => "SAMN00249905",
		:sex => "female",
		:population_code => "HG01796"
	},
	:HG01795 =>
	{
		:biosample_accession => "SAMN00249904",
		:sex => "female",
		:population_code => "HG01795"
	},
	:HG01794 =>
	{
		:biosample_accession => "SAMN00249903",
		:sex => "female",
		:population_code => "HG01794"
	},
	:HG01046 =>
	{
		:biosample_accession => "SAMN00249902",
		:sex => "female",
		:population_code => "HG01046"
	},
	:HG01031 =>
	{
		:biosample_accession => "SAMN00249901",
		:sex => "male",
		:population_code => "HG01031"
	},
	:HG01029 =>
	{
		:biosample_accession => "SAMN00249900",
		:sex => "female",
		:population_code => "HG01029"
	},
	:HG01028 =>
	{
		:biosample_accession => "SAMN00249899",
		:sex => "male",
		:population_code => "HG01028"
	},
	:HG00983 =>
	{
		:biosample_accession => "SAMN00249898",
		:sex => "male",
		:population_code => "HG00983"
	},
	:HG00982 =>
	{
		:biosample_accession => "SAMN00249897",
		:sex => "male",
		:population_code => "HG00982"
	},
	:HG00978 =>
	{
		:biosample_accession => "SAMN00249896",
		:sex => "female",
		:population_code => "HG00978"
	},
	:HG00956 =>
	{
		:biosample_accession => "SAMN00249895",
		:sex => "female",
		:population_code => "HG00956"
	},
	:HG00881 =>
	{
		:biosample_accession => "SAMN00249894",
		:sex => "male",
		:population_code => "HG00881"
	},
	:HG00879 =>
	{
		:biosample_accession => "SAMN00249893",
		:sex => "female",
		:population_code => "HG00879"
	},
	:HG00867 =>
	{
		:biosample_accession => "SAMN00249892",
		:sex => "female",
		:population_code => "HG00867"
	},
	:HG00866 =>
	{
		:biosample_accession => "SAMN00249891",
		:sex => "male",
		:population_code => "HG00866"
	},
	:HG00864 =>
	{
		:biosample_accession => "SAMN00249890",
		:sex => "female",
		:population_code => "HG00864"
	},
	:HG00851 =>
	{
		:biosample_accession => "SAMN00249889",
		:sex => "female",
		:population_code => "HG00851"
	},
	:HG00844 =>
	{
		:biosample_accession => "SAMN00249888",
		:sex => "male",
		:population_code => "HG00844"
	},
	:HG00766 =>
	{
		:biosample_accession => "SAMN00249887",
		:sex => "female",
		:population_code => "HG00766"
	},
	:HG00759 =>
	{
		:biosample_accession => "SAMN00249886",
		:sex => "female",
		:population_code => "HG00759"
	},
	:HG01779 =>
	{
		:biosample_accession => "SAMN00249884",
		:sex => "female",
		:population_code => "HG01779"
	},
	:HG01781 =>
	{
		:biosample_accession => "SAMN00249883",
		:sex => "male",
		:population_code => "HG01781"
	},
	:HG01776 =>
	{
		:biosample_accession => "SAMN00249881",
		:sex => "female",
		:population_code => "HG01776"
	},
	:HG01777 =>
	{
		:biosample_accession => "SAMN00249880",
		:sex => "male",
		:population_code => "HG01777"
	},
	:HG01773 =>
	{
		:biosample_accession => "SAMN00249878",
		:sex => "female",
		:population_code => "HG01773"
	},
	:HG01775 =>
	{
		:biosample_accession => "SAMN00249877",
		:sex => "male",
		:population_code => "HG01775"
	},
	:HG01770 =>
	{
		:biosample_accession => "SAMN00249875",
		:sex => "female",
		:population_code => "HG01770"
	},
	:HG01771 =>
	{
		:biosample_accession => "SAMN00249874",
		:sex => "male",
		:population_code => "HG01771"
	},
	:HG01762 =>
	{
		:biosample_accession => "SAMN00249872",
		:sex => "female",
		:population_code => "HG01762"
	},
	:HG01761 =>
	{
		:biosample_accession => "SAMN00249871",
		:sex => "male",
		:population_code => "HG01761"
	},
	:HG01757 =>
	{
		:biosample_accession => "SAMN00249869",
		:sex => "female",
		:population_code => "HG01757"
	},
	:HG01756 =>
	{
		:biosample_accession => "SAMN00249868",
		:sex => "male",
		:population_code => "HG01756"
	},
	:HG01746 =>
	{
		:biosample_accession => "SAMN00249866",
		:sex => "female",
		:population_code => "HG01746"
	},
	:HG01747 =>
	{
		:biosample_accession => "SAMN00249865",
		:sex => "male",
		:population_code => "HG01747"
	},
	:HG01710 =>
	{
		:biosample_accession => "SAMN00249863",
		:sex => "female",
		:population_code => "HG01710"
	},
	:HG01709 =>
	{
		:biosample_accession => "SAMN00249862",
		:sex => "male",
		:population_code => "HG01709"
	},
	:HG01695 =>
	{
		:biosample_accession => "SAMN00249860",
		:sex => "female",
		:population_code => "HG01695"
	},
	:HG01694 =>
	{
		:biosample_accession => "SAMN00249859",
		:sex => "male",
		:population_code => "HG01694"
	},
	:HG02142 =>
	{
		:biosample_accession => "SAMN00249858",
		:sex => "female",
		:population_code => "HG02142"
	},
	:HG02140 =>
	{
		:biosample_accession => "SAMN00249857",
		:sex => "female",
		:population_code => "HG02140"
	},
	:HG02139 =>
	{
		:biosample_accession => "SAMN00249856",
		:sex => "female",
		:population_code => "HG02139"
	},
	:HG02138 =>
	{
		:biosample_accession => "SAMN00249855",
		:sex => "male",
		:population_code => "HG02138"
	},
	:HG02088 =>
	{
		:biosample_accession => "SAMN00249854",
		:sex => "male",
		:population_code => "HG02088"
	},
	:HG02087 =>
	{
		:biosample_accession => "SAMN00249853",
		:sex => "female",
		:population_code => "HG02087"
	},
	:HG02086 =>
	{
		:biosample_accession => "SAMN00249852",
		:sex => "female",
		:population_code => "HG02086"
	},
	:HG02049 =>
	{
		:biosample_accession => "SAMN00249851",
		:sex => "female",
		:population_code => "HG02049"
	},
	:HG02048 =>
	{
		:biosample_accession => "SAMN00249850",
		:sex => "female",
		:population_code => "HG02048"
	},
	:HG01878 =>
	{
		:biosample_accession => "SAMN00249849",
		:sex => "female",
		:population_code => "HG01878"
	},
	:HG01874 =>
	{
		:biosample_accession => "SAMN00249848",
		:sex => "female",
		:population_code => "HG01874"
	},
	:HG01873 =>
	{
		:biosample_accession => "SAMN00249847",
		:sex => "male",
		:population_code => "HG01873"
	},
	:HG01872 =>
	{
		:biosample_accession => "SAMN00249846",
		:sex => "male",
		:population_code => "HG01872"
	},
	:HG01871 =>
	{
		:biosample_accession => "SAMN00249845",
		:sex => "female",
		:population_code => "HG01871"
	},
	:HG01870 =>
	{
		:biosample_accession => "SAMN00249844",
		:sex => "female",
		:population_code => "HG01870"
	},
	:HG01869 =>
	{
		:biosample_accession => "SAMN00249843",
		:sex => "female",
		:population_code => "HG01869"
	},
	:HG01868 =>
	{
		:biosample_accession => "SAMN00249842",
		:sex => "female",
		:population_code => "HG01868"
	},
	:HG01867 =>
	{
		:biosample_accession => "SAMN00249841",
		:sex => "male",
		:population_code => "HG01867"
	},
	:HG01866 =>
	{
		:biosample_accession => "SAMN00249840",
		:sex => "male",
		:population_code => "HG01866"
	},
	:HG01865 =>
	{
		:biosample_accession => "SAMN00249839",
		:sex => "male",
		:population_code => "HG01865"
	},
	:HG01864 =>
	{
		:biosample_accession => "SAMN00249838",
		:sex => "male",
		:population_code => "HG01864"
	},
	:HG01863 =>
	{
		:biosample_accession => "SAMN00249837",
		:sex => "female",
		:population_code => "HG01863"
	},
	:HG01862 =>
	{
		:biosample_accession => "SAMN00249836",
		:sex => "female",
		:population_code => "HG01862"
	},
	:HG01861 =>
	{
		:biosample_accession => "SAMN00249835",
		:sex => "male",
		:population_code => "HG01861"
	},
	:HG01860 =>
	{
		:biosample_accession => "SAMN00249834",
		:sex => "male",
		:population_code => "HG01860"
	},
	:HG01859 =>
	{
		:biosample_accession => "SAMN00249833",
		:sex => "female",
		:population_code => "HG01859"
	},
	:HG01858 =>
	{
		:biosample_accession => "SAMN00249832",
		:sex => "female",
		:population_code => "HG01858"
	},
	:HG01857 =>
	{
		:biosample_accession => "SAMN00249831",
		:sex => "female",
		:population_code => "HG01857"
	},
	:HG01855 =>
	{
		:biosample_accession => "SAMN00249830",
		:sex => "female",
		:population_code => "HG01855"
	},
	:HG01853 =>
	{
		:biosample_accession => "SAMN00249829",
		:sex => "female",
		:population_code => "HG01853"
	},
	:HG01852 =>
	{
		:biosample_accession => "SAMN00249828",
		:sex => "male",
		:population_code => "HG01852"
	},
	:HG01851 =>
	{
		:biosample_accession => "SAMN00249827",
		:sex => "female",
		:population_code => "HG01851"
	},
	:HG01850 =>
	{
		:biosample_accession => "SAMN00249826",
		:sex => "female",
		:population_code => "HG01850"
	},
	:HG01849 =>
	{
		:biosample_accession => "SAMN00249825",
		:sex => "male",
		:population_code => "HG01849"
	},
	:HG01848 =>
	{
		:biosample_accession => "SAMN00249824",
		:sex => "female",
		:population_code => "HG01848"
	},
	:HG01847 =>
	{
		:biosample_accession => "SAMN00249823",
		:sex => "female",
		:population_code => "HG01847"
	},
	:HG01846 =>
	{
		:biosample_accession => "SAMN00249822",
		:sex => "male",
		:population_code => "HG01846"
	},
	:HG01845 =>
	{
		:biosample_accession => "SAMN00249821",
		:sex => "female",
		:population_code => "HG01845"
	},
	:HG01844 =>
	{
		:biosample_accession => "SAMN00249820",
		:sex => "male",
		:population_code => "HG01844"
	},
	:HG01843 =>
	{
		:biosample_accession => "SAMN00249819",
		:sex => "female",
		:population_code => "HG01843"
	},
	:HG01842 =>
	{
		:biosample_accession => "SAMN00249818",
		:sex => "male",
		:population_code => "HG01842"
	},
	:HG01840 =>
	{
		:biosample_accession => "SAMN00249817",
		:sex => "male",
		:population_code => "HG01840"
	},
	:HG01600 =>
	{
		:biosample_accession => "SAMN00249816",
		:sex => "female",
		:population_code => "HG01600"
	},
	:HG01599 =>
	{
		:biosample_accession => "SAMN00249815",
		:sex => "female",
		:population_code => "HG01599"
	},
	:HG01598 =>
	{
		:biosample_accession => "SAMN00249814",
		:sex => "female",
		:population_code => "HG01598"
	},
	:HG01597 =>
	{
		:biosample_accession => "SAMN00249813",
		:sex => "female",
		:population_code => "HG01597"
	},
	:HG01596 =>
	{
		:biosample_accession => "SAMN00249812",
		:sex => "male",
		:population_code => "HG01596"
	},
	:HG01595 =>
	{
		:biosample_accession => "SAMN00249811",
		:sex => "female",
		:population_code => "HG01595"
	},
	:HG01841 =>
	{
		:biosample_accession => "SAMN00249810",
		:sex => "female",
		:population_code => "HG01841"
	},
	:HG02133 =>
	{
		:biosample_accession => "SAMN00249808",
		:sex => "female",
		:population_code => "HG02133"
	},
	:HG02134 =>
	{
		:biosample_accession => "SAMN00249807",
		:sex => "male",
		:population_code => "HG02134"
	},
	:HG02084 =>
	{
		:biosample_accession => "SAMN00249805",
		:sex => "female",
		:population_code => "HG02084"
	},
	:HG02085 =>
	{
		:biosample_accession => "SAMN00249804",
		:sex => "male",
		:population_code => "HG02085"
	},
	:HG02081 =>
	{
		:biosample_accession => "SAMN00249802",
		:sex => "female",
		:population_code => "HG02081"
	},
	:HG02082 =>
	{
		:biosample_accession => "SAMN00249801",
		:sex => "male",
		:population_code => "HG02082"
	},
	:HG02078 =>
	{
		:biosample_accession => "SAMN00249799",
		:sex => "female",
		:population_code => "HG02078"
	},
	:HG02079 =>
	{
		:biosample_accession => "SAMN00249798",
		:sex => "male",
		:population_code => "HG02079"
	},
	:HG02075 =>
	{
		:biosample_accession => "SAMN00249796",
		:sex => "female",
		:population_code => "HG02075"
	},
	:HG02076 =>
	{
		:biosample_accession => "SAMN00249795",
		:sex => "male",
		:population_code => "HG02076"
	},
	:HG02072 =>
	{
		:biosample_accession => "SAMN00249793",
		:sex => "female",
		:population_code => "HG02072"
	},
	:HG02073 =>
	{
		:biosample_accession => "SAMN00249792",
		:sex => "male",
		:population_code => "HG02073"
	},
	:HG02069 =>
	{
		:biosample_accession => "SAMN00249790",
		:sex => "female",
		:population_code => "HG02069"
	},
	:HG02070 =>
	{
		:biosample_accession => "SAMN00249789",
		:sex => "male",
		:population_code => "HG02070"
	},
	:HG02057 =>
	{
		:biosample_accession => "SAMN00249787",
		:sex => "female",
		:population_code => "HG02057"
	},
	:HG02058 =>
	{
		:biosample_accession => "SAMN00249786",
		:sex => "male",
		:population_code => "HG02058"
	},
	:HG02028 =>
	{
		:biosample_accession => "SAMN00249784",
		:sex => "female",
		:population_code => "HG02028"
	},
	:HG02029 =>
	{
		:biosample_accession => "SAMN00249783",
		:sex => "male",
		:population_code => "HG02029"
	},
	:HG02024 =>
	{
		:biosample_accession => "SAMN00249782",
		:sex => "female",
		:population_code => "HG02024"
	},
	:HG02025 =>
	{
		:biosample_accession => "SAMN00249781",
		:sex => "female",
		:population_code => "HG02025"
	},
	:HG02026 =>
	{
		:biosample_accession => "SAMN00249780",
		:sex => "male",
		:population_code => "HG02026"
	},
	:HG02023 =>
	{
		:biosample_accession => "SAMN00249777",
		:sex => "male",
		:population_code => "HG02023"
	},
	:HG02019 =>
	{
		:biosample_accession => "SAMN00249775",
		:sex => "female",
		:population_code => "HG02019"
	},
	:HG02020 =>
	{
		:biosample_accession => "SAMN00249774",
		:sex => "male",
		:population_code => "HG02020"
	},
	:HG02016 =>
	{
		:biosample_accession => "SAMN00249772",
		:sex => "female",
		:population_code => "HG02016"
	},
	:HG02017 =>
	{
		:biosample_accession => "SAMN00249771",
		:sex => "male",
		:population_code => "HG02017"
	},
	:HG02105 =>
	{
		:biosample_accession => "SAMN00249748",
		:sex => "female",
		:population_code => "HG02105"
	},
	:HG02104 =>
	{
		:biosample_accession => "SAMN00249747",
		:sex => "male",
		:population_code => "HG02104"
	},
	:HG02089 =>
	{
		:biosample_accession => "SAMN00249745",
		:sex => "female",
		:population_code => "HG02089"
	},
	:HG02090 =>
	{
		:biosample_accession => "SAMN00249744",
		:sex => "male",
		:population_code => "HG02090"
	},
	:HG02003 =>
	{
		:biosample_accession => "SAMN00249742",
		:sex => "female",
		:population_code => "HG02003"
	},
	:HG02002 =>
	{
		:biosample_accession => "SAMN00249741",
		:sex => "male",
		:population_code => "HG02002"
	},
	:HG01997 =>
	{
		:biosample_accession => "SAMN00249739",
		:sex => "female",
		:population_code => "HG01997"
	},
	:HG02008 =>
	{
		:biosample_accession => "SAMN00249738",
		:sex => "male",
		:population_code => "HG02008"
	},
	:HG01992 =>
	{
		:biosample_accession => "SAMN00249736",
		:sex => "female",
		:population_code => "HG01992"
	},
	:HG01991 =>
	{
		:biosample_accession => "SAMN00249735",
		:sex => "male",
		:population_code => "HG01991"
	},
	:HG01980 =>
	{
		:biosample_accession => "SAMN00249733",
		:sex => "female",
		:population_code => "HG01980"
	},
	:HG01979 =>
	{
		:biosample_accession => "SAMN00249732",
		:sex => "male",
		:population_code => "HG01979"
	},
	:HG01976 =>
	{
		:biosample_accession => "SAMN00249730",
		:sex => "female",
		:population_code => "HG01976"
	},
	:HG01977 =>
	{
		:biosample_accession => "SAMN00249729",
		:sex => "male",
		:population_code => "HG01977"
	},
	:HG01973 =>
	{
		:biosample_accession => "SAMN00249727",
		:sex => "female",
		:population_code => "HG01973"
	},
	:HG01974 =>
	{
		:biosample_accession => "SAMN00249726",
		:sex => "male",
		:population_code => "HG01974"
	},
	:HG01971 =>
	{
		:biosample_accession => "SAMN00249724",
		:sex => "female",
		:population_code => "HG01971"
	},
	:HG01970 =>
	{
		:biosample_accession => "SAMN00249723",
		:sex => "male",
		:population_code => "HG01970"
	},
	:HG01968 =>
	{
		:biosample_accession => "SAMN00249721",
		:sex => "female",
		:population_code => "HG01968"
	},
	:HG01967 =>
	{
		:biosample_accession => "SAMN00249720",
		:sex => "male",
		:population_code => "HG01967"
	},
	:HG01954 =>
	{
		:biosample_accession => "SAMN00249718",
		:sex => "female",
		:population_code => "HG01954"
	},
	:HG01953 =>
	{
		:biosample_accession => "SAMN00249717",
		:sex => "male",
		:population_code => "HG01953"
	},
	:HG01951 =>
	{
		:biosample_accession => "SAMN00249715",
		:sex => "female",
		:population_code => "HG01951"
	},
	:HG01950 =>
	{
		:biosample_accession => "SAMN00249714",
		:sex => "male",
		:population_code => "HG01950"
	},
	:HG01948 =>
	{
		:biosample_accession => "SAMN00249712",
		:sex => "female",
		:population_code => "HG01948"
	},
	:HG01947 =>
	{
		:biosample_accession => "SAMN00249711",
		:sex => "male",
		:population_code => "HG01947"
	},
	:HG01945 =>
	{
		:biosample_accession => "SAMN00249709",
		:sex => "female",
		:population_code => "HG01945"
	},
	:HG01944 =>
	{
		:biosample_accession => "SAMN00249708",
		:sex => "male",
		:population_code => "HG01944"
	},
	:HG01942 =>
	{
		:biosample_accession => "SAMN00249706",
		:sex => "female",
		:population_code => "HG01942"
	},
	:HG01941 =>
	{
		:biosample_accession => "SAMN00249705",
		:sex => "male",
		:population_code => "HG01941"
	},
	:HG01939 =>
	{
		:biosample_accession => "SAMN00249703",
		:sex => "female",
		:population_code => "HG01939"
	},
	:HG01938 =>
	{
		:biosample_accession => "SAMN00249702",
		:sex => "male",
		:population_code => "HG01938"
	},
	:HG01936 =>
	{
		:biosample_accession => "SAMN00249700",
		:sex => "female",
		:population_code => "HG01936"
	},
	:HG01935 =>
	{
		:biosample_accession => "SAMN00249699",
		:sex => "male",
		:population_code => "HG01935"
	},
	:HG01933 =>
	{
		:biosample_accession => "SAMN00249697",
		:sex => "female",
		:population_code => "HG01933"
	},
	:HG01932 =>
	{
		:biosample_accession => "SAMN00249696",
		:sex => "male",
		:population_code => "HG01932"
	},
	:HG01927 =>
	{
		:biosample_accession => "SAMN00249694",
		:sex => "female",
		:population_code => "HG01927"
	},
	:HG01926 =>
	{
		:biosample_accession => "SAMN00249693",
		:sex => "male",
		:population_code => "HG01926"
	},
	:HG01924 =>
	{
		:biosample_accession => "SAMN00249691",
		:sex => "female",
		:population_code => "HG01924"
	},
	:HG01923 =>
	{
		:biosample_accession => "SAMN00249690",
		:sex => "male",
		:population_code => "HG01923"
	},
	:HG01921 =>
	{
		:biosample_accession => "SAMN00249688",
		:sex => "female",
		:population_code => "HG01921"
	},
	:HG01920 =>
	{
		:biosample_accession => "SAMN00249687",
		:sex => "male",
		:population_code => "HG01920"
	},
	:HG01893 =>
	{
		:biosample_accession => "SAMN00249685",
		:sex => "female",
		:population_code => "HG01893"
	},
	:HG01892 =>
	{
		:biosample_accession => "SAMN00249684",
		:sex => "male",
		:population_code => "HG01892"
	},
	:HG01918 =>
	{
		:biosample_accession => "SAMN00249682",
		:sex => "female",
		:population_code => "HG01918"
	},
	:HG01917 =>
	{
		:biosample_accession => "SAMN00249681",
		:sex => "male",
		:population_code => "HG01917"
	},
	:HG01578 =>
	{
		:biosample_accession => "SAMN00249679",
		:sex => "female",
		:population_code => "HG01578"
	},
	:HG01577 =>
	{
		:biosample_accession => "SAMN00249678",
		:sex => "male",
		:population_code => "HG01577"
	},
	:HG01572 =>
	{
		:biosample_accession => "SAMN00249676",
		:sex => "female",
		:population_code => "HG01572"
	},
	:HG01571 =>
	{
		:biosample_accession => "SAMN00249675",
		:sex => "male",
		:population_code => "HG01571"
	},
	:HG01566 =>
	{
		:biosample_accession => "SAMN00249673",
		:sex => "female",
		:population_code => "HG01566"
	},
	:HG01565 =>
	{
		:biosample_accession => "SAMN00249672",
		:sex => "male",
		:population_code => "HG01565"
	},
	:HG00190 =>
	{
		:biosample_accession => "SAMN00016981",
		:sex => "male",
		:population_code => "HG00190"
	},
	:HG00189 =>
	{
		:biosample_accession => "SAMN00016980",
		:sex => "male",
		:population_code => "HG00189"
	},
	:HG00188 =>
	{
		:biosample_accession => "SAMN00016979",
		:sex => "male",
		:population_code => "HG00188"
	},
	:HG00187 =>
	{
		:biosample_accession => "SAMN00016978",
		:sex => "male",
		:population_code => "HG00187"
	},
	:HG00186 =>
	{
		:biosample_accession => "SAMN00016977",
		:sex => "male",
		:population_code => "HG00186"
	},
	:HG00185 =>
	{
		:biosample_accession => "SAMN00016976",
		:sex => "male",
		:population_code => "HG00185"
	},
	:HG00183 =>
	{
		:biosample_accession => "SAMN00016975",
		:sex => "male",
		:population_code => "HG00183"
	},
	:HG00182 =>
	{
		:biosample_accession => "SAMN00016974",
		:sex => "male",
		:population_code => "HG00182"
	},
	:HG00181 =>
	{
		:biosample_accession => "SAMN00016973",
		:sex => "male",
		:population_code => "HG00181"
	},
	:HG00180 =>
	{
		:biosample_accession => "SAMN00016972",
		:sex => "female",
		:population_code => "HG00180"
	},
	:HG00179 =>
	{
		:biosample_accession => "SAMN00016971",
		:sex => "female",
		:population_code => "HG00179"
	},
	:HG00178 =>
	{
		:biosample_accession => "SAMN00016970",
		:sex => "female",
		:population_code => "HG00178"
	},
	:HG00177 =>
	{
		:biosample_accession => "SAMN00016969",
		:sex => "female",
		:population_code => "HG00177"
	},
	:HG00176 =>
	{
		:biosample_accession => "SAMN00016968",
		:sex => "female",
		:population_code => "HG00176"
	},
	:HG00174 =>
	{
		:biosample_accession => "SAMN00016967",
		:sex => "female",
		:population_code => "HG00174"
	},
	:HG00173 =>
	{
		:biosample_accession => "SAMN00016966",
		:sex => "female",
		:population_code => "HG00173"
	},
	:HG00171 =>
	{
		:biosample_accession => "SAMN00016965",
		:sex => "female",
		:population_code => "HG00171"
	},
	:HG01708 =>
	{
		:biosample_accession => "SAMN00016860",
		:sex => "male",
		:population_code => "HG01708"
	},
	:HG01707 =>
	{
		:biosample_accession => "SAMN00016859",
		:sex => "female",
		:population_code => "HG01707"
	},
	:HG01705 =>
	{
		:biosample_accession => "SAMN00016857",
		:sex => "male",
		:population_code => "HG01705"
	},
	:HG01704 =>
	{
		:biosample_accession => "SAMN00016856",
		:sex => "female",
		:population_code => "HG01704"
	},
	:HG01702 =>
	{
		:biosample_accession => "SAMN00016854",
		:sex => "female",
		:population_code => "HG01702"
	},
	:HG01700 =>
	{
		:biosample_accession => "SAMN00016852",
		:sex => "male",
		:population_code => "HG01700"
	},
	:HG01686 =>
	{
		:biosample_accession => "SAMN00016850",
		:sex => "male",
		:population_code => "HG01686"
	},
	:HG01685 =>
	{
		:biosample_accession => "SAMN00016849",
		:sex => "female",
		:population_code => "HG01685"
	},
	:HG01684 =>
	{
		:biosample_accession => "SAMN00016848",
		:sex => "female",
		:population_code => "HG01684"
	},
	:HG01682 =>
	{
		:biosample_accession => "SAMN00016846",
		:sex => "male",
		:population_code => "HG01682"
	},
	:HG01680 =>
	{
		:biosample_accession => "SAMN00016844",
		:sex => "male",
		:population_code => "HG01680"
	},
	:HG01679 =>
	{
		:biosample_accession => "SAMN00016843",
		:sex => "female",
		:population_code => "HG01679"
	},
	:HG01678 =>
	{
		:biosample_accession => "SAMN00016842",
		:sex => "male",
		:population_code => "HG01678"
	},
	:HG01676 =>
	{
		:biosample_accession => "SAMN00016840",
		:sex => "female",
		:population_code => "HG01676"
	},
	:HG01675 =>
	{
		:biosample_accession => "SAMN00016839",
		:sex => "male",
		:population_code => "HG01675"
	},
	:HG01673 =>
	{
		:biosample_accession => "SAMN00016837",
		:sex => "female",
		:population_code => "HG01673"
	},
	:HG01672 =>
	{
		:biosample_accession => "SAMN00016836",
		:sex => "male",
		:population_code => "HG01672"
	},
	:HG01670 =>
	{
		:biosample_accession => "SAMN00016834",
		:sex => "female",
		:population_code => "HG01670"
	},
	:HG01669 =>
	{
		:biosample_accession => "SAMN00016833",
		:sex => "male",
		:population_code => "HG01669"
	},
	:HG01668 =>
	{
		:biosample_accession => "SAMN00016832",
		:sex => "female",
		:population_code => "HG01668"
	},
	:HG01632 =>
	{
		:biosample_accession => "SAMN00014435",
		:sex => "female",
		:population_code => "HG01632"
	},
	:HG01631 =>
	{
		:biosample_accession => "SAMN00014434",
		:sex => "male",
		:population_code => "HG01631"
	},
	:HG01630 =>
	{
		:biosample_accession => "SAMN00014433",
		:sex => "male",
		:population_code => "HG01630"
	},
	:HG01628 =>
	{
		:biosample_accession => "SAMN00014431",
		:sex => "female",
		:population_code => "HG01628"
	},
	:HG01626 =>
	{
		:biosample_accession => "SAMN00014429",
		:sex => "female",
		:population_code => "HG01626"
	},
	:HG01625 =>
	{
		:biosample_accession => "SAMN00014428",
		:sex => "male",
		:population_code => "HG01625"
	},
	:HG01624 =>
	{
		:biosample_accession => "SAMN00014427",
		:sex => "male",
		:population_code => "HG01624"
	},
	:HG01623 =>
	{
		:biosample_accession => "SAMN00014426",
		:sex => "female",
		:population_code => "HG01623"
	},
	:HG01620 =>
	{
		:biosample_accession => "SAMN00014423",
		:sex => "female",
		:population_code => "HG01620"
	},
	:HG01619 =>
	{
		:biosample_accession => "SAMN00014422",
		:sex => "male",
		:population_code => "HG01619"
	},
	:HG01618 =>
	{
		:biosample_accession => "SAMN00014421",
		:sex => "female",
		:population_code => "HG01618"
	},
	:HG01617 =>
	{
		:biosample_accession => "SAMN00014420",
		:sex => "male",
		:population_code => "HG01617"
	},
	:HG01615 =>
	{
		:biosample_accession => "SAMN00014418",
		:sex => "male",
		:population_code => "HG01615"
	},
	:HG01613 =>
	{
		:biosample_accession => "SAMN00014416",
		:sex => "female",
		:population_code => "HG01613"
	},
	:HG01612 =>
	{
		:biosample_accession => "SAMN00014415",
		:sex => "female",
		:population_code => "HG01612"
	},
	:HG01610 =>
	{
		:biosample_accession => "SAMN00014413",
		:sex => "male",
		:population_code => "HG01610"
	},
	:HG01608 =>
	{
		:biosample_accession => "SAMN00014411",
		:sex => "male",
		:population_code => "HG01608"
	},
	:HG01607 =>
	{
		:biosample_accession => "SAMN00014410",
		:sex => "female",
		:population_code => "HG01607"
	},
	:HG01606 =>
	{
		:biosample_accession => "SAMN00014409",
		:sex => "male",
		:population_code => "HG01606"
	},
	:HG01605 =>
	{
		:biosample_accession => "SAMN00014408",
		:sex => "female",
		:population_code => "HG01605"
	},
	:HG01603 =>
	{
		:biosample_accession => "SAMN00014406",
		:sex => "male",
		:population_code => "HG01603"
	},
	:HG01602 =>
	{
		:biosample_accession => "SAMN00014405",
		:sex => "female",
		:population_code => "HG01602"
	},
	:HG01551 =>
	{
		:biosample_accession => "SAMN00014396",
		:sex => "female",
		:population_code => "HG01551"
	},
	:HG01550 =>
	{
		:biosample_accession => "SAMN00014395",
		:sex => "male",
		:population_code => "HG01550"
	},
	:HG01537 =>
	{
		:biosample_accession => "SAMN00014393",
		:sex => "female",
		:population_code => "HG01537"
	},
	:HG01536 =>
	{
		:biosample_accession => "SAMN00014392",
		:sex => "male",
		:population_code => "HG01536"
	},
	:HG01531 =>
	{
		:biosample_accession => "SAMN00014390",
		:sex => "female",
		:population_code => "HG01531"
	},
	:HG01530 =>
	{
		:biosample_accession => "SAMN00014389",
		:sex => "male",
		:population_code => "HG01530"
	},
	:HG01528 =>
	{
		:biosample_accession => "SAMN00014387",
		:sex => "female",
		:population_code => "HG01528"
	},
	:HG01527 =>
	{
		:biosample_accession => "SAMN00014386",
		:sex => "male",
		:population_code => "HG01527"
	},
	:HG01525 =>
	{
		:biosample_accession => "SAMN00014384",
		:sex => "female",
		:population_code => "HG01525"
	},
	:HG01524 =>
	{
		:biosample_accession => "SAMN00014383",
		:sex => "male",
		:population_code => "HG01524"
	},
	:HG01522 =>
	{
		:biosample_accession => "SAMN00014381",
		:sex => "female",
		:population_code => "HG01522"
	},
	:HG01521 =>
	{
		:biosample_accession => "SAMN00014380",
		:sex => "male",
		:population_code => "HG01521"
	},
	:HG01519 =>
	{
		:biosample_accession => "SAMN00014378",
		:sex => "female",
		:population_code => "HG01519"
	},
	:HG01518 =>
	{
		:biosample_accession => "SAMN00014377",
		:sex => "male",
		:population_code => "HG01518"
	},
	:HG01516 =>
	{
		:biosample_accession => "SAMN00014375",
		:sex => "female",
		:population_code => "HG01516"
	},
	:HG01515 =>
	{
		:biosample_accession => "SAMN00014374",
		:sex => "male",
		:population_code => "HG01515"
	},
	:HG01513 =>
	{
		:biosample_accession => "SAMN00014372",
		:sex => "female",
		:population_code => "HG01513"
	},
	:HG01512 =>
	{
		:biosample_accession => "SAMN00014371",
		:sex => "male",
		:population_code => "HG01512"
	},
	:HG01510 =>
	{
		:biosample_accession => "SAMN00014369",
		:sex => "female",
		:population_code => "HG01510"
	},
	:HG01509 =>
	{
		:biosample_accession => "SAMN00014368",
		:sex => "male",
		:population_code => "HG01509"
	},
	:HG01507 =>
	{
		:biosample_accession => "SAMN00014366",
		:sex => "female",
		:population_code => "HG01507"
	},
	:HG01506 =>
	{
		:biosample_accession => "SAMN00014365",
		:sex => "male",
		:population_code => "HG01506"
	},
	:HG01504 =>
	{
		:biosample_accession => "SAMN00014363",
		:sex => "female",
		:population_code => "HG01504"
	},
	:HG01503 =>
	{
		:biosample_accession => "SAMN00014362",
		:sex => "male",
		:population_code => "HG01503"
	},
	:HG01501 =>
	{
		:biosample_accession => "SAMN00014360",
		:sex => "female",
		:population_code => "HG01501"
	},
	:HG01500 =>
	{
		:biosample_accession => "SAMN00014359",
		:sex => "male",
		:population_code => "HG01500"
	},
	:HG01498 =>
	{
		:biosample_accession => "SAMN00014357",
		:sex => "female",
		:population_code => "HG01498"
	},
	:HG01497 =>
	{
		:biosample_accession => "SAMN00014356",
		:sex => "male",
		:population_code => "HG01497"
	},
	:HG01495 =>
	{
		:biosample_accession => "SAMN00014354",
		:sex => "female",
		:population_code => "HG01495"
	},
	:HG01494 =>
	{
		:biosample_accession => "SAMN00014353",
		:sex => "male",
		:population_code => "HG01494"
	},
	:HG01492 =>
	{
		:biosample_accession => "SAMN00014351",
		:sex => "female",
		:population_code => "HG01492"
	},
	:HG01491 =>
	{
		:biosample_accession => "SAMN00014350",
		:sex => "male",
		:population_code => "HG01491"
	},
	:HG01489 =>
	{
		:biosample_accession => "SAMN00014348",
		:sex => "female",
		:population_code => "HG01489"
	},
	:HG01488 =>
	{
		:biosample_accession => "SAMN00014347",
		:sex => "male",
		:population_code => "HG01488"
	},
	:HG01465 =>
	{
		:biosample_accession => "SAMN00014345",
		:sex => "female",
		:population_code => "HG01465"
	},
	:HG01464 =>
	{
		:biosample_accession => "SAMN00014344",
		:sex => "male",
		:population_code => "HG01464"
	},
	:HG01462 =>
	{
		:biosample_accession => "SAMN00014342",
		:sex => "female",
		:population_code => "HG01462"
	},
	:HG01461 =>
	{
		:biosample_accession => "SAMN00014341",
		:sex => "male",
		:population_code => "HG01461"
	},
	:HG01456 =>
	{
		:biosample_accession => "SAMN00014339",
		:sex => "female",
		:population_code => "HG01456"
	},
	:HG01455 =>
	{
		:biosample_accession => "SAMN00014338",
		:sex => "male",
		:population_code => "HG01455"
	},
	:HG01441 =>
	{
		:biosample_accession => "SAMN00014336",
		:sex => "female",
		:population_code => "HG01441"
	},
	:HG01440 =>
	{
		:biosample_accession => "SAMN00014335",
		:sex => "male",
		:population_code => "HG01440"
	},
	:HG01438 =>
	{
		:biosample_accession => "SAMN00014333",
		:sex => "female",
		:population_code => "HG01438"
	},
	:HG01437 =>
	{
		:biosample_accession => "SAMN00014332",
		:sex => "male",
		:population_code => "HG01437"
	},
	:HG01390 =>
	{
		:biosample_accession => "SAMN00014330",
		:sex => "female",
		:population_code => "HG01390"
	},
	:HG01389 =>
	{
		:biosample_accession => "SAMN00014329",
		:sex => "male",
		:population_code => "HG01389"
	},
	:HG01375 =>
	{
		:biosample_accession => "SAMN00014327",
		:sex => "female",
		:population_code => "HG01375"
	},
	:HG01374 =>
	{
		:biosample_accession => "SAMN00014326",
		:sex => "male",
		:population_code => "HG01374"
	},
	:HG01366 =>
	{
		:biosample_accession => "SAMN00014324",
		:sex => "female",
		:population_code => "HG01366"
	},
	:HG01365 =>
	{
		:biosample_accession => "SAMN00014323",
		:sex => "male",
		:population_code => "HG01365"
	},
	:HG01360 =>
	{
		:biosample_accession => "SAMN00014321",
		:sex => "female",
		:population_code => "HG01360"
	},
	:HG01359 =>
	{
		:biosample_accession => "SAMN00014320",
		:sex => "male",
		:population_code => "HG01359"
	},
	:HG01354 =>
	{
		:biosample_accession => "SAMN00014318",
		:sex => "female",
		:population_code => "HG01354"
	},
	:HG01353 =>
	{
		:biosample_accession => "SAMN00014317",
		:sex => "male",
		:population_code => "HG01353"
	},
	:HG01351 =>
	{
		:biosample_accession => "SAMN00014315",
		:sex => "female",
		:population_code => "HG01351"
	},
	:HG01350 =>
	{
		:biosample_accession => "SAMN00014314",
		:sex => "male",
		:population_code => "HG01350"
	},
	:HG01342 =>
	{
		:biosample_accession => "SAMN00014312",
		:sex => "female",
		:population_code => "HG01342"
	},
	:HG01341 =>
	{
		:biosample_accession => "SAMN00014311",
		:sex => "male",
		:population_code => "HG01341"
	},
	:HG01384 =>
	{
		:biosample_accession => "SAMN00009254",
		:sex => "female",
		:population_code => "HG01384"
	},
	:HG01383 =>
	{
		:biosample_accession => "SAMN00009253",
		:sex => "male",
		:population_code => "HG01383"
	},
	:HG01378 =>
	{
		:biosample_accession => "SAMN00009251",
		:sex => "female",
		:population_code => "HG01378"
	},
	:HG01377 =>
	{
		:biosample_accession => "SAMN00009250",
		:sex => "male",
		:population_code => "HG01377"
	},
	:HG01357 =>
	{
		:biosample_accession => "SAMN00009248",
		:sex => "female",
		:population_code => "HG01357"
	},
	:HG01356 =>
	{
		:biosample_accession => "SAMN00009247",
		:sex => "male",
		:population_code => "HG01356"
	},
	:HG01348 =>
	{
		:biosample_accession => "SAMN00009245",
		:sex => "female",
		:population_code => "HG01348"
	},
	:HG01347 =>
	{
		:biosample_accession => "SAMN00009244",
		:sex => "male",
		:population_code => "HG01347"
	},
	:HG01345 =>
	{
		:biosample_accession => "SAMN00009242",
		:sex => "female",
		:population_code => "HG01345"
	},
	:HG01344 =>
	{
		:biosample_accession => "SAMN00009241",
		:sex => "male",
		:population_code => "HG01344"
	},
	:HG01334 =>
	{
		:biosample_accession => "SAMN00009240",
		:sex => "male",
		:population_code => "HG01334"
	},
	:HG01278 =>
	{
		:biosample_accession => "SAMN00009226",
		:sex => "female",
		:population_code => "HG01278"
	},
	:HG01277 =>
	{
		:biosample_accession => "SAMN00009225",
		:sex => "male",
		:population_code => "HG01277"
	},
	:HG01275 =>
	{
		:biosample_accession => "SAMN00009223",
		:sex => "female",
		:population_code => "HG01275"
	},
	:HG01274 =>
	{
		:biosample_accession => "SAMN00009222",
		:sex => "male",
		:population_code => "HG01274"
	},
	:HG01272 =>
	{
		:biosample_accession => "SAMN00009220",
		:sex => "female",
		:population_code => "HG01272"
	},
	:HG01271 =>
	{
		:biosample_accession => "SAMN00009219",
		:sex => "male",
		:population_code => "HG01271"
	},
	:HG01260 =>
	{
		:biosample_accession => "SAMN00009214",
		:sex => "female",
		:population_code => "HG01260"
	},
	:HG01259 =>
	{
		:biosample_accession => "SAMN00009213",
		:sex => "male",
		:population_code => "HG01259"
	},
	:HG01257 =>
	{
		:biosample_accession => "SAMN00009211",
		:sex => "female",
		:population_code => "HG01257"
	},
	:HG01256 =>
	{
		:biosample_accession => "SAMN00009210",
		:sex => "male",
		:population_code => "HG01256"
	},
	:HG01254 =>
	{
		:biosample_accession => "SAMN00009208",
		:sex => "female",
		:population_code => "HG01254"
	},
	:HG01253 =>
	{
		:biosample_accession => "SAMN00009207",
		:sex => "male",
		:population_code => "HG01253"
	},
	:HG01251 =>
	{
		:biosample_accession => "SAMN00009205",
		:sex => "female",
		:population_code => "HG01251"
	},
	:HG01250 =>
	{
		:biosample_accession => "SAMN00009204",
		:sex => "male",
		:population_code => "HG01250"
	},
	:HG01248 =>
	{
		:biosample_accession => "SAMN00009202",
		:sex => "female",
		:population_code => "HG01248"
	},
	:HG01247 =>
	{
		:biosample_accession => "SAMN00009201",
		:sex => "male",
		:population_code => "HG01247"
	},
	:HG01242 =>
	{
		:biosample_accession => "SAMN00009199",
		:sex => "female",
		:population_code => "HG01242"
	},
	:HG01241 =>
	{
		:biosample_accession => "SAMN00009198",
		:sex => "male",
		:population_code => "HG01241"
	},
	:HG01205 =>
	{
		:biosample_accession => "SAMN00009196",
		:sex => "female",
		:population_code => "HG01205"
	},
	:HG01204 =>
	{
		:biosample_accession => "SAMN00009195",
		:sex => "male",
		:population_code => "HG01204"
	},
	:HG01198 =>
	{
		:biosample_accession => "SAMN00009193",
		:sex => "female",
		:population_code => "HG01198"
	},
	:HG01197 =>
	{
		:biosample_accession => "SAMN00009192",
		:sex => "male",
		:population_code => "HG01197"
	},
	:HG01191 =>
	{
		:biosample_accession => "SAMN00009190",
		:sex => "female",
		:population_code => "HG01191"
	},
	:HG01190 =>
	{
		:biosample_accession => "SAMN00009189",
		:sex => "male",
		:population_code => "HG01190"
	},
	:HG01188 =>
	{
		:biosample_accession => "SAMN00009187",
		:sex => "female",
		:population_code => "HG01188"
	},
	:HG01187 =>
	{
		:biosample_accession => "SAMN00009186",
		:sex => "male",
		:population_code => "HG01187"
	},
	:HG01183 =>
	{
		:biosample_accession => "SAMN00009184",
		:sex => "female",
		:population_code => "HG01183"
	},
	:HG01182 =>
	{
		:biosample_accession => "SAMN00009183",
		:sex => "male",
		:population_code => "HG01182"
	},
	:HG01177 =>
	{
		:biosample_accession => "SAMN00009178",
		:sex => "female",
		:population_code => "HG01177"
	},
	:HG01176 =>
	{
		:biosample_accession => "SAMN00009177",
		:sex => "male",
		:population_code => "HG01176"
	},
	:HG01174 =>
	{
		:biosample_accession => "SAMN00009175",
		:sex => "female",
		:population_code => "HG01174"
	},
	:HG01173 =>
	{
		:biosample_accession => "SAMN00009174",
		:sex => "male",
		:population_code => "HG01173"
	},
	:HG01171 =>
	{
		:biosample_accession => "SAMN00009172",
		:sex => "female",
		:population_code => "HG01171"
	},
	:HG01170 =>
	{
		:biosample_accession => "SAMN00009171",
		:sex => "male",
		:population_code => "HG01170"
	},
	:HG01168 =>
	{
		:biosample_accession => "SAMN00009169",
		:sex => "female",
		:population_code => "HG01168"
	},
	:HG01167 =>
	{
		:biosample_accession => "SAMN00009168",
		:sex => "male",
		:population_code => "HG01167"
	},
	:HG01149 =>
	{
		:biosample_accession => "SAMN00009166",
		:sex => "female",
		:population_code => "HG01149"
	},
	:HG01148 =>
	{
		:biosample_accession => "SAMN00009165",
		:sex => "male",
		:population_code => "HG01148"
	},
	:HG01140 =>
	{
		:biosample_accession => "SAMN00009163",
		:sex => "female",
		:population_code => "HG01140"
	},
	:HG01139 =>
	{
		:biosample_accession => "SAMN00009162",
		:sex => "male",
		:population_code => "HG01139"
	},
	:HG01137 =>
	{
		:biosample_accession => "SAMN00009160",
		:sex => "female",
		:population_code => "HG01137"
	},
	:HG01136 =>
	{
		:biosample_accession => "SAMN00009159",
		:sex => "male",
		:population_code => "HG01136"
	},
	:HG01134 =>
	{
		:biosample_accession => "SAMN00009157",
		:sex => "female",
		:population_code => "HG01134"
	},
	:HG01133 =>
	{
		:biosample_accession => "SAMN00009156",
		:sex => "male",
		:population_code => "HG01133"
	},
	:HG01125 =>
	{
		:biosample_accession => "SAMN00009154",
		:sex => "female",
		:population_code => "HG01125"
	},
	:HG01124 =>
	{
		:biosample_accession => "SAMN00009153",
		:sex => "male",
		:population_code => "HG01124"
	},
	:HG01113 =>
	{
		:biosample_accession => "SAMN00009151",
		:sex => "female",
		:population_code => "HG01113"
	},
	:HG01112 =>
	{
		:biosample_accession => "SAMN00009150",
		:sex => "male",
		:population_code => "HG01112"
	},
	:HG01111 =>
	{
		:biosample_accession => "SAMN00009149",
		:sex => "female",
		:population_code => "HG01111"
	},
	:HG01110 =>
	{
		:biosample_accession => "SAMN00009148",
		:sex => "male",
		:population_code => "HG01110"
	},
	:HG01108 =>
	{
		:biosample_accession => "SAMN00009146",
		:sex => "female",
		:population_code => "HG01108"
	},
	:HG01107 =>
	{
		:biosample_accession => "SAMN00009145",
		:sex => "male",
		:population_code => "HG01107"
	},
	:HG01105 =>
	{
		:biosample_accession => "SAMN00009143",
		:sex => "female",
		:population_code => "HG01105"
	},
	:HG01104 =>
	{
		:biosample_accession => "SAMN00009142",
		:sex => "male",
		:population_code => "HG01104"
	},
	:HG01102 =>
	{
		:biosample_accession => "SAMN00009140",
		:sex => "female",
		:population_code => "HG01102"
	},
	:HG01101 =>
	{
		:biosample_accession => "SAMN00009139",
		:sex => "male",
		:population_code => "HG01101"
	},
	:HG01095 =>
	{
		:biosample_accession => "SAMN00009136",
		:sex => "female",
		:population_code => "HG01095"
	},
	:HG01094 =>
	{
		:biosample_accession => "SAMN00009135",
		:sex => "male",
		:population_code => "HG01094"
	},
	:HG01086 =>
	{
		:biosample_accession => "SAMN00009133",
		:sex => "female",
		:population_code => "HG01086"
	},
	:HG01085 =>
	{
		:biosample_accession => "SAMN00009132",
		:sex => "male",
		:population_code => "HG01085"
	},
	:HG01083 =>
	{
		:biosample_accession => "SAMN00009130",
		:sex => "female",
		:population_code => "HG01083"
	},
	:HG01082 =>
	{
		:biosample_accession => "SAMN00009129",
		:sex => "male",
		:population_code => "HG01082"
	},
	:HG01075 =>
	{
		:biosample_accession => "SAMN00009128",
		:sex => "male",
		:population_code => "HG01075"
	},
	:HG01073 =>
	{
		:biosample_accession => "SAMN00009126",
		:sex => "female",
		:population_code => "HG01073"
	},
	:HG01072 =>
	{
		:biosample_accession => "SAMN00009125",
		:sex => "male",
		:population_code => "HG01072"
	},
	:HG01070 =>
	{
		:biosample_accession => "SAMN00009123",
		:sex => "female",
		:population_code => "HG01070"
	},
	:HG01069 =>
	{
		:biosample_accession => "SAMN00009122",
		:sex => "male",
		:population_code => "HG01069"
	},
	:HG01061 =>
	{
		:biosample_accession => "SAMN00009120",
		:sex => "female",
		:population_code => "HG01061"
	},
	:HG01060 =>
	{
		:biosample_accession => "SAMN00009119",
		:sex => "male",
		:population_code => "HG01060"
	},
	:HG01052 =>
	{
		:biosample_accession => "SAMN00009117",
		:sex => "female",
		:population_code => "HG01052"
	},
	:HG01051 =>
	{
		:biosample_accession => "SAMN00009116",
		:sex => "male",
		:population_code => "HG01051"
	},
	:HG00551 =>
	{
		:biosample_accession => "SAMN00009114",
		:sex => "female",
		:population_code => "HG00551"
	},
	:HG00383 =>
	{
		:biosample_accession => "SAMN00009113",
		:sex => "female",
		:population_code => "HG00383"
	},
	:HG00341 =>
	{
		:biosample_accession => "SAMN00009112",
		:sex => "male",
		:population_code => "HG00341"
	},
	:HG00334 =>
	{
		:biosample_accession => "SAMN00009111",
		:sex => "female",
		:population_code => "HG00334"
	},
	:HG00332 =>
	{
		:biosample_accession => "SAMN00009110",
		:sex => "female",
		:population_code => "HG00332"
	},
	:HG00331 =>
	{
		:biosample_accession => "SAMN00009109",
		:sex => "female",
		:population_code => "HG00331"
	},
	:HG00330 =>
	{
		:biosample_accession => "SAMN00009108",
		:sex => "female",
		:population_code => "HG00330"
	},
	:HG00329 =>
	{
		:biosample_accession => "SAMN00009107",
		:sex => "male",
		:population_code => "HG00329"
	},
	:HG00326 =>
	{
		:biosample_accession => "SAMN00009106",
		:sex => "female",
		:population_code => "HG00326"
	},
	:HG00325 =>
	{
		:biosample_accession => "SAMN00009105",
		:sex => "male",
		:population_code => "HG00325"
	},
	:HG00324 =>
	{
		:biosample_accession => "SAMN00009104",
		:sex => "female",
		:population_code => "HG00324"
	},
	:HG00310 =>
	{
		:biosample_accession => "SAMN00009103",
		:sex => "male",
		:population_code => "HG00310"
	},
	:HG00285 =>
	{
		:biosample_accession => "SAMN00009102",
		:sex => "female",
		:population_code => "HG00285"
	},
	:HG00284 =>
	{
		:biosample_accession => "SAMN00009101",
		:sex => "male",
		:population_code => "HG00284"
	},
	:HG00282 =>
	{
		:biosample_accession => "SAMN00009100",
		:sex => "female",
		:population_code => "HG00282"
	},
	:HG00281 =>
	{
		:biosample_accession => "SAMN00009099",
		:sex => "female",
		:population_code => "HG00281"
	},
	:HG00280 =>
	{
		:biosample_accession => "SAMN00009098",
		:sex => "male",
		:population_code => "HG00280"
	},
	:HG00278 =>
	{
		:biosample_accession => "SAMN00009097",
		:sex => "male",
		:population_code => "HG00278"
	},
	:HG00277 =>
	{
		:biosample_accession => "SAMN00009096",
		:sex => "male",
		:population_code => "HG00277"
	},
	:HG00276 =>
	{
		:biosample_accession => "SAMN00009095",
		:sex => "female",
		:population_code => "HG00276"
	},
	:HG00275 =>
	{
		:biosample_accession => "SAMN00009094",
		:sex => "female",
		:population_code => "HG00275"
	},
	:HG00274 =>
	{
		:biosample_accession => "SAMN00009093",
		:sex => "female",
		:population_code => "HG00274"
	},
	:HG00251 =>
	{
		:biosample_accession => "SAMN00009092",
		:sex => "male",
		:population_code => "HG00251"
	},
	:HG00250 =>
	{
		:biosample_accession => "SAMN00009091",
		:sex => "female",
		:population_code => "HG00250"
	},
	:HG00246 =>
	{
		:biosample_accession => "SAMN00009089",
		:sex => "male",
		:population_code => "HG00246"
	},
	:HG00154 =>
	{
		:biosample_accession => "SAMN00009088",
		:sex => "female",
		:population_code => "HG00154"
	},
	:NA21144 =>
	{
		:biosample_accession => "SAMN00007979",
		:sex => "female",
		:population_code => "NA21144"
	},
	:NA21143 =>
	{
		:biosample_accession => "SAMN00007978",
		:sex => "female",
		:population_code => "NA21143"
	},
	:NA21142 =>
	{
		:biosample_accession => "SAMN00007977",
		:sex => "female",
		:population_code => "NA21142"
	},
	:NA21141 =>
	{
		:biosample_accession => "SAMN00007976",
		:sex => "female",
		:population_code => "NA21141"
	},
	:NA21137 =>
	{
		:biosample_accession => "SAMN00007975",
		:sex => "female",
		:population_code => "NA21137"
	},
	:NA21135 =>
	{
		:biosample_accession => "SAMN00007974",
		:sex => "male",
		:population_code => "NA21135"
	},
	:NA21133 =>
	{
		:biosample_accession => "SAMN00007973",
		:sex => "male",
		:population_code => "NA21133"
	},
	:NA21130 =>
	{
		:biosample_accession => "SAMN00007972",
		:sex => "male",
		:population_code => "NA21130"
	},
	:NA21128 =>
	{
		:biosample_accession => "SAMN00007971",
		:sex => "male",
		:population_code => "NA21128"
	},
	:NA21127 =>
	{
		:biosample_accession => "SAMN00007970",
		:sex => "male",
		:population_code => "NA21127"
	},
	:NA21125 =>
	{
		:biosample_accession => "SAMN00007969",
		:sex => "female",
		:population_code => "NA21125"
	},
	:NA21123 =>
	{
		:biosample_accession => "SAMN00007968",
		:sex => "male",
		:population_code => "NA21123"
	},
	:NA21122 =>
	{
		:biosample_accession => "SAMN00007967",
		:sex => "female",
		:population_code => "NA21122"
	},
	:GM21121 =>
	{
		:biosample_accession => "SAMN00007966",
		:sex => "female",
		:population_code => "GM21121"
	},
	:NA21120 =>
	{
		:biosample_accession => "SAMN00007965",
		:sex => "female",
		:population_code => "NA21120"
	},
	:NA21119 =>
	{
		:biosample_accession => "SAMN00007964",
		:sex => "male",
		:population_code => "NA21119"
	},
	:NA21118 =>
	{
		:biosample_accession => "SAMN00007963",
		:sex => "male",
		:population_code => "NA21118"
	},
	:NA21117 =>
	{
		:biosample_accession => "SAMN00007962",
		:sex => "male",
		:population_code => "NA21117"
	},
	:NA21116 =>
	{
		:biosample_accession => "SAMN00007961",
		:sex => "male",
		:population_code => "NA21116"
	},
	:NA21115 =>
	{
		:biosample_accession => "SAMN00007960",
		:sex => "male",
		:population_code => "NA21115"
	},
	:NA21113 =>
	{
		:biosample_accession => "SAMN00007959",
		:sex => "male",
		:population_code => "NA21113"
	},
	:NA21112 =>
	{
		:biosample_accession => "SAMN00007958",
		:sex => "male",
		:population_code => "NA21112"
	},
	:NA21111 =>
	{
		:biosample_accession => "SAMN00007957",
		:sex => "male",
		:population_code => "NA21111"
	},
	:NA21110 =>
	{
		:biosample_accession => "SAMN00007956",
		:sex => "female",
		:population_code => "NA21110"
	},
	:NA21109 =>
	{
		:biosample_accession => "SAMN00007955",
		:sex => "male",
		:population_code => "NA21109"
	},
	:NA21108 =>
	{
		:biosample_accession => "SAMN00007954",
		:sex => "female",
		:population_code => "NA21108"
	},
	:NA21107 =>
	{
		:biosample_accession => "SAMN00007953",
		:sex => "male",
		:population_code => "NA21107"
	},
	:NA21106 =>
	{
		:biosample_accession => "SAMN00007952",
		:sex => "female",
		:population_code => "NA21106"
	},
	:NA21105 =>
	{
		:biosample_accession => "SAMN00007951",
		:sex => "male",
		:population_code => "NA21105"
	},
	:NA21104 =>
	{
		:biosample_accession => "SAMN00007950",
		:sex => "male",
		:population_code => "NA21104"
	},
	:NA21103 =>
	{
		:biosample_accession => "SAMN00007949",
		:sex => "female",
		:population_code => "NA21103"
	},
	:NA21102 =>
	{
		:biosample_accession => "SAMN00007948",
		:sex => "female",
		:population_code => "NA21102"
	},
	:NA21101 =>
	{
		:biosample_accession => "SAMN00007947",
		:sex => "female",
		:population_code => "NA21101"
	},
	:NA21100 =>
	{
		:biosample_accession => "SAMN00007946",
		:sex => "male",
		:population_code => "NA21100"
	},
	:NA21099 =>
	{
		:biosample_accession => "SAMN00007945",
		:sex => "male",
		:population_code => "NA21099"
	},
	:NA21098 =>
	{
		:biosample_accession => "SAMN00007944",
		:sex => "male",
		:population_code => "NA21098"
	},
	:NA21097 =>
	{
		:biosample_accession => "SAMN00007943",
		:sex => "female",
		:population_code => "NA21097"
	},
	:NA21094 =>
	{
		:biosample_accession => "SAMN00007942",
		:sex => "male",
		:population_code => "NA21094"
	},
	:NA21092 =>
	{
		:biosample_accession => "SAMN00007941",
		:sex => "male",
		:population_code => "NA21092"
	},
	:NA21091 =>
	{
		:biosample_accession => "SAMN00007940",
		:sex => "male",
		:population_code => "NA21091"
	},
	:NA21090 =>
	{
		:biosample_accession => "SAMN00007939",
		:sex => "male",
		:population_code => "NA21090"
	},
	:NA21089 =>
	{
		:biosample_accession => "SAMN00007938",
		:sex => "female",
		:population_code => "NA21089"
	},
	:NA21088 =>
	{
		:biosample_accession => "SAMN00007937",
		:sex => "female",
		:population_code => "NA21088"
	},
	:NA21086 =>
	{
		:biosample_accession => "SAMN00007936",
		:sex => "female",
		:population_code => "NA21086"
	},
	:NA20911 =>
	{
		:biosample_accession => "SAMN00007935",
		:sex => "male",
		:population_code => "NA20911"
	},
	:NA20910 =>
	{
		:biosample_accession => "SAMN00007934",
		:sex => "female",
		:population_code => "NA20910"
	},
	:NA20908 =>
	{
		:biosample_accession => "SAMN00007932",
		:sex => "female",
		:population_code => "NA20908"
	},
	:NA20906 =>
	{
		:biosample_accession => "SAMN00007930",
		:sex => "female",
		:population_code => "NA20906"
	},
	:NA20904 =>
	{
		:biosample_accession => "SAMN00007929",
		:sex => "male",
		:population_code => "NA20904"
	},
	:NA20903 =>
	{
		:biosample_accession => "SAMN00007928",
		:sex => "male",
		:population_code => "NA20903"
	},
	:NA20902 =>
	{
		:biosample_accession => "SAMN00007927",
		:sex => "female",
		:population_code => "NA20902"
	},
	:NA20901 =>
	{
		:biosample_accession => "SAMN00007926",
		:sex => "male",
		:population_code => "NA20901"
	},
	:NA20900 =>
	{
		:biosample_accession => "SAMN00007925",
		:sex => "female",
		:population_code => "NA20900"
	},
	:NA20899 =>
	{
		:biosample_accession => "SAMN00007924",
		:sex => "female",
		:population_code => "NA20899"
	},
	:NA20898 =>
	{
		:biosample_accession => "SAMN00007923",
		:sex => "male",
		:population_code => "NA20898"
	},
	:NA20897 =>
	{
		:biosample_accession => "SAMN00007922",
		:sex => "male",
		:population_code => "NA20897"
	},
	:NA20896 =>
	{
		:biosample_accession => "SAMN00007921",
		:sex => "female",
		:population_code => "NA20896"
	},
	:NA20895 =>
	{
		:biosample_accession => "SAMN00007920",
		:sex => "male",
		:population_code => "NA20895"
	},
	:NA20894 =>
	{
		:biosample_accession => "SAMN00007919",
		:sex => "female",
		:population_code => "NA20894"
	},
	:NA20893 =>
	{
		:biosample_accession => "SAMN00007918",
		:sex => "female",
		:population_code => "NA20893"
	},
	:NA20892 =>
	{
		:biosample_accession => "SAMN00007917",
		:sex => "female",
		:population_code => "NA20892"
	},
	:NA20891 =>
	{
		:biosample_accession => "SAMN00007916",
		:sex => "male",
		:population_code => "NA20891"
	},
	:NA20890 =>
	{
		:biosample_accession => "SAMN00007915",
		:sex => "male",
		:population_code => "NA20890"
	},
	:NA20889 =>
	{
		:biosample_accession => "SAMN00007914",
		:sex => "male",
		:population_code => "NA20889"
	},
	:NA20888 =>
	{
		:biosample_accession => "SAMN00007913",
		:sex => "female",
		:population_code => "NA20888"
	},
	:NA20887 =>
	{
		:biosample_accession => "SAMN00007912",
		:sex => "male",
		:population_code => "NA20887"
	},
	:NA20886 =>
	{
		:biosample_accession => "SAMN00007911",
		:sex => "female",
		:population_code => "NA20886"
	},
	:NA20885 =>
	{
		:biosample_accession => "SAMN00007910",
		:sex => "male",
		:population_code => "NA20885"
	},
	:NA20884 =>
	{
		:biosample_accession => "SAMN00007909",
		:sex => "male",
		:population_code => "NA20884"
	},
	:GM20883 =>
	{
		:biosample_accession => "SAMN00007908",
		:sex => "male",
		:population_code => "GM20883"
	},
	:NA20882 =>
	{
		:biosample_accession => "SAMN00007907",
		:sex => "female",
		:population_code => "NA20882"
	},
	:NA20881 =>
	{
		:biosample_accession => "SAMN00007906",
		:sex => "female",
		:population_code => "NA20881"
	},
	:NA20878 =>
	{
		:biosample_accession => "SAMN00007904",
		:sex => "female",
		:population_code => "NA20878"
	},
	:NA20877 =>
	{
		:biosample_accession => "SAMN00007903",
		:sex => "female",
		:population_code => "NA20877"
	},
	:NA20876 =>
	{
		:biosample_accession => "SAMN00007902",
		:sex => "female",
		:population_code => "NA20876"
	},
	:NA20875 =>
	{
		:biosample_accession => "SAMN00007901",
		:sex => "female",
		:population_code => "NA20875"
	},
	:NA20874 =>
	{
		:biosample_accession => "SAMN00007900",
		:sex => "female",
		:population_code => "NA20874"
	},
	:GM20873 =>
	{
		:biosample_accession => "SAMN00007899",
		:sex => "male",
		:population_code => "GM20873"
	},
	:NA20872 =>
	{
		:biosample_accession => "SAMN00007898",
		:sex => "female",
		:population_code => "NA20872"
	},
	:NA20871 =>
	{
		:biosample_accession => "SAMN00007897",
		:sex => "male",
		:population_code => "NA20871"
	},
	:NA20870 =>
	{
		:biosample_accession => "SAMN00007896",
		:sex => "male",
		:population_code => "NA20870"
	},
	:NA20869 =>
	{
		:biosample_accession => "SAMN00007895",
		:sex => "female",
		:population_code => "NA20869"
	},
	:NA20866 =>
	{
		:biosample_accession => "SAMN00007894",
		:sex => "male",
		:population_code => "NA20866"
	},
	:NA20862 =>
	{
		:biosample_accession => "SAMN00007893",
		:sex => "female",
		:population_code => "NA20862"
	},
	:NA20861 =>
	{
		:biosample_accession => "SAMN00007892",
		:sex => "male",
		:population_code => "NA20861"
	},
	:NA20859 =>
	{
		:biosample_accession => "SAMN00007891",
		:sex => "female",
		:population_code => "NA20859"
	},
	:NA20858 =>
	{
		:biosample_accession => "SAMN00007890",
		:sex => "male",
		:population_code => "NA20858"
	},
	:NA20856 =>
	{
		:biosample_accession => "SAMN00007889",
		:sex => "female",
		:population_code => "NA20856"
	},
	:NA20854 =>
	{
		:biosample_accession => "SAMN00007888",
		:sex => "female",
		:population_code => "NA20854"
	},
	:NA20853 =>
	{
		:biosample_accession => "SAMN00007887",
		:sex => "female",
		:population_code => "NA20853"
	},
	:NA20852 =>
	{
		:biosample_accession => "SAMN00007886",
		:sex => "male",
		:population_code => "NA20852"
	},
	:NA20851 =>
	{
		:biosample_accession => "SAMN00007885",
		:sex => "female",
		:population_code => "NA20851"
	},
	:NA20850 =>
	{
		:biosample_accession => "SAMN00007884",
		:sex => "male",
		:population_code => "NA20850"
	},
	:NA20849 =>
	{
		:biosample_accession => "SAMN00007883",
		:sex => "female",
		:population_code => "NA20849"
	},
	:NA20847 =>
	{
		:biosample_accession => "SAMN00007882",
		:sex => "female",
		:population_code => "NA20847"
	},
	:NA20846 =>
	{
		:biosample_accession => "SAMN00007881",
		:sex => "male",
		:population_code => "NA20846"
	},
	:NA20845 =>
	{
		:biosample_accession => "SAMN00007880",
		:sex => "male",
		:population_code => "NA20845"
	},
	:NA20363 =>
	{
		:biosample_accession => "SAMN00007878",
		:sex => "female",
		:population_code => "NA20363"
	},
	:NA20359 =>
	{
		:biosample_accession => "SAMN00007876",
		:sex => "female",
		:population_code => "NA20359"
	},
	:NA20357 =>
	{
		:biosample_accession => "SAMN00007874",
		:sex => "female",
		:population_code => "NA20357"
	},
	:NA20356 =>
	{
		:biosample_accession => "SAMN00007873",
		:sex => "male",
		:population_code => "NA20356"
	},
	:NA20348 =>
	{
		:biosample_accession => "SAMN00007870",
		:sex => "male",
		:population_code => "NA20348"
	},
	:NA20346 =>
	{
		:biosample_accession => "SAMN00007868",
		:sex => "male",
		:population_code => "NA20346"
	},
	:NA20344 =>
	{
		:biosample_accession => "SAMN00007866",
		:sex => "female",
		:population_code => "NA20344"
	},
	:NA20342 =>
	{
		:biosample_accession => "SAMN00007864",
		:sex => "male",
		:population_code => "NA20342"
	},
	:NA20341 =>
	{
		:biosample_accession => "SAMN00007863",
		:sex => "female",
		:population_code => "NA20341"
	},
	:NA20340 =>
	{
		:biosample_accession => "SAMN00007862",
		:sex => "male",
		:population_code => "NA20340"
	},
	:NA20336 =>
	{
		:biosample_accession => "SAMN00007860",
		:sex => "female",
		:population_code => "NA20336"
	},
	:NA20334 =>
	{
		:biosample_accession => "SAMN00007858",
		:sex => "female",
		:population_code => "NA20334"
	},
	:NA20332 =>
	{
		:biosample_accession => "SAMN00007856",
		:sex => "female",
		:population_code => "NA20332"
	},
	:NA20322 =>
	{
		:biosample_accession => "SAMN00007855",
		:sex => "female",
		:population_code => "NA20322"
	},
	:NA20317 =>
	{
		:biosample_accession => "SAMN00007853",
		:sex => "female",
		:population_code => "NA20317"
	},
	:NA20314 =>
	{
		:biosample_accession => "SAMN00007851",
		:sex => "female",
		:population_code => "NA20314"
	},
	:NA20299 =>
	{
		:biosample_accession => "SAMN00007847",
		:sex => "female",
		:population_code => "NA20299"
	},
	:NA20296 =>
	{
		:biosample_accession => "SAMN00007845",
		:sex => "female",
		:population_code => "NA20296"
	},
	:NA20294 =>
	{
		:biosample_accession => "SAMN00007843",
		:sex => "female",
		:population_code => "NA20294"
	},
	:NA20291 =>
	{
		:biosample_accession => "SAMN00007841",
		:sex => "male",
		:population_code => "NA20291"
	},
	:NA20289 =>
	{
		:biosample_accession => "SAMN00007839",
		:sex => "female",
		:population_code => "NA20289"
	},
	:NA20287 =>
	{
		:biosample_accession => "SAMN00007837",
		:sex => "female",
		:population_code => "NA20287"
	},
	:NA20282 =>
	{
		:biosample_accession => "SAMN00007835",
		:sex => "female",
		:population_code => "NA20282"
	},
	:NA20281 =>
	{
		:biosample_accession => "SAMN00007834",
		:sex => "male",
		:population_code => "NA20281"
	},
	:NA20278 =>
	{
		:biosample_accession => "SAMN00007832",
		:sex => "male",
		:population_code => "NA20278"
	},
	:NA20276 =>
	{
		:biosample_accession => "SAMN00007830",
		:sex => "female",
		:population_code => "NA20276"
	},
	:NA20127 =>
	{
		:biosample_accession => "SAMN00007827",
		:sex => "female",
		:population_code => "NA20127"
	},
	:NA20126 =>
	{
		:biosample_accession => "SAMN00007826",
		:sex => "male",
		:population_code => "NA20126"
	},
	:NA19985 =>
	{
		:biosample_accession => "SAMN00007825",
		:sex => "female",
		:population_code => "NA19985"
	},
	:NA19982 =>
	{
		:biosample_accession => "SAMN00007823",
		:sex => "male",
		:population_code => "NA19982"
	},
	:NA19921 =>
	{
		:biosample_accession => "SAMN00007822",
		:sex => "female",
		:population_code => "NA19921"
	},
	:NA19920 =>
	{
		:biosample_accession => "SAMN00007821",
		:sex => "male",
		:population_code => "NA19920"
	},
	:NA19917 =>
	{
		:biosample_accession => "SAMN00007818",
		:sex => "female",
		:population_code => "NA19917"
	},
	:NA19916 =>
	{
		:biosample_accession => "SAMN00007817",
		:sex => "male",
		:population_code => "NA19916"
	},
	:NA19914 =>
	{
		:biosample_accession => "SAMN00007815",
		:sex => "female",
		:population_code => "NA19914"
	},
	:NA19909 =>
	{
		:biosample_accession => "SAMN00007814",
		:sex => "female",
		:population_code => "NA19909"
	},
	:NA19908 =>
	{
		:biosample_accession => "SAMN00007813",
		:sex => "male",
		:population_code => "NA19908"
	},
	:NA19904 =>
	{
		:biosample_accession => "SAMN00007812",
		:sex => "male",
		:population_code => "NA19904"
	},
	:NA19901 =>
	{
		:biosample_accession => "SAMN00007810",
		:sex => "female",
		:population_code => "NA19901"
	},
	:NA19900 =>
	{
		:biosample_accession => "SAMN00007809",
		:sex => "male",
		:population_code => "NA19900"
	},
	:NA19835 =>
	{
		:biosample_accession => "SAMN00007807",
		:sex => "female",
		:population_code => "NA19835"
	},
	:NA19834 =>
	{
		:biosample_accession => "SAMN00007806",
		:sex => "male",
		:population_code => "NA19834"
	},
	:NA19819 =>
	{
		:biosample_accession => "SAMN00007804",
		:sex => "female",
		:population_code => "NA19819"
	},
	:NA19818 =>
	{
		:biosample_accession => "SAMN00007803",
		:sex => "male",
		:population_code => "NA19818"
	},
	:NA19795 =>
	{
		:biosample_accession => "SAMN00007801",
		:sex => "male",
		:population_code => "NA19795"
	},
	:NA19794 =>
	{
		:biosample_accession => "SAMN00007800",
		:sex => "female",
		:population_code => "NA19794"
	},
	:NA19789 =>
	{
		:biosample_accession => "SAMN00007798",
		:sex => "male",
		:population_code => "NA19789"
	},
	:NA19788 =>
	{
		:biosample_accession => "SAMN00007797",
		:sex => "female",
		:population_code => "NA19788"
	},
	:NA19786 =>
	{
		:biosample_accession => "SAMN00007795",
		:sex => "male",
		:population_code => "NA19786"
	},
	:NA19785 =>
	{
		:biosample_accession => "SAMN00007794",
		:sex => "female",
		:population_code => "NA19785"
	},
	:NA19783 =>
	{
		:biosample_accession => "SAMN00007792",
		:sex => "male",
		:population_code => "NA19783"
	},
	:NA19782 =>
	{
		:biosample_accession => "SAMN00007791",
		:sex => "female",
		:population_code => "NA19782"
	},
	:NA19780 =>
	{
		:biosample_accession => "SAMN00007789",
		:sex => "male",
		:population_code => "NA19780"
	},
	:NA19779 =>
	{
		:biosample_accession => "SAMN00007788",
		:sex => "female",
		:population_code => "NA19779"
	},
	:NA19777 =>
	{
		:biosample_accession => "SAMN00007786",
		:sex => "male",
		:population_code => "NA19777"
	},
	:NA19776 =>
	{
		:biosample_accession => "SAMN00007785",
		:sex => "female",
		:population_code => "NA19776"
	},
	:NA19774 =>
	{
		:biosample_accession => "SAMN00007783",
		:sex => "male",
		:population_code => "NA19774"
	},
	:NA19773 =>
	{
		:biosample_accession => "SAMN00007782",
		:sex => "female",
		:population_code => "NA19773"
	},
	:NA19771 =>
	{
		:biosample_accession => "SAMN00007780",
		:sex => "male",
		:population_code => "NA19771"
	},
	:NA19770 =>
	{
		:biosample_accession => "SAMN00007779",
		:sex => "female",
		:population_code => "NA19770"
	},
	:NA19762 =>
	{
		:biosample_accession => "SAMN00007777",
		:sex => "male",
		:population_code => "NA19762"
	},
	:NA19761 =>
	{
		:biosample_accession => "SAMN00007776",
		:sex => "female",
		:population_code => "NA19761"
	},
	:NA19759 =>
	{
		:biosample_accession => "SAMN00007774",
		:sex => "male",
		:population_code => "NA19759"
	},
	:NA19758 =>
	{
		:biosample_accession => "SAMN00007773",
		:sex => "female",
		:population_code => "NA19758"
	},
	:NA19756 =>
	{
		:biosample_accession => "SAMN00007771",
		:sex => "male",
		:population_code => "NA19756"
	},
	:NA19755 =>
	{
		:biosample_accession => "SAMN00007770",
		:sex => "female",
		:population_code => "NA19755"
	},
	:NA19750 =>
	{
		:biosample_accession => "SAMN00007768",
		:sex => "male",
		:population_code => "NA19750"
	},
	:NA19749 =>
	{
		:biosample_accession => "SAMN00007767",
		:sex => "female",
		:population_code => "NA19749"
	},
	:NA19747 =>
	{
		:biosample_accession => "SAMN00007765",
		:sex => "male",
		:population_code => "NA19747"
	},
	:NA19746 =>
	{
		:biosample_accession => "SAMN00007764",
		:sex => "female",
		:population_code => "NA19746"
	},
	:NA19732 =>
	{
		:biosample_accession => "SAMN00007762",
		:sex => "male",
		:population_code => "NA19732"
	},
	:NA19731 =>
	{
		:biosample_accession => "SAMN00007761",
		:sex => "female",
		:population_code => "NA19731"
	},
	:NA19729 =>
	{
		:biosample_accession => "SAMN00007759",
		:sex => "male",
		:population_code => "NA19729"
	},
	:NA19728 =>
	{
		:biosample_accession => "SAMN00007758",
		:sex => "female",
		:population_code => "NA19728"
	},
	:NA19726 =>
	{
		:biosample_accession => "SAMN00007756",
		:sex => "male",
		:population_code => "NA19726"
	},
	:NA19725 =>
	{
		:biosample_accession => "SAMN00007755",
		:sex => "female",
		:population_code => "NA19725"
	},
	:NA19723 =>
	{
		:biosample_accession => "SAMN00007753",
		:sex => "male",
		:population_code => "NA19723"
	},
	:NA19722 =>
	{
		:biosample_accession => "SAMN00007752",
		:sex => "female",
		:population_code => "NA19722"
	},
	:NA19720 =>
	{
		:biosample_accession => "SAMN00007750",
		:sex => "male",
		:population_code => "NA19720"
	},
	:NA19719 =>
	{
		:biosample_accession => "SAMN00007749",
		:sex => "female",
		:population_code => "NA19719"
	},
	:NA19717 =>
	{
		:biosample_accession => "SAMN00007747",
		:sex => "male",
		:population_code => "NA19717"
	},
	:NA19716 =>
	{
		:biosample_accession => "SAMN00007746",
		:sex => "female",
		:population_code => "NA19716"
	},
	:NA19713 =>
	{
		:biosample_accession => "SAMN00007744",
		:sex => "female",
		:population_code => "NA19713"
	},
	:NA19712 =>
	{
		:biosample_accession => "SAMN00007743",
		:sex => "female",
		:population_code => "NA19712"
	},
	:NA19711 =>
	{
		:biosample_accession => "SAMN00007742",
		:sex => "male",
		:population_code => "NA19711"
	},
	:NA19707 =>
	{
		:biosample_accession => "SAMN00007740",
		:sex => "female",
		:population_code => "NA19707"
	},
	:NA19704 =>
	{
		:biosample_accession => "SAMN00007738",
		:sex => "female",
		:population_code => "NA19704"
	},
	:NA19703 =>
	{
		:biosample_accession => "SAMN00007737",
		:sex => "male",
		:population_code => "NA19703"
	},
	:NA19701 =>
	{
		:biosample_accession => "SAMN00007735",
		:sex => "female",
		:population_code => "NA19701"
	},
	:NA19700 =>
	{
		:biosample_accession => "SAMN00007734",
		:sex => "male",
		:population_code => "NA19700"
	},
	:NA19685 =>
	{
		:biosample_accession => "SAMN00007732",
		:sex => "male",
		:population_code => "NA19685"
	},
	:NA19684 =>
	{
		:biosample_accession => "SAMN00007731",
		:sex => "female",
		:population_code => "NA19684"
	},
	:NA19682 =>
	{
		:biosample_accession => "SAMN00007729",
		:sex => "male",
		:population_code => "NA19682"
	},
	:NA19681 =>
	{
		:biosample_accession => "SAMN00007728",
		:sex => "female",
		:population_code => "NA19681"
	},
	:NA19679 =>
	{
		:biosample_accession => "SAMN00007726",
		:sex => "male",
		:population_code => "NA19679"
	},
	:NA19678 =>
	{
		:biosample_accession => "SAMN00007725",
		:sex => "female",
		:population_code => "NA19678"
	},
	:NA19676 =>
	{
		:biosample_accession => "SAMN00007723",
		:sex => "male",
		:population_code => "NA19676"
	},
	:NA19675 =>
	{
		:biosample_accession => "SAMN00007722",
		:sex => "female",
		:population_code => "NA19675"
	},
	:NA19670 =>
	{
		:biosample_accession => "SAMN00007720",
		:sex => "male",
		:population_code => "NA19670"
	},
	:NA19669 =>
	{
		:biosample_accession => "SAMN00007719",
		:sex => "female",
		:population_code => "NA19669"
	},
	:NA19664 =>
	{
		:biosample_accession => "SAMN00007717",
		:sex => "male",
		:population_code => "NA19664"
	},
	:NA19663 =>
	{
		:biosample_accession => "SAMN00007716",
		:sex => "female",
		:population_code => "NA19663"
	},
	:NA19661 =>
	{
		:biosample_accession => "SAMN00007714",
		:sex => "male",
		:population_code => "NA19661"
	},
	:NA19660 =>
	{
		:biosample_accession => "SAMN00007713",
		:sex => "female",
		:population_code => "NA19660"
	},
	:NA19658 =>
	{
		:biosample_accession => "SAMN00007711",
		:sex => "male",
		:population_code => "NA19658"
	},
	:NA19657 =>
	{
		:biosample_accession => "SAMN00007710",
		:sex => "female",
		:population_code => "NA19657"
	},
	:NA19655 =>
	{
		:biosample_accession => "SAMN00007708",
		:sex => "male",
		:population_code => "NA19655"
	},
	:NA19654 =>
	{
		:biosample_accession => "SAMN00007707",
		:sex => "female",
		:population_code => "NA19654"
	},
	:NA19652 =>
	{
		:biosample_accession => "SAMN00007705",
		:sex => "male",
		:population_code => "NA19652"
	},
	:NA19651 =>
	{
		:biosample_accession => "SAMN00007704",
		:sex => "female",
		:population_code => "NA19651"
	},
	:NA19649 =>
	{
		:biosample_accession => "SAMN00007702",
		:sex => "male",
		:population_code => "NA19649"
	},
	:NA19648 =>
	{
		:biosample_accession => "SAMN00007701",
		:sex => "female",
		:population_code => "NA19648"
	},
	:NA19625 =>
	{
		:biosample_accession => "SAMN00007700",
		:sex => "female",
		:population_code => "NA19625"
	},
	:GM19258 =>
	{
		:biosample_accession => "SAMN00007699",
		:sex => "male",
		:population_code => "GM19258"
	},
	:GM19249 =>
	{
		:biosample_accession => "SAMN00007697",
		:sex => "male",
		:population_code => "GM19249"
	},
	:GM19221 =>
	{
		:biosample_accession => "SAMN00007693",
		:sex => "female",
		:population_code => "GM19221"
	},
	:GM19211 =>
	{
		:biosample_accession => "SAMN00007691",
		:sex => "male",
		:population_code => "GM19211"
	},
	:GM19202 =>
	{
		:biosample_accession => "SAMN00007687",
		:sex => "female",
		:population_code => "GM19202"
	},
	:GM19191 =>
	{
		:biosample_accession => "SAMN00007682",
		:sex => "male",
		:population_code => "GM19191"
	},
	:GM19186 =>
	{
		:biosample_accession => "SAMN00007681",
		:sex => "male",
		:population_code => "GM19186"
	},
	:GM19174 =>
	{
		:biosample_accession => "SAMN00007675",
		:sex => "male",
		:population_code => "GM19174"
	},
	:GM19173 =>
	{
		:biosample_accession => "SAMN00007674",
		:sex => "male",
		:population_code => "GM19173"
	},
	:GM19161 =>
	{
		:biosample_accession => "SAMN00007673",
		:sex => "male",
		:population_code => "GM19161"
	},
	:GM19154 =>
	{
		:biosample_accession => "SAMN00007672",
		:sex => "male",
		:population_code => "GM19154"
	},
	:GM19148 =>
	{
		:biosample_accession => "SAMN00007670",
		:sex => "female",
		:population_code => "GM19148"
	},
	:GM19145 =>
	{
		:biosample_accession => "SAMN00007669",
		:sex => "male",
		:population_code => "GM19145"
	},
	:GM19139 =>
	{
		:biosample_accession => "SAMN00007666",
		:sex => "male",
		:population_code => "GM19139"
	},
	:GM19120 =>
	{
		:biosample_accession => "SAMN00007661",
		:sex => "male",
		:population_code => "GM19120"
	},
	:GM19115 =>
	{
		:biosample_accession => "SAMN00007660",
		:sex => "female",
		:population_code => "GM19115"
	},
	:GM19109 =>
	{
		:biosample_accession => "SAMN00007659",
		:sex => "female",
		:population_code => "GM19109"
	},
	:GM19100 =>
	{
		:biosample_accession => "SAMN00007656",
		:sex => "female",
		:population_code => "GM19100"
	},
	:GM19097 =>
	{
		:biosample_accession => "SAMN00007655",
		:sex => "female",
		:population_code => "GM19097"
	},
	:GM18935 =>
	{
		:biosample_accession => "SAMN00007653",
		:sex => "male",
		:population_code => "GM18935"
	},
	:GM18930 =>
	{
		:biosample_accession => "SAMN00007652",
		:sex => "female",
		:population_code => "GM18930"
	},
	:GM18911 =>
	{
		:biosample_accession => "SAMN00007648",
		:sex => "male",
		:population_code => "GM18911"
	},
	:GM18872 =>
	{
		:biosample_accession => "SAMN00007646",
		:sex => "male",
		:population_code => "GM18872"
	},
	:GM18521 =>
	{
		:biosample_accession => "SAMN00007635",
		:sex => "male",
		:population_code => "GM18521"
	},
	:GM18506 =>
	{
		:biosample_accession => "SAMN00007631",
		:sex => "male",
		:population_code => "GM18506"
	},
	:GM18503 =>
	{
		:biosample_accession => "SAMN00007630",
		:sex => "male",
		:population_code => "GM18503"
	},
	:GM18500 =>
	{
		:biosample_accession => "SAMN00007629",
		:sex => "male",
		:population_code => "GM18500"
	},
	:GM18497 =>
	{
		:biosample_accession => "SAMN00007628",
		:sex => "male",
		:population_code => "GM18497"
	},
	:NA12818 =>
	{
		:biosample_accession => "SAMN00007621",
		:sex => "female",
		:population_code => "NA12818"
	},
	:NA12817 =>
	{
		:biosample_accession => "SAMN00007620",
		:sex => "male",
		:population_code => "NA12817"
	},
	:NA12802 =>
	{
		:biosample_accession => "SAMN00007619",
		:sex => "female",
		:population_code => "NA12802"
	},
	:NA12767 =>
	{
		:biosample_accession => "SAMN00007617",
		:sex => "female",
		:population_code => "NA12767"
	},
	:NA12707 =>
	{
		:biosample_accession => "SAMN00007610",
		:sex => "male",
		:population_code => "NA12707"
	},
	:NA12485 =>
	{
		:biosample_accession => "SAMN00007609",
		:sex => "male",
		:population_code => "NA12485"
	},
	:NA12335 =>
	{
		:biosample_accession => "SAMN00007602",
		:sex => "male",
		:population_code => "NA12335"
	},
	:NA10839 =>
	{
		:biosample_accession => "SAMN00007578",
		:sex => "female",
		:population_code => "NA10839"
	},
	:NA07029 =>
	{
		:biosample_accession => "SAMN00007565",
		:sex => "male",
		:population_code => "NA07029"
	},
	:HG00734 =>
	{
		:biosample_accession => "SAMN00006820",
		:sex => "female",
		:population_code => "HG00734"
	},
	:NA20362 =>
	{
		:biosample_accession => "SAMN00006629",
		:sex => "male",
		:population_code => "NA20362"
	},
	:NA20361 =>
	{
		:biosample_accession => "SAMN00006628",
		:sex => "female",
		:population_code => "NA20361"
	},
	:NA20355 =>
	{
		:biosample_accession => "SAMN00006627",
		:sex => "female",
		:population_code => "NA20355"
	},
	:NA20321 =>
	{
		:biosample_accession => "SAMN00006626",
		:sex => "female",
		:population_code => "NA20321"
	},
	:NA20320 =>
	{
		:biosample_accession => "SAMN00006625",
		:sex => "female",
		:population_code => "NA20320"
	},
	:NA20318 =>
	{
		:biosample_accession => "SAMN00006624",
		:sex => "male",
		:population_code => "NA20318"
	},
	:NA20313 =>
	{
		:biosample_accession => "SAMN00006623",
		:sex => "female",
		:population_code => "NA20313"
	},
	:NA20274 =>
	{
		:biosample_accession => "SAMN00006620",
		:sex => "female",
		:population_code => "NA20274"
	},
	:NA19913 =>
	{
		:biosample_accession => "SAMN00006618",
		:sex => "female",
		:population_code => "NA19913"
	},
	:HG01098 =>
	{
		:biosample_accession => "SAMN00006602",
		:sex => "female",
		:population_code => "HG01098"
	},
	:HG01097 =>
	{
		:biosample_accession => "SAMN00006601",
		:sex => "male",
		:population_code => "HG01097"
	},
	:HG01080 =>
	{
		:biosample_accession => "SAMN00006599",
		:sex => "female",
		:population_code => "HG01080"
	},
	:HG01079 =>
	{
		:biosample_accession => "SAMN00006598",
		:sex => "male",
		:population_code => "HG01079"
	},
	:HG01067 =>
	{
		:biosample_accession => "SAMN00006596",
		:sex => "female",
		:population_code => "HG01067"
	},
	:HG01066 =>
	{
		:biosample_accession => "SAMN00006595",
		:sex => "male",
		:population_code => "HG01066"
	},
	:HG01055 =>
	{
		:biosample_accession => "SAMN00006593",
		:sex => "female",
		:population_code => "HG01055"
	},
	:HG01054 =>
	{
		:biosample_accession => "SAMN00006592",
		:sex => "male",
		:population_code => "HG01054"
	},
	:HG01049 =>
	{
		:biosample_accession => "SAMN00006590",
		:sex => "female",
		:population_code => "HG01049"
	},
	:HG01048 =>
	{
		:biosample_accession => "SAMN00006589",
		:sex => "male",
		:population_code => "HG01048"
	},
	:HG01047 =>
	{
		:biosample_accession => "SAMN00006588",
		:sex => "male",
		:population_code => "HG01047"
	},
	:HG00740 =>
	{
		:biosample_accession => "SAMN00006586",
		:sex => "female",
		:population_code => "HG00740"
	},
	:HG00739 =>
	{
		:biosample_accession => "SAMN00006585",
		:sex => "male",
		:population_code => "HG00739"
	},
	:HG00737 =>
	{
		:biosample_accession => "SAMN00006583",
		:sex => "female",
		:population_code => "HG00737"
	},
	:HG00736 =>
	{
		:biosample_accession => "SAMN00006582",
		:sex => "male",
		:population_code => "HG00736"
	},
	:HG00733 =>
	{
		:biosample_accession => "SAMN00006581",
		:sex => "female",
		:population_code => "HG00733"
	},
	:HG00732 =>
	{
		:biosample_accession => "SAMN00006580",
		:sex => "female",
		:population_code => "HG00732"
	},
	:HG00731 =>
	{
		:biosample_accession => "SAMN00006579",
		:sex => "male",
		:population_code => "HG00731"
	},
	:HG00717 =>
	{
		:biosample_accession => "SAMN00006577",
		:sex => "female",
		:population_code => "HG00717"
	},
	:HG00716 =>
	{
		:biosample_accession => "SAMN00006576",
		:sex => "male",
		:population_code => "HG00716"
	},
	:HG00708 =>
	{
		:biosample_accession => "SAMN00006574",
		:sex => "female",
		:population_code => "HG00708"
	},
	:HG00707 =>
	{
		:biosample_accession => "SAMN00006573",
		:sex => "male",
		:population_code => "HG00707"
	},
	:HG00705 =>
	{
		:biosample_accession => "SAMN00006571",
		:sex => "female",
		:population_code => "HG00705"
	},
	:HG00704 =>
	{
		:biosample_accession => "SAMN00006570",
		:sex => "male",
		:population_code => "HG00704"
	},
	:HG00702 =>
	{
		:biosample_accession => "SAMN00006568",
		:sex => "female",
		:population_code => "HG00702"
	},
	:HG00701 =>
	{
		:biosample_accession => "SAMN00006567",
		:sex => "male",
		:population_code => "HG00701"
	},
	:HG00699 =>
	{
		:biosample_accession => "SAMN00006565",
		:sex => "female",
		:population_code => "HG00699"
	},
	:HG00698 =>
	{
		:biosample_accession => "SAMN00006564",
		:sex => "male",
		:population_code => "HG00698"
	},
	:HG00694 =>
	{
		:biosample_accession => "SAMN00006563",
		:population_code => "HG00694"
	},
	:HG00693 =>
	{
		:biosample_accession => "SAMN00006562",
		:sex => "female",
		:population_code => "HG00693"
	},
	:HG00692 =>
	{
		:biosample_accession => "SAMN00006561",
		:sex => "male",
		:population_code => "HG00692"
	},
	:HG00691 =>
	{
		:biosample_accession => "SAMN00006560",
		:population_code => "HG00691"
	},
	:HG00690 =>
	{
		:biosample_accession => "SAMN00006559",
		:sex => "female",
		:population_code => "HG00690"
	},
	:HG00689 =>
	{
		:biosample_accession => "SAMN00006558",
		:sex => "male",
		:population_code => "HG00689"
	},
	:HG00685 =>
	{
		:biosample_accession => "SAMN00006557",
		:population_code => "HG00685"
	},
	:HG00684 =>
	{
		:biosample_accession => "SAMN00006556",
		:sex => "female",
		:population_code => "HG00684"
	},
	:HG00683 =>
	{
		:biosample_accession => "SAMN00006555",
		:sex => "male",
		:population_code => "HG00683"
	},
	:HG00673 =>
	{
		:biosample_accession => "SAMN00006554",
		:population_code => "HG00673"
	},
	:HG00672 =>
	{
		:biosample_accession => "SAMN00006553",
		:sex => "female",
		:population_code => "HG00672"
	},
	:HG00671 =>
	{
		:biosample_accession => "SAMN00006552",
		:sex => "male",
		:population_code => "HG00671"
	},
	:HG00664 =>
	{
		:biosample_accession => "SAMN00006551",
		:population_code => "HG00664"
	},
	:HG00663 =>
	{
		:biosample_accession => "SAMN00006550",
		:sex => "female",
		:population_code => "HG00663"
	},
	:HG00662 =>
	{
		:biosample_accession => "SAMN00006549",
		:sex => "male",
		:population_code => "HG00662"
	},
	:HG00657 =>
	{
		:biosample_accession => "SAMN00006547",
		:sex => "female",
		:population_code => "HG00657"
	},
	:HG00656 =>
	{
		:biosample_accession => "SAMN00006546",
		:sex => "male",
		:population_code => "HG00656"
	},
	:HG00655 =>
	{
		:biosample_accession => "SAMN00006545",
		:population_code => "HG00655"
	},
	:HG00654 =>
	{
		:biosample_accession => "SAMN00006544",
		:sex => "female",
		:population_code => "HG00654"
	},
	:HG00653 =>
	{
		:biosample_accession => "SAMN00006543",
		:sex => "male",
		:population_code => "HG00653"
	},
	:HG00652 =>
	{
		:biosample_accession => "SAMN00006542",
		:population_code => "HG00652"
	},
	:HG00651 =>
	{
		:biosample_accession => "SAMN00006541",
		:sex => "female",
		:population_code => "HG00651"
	},
	:HG00650 =>
	{
		:biosample_accession => "SAMN00006540",
		:sex => "male",
		:population_code => "HG00650"
	},
	:HG00641 =>
	{
		:biosample_accession => "SAMN00006538",
		:sex => "female",
		:population_code => "HG00641"
	},
	:HG00640 =>
	{
		:biosample_accession => "SAMN00006537",
		:sex => "male",
		:population_code => "HG00640"
	},
	:HG00638 =>
	{
		:biosample_accession => "SAMN00006535",
		:sex => "female",
		:population_code => "HG00638"
	},
	:HG00637 =>
	{
		:biosample_accession => "SAMN00006534",
		:sex => "male",
		:population_code => "HG00637"
	},
	:HG00635 =>
	{
		:biosample_accession => "SAMN00006532",
		:sex => "female",
		:population_code => "HG00635"
	},
	:HG00634 =>
	{
		:biosample_accession => "SAMN00006531",
		:sex => "male",
		:population_code => "HG00634"
	},
	:HG00630 =>
	{
		:biosample_accession => "SAMN00006530",
		:population_code => "HG00630"
	},
	:HG00629 =>
	{
		:biosample_accession => "SAMN00006529",
		:sex => "female",
		:population_code => "HG00629"
	},
	:HG00628 =>
	{
		:biosample_accession => "SAMN00006528",
		:sex => "male",
		:population_code => "HG00628"
	},
	:HG00627 =>
	{
		:biosample_accession => "SAMN00006527",
		:population_code => "HG00627"
	},
	:HG00626 =>
	{
		:biosample_accession => "SAMN00006526",
		:sex => "female",
		:population_code => "HG00626"
	},
	:HG00625 =>
	{
		:biosample_accession => "SAMN00006525",
		:sex => "male",
		:population_code => "HG00625"
	},
	:HG00621 =>
	{
		:biosample_accession => "SAMN00006524",
		:population_code => "HG00621"
	},
	:HG00620 =>
	{
		:biosample_accession => "SAMN00006523",
		:sex => "female",
		:population_code => "HG00620"
	},
	:HG00619 =>
	{
		:biosample_accession => "SAMN00006522",
		:sex => "male",
		:population_code => "HG00619"
	},
	:HG00615 =>
	{
		:biosample_accession => "SAMN00006521",
		:population_code => "HG00615"
	},
	:HG00614 =>
	{
		:biosample_accession => "SAMN00006520",
		:sex => "female",
		:population_code => "HG00614"
	},
	:HG00613 =>
	{
		:biosample_accession => "SAMN00006519",
		:sex => "male",
		:population_code => "HG00613"
	},
	:HG00612 =>
	{
		:biosample_accession => "SAMN00006518",
		:population_code => "HG00612"
	},
	:HG00611 =>
	{
		:biosample_accession => "SAMN00006517",
		:sex => "female",
		:population_code => "HG00611"
	},
	:HG00610 =>
	{
		:biosample_accession => "SAMN00006516",
		:sex => "male",
		:population_code => "HG00610"
	},
	:HG00609 =>
	{
		:biosample_accession => "SAMN00006515",
		:population_code => "HG00609"
	},
	:HG00608 =>
	{
		:biosample_accession => "SAMN00006514",
		:sex => "female",
		:population_code => "HG00608"
	},
	:HG00607 =>
	{
		:biosample_accession => "SAMN00006513",
		:sex => "male",
		:population_code => "HG00607"
	},
	:HG00596 =>
	{
		:biosample_accession => "SAMN00006511",
		:sex => "female",
		:population_code => "HG00596"
	},
	:HG00595 =>
	{
		:biosample_accession => "SAMN00006510",
		:sex => "male",
		:population_code => "HG00595"
	},
	:HG00594 =>
	{
		:biosample_accession => "SAMN00006509",
		:population_code => "HG00594"
	},
	:HG00593 =>
	{
		:biosample_accession => "SAMN00006508",
		:sex => "female",
		:population_code => "HG00593"
	},
	:HG00592 =>
	{
		:biosample_accession => "SAMN00006507",
		:sex => "male",
		:population_code => "HG00592"
	},
	:HG00591 =>
	{
		:biosample_accession => "SAMN00006506",
		:population_code => "HG00591"
	},
	:HG00590 =>
	{
		:biosample_accession => "SAMN00006505",
		:sex => "female",
		:population_code => "HG00590"
	},
	:HG00589 =>
	{
		:biosample_accession => "SAMN00006504",
		:sex => "male",
		:population_code => "HG00589"
	},
	:HG00584 =>
	{
		:biosample_accession => "SAMN00006502",
		:sex => "female",
		:population_code => "HG00584"
	},
	:HG00583 =>
	{
		:biosample_accession => "SAMN00006501",
		:sex => "male",
		:population_code => "HG00583"
	},
	:HG00581 =>
	{
		:biosample_accession => "SAMN00006499",
		:sex => "female",
		:population_code => "HG00581"
	},
	:HG00580 =>
	{
		:biosample_accession => "SAMN00006498",
		:sex => "male",
		:population_code => "HG00580"
	},
	:HG00578 =>
	{
		:biosample_accession => "SAMN00006496",
		:sex => "female",
		:population_code => "HG00578"
	},
	:HG00577 =>
	{
		:biosample_accession => "SAMN00006495",
		:sex => "male",
		:population_code => "HG00577"
	},
	:HG00566 =>
	{
		:biosample_accession => "SAMN00006493",
		:sex => "female",
		:population_code => "HG00566"
	},
	:HG00565 =>
	{
		:biosample_accession => "SAMN00006492",
		:sex => "male",
		:population_code => "HG00565"
	},
	:HG00561 =>
	{
		:biosample_accession => "SAMN00006491",
		:population_code => "HG00561"
	},
	:HG00560 =>
	{
		:biosample_accession => "SAMN00006490",
		:sex => "female",
		:population_code => "HG00560"
	},
	:HG00559 =>
	{
		:biosample_accession => "SAMN00006489",
		:sex => "male",
		:population_code => "HG00559"
	},
	:HG00558 =>
	{
		:biosample_accession => "SAMN00006488",
		:population_code => "HG00558"
	},
	:HG00557 =>
	{
		:biosample_accession => "SAMN00006487",
		:sex => "female",
		:population_code => "HG00557"
	},
	:HG00556 =>
	{
		:biosample_accession => "SAMN00006486",
		:sex => "male",
		:population_code => "HG00556"
	},
	:HG00554 =>
	{
		:biosample_accession => "SAMN00006484",
		:sex => "female",
		:population_code => "HG00554"
	},
	:HG00553 =>
	{
		:biosample_accession => "SAMN00006483",
		:sex => "male",
		:population_code => "HG00553"
	},
	:HG00544 =>
	{
		:biosample_accession => "SAMN00006482",
		:population_code => "HG00544"
	},
	:HG00543 =>
	{
		:biosample_accession => "SAMN00006481",
		:sex => "female",
		:population_code => "HG00543"
	},
	:HG00542 =>
	{
		:biosample_accession => "SAMN00006480",
		:sex => "male",
		:population_code => "HG00542"
	},
	:HG00538 =>
	{
		:biosample_accession => "SAMN00006479",
		:population_code => "HG00538"
	},
	:HG00537 =>
	{
		:biosample_accession => "SAMN00006478",
		:sex => "female",
		:population_code => "HG00537"
	},
	:HG00536 =>
	{
		:biosample_accession => "SAMN00006477",
		:sex => "male",
		:population_code => "HG00536"
	},
	:HG00535 =>
	{
		:biosample_accession => "SAMN00006476",
		:population_code => "HG00535"
	},
	:HG00534 =>
	{
		:biosample_accession => "SAMN00006475",
		:sex => "female",
		:population_code => "HG00534"
	},
	:HG00533 =>
	{
		:biosample_accession => "SAMN00006474",
		:sex => "male",
		:population_code => "HG00533"
	},
	:HG00532 =>
	{
		:biosample_accession => "SAMN00006473",
		:population_code => "HG00532"
	},
	:HG00531 =>
	{
		:biosample_accession => "SAMN00006472",
		:sex => "female",
		:population_code => "HG00531"
	},
	:HG00530 =>
	{
		:biosample_accession => "SAMN00006471",
		:sex => "male",
		:population_code => "HG00530"
	},
	:HG00525 =>
	{
		:biosample_accession => "SAMN00006469",
		:sex => "female",
		:population_code => "HG00525"
	},
	:HG00524 =>
	{
		:biosample_accession => "SAMN00006468",
		:sex => "male",
		:population_code => "HG00524"
	},
	:HG00513 =>
	{
		:biosample_accession => "SAMN00006466",
		:sex => "female",
		:population_code => "HG00513"
	},
	:HG00512 =>
	{
		:biosample_accession => "SAMN00006465",
		:sex => "male",
		:population_code => "HG00512"
	},
	:HG00501 =>
	{
		:biosample_accession => "SAMN00006463",
		:sex => "female",
		:population_code => "HG00501"
	},
	:HG00500 =>
	{
		:biosample_accession => "SAMN00006462",
		:sex => "male",
		:population_code => "HG00500"
	},
	:HG00480 =>
	{
		:biosample_accession => "SAMN00006461",
		:population_code => "HG00480"
	},
	:HG00479 =>
	{
		:biosample_accession => "SAMN00006460",
		:sex => "female",
		:population_code => "HG00479"
	},
	:HG00478 =>
	{
		:biosample_accession => "SAMN00006459",
		:sex => "male",
		:population_code => "HG00478"
	},
	:HG00477 =>
	{
		:biosample_accession => "SAMN00006458",
		:population_code => "HG00477"
	},
	:HG00476 =>
	{
		:biosample_accession => "SAMN00006457",
		:sex => "female",
		:population_code => "HG00476"
	},
	:HG00475 =>
	{
		:biosample_accession => "SAMN00006456",
		:sex => "male",
		:population_code => "HG00475"
	},
	:HG00474 =>
	{
		:biosample_accession => "SAMN00006455",
		:population_code => "HG00474"
	},
	:HG00473 =>
	{
		:biosample_accession => "SAMN00006454",
		:sex => "female",
		:population_code => "HG00473"
	},
	:HG00472 =>
	{
		:biosample_accession => "SAMN00006453",
		:sex => "male",
		:population_code => "HG00472"
	},
	:HG00458 =>
	{
		:biosample_accession => "SAMN00006451",
		:sex => "female",
		:population_code => "HG00458"
	},
	:HG00457 =>
	{
		:biosample_accession => "SAMN00006450",
		:sex => "male",
		:population_code => "HG00457"
	},
	:HG00438 =>
	{
		:biosample_accession => "SAMN00006449",
		:population_code => "HG00438"
	},
	:HG00437 =>
	{
		:biosample_accession => "SAMN00006448",
		:sex => "female",
		:population_code => "HG00437"
	},
	:HG00436 =>
	{
		:biosample_accession => "SAMN00006447",
		:sex => "male",
		:population_code => "HG00436"
	},
	:HG00428 =>
	{
		:biosample_accession => "SAMN00006445",
		:sex => "female",
		:population_code => "HG00428"
	},
	:HG00427 =>
	{
		:biosample_accession => "SAMN00006444",
		:sex => "male",
		:population_code => "HG00427"
	},
	:HG00423 =>
	{
		:biosample_accession => "SAMN00006443",
		:population_code => "HG00423"
	},
	:HG00422 =>
	{
		:biosample_accession => "SAMN00006442",
		:sex => "female",
		:population_code => "HG00422"
	},
	:HG00421 =>
	{
		:biosample_accession => "SAMN00006441",
		:sex => "male",
		:population_code => "HG00421"
	},
	:HG00419 =>
	{
		:biosample_accession => "SAMN00006439",
		:sex => "female",
		:population_code => "HG00419"
	},
	:HG00418 =>
	{
		:biosample_accession => "SAMN00006438",
		:sex => "male",
		:population_code => "HG00418"
	},
	:HG00408 =>
	{
		:biosample_accession => "SAMN00006437",
		:population_code => "HG00408"
	},
	:HG00407 =>
	{
		:biosample_accession => "SAMN00006436",
		:sex => "female",
		:population_code => "HG00407"
	},
	:HG00406 =>
	{
		:biosample_accession => "SAMN00006435",
		:sex => "male",
		:population_code => "HG00406"
	},
	:HG00405 =>
	{
		:biosample_accession => "SAMN00006434",
		:population_code => "HG00405"
	},
	:HG00404 =>
	{
		:biosample_accession => "SAMN00006433",
		:sex => "female",
		:population_code => "HG00404"
	},
	:HG00403 =>
	{
		:biosample_accession => "SAMN00006432",
		:sex => "male",
		:population_code => "HG00403"
	},
	:HG00384 =>
	{
		:biosample_accession => "SAMN00006431",
		:sex => "female",
		:population_code => "HG00384"
	},
	:HG00382 =>
	{
		:biosample_accession => "SAMN00006430",
		:sex => "male",
		:population_code => "HG00382"
	},
	:HG00381 =>
	{
		:biosample_accession => "SAMN00006429",
		:sex => "female",
		:population_code => "HG00381"
	},
	:HG00380 =>
	{
		:biosample_accession => "SAMN00006428",
		:sex => "female",
		:population_code => "HG00380"
	},
	:HG00379 =>
	{
		:biosample_accession => "SAMN00006427",
		:sex => "female",
		:population_code => "HG00379"
	},
	:HG00378 =>
	{
		:biosample_accession => "SAMN00006426",
		:sex => "female",
		:population_code => "HG00378"
	},
	:HG00377 =>
	{
		:biosample_accession => "SAMN00006425",
		:sex => "female",
		:population_code => "HG00377"
	},
	:HG00376 =>
	{
		:biosample_accession => "SAMN00006424",
		:sex => "female",
		:population_code => "HG00376"
	},
	:HG00375 =>
	{
		:biosample_accession => "SAMN00006423",
		:sex => "male",
		:population_code => "HG00375"
	},
	:HG00373 =>
	{
		:biosample_accession => "SAMN00006422",
		:sex => "female",
		:population_code => "HG00373"
	},
	:HG00372 =>
	{
		:biosample_accession => "SAMN00006421",
		:sex => "male",
		:population_code => "HG00372"
	},
	:HG00371 =>
	{
		:biosample_accession => "SAMN00006420",
		:sex => "male",
		:population_code => "HG00371"
	},
	:HG00369 =>
	{
		:biosample_accession => "SAMN00006419",
		:sex => "male",
		:population_code => "HG00369"
	},
	:HG00368 =>
	{
		:biosample_accession => "SAMN00006418",
		:sex => "female",
		:population_code => "HG00368"
	},
	:HG00367 =>
	{
		:biosample_accession => "SAMN00006417",
		:sex => "female",
		:population_code => "HG00367"
	},
	:HG00366 =>
	{
		:biosample_accession => "SAMN00006416",
		:sex => "male",
		:population_code => "HG00366"
	},
	:HG00365 =>
	{
		:biosample_accession => "SAMN00006415",
		:sex => "female",
		:population_code => "HG00365"
	},
	:HG00364 =>
	{
		:biosample_accession => "SAMN00006414",
		:sex => "female",
		:population_code => "HG00364"
	},
	:HG00362 =>
	{
		:biosample_accession => "SAMN00006413",
		:sex => "female",
		:population_code => "HG00362"
	},
	:HG00361 =>
	{
		:biosample_accession => "SAMN00006412",
		:sex => "female",
		:population_code => "HG00361"
	},
	:HG00360 =>
	{
		:biosample_accession => "SAMN00006411",
		:sex => "male",
		:population_code => "HG00360"
	},
	:HG00359 =>
	{
		:biosample_accession => "SAMN00006410",
		:sex => "female",
		:population_code => "HG00359"
	},
	:HG00358 =>
	{
		:biosample_accession => "SAMN00006409",
		:sex => "male",
		:population_code => "HG00358"
	},
	:HG00357 =>
	{
		:biosample_accession => "SAMN00006408",
		:sex => "female",
		:population_code => "HG00357"
	},
	:HG00356 =>
	{
		:biosample_accession => "SAMN00006407",
		:sex => "female",
		:population_code => "HG00356"
	},
	:HG00355 =>
	{
		:biosample_accession => "SAMN00006406",
		:sex => "female",
		:population_code => "HG00355"
	},
	:HG00353 =>
	{
		:biosample_accession => "SAMN00006405",
		:sex => "female",
		:population_code => "HG00353"
	},
	:HG00351 =>
	{
		:biosample_accession => "SAMN00006404",
		:sex => "male",
		:population_code => "HG00351"
	},
	:HG00350 =>
	{
		:biosample_accession => "SAMN00006403",
		:sex => "female",
		:population_code => "HG00350"
	},
	:HG00349 =>
	{
		:biosample_accession => "SAMN00006402",
		:sex => "female",
		:population_code => "HG00349"
	},
	:HG00346 =>
	{
		:biosample_accession => "SAMN00006401",
		:sex => "female",
		:population_code => "HG00346"
	},
	:HG00345 =>
	{
		:biosample_accession => "SAMN00006400",
		:sex => "male",
		:population_code => "HG00345"
	},
	:HG00344 =>
	{
		:biosample_accession => "SAMN00006399",
		:sex => "female",
		:population_code => "HG00344"
	},
	:HG00343 =>
	{
		:biosample_accession => "SAMN00006398",
		:sex => "female",
		:population_code => "HG00343"
	},
	:HG00342 =>
	{
		:biosample_accession => "SAMN00006397",
		:sex => "male",
		:population_code => "HG00342"
	},
	:HG00339 =>
	{
		:biosample_accession => "SAMN00006396",
		:sex => "female",
		:population_code => "HG00339"
	},
	:HG00338 =>
	{
		:biosample_accession => "SAMN00006395",
		:sex => "male",
		:population_code => "HG00338"
	},
	:HG00337 =>
	{
		:biosample_accession => "SAMN00006394",
		:sex => "female",
		:population_code => "HG00337"
	},
	:HG00336 =>
	{
		:biosample_accession => "SAMN00006393",
		:sex => "male",
		:population_code => "HG00336"
	},
	:HG00335 =>
	{
		:biosample_accession => "SAMN00006392",
		:sex => "male",
		:population_code => "HG00335"
	},
	:HG00328 =>
	{
		:biosample_accession => "SAMN00006391",
		:sex => "female",
		:population_code => "HG00328"
	},
	:HG00327 =>
	{
		:biosample_accession => "SAMN00006390",
		:sex => "female",
		:population_code => "HG00327"
	},
	:HG00323 =>
	{
		:biosample_accession => "SAMN00006389",
		:sex => "female",
		:population_code => "HG00323"
	},
	:HG00321 =>
	{
		:biosample_accession => "SAMN00006388",
		:sex => "male",
		:population_code => "HG00321"
	},
	:HG00320 =>
	{
		:biosample_accession => "SAMN00006387",
		:sex => "female",
		:population_code => "HG00320"
	},
	:HG00319 =>
	{
		:biosample_accession => "SAMN00006386",
		:sex => "female",
		:population_code => "HG00319"
	},
	:HG00318 =>
	{
		:biosample_accession => "SAMN00006385",
		:sex => "female",
		:population_code => "HG00318"
	},
	:HG00315 =>
	{
		:biosample_accession => "SAMN00006384",
		:sex => "female",
		:population_code => "HG00315"
	},
	:HG00313 =>
	{
		:biosample_accession => "SAMN00006383",
		:sex => "female",
		:population_code => "HG00313"
	},
	:HG00312 =>
	{
		:biosample_accession => "SAMN00006382",
		:sex => "male",
		:population_code => "HG00312"
	},
	:HG00311 =>
	{
		:biosample_accession => "SAMN00006381",
		:sex => "male",
		:population_code => "HG00311"
	},
	:HG00309 =>
	{
		:biosample_accession => "SAMN00006380",
		:sex => "female",
		:population_code => "HG00309"
	},
	:HG00308 =>
	{
		:biosample_accession => "SAMN00006379",
		:sex => "male",
		:population_code => "HG00308"
	},
	:HG00306 =>
	{
		:biosample_accession => "SAMN00006378",
		:sex => "female",
		:population_code => "HG00306"
	},
	:HG00273 =>
	{
		:biosample_accession => "SAMN00006377",
		:sex => "male",
		:population_code => "HG00273"
	},
	:HG00272 =>
	{
		:biosample_accession => "SAMN00006376",
		:sex => "female",
		:population_code => "HG00272"
	},
	:HG00271 =>
	{
		:biosample_accession => "SAMN00006375",
		:sex => "male",
		:population_code => "HG00271"
	},
	:HG00270 =>
	{
		:biosample_accession => "SAMN00006374",
		:sex => "female",
		:population_code => "HG00270"
	},
	:HG00269 =>
	{
		:biosample_accession => "SAMN00006373",
		:sex => "female",
		:population_code => "HG00269"
	},
	:HG00268 =>
	{
		:biosample_accession => "SAMN00006372",
		:sex => "female",
		:population_code => "HG00268"
	},
	:HG00267 =>
	{
		:biosample_accession => "SAMN00006371",
		:sex => "male",
		:population_code => "HG00267"
	},
	:HG00266 =>
	{
		:biosample_accession => "SAMN00006370",
		:sex => "female",
		:population_code => "HG00266"
	},
	:HG00265 =>
	{
		:biosample_accession => "SAMN00006369",
		:sex => "male",
		:population_code => "HG00265"
	},
	:HG00264 =>
	{
		:biosample_accession => "SAMN00006368",
		:sex => "male",
		:population_code => "HG00264"
	},
	:HG00263 =>
	{
		:biosample_accession => "SAMN00006367",
		:sex => "female",
		:population_code => "HG00263"
	},
	:HG00262 =>
	{
		:biosample_accession => "SAMN00006366",
		:sex => "female",
		:population_code => "HG00262"
	},
	:HG00261 =>
	{
		:biosample_accession => "SAMN00006365",
		:sex => "female",
		:population_code => "HG00261"
	},
	:HG00260 =>
	{
		:biosample_accession => "SAMN00006364",
		:sex => "male",
		:population_code => "HG00260"
	},
	:HG00259 =>
	{
		:biosample_accession => "SAMN00006363",
		:sex => "female",
		:population_code => "HG00259"
	},
	:HG00258 =>
	{
		:biosample_accession => "SAMN00006362",
		:sex => "female",
		:population_code => "HG00258"
	},
	:HG00257 =>
	{
		:biosample_accession => "SAMN00006361",
		:sex => "female",
		:population_code => "HG00257"
	},
	:HG00256 =>
	{
		:biosample_accession => "SAMN00006360",
		:sex => "male",
		:population_code => "HG00256"
	},
	:HG00254 =>
	{
		:biosample_accession => "SAMN00006359",
		:sex => "female",
		:population_code => "HG00254"
	},
	:HG00253 =>
	{
		:biosample_accession => "SAMN00006358",
		:sex => "female",
		:population_code => "HG00253"
	},
	:HG00252 =>
	{
		:biosample_accession => "SAMN00006357",
		:sex => "male",
		:population_code => "HG00252"
	},
	:HG00249 =>
	{
		:biosample_accession => "SAMN00006356",
		:sex => "female",
		:population_code => "HG00249"
	},
	:HG00247 =>
	{
		:biosample_accession => "SAMN00006355",
		:sex => "female",
		:population_code => "HG00247"
	},
	:HG00245 =>
	{
		:biosample_accession => "SAMN00006354",
		:sex => "female",
		:population_code => "HG00245"
	},
	:HG00244 =>
	{
		:biosample_accession => "SAMN00006353",
		:sex => "male",
		:population_code => "HG00244"
	},
	:HG00243 =>
	{
		:biosample_accession => "SAMN00006352",
		:sex => "male",
		:population_code => "HG00243"
	},
	:HG00242 =>
	{
		:biosample_accession => "SAMN00006351",
		:sex => "male",
		:population_code => "HG00242"
	},
	:HG00239 =>
	{
		:biosample_accession => "SAMN00006350",
		:sex => "female",
		:population_code => "HG00239"
	},
	:HG00237 =>
	{
		:biosample_accession => "SAMN00006349",
		:sex => "female",
		:population_code => "HG00237"
	},
	:HG00236 =>
	{
		:biosample_accession => "SAMN00006348",
		:sex => "female",
		:population_code => "HG00236"
	},
	:HG00232 =>
	{
		:biosample_accession => "SAMN00006347",
		:sex => "female",
		:population_code => "HG00232"
	},
	:HG00231 =>
	{
		:biosample_accession => "SAMN00006346",
		:sex => "female",
		:population_code => "HG00231"
	},
	:HG00159 =>
	{
		:biosample_accession => "SAMN00006345",
		:sex => "male",
		:population_code => "HG00159"
	},
	:HG00126 =>
	{
		:biosample_accession => "SAMN00006344",
		:sex => "male",
		:population_code => "HG00126"
	},
	:HG00125 =>
	{
		:biosample_accession => "SAMN00006343",
		:sex => "female",
		:population_code => "HG00125"
	},
	:HG00124 =>
	{
		:biosample_accession => "SAMN00006342",
		:sex => "female",
		:population_code => "HG00124"
	},
	:HG00123 =>
	{
		:biosample_accession => "SAMN00006341",
		:sex => "female",
		:population_code => "HG00123"
	},
	:HG00122 =>
	{
		:biosample_accession => "SAMN00006340",
		:sex => "female",
		:population_code => "HG00122"
	},
	:HG00121 =>
	{
		:biosample_accession => "SAMN00006339",
		:sex => "female",
		:population_code => "HG00121"
	},
	:HG00119 =>
	{
		:biosample_accession => "SAMN00006338",
		:sex => "male",
		:population_code => "HG00119"
	},
	:HG00118 =>
	{
		:biosample_accession => "SAMN00006337",
		:sex => "female",
		:population_code => "HG00118"
	},
	:HG00465 =>
	{
		:biosample_accession => "SAMN00004697",
		:population_code => "HG00465"
	},
	:HG00464 =>
	{
		:biosample_accession => "SAMN00004696",
		:sex => "female",
		:population_code => "HG00464"
	},
	:HG00463 =>
	{
		:biosample_accession => "SAMN00004695",
		:sex => "male",
		:population_code => "HG00463"
	},
	:HG00452 =>
	{
		:biosample_accession => "SAMN00004693",
		:sex => "female",
		:population_code => "HG00452"
	},
	:HG00451 =>
	{
		:biosample_accession => "SAMN00004692",
		:sex => "male",
		:population_code => "HG00451"
	},
	:HG00450 =>
	{
		:biosample_accession => "SAMN00004691",
		:population_code => "HG00450"
	},
	:HG00449 =>
	{
		:biosample_accession => "SAMN00004690",
		:sex => "female",
		:population_code => "HG00449"
	},
	:HG00448 =>
	{
		:biosample_accession => "SAMN00004689",
		:sex => "male",
		:population_code => "HG00448"
	},
	:HG00446 =>
	{
		:biosample_accession => "SAMN00004687",
		:sex => "female",
		:population_code => "HG00446"
	},
	:HG00445 =>
	{
		:biosample_accession => "SAMN00004686",
		:sex => "male",
		:population_code => "HG00445"
	},
	:HG00444 =>
	{
		:biosample_accession => "SAMN00004685",
		:population_code => "HG00444"
	},
	:HG00443 =>
	{
		:biosample_accession => "SAMN00004684",
		:sex => "female",
		:population_code => "HG00443"
	},
	:HG00442 =>
	{
		:biosample_accession => "SAMN00004683",
		:sex => "male",
		:population_code => "HG00442"
	},
	:HG00255 =>
	{
		:biosample_accession => "SAMN00004682",
		:sex => "female",
		:population_code => "HG00255"
	},
	:HG00240 =>
	{
		:biosample_accession => "SAMN00004681",
		:sex => "female",
		:population_code => "HG00240"
	},
	:HG00238 =>
	{
		:biosample_accession => "SAMN00004680",
		:sex => "female",
		:population_code => "HG00238"
	},
	:HG00235 =>
	{
		:biosample_accession => "SAMN00004679",
		:sex => "female",
		:population_code => "HG00235"
	},
	:HG00234 =>
	{
		:biosample_accession => "SAMN00004678",
		:sex => "male",
		:population_code => "HG00234"
	},
	:HG00233 =>
	{
		:biosample_accession => "SAMN00004677",
		:sex => "female",
		:population_code => "HG00233"
	},
	:HG00160 =>
	{
		:biosample_accession => "SAMN00004676",
		:sex => "male",
		:population_code => "HG00160"
	},
	:HG00158 =>
	{
		:biosample_accession => "SAMN00004675",
		:sex => "female",
		:population_code => "HG00158"
	},
	:HG00157 =>
	{
		:biosample_accession => "SAMN00004674",
		:sex => "male",
		:population_code => "HG00157"
	},
	:HG00156 =>
	{
		:biosample_accession => "SAMN00004673",
		:sex => "male",
		:population_code => "HG00156"
	},
	:HG00155 =>
	{
		:biosample_accession => "SAMN00004672",
		:sex => "male",
		:population_code => "HG00155"
	},
	:HG00153 =>
	{
		:biosample_accession => "SAMN00004671",
		:sex => "female",
		:population_code => "HG00153"
	},
	:HG00152 =>
	{
		:biosample_accession => "SAMN00004670",
		:sex => "male",
		:population_code => "HG00152"
	},
	:HG00151 =>
	{
		:biosample_accession => "SAMN00004669",
		:sex => "male",
		:population_code => "HG00151"
	},
	:HG00150 =>
	{
		:biosample_accession => "SAMN00004668",
		:sex => "female",
		:population_code => "HG00150"
	},
	:HG00149 =>
	{
		:biosample_accession => "SAMN00004667",
		:sex => "male",
		:population_code => "HG00149"
	},
	:HG00148 =>
	{
		:biosample_accession => "SAMN00004666",
		:sex => "male",
		:population_code => "HG00148"
	},
	:HG00147 =>
	{
		:biosample_accession => "SAMN00004665",
		:sex => "female",
		:population_code => "HG00147"
	},
	:HG00146 =>
	{
		:biosample_accession => "SAMN00004664",
		:sex => "female",
		:population_code => "HG00146"
	},
	:HG00145 =>
	{
		:biosample_accession => "SAMN00004663",
		:sex => "male",
		:population_code => "HG00145"
	},
	:HG00144 =>
	{
		:biosample_accession => "SAMN00004662",
		:sex => "female",
		:population_code => "HG00144"
	},
	:HG00143 =>
	{
		:biosample_accession => "SAMN00004661",
		:sex => "male",
		:population_code => "HG00143"
	},
	:HG00142 =>
	{
		:biosample_accession => "SAMN00004660",
		:sex => "male",
		:population_code => "HG00142"
	},
	:HG00141 =>
	{
		:biosample_accession => "SAMN00004659",
		:sex => "male",
		:population_code => "HG00141"
	},
	:HG00140 =>
	{
		:biosample_accession => "SAMN00004658",
		:sex => "male",
		:population_code => "HG00140"
	},
	:HG00139 =>
	{
		:biosample_accession => "SAMN00004657",
		:sex => "male",
		:population_code => "HG00139"
	},
	:HG00138 =>
	{
		:biosample_accession => "SAMN00004656",
		:sex => "male",
		:population_code => "HG00138"
	},
	:HG00137 =>
	{
		:biosample_accession => "SAMN00004655",
		:sex => "female",
		:population_code => "HG00137"
	},
	:HG00136 =>
	{
		:biosample_accession => "SAMN00004654",
		:sex => "male",
		:population_code => "HG00136"
	},
	:HG00135 =>
	{
		:biosample_accession => "SAMN00004653",
		:sex => "female",
		:population_code => "HG00135"
	},
	:HG00134 =>
	{
		:biosample_accession => "SAMN00004652",
		:sex => "female",
		:population_code => "HG00134"
	},
	:HG00133 =>
	{
		:biosample_accession => "SAMN00004651",
		:sex => "female",
		:population_code => "HG00133"
	},
	:HG00132 =>
	{
		:biosample_accession => "SAMN00004650",
		:sex => "female",
		:population_code => "HG00132"
	},
	:HG00131 =>
	{
		:biosample_accession => "SAMN00004649",
		:sex => "male",
		:population_code => "HG00131"
	},
	:HG00130 =>
	{
		:biosample_accession => "SAMN00004648",
		:sex => "female",
		:population_code => "HG00130"
	},
	:HG00129 =>
	{
		:biosample_accession => "SAMN00004647",
		:sex => "male",
		:population_code => "HG00129"
	},
	:HG00128 =>
	{
		:biosample_accession => "SAMN00004646",
		:sex => "female",
		:population_code => "HG00128"
	},
	:HG00127 =>
	{
		:biosample_accession => "SAMN00004645",
		:sex => "female",
		:population_code => "HG00127"
	},
	:HG00120 =>
	{
		:biosample_accession => "SAMN00004644",
		:sex => "female",
		:population_code => "HG00120"
	},
	:HG00117 =>
	{
		:biosample_accession => "SAMN00004643",
		:sex => "male",
		:population_code => "HG00117"
	},
	:HG00116 =>
	{
		:biosample_accession => "SAMN00004642",
		:sex => "male",
		:population_code => "HG00116"
	},
	:HG00115 =>
	{
		:biosample_accession => "SAMN00004641",
		:sex => "male",
		:population_code => "HG00115"
	},
	:HG00114 =>
	{
		:biosample_accession => "SAMN00004640",
		:sex => "male",
		:population_code => "HG00114"
	},
	:HG00113 =>
	{
		:biosample_accession => "SAMN00004639",
		:sex => "male",
		:population_code => "HG00113"
	},
	:HG00112 =>
	{
		:biosample_accession => "SAMN00004638",
		:sex => "male",
		:population_code => "HG00112"
	},
	:HG00111 =>
	{
		:biosample_accession => "SAMN00004637",
		:sex => "female",
		:population_code => "HG00111"
	},
	:HG00110 =>
	{
		:biosample_accession => "SAMN00004636",
		:sex => "female",
		:population_code => "HG00110"
	},
	:HG00109 =>
	{
		:biosample_accession => "SAMN00004635",
		:sex => "male",
		:population_code => "HG00109"
	},
	:HG00108 =>
	{
		:biosample_accession => "SAMN00004634",
		:sex => "male",
		:population_code => "HG00108"
	},
	:HG00107 =>
	{
		:biosample_accession => "SAMN00004633",
		:sex => "male",
		:population_code => "HG00107"
	},
	:HG00106 =>
	{
		:biosample_accession => "SAMN00004632",
		:sex => "female",
		:population_code => "HG00106"
	},
	:HG00105 =>
	{
		:biosample_accession => "SAMN00004631",
		:sex => "male",
		:population_code => "HG00105"
	},
	:HG00104 =>
	{
		:biosample_accession => "SAMN00004630",
		:sex => "female",
		:population_code => "HG00104"
	},
	:HG00103 =>
	{
		:biosample_accession => "SAMN00004629",
		:sex => "male",
		:population_code => "HG00103"
	},
	:HG00102 =>
	{
		:biosample_accession => "SAMN00004628",
		:sex => "female",
		:population_code => "HG00102"
	},
	:HG00101 =>
	{
		:biosample_accession => "SAMN00004627",
		:sex => "male",
		:population_code => "HG00101"
	},
	:HG00100 =>
	{
		:biosample_accession => "SAMN00004626",
		:sex => "female",
		:population_code => "HG00100"
	},
	:HG00099 =>
	{
		:biosample_accession => "SAMN00004625",
		:sex => "female",
		:population_code => "HG00099"
	},
	:HG00098 =>
	{
		:biosample_accession => "SAMN00004624",
		:sex => "male",
		:population_code => "HG00098"
	},
	:HG00097 =>
	{
		:biosample_accession => "SAMN00004623",
		:sex => "female",
		:population_code => "HG00097"
	},
	:HG00096 =>
	{
		:biosample_accession => "SAMN00004622",
		:sex => "male",
		:population_code => "HG00096"
	},
	:NA21129 =>
	{
		:biosample_accession => "SAMN00004499",
		:sex => "male",
		:population_code => "NA21129"
	},
	:NA21126 =>
	{
		:biosample_accession => "SAMN00004498",
		:sex => "male",
		:population_code => "NA21126"
	},
	:NA21124 =>
	{
		:biosample_accession => "SAMN00004497",
		:sex => "male",
		:population_code => "NA21124"
	},
	:NA21114 =>
	{
		:biosample_accession => "SAMN00004496",
		:sex => "male",
		:population_code => "NA21114"
	},
	:NA21095 =>
	{
		:biosample_accession => "SAMN00004495",
		:sex => "male",
		:population_code => "NA21095"
	},
	:NA21093 =>
	{
		:biosample_accession => "SAMN00004494",
		:sex => "male",
		:population_code => "NA21093"
	},
	:NA21087 =>
	{
		:biosample_accession => "SAMN00004493",
		:sex => "male",
		:population_code => "NA21087"
	},
	:NA20905 =>
	{
		:biosample_accession => "SAMN00004492",
		:sex => "male",
		:population_code => "NA20905"
	},
	:NA20868 =>
	{
		:biosample_accession => "SAMN00004491",
		:sex => "female",
		:population_code => "NA20868"
	},
	:NA20867 =>
	{
		:biosample_accession => "SAMN00004490",
		:sex => "male",
		:population_code => "NA20867"
	},
	:NA20864 =>
	{
		:biosample_accession => "SAMN00004489",
		:sex => "male",
		:population_code => "NA20864"
	},
	:NA20863 =>
	{
		:biosample_accession => "SAMN00004488",
		:sex => "male",
		:population_code => "NA20863"
	},
	:NA20414 =>
	{
		:biosample_accession => "SAMN00004487",
		:sex => "female",
		:population_code => "NA20414"
	},
	:NA20412 =>
	{
		:biosample_accession => "SAMN00004486",
		:sex => "female",
		:population_code => "NA20412"
	},
	:NA20351 =>
	{
		:biosample_accession => "SAMN00004485",
		:sex => "male",
		:population_code => "NA20351"
	},
	:NA20339 =>
	{
		:biosample_accession => "SAMN00004484",
		:sex => "female",
		:population_code => "NA20339"
	},
	:NA20298 =>
	{
		:biosample_accession => "SAMN00004483",
		:sex => "male",
		:population_code => "NA20298"
	},
	:NA19984 =>
	{
		:biosample_accession => "SAMN00004482",
		:sex => "male",
		:population_code => "NA19984"
	},
	:NA19923 =>
	{
		:biosample_accession => "SAMN00004481",
		:sex => "female",
		:population_code => "NA19923"
	},
	:NA19922 =>
	{
		:biosample_accession => "SAMN00004480",
		:sex => "male",
		:population_code => "NA19922"
	},
	:NA19798 =>
	{
		:biosample_accession => "SAMN00004479",
		:sex => "male",
		:population_code => "NA19798"
	},
	:NA19797 =>
	{
		:biosample_accession => "SAMN00004478",
		:sex => "female",
		:population_code => "NA19797"
	},
	:NA19792 =>
	{
		:biosample_accession => "SAMN00004477",
		:sex => "male",
		:population_code => "NA19792"
	},
	:NA19764 =>
	{
		:biosample_accession => "SAMN00004475",
		:sex => "female",
		:population_code => "NA19764"
	},
	:NA19753 =>
	{
		:biosample_accession => "SAMN00004474",
		:sex => "male",
		:population_code => "NA19753"
	},
	:NA19752 =>
	{
		:biosample_accession => "SAMN00004473",
		:sex => "female",
		:population_code => "NA19752"
	},
	:NA19741 =>
	{
		:biosample_accession => "SAMN00004472",
		:sex => "male",
		:population_code => "NA19741"
	},
	:NA19740 =>
	{
		:biosample_accession => "SAMN00004471",
		:sex => "female",
		:population_code => "NA19740"
	},
	:NA19738 =>
	{
		:biosample_accession => "SAMN00004470",
		:sex => "male",
		:population_code => "NA19738"
	},
	:NA19737 =>
	{
		:biosample_accession => "SAMN00004469",
		:sex => "female",
		:population_code => "NA19737"
	},
	:NA19735 =>
	{
		:biosample_accession => "SAMN00004468",
		:sex => "male",
		:population_code => "NA19735"
	},
	:NA19734 =>
	{
		:biosample_accession => "SAMN00004467",
		:sex => "female",
		:population_code => "NA19734"
	},
	:NA19672 =>
	{
		:biosample_accession => "SAMN00004466",
		:sex => "female",
		:population_code => "NA19672"
	},
	:NA18507 =>
	{
		:biosample_accession => "SAMN00004417",
		:sex => "male",
		:population_code => "NA18507"
	},
	:NA19257 =>
	{
		:biosample_accession => "SAMN00001697",
		:sex => "female",
		:population_code => "NA19257"
	},
	:NA19240 =>
	{
		:biosample_accession => "SAMN00001696",
		:sex => "female",
		:population_code => "NA19240"
	},
	:NA19239 =>
	{
		:biosample_accession => "SAMN00001695",
		:sex => "male",
		:population_code => "NA19239"
	},
	:NA19238 =>
	{
		:biosample_accession => "SAMN00001694",
		:sex => "female",
		:population_code => "NA19238"
	},
	:NA19225 =>
	{
		:biosample_accession => "SAMN00001693",
		:sex => "female",
		:population_code => "NA19225"
	},
	:NA19210 =>
	{
		:biosample_accession => "SAMN00001692",
		:sex => "male",
		:population_code => "NA19210"
	},
	:NA19209 =>
	{
		:biosample_accession => "SAMN00001691",
		:sex => "female",
		:population_code => "NA19209"
	},
	:NA19207 =>
	{
		:biosample_accession => "SAMN00001690",
		:sex => "male",
		:population_code => "NA19207"
	},
	:NA19206 =>
	{
		:biosample_accession => "SAMN00001689",
		:sex => "female",
		:population_code => "NA19206"
	},
	:NA19204 =>
	{
		:biosample_accession => "SAMN00001688",
		:sex => "female",
		:population_code => "NA19204"
	},
	:NA19201 =>
	{
		:biosample_accession => "SAMN00001687",
		:sex => "female",
		:population_code => "NA19201"
	},
	:NA19200 =>
	{
		:biosample_accession => "SAMN00001686",
		:sex => "male",
		:population_code => "NA19200"
	},
	:NA19190 =>
	{
		:biosample_accession => "SAMN00001685",
		:sex => "female",
		:population_code => "NA19190"
	},
	:NA19172 =>
	{
		:biosample_accession => "SAMN00001684",
		:sex => "female",
		:population_code => "NA19172"
	},
	:NA19171 =>
	{
		:biosample_accession => "SAMN00001683",
		:sex => "male",
		:population_code => "NA19171"
	},
	:NA19160 =>
	{
		:biosample_accession => "SAMN00001682",
		:sex => "male",
		:population_code => "NA19160"
	},
	:NA19159 =>
	{
		:biosample_accession => "SAMN00001681",
		:sex => "female",
		:population_code => "NA19159"
	},
	:NA19153 =>
	{
		:biosample_accession => "SAMN00001680",
		:sex => "male",
		:population_code => "NA19153"
	},
	:NA19152 =>
	{
		:biosample_accession => "SAMN00001679",
		:sex => "female",
		:population_code => "NA19152"
	},
	:NA19147 =>
	{
		:biosample_accession => "SAMN00001678",
		:sex => "female",
		:population_code => "NA19147"
	},
	:NA19144 =>
	{
		:biosample_accession => "SAMN00001677",
		:sex => "male",
		:population_code => "NA19144"
	},
	:NA19143 =>
	{
		:biosample_accession => "SAMN00001676",
		:sex => "female",
		:population_code => "NA19143"
	},
	:NA19141 =>
	{
		:biosample_accession => "SAMN00001675",
		:sex => "male",
		:population_code => "NA19141"
	},
	:NA19138 =>
	{
		:biosample_accession => "SAMN00001674",
		:sex => "male",
		:population_code => "NA19138"
	},
	:NA19137 =>
	{
		:biosample_accession => "SAMN00001673",
		:sex => "female",
		:population_code => "NA19137"
	},
	:NA19131 =>
	{
		:biosample_accession => "SAMN00001672",
		:sex => "female",
		:population_code => "NA19131"
	},
	:NA19129 =>
	{
		:biosample_accession => "SAMN00001671",
		:sex => "female",
		:population_code => "NA19129"
	},
	:NA19119 =>
	{
		:biosample_accession => "SAMN00001670",
		:sex => "male",
		:population_code => "NA19119"
	},
	:NA19116 =>
	{
		:biosample_accession => "SAMN00001669",
		:sex => "female",
		:population_code => "NA19116"
	},
	:NA19114 =>
	{
		:biosample_accession => "SAMN00001668",
		:sex => "female",
		:population_code => "NA19114"
	},
	:NA19108 =>
	{
		:biosample_accession => "SAMN00001667",
		:sex => "female",
		:population_code => "NA19108"
	},
	:NA19102 =>
	{
		:biosample_accession => "SAMN00001666",
		:sex => "female",
		:population_code => "NA19102"
	},
	:NA19099 =>
	{
		:biosample_accession => "SAMN00001665",
		:sex => "female",
		:population_code => "NA19099"
	},
	:NA19098 =>
	{
		:biosample_accession => "SAMN00001664",
		:sex => "male",
		:population_code => "NA19098"
	},
	:NA19093 =>
	{
		:biosample_accession => "SAMN00001663",
		:sex => "female",
		:population_code => "NA19093"
	},
	:NA19005 =>
	{
		:biosample_accession => "SAMN00001662",
		:sex => "male",
		:population_code => "NA19005"
	},
	:NA18981 =>
	{
		:biosample_accession => "SAMN00001661",
		:sex => "female",
		:population_code => "NA18981"
	},
	:NA18980 =>
	{
		:biosample_accession => "SAMN00001660",
		:sex => "female",
		:population_code => "NA18980"
	},
	:NA18976 =>
	{
		:biosample_accession => "SAMN00001659",
		:sex => "female",
		:population_code => "NA18976"
	},
	:NA18975 =>
	{
		:biosample_accession => "SAMN00001658",
		:sex => "female",
		:population_code => "NA18975"
	},
	:NA18974 =>
	{
		:biosample_accession => "SAMN00001657",
		:sex => "male",
		:population_code => "NA18974"
	},
	:NA18973 =>
	{
		:biosample_accession => "SAMN00001656",
		:sex => "female",
		:population_code => "NA18973"
	},
	:NA18972 =>
	{
		:biosample_accession => "SAMN00001655",
		:sex => "female",
		:population_code => "NA18972"
	},
	:NA18971 =>
	{
		:biosample_accession => "SAMN00001654",
		:sex => "male",
		:population_code => "NA18971"
	},
	:NA18970 =>
	{
		:biosample_accession => "SAMN00001653",
		:sex => "male",
		:population_code => "NA18970"
	},
	:NA18969 =>
	{
		:biosample_accession => "SAMN00001652",
		:sex => "female",
		:population_code => "NA18969"
	},
	:NA18968 =>
	{
		:biosample_accession => "SAMN00001651",
		:sex => "female",
		:population_code => "NA18968"
	},
	:NA18967 =>
	{
		:biosample_accession => "SAMN00001650",
		:sex => "male",
		:population_code => "NA18967"
	},
	:NA18965 =>
	{
		:biosample_accession => "SAMN00001649",
		:sex => "male",
		:population_code => "NA18965"
	},
	:NA18964 =>
	{
		:biosample_accession => "SAMN00001648",
		:sex => "female",
		:population_code => "NA18964"
	},
	:NA18961 =>
	{
		:biosample_accession => "SAMN00001647",
		:sex => "male",
		:population_code => "NA18961"
	},
	:NA18960 =>
	{
		:biosample_accession => "SAMN00001646",
		:sex => "male",
		:population_code => "NA18960"
	},
	:NA18959 =>
	{
		:biosample_accession => "SAMN00001645",
		:sex => "male",
		:population_code => "NA18959"
	},
	:NA18956 =>
	{
		:biosample_accession => "SAMN00001644",
		:sex => "female",
		:population_code => "NA18956"
	},
	:NA18953 =>
	{
		:biosample_accession => "SAMN00001643",
		:sex => "male",
		:population_code => "NA18953"
	},
	:NA18952 =>
	{
		:biosample_accession => "SAMN00001642",
		:sex => "male",
		:population_code => "NA18952"
	},
	:NA18951 =>
	{
		:biosample_accession => "SAMN00001641",
		:sex => "female",
		:population_code => "NA18951"
	},
	:NA18949 =>
	{
		:biosample_accession => "SAMN00001640",
		:sex => "female",
		:population_code => "NA18949"
	},
	:NA18948 =>
	{
		:biosample_accession => "SAMN00001639",
		:sex => "male",
		:population_code => "NA18948"
	},
	:NA18947 =>
	{
		:biosample_accession => "SAMN00001638",
		:sex => "female",
		:population_code => "NA18947"
	},
	:NA18945 =>
	{
		:biosample_accession => "SAMN00001637",
		:sex => "male",
		:population_code => "NA18945"
	},
	:NA18944 =>
	{
		:biosample_accession => "SAMN00001636",
		:sex => "male",
		:population_code => "NA18944"
	},
	:NA18943 =>
	{
		:biosample_accession => "SAMN00001635",
		:sex => "male",
		:population_code => "NA18943"
	},
	:NA18942 =>
	{
		:biosample_accession => "SAMN00001634",
		:sex => "female",
		:population_code => "NA18942"
	},
	:NA18940 =>
	{
		:biosample_accession => "SAMN00001633",
		:sex => "male",
		:population_code => "NA18940"
	},
	:NA18916 =>
	{
		:biosample_accession => "SAMN00001632",
		:sex => "female",
		:population_code => "NA18916"
	},
	:NA18912 =>
	{
		:biosample_accession => "SAMN00001631",
		:sex => "female",
		:population_code => "NA18912"
	},
	:NA18909 =>
	{
		:biosample_accession => "SAMN00001630",
		:sex => "female",
		:population_code => "NA18909"
	},
	:NA18907 =>
	{
		:biosample_accession => "SAMN00001629",
		:sex => "female",
		:population_code => "NA18907"
	},
	:NA18871 =>
	{
		:biosample_accession => "SAMN00001628",
		:sex => "male",
		:population_code => "NA18871"
	},
	:NA18870 =>
	{
		:biosample_accession => "SAMN00001627",
		:sex => "female",
		:population_code => "NA18870"
	},
	:NA18861 =>
	{
		:biosample_accession => "SAMN00001626",
		:sex => "female",
		:population_code => "NA18861"
	},
	:NA18858 =>
	{
		:biosample_accession => "SAMN00001625",
		:sex => "female",
		:population_code => "NA18858"
	},
	:NA18856 =>
	{
		:biosample_accession => "SAMN00001624",
		:sex => "male",
		:population_code => "NA18856"
	},
	:NA18853 =>
	{
		:biosample_accession => "SAMN00001623",
		:sex => "male",
		:population_code => "NA18853"
	},
	:NA18638 =>
	{
		:biosample_accession => "SAMN00001622",
		:sex => "male",
		:population_code => "NA18638"
	},
	:NA18609 =>
	{
		:biosample_accession => "SAMN00001621",
		:sex => "male",
		:population_code => "NA18609"
	},
	:NA18608 =>
	{
		:biosample_accession => "SAMN00001620",
		:sex => "male",
		:population_code => "NA18608"
	},
	:NA18605 =>
	{
		:biosample_accession => "SAMN00001619",
		:sex => "male",
		:population_code => "NA18605"
	},
	:NA18603 =>
	{
		:biosample_accession => "SAMN00001618",
		:sex => "male",
		:population_code => "NA18603"
	},
	:NA18593 =>
	{
		:biosample_accession => "SAMN00001617",
		:sex => "female",
		:population_code => "NA18593"
	},
	:NA18592 =>
	{
		:biosample_accession => "SAMN00001616",
		:sex => "female",
		:population_code => "NA18592"
	},
	:NA18582 =>
	{
		:biosample_accession => "SAMN00001615",
		:sex => "female",
		:population_code => "NA18582"
	},
	:NA18579 =>
	{
		:biosample_accession => "SAMN00001614",
		:sex => "female",
		:population_code => "NA18579"
	},
	:NA18577 =>
	{
		:biosample_accession => "SAMN00001613",
		:sex => "female",
		:population_code => "NA18577"
	},
	:NA18576 =>
	{
		:biosample_accession => "SAMN00001612",
		:sex => "female",
		:population_code => "NA18576"
	},
	:NA18573 =>
	{
		:biosample_accession => "SAMN00001611",
		:sex => "female",
		:population_code => "NA18573"
	},
	:NA18572 =>
	{
		:biosample_accession => "SAMN00001610",
		:sex => "male",
		:population_code => "NA18572"
	},
	:NA18571 =>
	{
		:biosample_accession => "SAMN00001609",
		:sex => "female",
		:population_code => "NA18571"
	},
	:NA18570 =>
	{
		:biosample_accession => "SAMN00001608",
		:sex => "female",
		:population_code => "NA18570"
	},
	:NA18566 =>
	{
		:biosample_accession => "SAMN00001607",
		:sex => "female",
		:population_code => "NA18566"
	},
	:NA18564 =>
	{
		:biosample_accession => "SAMN00001606",
		:sex => "female",
		:population_code => "NA18564"
	},
	:NA18563 =>
	{
		:biosample_accession => "SAMN00001605",
		:sex => "male",
		:population_code => "NA18563"
	},
	:NA18562 =>
	{
		:biosample_accession => "SAMN00001604",
		:sex => "male",
		:population_code => "NA18562"
	},
	:NA18561 =>
	{
		:biosample_accession => "SAMN00001603",
		:sex => "male",
		:population_code => "NA18561"
	},
	:NA18558 =>
	{
		:biosample_accession => "SAMN00001602",
		:sex => "male",
		:population_code => "NA18558"
	},
	:NA18555 =>
	{
		:biosample_accession => "SAMN00001601",
		:sex => "female",
		:population_code => "NA18555"
	},
	:NA18552 =>
	{
		:biosample_accession => "SAMN00001600",
		:sex => "female",
		:population_code => "NA18552"
	},
	:NA18550 =>
	{
		:biosample_accession => "SAMN00001599",
		:sex => "female",
		:population_code => "NA18550"
	},
	:NA18547 =>
	{
		:biosample_accession => "SAMN00001598",
		:sex => "female",
		:population_code => "NA18547"
	},
	:NA18545 =>
	{
		:biosample_accession => "SAMN00001597",
		:sex => "female",
		:population_code => "NA18545"
	},
	:NA18542 =>
	{
		:biosample_accession => "SAMN00001596",
		:sex => "female",
		:population_code => "NA18542"
	},
	:NA18537 =>
	{
		:biosample_accession => "SAMN00001595",
		:sex => "female",
		:population_code => "NA18537"
	},
	:NA18532 =>
	{
		:biosample_accession => "SAMN00001594",
		:sex => "female",
		:population_code => "NA18532"
	},
	:NA18526 =>
	{
		:biosample_accession => "SAMN00001593",
		:sex => "female",
		:population_code => "NA18526"
	},
	:NA18523 =>
	{
		:biosample_accession => "SAMN00001592",
		:sex => "female",
		:population_code => "NA18523"
	},
	:NA18522 =>
	{
		:biosample_accession => "SAMN00001591",
		:sex => "male",
		:population_code => "NA18522"
	},
	:NA18520 =>
	{
		:biosample_accession => "SAMN00001590",
		:sex => "female",
		:population_code => "NA18520"
	},
	:NA18519 =>
	{
		:biosample_accession => "SAMN00001589",
		:sex => "male",
		:population_code => "NA18519"
	},
	:NA18517 =>
	{
		:biosample_accession => "SAMN00001588",
		:sex => "female",
		:population_code => "NA18517"
	},
	:NA18516 =>
	{
		:biosample_accession => "SAMN00001587",
		:sex => "male",
		:population_code => "NA18516"
	},
	:NA18511 =>
	{
		:biosample_accession => "SAMN00001586",
		:sex => "female",
		:population_code => "NA18511"
	},
	:NA18510 =>
	{
		:biosample_accession => "SAMN00001585",
		:sex => "male",
		:population_code => "NA18510"
	},
	:NA18508 =>
	{
		:biosample_accession => "SAMN00001584",
		:sex => "female",
		:population_code => "NA18508"
	},
	:NA18505 =>
	{
		:biosample_accession => "SAMN00001583",
		:sex => "female",
		:population_code => "NA18505"
	},
	:NA18504 =>
	{
		:biosample_accession => "SAMN00001582",
		:sex => "male",
		:population_code => "NA18504"
	},
	:NA18502 =>
	{
		:biosample_accession => "SAMN00001581",
		:sex => "female",
		:population_code => "NA18502"
	},
	:NA18501 =>
	{
		:biosample_accession => "SAMN00001580",
		:sex => "male",
		:population_code => "NA18501"
	},
	:NA18499 =>
	{
		:biosample_accession => "SAMN00001579",
		:sex => "female",
		:population_code => "NA18499"
	},
	:NA18498 =>
	{
		:biosample_accession => "SAMN00001578",
		:sex => "male",
		:population_code => "NA18498"
	},
	:NA18489 =>
	{
		:biosample_accession => "SAMN00001577",
		:sex => "female",
		:population_code => "NA18489"
	},
	:NA18486 =>
	{
		:biosample_accession => "SAMN00001576",
		:sex => "male",
		:population_code => "NA18486"
	},
	:NA19222 =>
	{
		:biosample_accession => "SAMN00001339",
		:sex => "female",
		:population_code => "NA19222"
	},
	:NA20832 =>
	{
		:biosample_accession => "SAMN00001338",
		:sex => "female",
		:population_code => "NA20832"
	},
	:NA20831 =>
	{
		:biosample_accession => "SAMN00001337",
		:population_code => "NA20831"
	},
	:NA20829 =>
	{
		:biosample_accession => "SAMN00001336",
		:population_code => "NA20829"
	},
	:NA20828 =>
	{
		:biosample_accession => "SAMN00001335",
		:sex => "female",
		:population_code => "NA20828"
	},
	:NA20827 =>
	{
		:biosample_accession => "SAMN00001334",
		:sex => "male",
		:population_code => "NA20827"
	},
	:NA20826 =>
	{
		:biosample_accession => "SAMN00001333",
		:sex => "female",
		:population_code => "NA20826"
	},
	:NA20822 =>
	{
		:biosample_accession => "SAMN00001331",
		:sex => "female",
		:population_code => "NA20822"
	},
	:NA20821 =>
	{
		:biosample_accession => "SAMN00001330",
		:sex => "female",
		:population_code => "NA20821"
	},
	:NA20819 =>
	{
		:biosample_accession => "SAMN00001328",
		:sex => "female",
		:population_code => "NA20819"
	},
	:NA20818 =>
	{
		:biosample_accession => "SAMN00001327",
		:sex => "female",
		:population_code => "NA20818"
	},
	:NA20816 =>
	{
		:biosample_accession => "SAMN00001325",
		:sex => "male",
		:population_code => "NA20816"
	},
	:NA20815 =>
	{
		:biosample_accession => "SAMN00001324",
		:sex => "male",
		:population_code => "NA20815"
	},
	:NA20814 =>
	{
		:biosample_accession => "SAMN00001323",
		:sex => "male",
		:population_code => "NA20814"
	},
	:NA20813 =>
	{
		:biosample_accession => "SAMN00001322",
		:sex => "female",
		:population_code => "NA20813"
	},
	:NA20812 =>
	{
		:biosample_accession => "SAMN00001321",
		:sex => "male",
		:population_code => "NA20812"
	},
	:NA20811 =>
	{
		:biosample_accession => "SAMN00001320",
		:sex => "male",
		:population_code => "NA20811"
	},
	:NA20810 =>
	{
		:biosample_accession => "SAMN00001319",
		:sex => "male",
		:population_code => "NA20810"
	},
	:NA20809 =>
	{
		:biosample_accession => "SAMN00001318",
		:sex => "male",
		:population_code => "NA20809"
	},
	:NA20808 =>
	{
		:biosample_accession => "SAMN00001317",
		:sex => "female",
		:population_code => "NA20808"
	},
	:NA20807 =>
	{
		:biosample_accession => "SAMN00001316",
		:sex => "female",
		:population_code => "NA20807"
	},
	:NA20806 =>
	{
		:biosample_accession => "SAMN00001315",
		:sex => "male",
		:population_code => "NA20806"
	},
	:NA20805 =>
	{
		:biosample_accession => "SAMN00001314",
		:sex => "male",
		:population_code => "NA20805"
	},
	:NA20804 =>
	{
		:biosample_accession => "SAMN00001313",
		:sex => "female",
		:population_code => "NA20804"
	},
	:NA20803 =>
	{
		:biosample_accession => "SAMN00001312",
		:sex => "male",
		:population_code => "NA20803"
	},
	:NA20802 =>
	{
		:biosample_accession => "SAMN00001311",
		:sex => "female",
		:population_code => "NA20802"
	},
	:NA20801 =>
	{
		:biosample_accession => "SAMN00001310",
		:sex => "male",
		:population_code => "NA20801"
	},
	:NA20800 =>
	{
		:biosample_accession => "SAMN00001309",
		:sex => "female",
		:population_code => "NA20800"
	},
	:NA20799 =>
	{
		:biosample_accession => "SAMN00001308",
		:sex => "female",
		:population_code => "NA20799"
	},
	:NA20798 =>
	{
		:biosample_accession => "SAMN00001307",
		:sex => "male",
		:population_code => "NA20798"
	},
	:NA20797 =>
	{
		:biosample_accession => "SAMN00001306",
		:sex => "female",
		:population_code => "NA20797"
	},
	:NA20796 =>
	{
		:biosample_accession => "SAMN00001305",
		:sex => "male",
		:population_code => "NA20796"
	},
	:NA20795 =>
	{
		:biosample_accession => "SAMN00001304",
		:sex => "female",
		:population_code => "NA20795"
	},
	:NA20792 =>
	{
		:biosample_accession => "SAMN00001303",
		:sex => "male",
		:population_code => "NA20792"
	},
	:NA20790 =>
	{
		:biosample_accession => "SAMN00001301",
		:sex => "female",
		:population_code => "NA20790"
	},
	:NA20787 =>
	{
		:biosample_accession => "SAMN00001300",
		:sex => "male",
		:population_code => "NA20787"
	},
	:NA20786 =>
	{
		:biosample_accession => "SAMN00001299",
		:sex => "female",
		:population_code => "NA20786"
	},
	:NA20785 =>
	{
		:biosample_accession => "SAMN00001298",
		:sex => "male",
		:population_code => "NA20785"
	},
	:NA20783 =>
	{
		:biosample_accession => "SAMN00001297",
		:sex => "male",
		:population_code => "NA20783"
	},
	:NA20780 =>
	{
		:biosample_accession => "SAMN00001296",
		:population_code => "NA20780"
	},
	:NA20778 =>
	{
		:biosample_accession => "SAMN00001295",
		:sex => "male",
		:population_code => "NA20778"
	},
	:NA20775 =>
	{
		:biosample_accession => "SAMN00001294",
		:sex => "female",
		:population_code => "NA20775"
	},
	:NA20774 =>
	{
		:biosample_accession => "SAMN00001293",
		:sex => "female",
		:population_code => "NA20774"
	},
	:NA20773 =>
	{
		:biosample_accession => "SAMN00001292",
		:sex => "female",
		:population_code => "NA20773"
	},
	:NA20772 =>
	{
		:biosample_accession => "SAMN00001291",
		:sex => "female",
		:population_code => "NA20772"
	},
	:NA20771 =>
	{
		:biosample_accession => "SAMN00001290",
		:sex => "female",
		:population_code => "NA20771"
	},
	:NA20770 =>
	{
		:biosample_accession => "SAMN00001289",
		:sex => "male",
		:population_code => "NA20770"
	},
	:NA20769 =>
	{
		:biosample_accession => "SAMN00001288",
		:sex => "female",
		:population_code => "NA20769"
	},
	:NA20768 =>
	{
		:biosample_accession => "SAMN00001287",
		:sex => "female",
		:population_code => "NA20768"
	},
	:NA20767 =>
	{
		:biosample_accession => "SAMN00001286",
		:sex => "male",
		:population_code => "NA20767"
	},
	:NA20766 =>
	{
		:biosample_accession => "SAMN00001285",
		:sex => "female",
		:population_code => "NA20766"
	},
	:NA20765 =>
	{
		:biosample_accession => "SAMN00001284",
		:sex => "male",
		:population_code => "NA20765"
	},
	:NA20764 =>
	{
		:biosample_accession => "SAMN00001283",
		:sex => "female",
		:population_code => "NA20764"
	},
	:NA20763 =>
	{
		:biosample_accession => "SAMN00001282",
		:sex => "male",
		:population_code => "NA20763"
	},
	:NA20762 =>
	{
		:biosample_accession => "SAMN00001281",
		:sex => "male",
		:population_code => "NA20762"
	},
	:NA20761 =>
	{
		:biosample_accession => "SAMN00001280",
		:sex => "female",
		:population_code => "NA20761"
	},
	:NA20760 =>
	{
		:biosample_accession => "SAMN00001279",
		:sex => "female",
		:population_code => "NA20760"
	},
	:NA20759 =>
	{
		:biosample_accession => "SAMN00001278",
		:sex => "male",
		:population_code => "NA20759"
	},
	:NA20758 =>
	{
		:biosample_accession => "SAMN00001277",
		:sex => "male",
		:population_code => "NA20758"
	},
	:NA20757 =>
	{
		:biosample_accession => "SAMN00001276",
		:sex => "female",
		:population_code => "NA20757"
	},
	:NA20756 =>
	{
		:biosample_accession => "SAMN00001275",
		:sex => "female",
		:population_code => "NA20756"
	},
	:NA20755 =>
	{
		:biosample_accession => "SAMN00001274",
		:sex => "male",
		:population_code => "NA20755"
	},
	:NA20754 =>
	{
		:biosample_accession => "SAMN00001273",
		:sex => "male",
		:population_code => "NA20754"
	},
	:NA20753 =>
	{
		:biosample_accession => "SAMN00001272",
		:sex => "female",
		:population_code => "NA20753"
	},
	:NA20752 =>
	{
		:biosample_accession => "SAMN00001271",
		:sex => "male",
		:population_code => "NA20752"
	},
	:NA20589 =>
	{
		:biosample_accession => "SAMN00001270",
		:sex => "female",
		:population_code => "NA20589"
	},
	:NA20588 =>
	{
		:biosample_accession => "SAMN00001269",
		:sex => "male",
		:population_code => "NA20588"
	},
	:NA20587 =>
	{
		:biosample_accession => "SAMN00001268",
		:sex => "female",
		:population_code => "NA20587"
	},
	:NA20586 =>
	{
		:biosample_accession => "SAMN00001267",
		:sex => "male",
		:population_code => "NA20586"
	},
	:NA20585 =>
	{
		:biosample_accession => "SAMN00001266",
		:sex => "female",
		:population_code => "NA20585"
	},
	:NA20582 =>
	{
		:biosample_accession => "SAMN00001265",
		:sex => "female",
		:population_code => "NA20582"
	},
	:NA20581 =>
	{
		:biosample_accession => "SAMN00001264",
		:sex => "male",
		:population_code => "NA20581"
	},
	:NA20544 =>
	{
		:biosample_accession => "SAMN00001263",
		:sex => "male",
		:population_code => "NA20544"
	},
	:NA20543 =>
	{
		:biosample_accession => "SAMN00001262",
		:sex => "male",
		:population_code => "NA20543"
	},
	:NA20542 =>
	{
		:biosample_accession => "SAMN00001261",
		:sex => "female",
		:population_code => "NA20542"
	},
	:NA20541 =>
	{
		:biosample_accession => "SAMN00001260",
		:sex => "female",
		:population_code => "NA20541"
	},
	:NA20540 =>
	{
		:biosample_accession => "SAMN00001259",
		:sex => "female",
		:population_code => "NA20540"
	},
	:NA20539 =>
	{
		:biosample_accession => "SAMN00001258",
		:sex => "male",
		:population_code => "NA20539"
	},
	:NA20538 =>
	{
		:biosample_accession => "SAMN00001257",
		:sex => "male",
		:population_code => "NA20538"
	},
	:NA20537 =>
	{
		:biosample_accession => "SAMN00001256",
		:sex => "male",
		:population_code => "NA20537"
	},
	:NA20536 =>
	{
		:biosample_accession => "SAMN00001255",
		:sex => "male",
		:population_code => "NA20536"
	},
	:NA20535 =>
	{
		:biosample_accession => "SAMN00001254",
		:sex => "female",
		:population_code => "NA20535"
	},
	:NA20534 =>
	{
		:biosample_accession => "SAMN00001253",
		:sex => "male",
		:population_code => "NA20534"
	},
	:NA20533 =>
	{
		:biosample_accession => "SAMN00001252",
		:sex => "female",
		:population_code => "NA20533"
	},
	:NA20532 =>
	{
		:biosample_accession => "SAMN00001251",
		:sex => "male",
		:population_code => "NA20532"
	},
	:NA20531 =>
	{
		:biosample_accession => "SAMN00001250",
		:sex => "female",
		:population_code => "NA20531"
	},
	:NA20530 =>
	{
		:biosample_accession => "SAMN00001249",
		:sex => "female",
		:population_code => "NA20530"
	},
	:NA20529 =>
	{
		:biosample_accession => "SAMN00001248",
		:sex => "female",
		:population_code => "NA20529"
	},
	:NA20528 =>
	{
		:biosample_accession => "SAMN00001247",
		:sex => "male",
		:population_code => "NA20528"
	},
	:NA20527 =>
	{
		:biosample_accession => "SAMN00001246",
		:sex => "male",
		:population_code => "NA20527"
	},
	:NA20526 =>
	{
		:biosample_accession => "SAMN00001245",
		:sex => "female",
		:population_code => "NA20526"
	},
	:NA20525 =>
	{
		:biosample_accession => "SAMN00001244",
		:sex => "male",
		:population_code => "NA20525"
	},
	:NA20524 =>
	{
		:biosample_accession => "SAMN00001243",
		:sex => "male",
		:population_code => "NA20524"
	},
	:NA20522 =>
	{
		:biosample_accession => "SAMN00001242",
		:sex => "female",
		:population_code => "NA20522"
	},
	:NA20521 =>
	{
		:biosample_accession => "SAMN00001241",
		:sex => "male",
		:population_code => "NA20521"
	},
	:NA20520 =>
	{
		:biosample_accession => "SAMN00001240",
		:sex => "male",
		:population_code => "NA20520"
	},
	:NA20519 =>
	{
		:biosample_accession => "SAMN00001239",
		:sex => "male",
		:population_code => "NA20519"
	},
	:NA20518 =>
	{
		:biosample_accession => "SAMN00001238",
		:sex => "male",
		:population_code => "NA20518"
	},
	:NA20517 =>
	{
		:biosample_accession => "SAMN00001237",
		:sex => "female",
		:population_code => "NA20517"
	},
	:NA20516 =>
	{
		:biosample_accession => "SAMN00001236",
		:sex => "male",
		:population_code => "NA20516"
	},
	:NA20515 =>
	{
		:biosample_accession => "SAMN00001235",
		:sex => "male",
		:population_code => "NA20515"
	},
	:NA20514 =>
	{
		:biosample_accession => "SAMN00001234",
		:sex => "female",
		:population_code => "NA20514"
	},
	:NA20513 =>
	{
		:biosample_accession => "SAMN00001233",
		:sex => "male",
		:population_code => "NA20513"
	},
	:NA20512 =>
	{
		:biosample_accession => "SAMN00001232",
		:sex => "male",
		:population_code => "NA20512"
	},
	:NA20511 =>
	{
		:biosample_accession => "SAMN00001231",
		:sex => "male",
		:population_code => "NA20511"
	},
	:NA20510 =>
	{
		:biosample_accession => "SAMN00001230",
		:sex => "male",
		:population_code => "NA20510"
	},
	:NA20509 =>
	{
		:biosample_accession => "SAMN00001229",
		:sex => "male",
		:population_code => "NA20509"
	},
	:NA20508 =>
	{
		:biosample_accession => "SAMN00001228",
		:sex => "female",
		:population_code => "NA20508"
	},
	:NA20507 =>
	{
		:biosample_accession => "SAMN00001227",
		:sex => "female",
		:population_code => "NA20507"
	},
	:NA20506 =>
	{
		:biosample_accession => "SAMN00001226",
		:sex => "female",
		:population_code => "NA20506"
	},
	:NA20505 =>
	{
		:biosample_accession => "SAMN00001225",
		:sex => "female",
		:population_code => "NA20505"
	},
	:NA20504 =>
	{
		:biosample_accession => "SAMN00001224",
		:sex => "female",
		:population_code => "NA20504"
	},
	:NA20503 =>
	{
		:biosample_accession => "SAMN00001223",
		:sex => "female",
		:population_code => "NA20503"
	},
	:NA20502 =>
	{
		:biosample_accession => "SAMN00001222",
		:sex => "female",
		:population_code => "NA20502"
	},
	:NA19574 =>
	{
		:biosample_accession => "SAMN00001221",
		:population_code => "NA19574"
	},
	:NA19573 =>
	{
		:biosample_accession => "SAMN00001220",
		:population_code => "NA19573"
	},
	:NA19572 =>
	{
		:biosample_accession => "SAMN00001219",
		:population_code => "NA19572"
	},
	:NA19570 =>
	{
		:biosample_accession => "SAMN00001218",
		:population_code => "NA19570"
	},
	:NA19569 =>
	{
		:biosample_accession => "SAMN00001217",
		:population_code => "NA19569"
	},
	:NA19568 =>
	{
		:biosample_accession => "SAMN00001216",
		:population_code => "NA19568"
	},
	:NA19566 =>
	{
		:biosample_accession => "SAMN00001215",
		:population_code => "NA19566"
	},
	:NA19565 =>
	{
		:biosample_accession => "SAMN00001214",
		:population_code => "NA19565"
	},
	:NA19564 =>
	{
		:biosample_accession => "SAMN00001213",
		:population_code => "NA19564"
	},
	:NA19563 =>
	{
		:biosample_accession => "SAMN00001212",
		:population_code => "NA19563"
	},
	:NA19562 =>
	{
		:biosample_accession => "SAMN00001211",
		:population_code => "NA19562"
	},
	:NA19561 =>
	{
		:biosample_accession => "SAMN00001210",
		:population_code => "NA19561"
	},
	:NA19560 =>
	{
		:biosample_accession => "SAMN00001209",
		:population_code => "NA19560"
	},
	:NA19559 =>
	{
		:biosample_accession => "SAMN00001208",
		:population_code => "NA19559"
	},
	:NA19558 =>
	{
		:biosample_accession => "SAMN00001207",
		:population_code => "NA19558"
	},
	:NA19557 =>
	{
		:biosample_accession => "SAMN00001206",
		:population_code => "NA19557"
	},
	:NA19556 =>
	{
		:biosample_accession => "SAMN00001205",
		:population_code => "NA19556"
	},
	:NA19555 =>
	{
		:biosample_accession => "SAMN00001204",
		:population_code => "NA19555"
	},
	:NA19554 =>
	{
		:biosample_accession => "SAMN00001203",
		:population_code => "NA19554"
	},
	:NA19553 =>
	{
		:biosample_accession => "SAMN00001202",
		:population_code => "NA19553"
	},
	:NA19552 =>
	{
		:biosample_accession => "SAMN00001201",
		:population_code => "NA19552"
	},
	:NA19551 =>
	{
		:biosample_accession => "SAMN00001200",
		:population_code => "NA19551"
	},
	:NA19550 =>
	{
		:biosample_accession => "SAMN00001199",
		:population_code => "NA19550"
	},
	:NA19548 =>
	{
		:biosample_accession => "SAMN00001198",
		:population_code => "NA19548"
	},
	:NA19546 =>
	{
		:biosample_accession => "SAMN00001197",
		:population_code => "NA19546"
	},
	:NA19545 =>
	{
		:biosample_accession => "SAMN00001196",
		:population_code => "NA19545"
	},
	:NA19475 =>
	{
		:biosample_accession => "SAMN00001195",
		:sex => "female",
		:population_code => "NA19475"
	},
	:NA19474 =>
	{
		:biosample_accession => "SAMN00001194",
		:sex => "female",
		:population_code => "NA19474"
	},
	:NA19473 =>
	{
		:biosample_accession => "SAMN00001193",
		:sex => "female",
		:population_code => "NA19473"
	},
	:NA19472 =>
	{
		:biosample_accession => "SAMN00001192",
		:sex => "female",
		:population_code => "NA19472"
	},
	:NA19471 =>
	{
		:biosample_accession => "SAMN00001191",
		:sex => "female",
		:population_code => "NA19471"
	},
	:NA19470 =>
	{
		:biosample_accession => "SAMN00001190",
		:sex => "female",
		:population_code => "NA19470"
	},
	:NA19469 =>
	{
		:biosample_accession => "SAMN00001189",
		:sex => "female",
		:population_code => "NA19469"
	},
	:NA19468 =>
	{
		:biosample_accession => "SAMN00001188",
		:sex => "female",
		:population_code => "NA19468"
	},
	:NA19467 =>
	{
		:biosample_accession => "SAMN00001187",
		:sex => "female",
		:population_code => "NA19467"
	},
	:NA19466 =>
	{
		:biosample_accession => "SAMN00001186",
		:sex => "male",
		:population_code => "NA19466"
	},
	:NA19463 =>
	{
		:biosample_accession => "SAMN00001185",
		:sex => "female",
		:population_code => "NA19463"
	},
	:NA19462 =>
	{
		:biosample_accession => "SAMN00001184",
		:sex => "female",
		:population_code => "NA19462"
	},
	:NA19461 =>
	{
		:biosample_accession => "SAMN00001183",
		:sex => "male",
		:population_code => "NA19461"
	},
	:NA19457 =>
	{
		:biosample_accession => "SAMN00001182",
		:sex => "female",
		:population_code => "NA19457"
	},
	:NA19456 =>
	{
		:biosample_accession => "SAMN00001181",
		:sex => "female",
		:population_code => "NA19456"
	},
	:NA19455 =>
	{
		:biosample_accession => "SAMN00001180",
		:sex => "male",
		:population_code => "NA19455"
	},
	:NA19454 =>
	{
		:biosample_accession => "SAMN00001179",
		:sex => "male",
		:population_code => "NA19454"
	},
	:NA19453 =>
	{
		:biosample_accession => "SAMN00001178",
		:sex => "male",
		:population_code => "NA19453"
	},
	:NA19452 =>
	{
		:biosample_accession => "SAMN00001177",
		:sex => "male",
		:population_code => "NA19452"
	},
	:NA19451 =>
	{
		:biosample_accession => "SAMN00001176",
		:sex => "male",
		:population_code => "NA19451"
	},
	:NA19449 =>
	{
		:biosample_accession => "SAMN00001175",
		:sex => "female",
		:population_code => "NA19449"
	},
	:NA19448 =>
	{
		:biosample_accession => "SAMN00001174",
		:sex => "male",
		:population_code => "NA19448"
	},
	:NA19446 =>
	{
		:biosample_accession => "SAMN00001173",
		:sex => "female",
		:population_code => "NA19446"
	},
	:NA19445 =>
	{
		:biosample_accession => "SAMN00001172",
		:sex => "female",
		:population_code => "NA19445"
	},
	:NA19444 =>
	{
		:biosample_accession => "SAMN00001171",
		:sex => "male",
		:population_code => "NA19444"
	},
	:NA19443 =>
	{
		:biosample_accession => "SAMN00001170",
		:sex => "male",
		:population_code => "NA19443"
	},
	:NA19441 =>
	{
		:biosample_accession => "SAMN00001169",
		:population_code => "NA19441"
	},
	:NA19440 =>
	{
		:biosample_accession => "SAMN00001168",
		:sex => "female",
		:population_code => "NA19440"
	},
	:NA19439 =>
	{
		:biosample_accession => "SAMN00001167",
		:sex => "female",
		:population_code => "NA19439"
	},
	:NA19438 =>
	{
		:biosample_accession => "SAMN00001166",
		:sex => "female",
		:population_code => "NA19438"
	},
	:NA19437 =>
	{
		:biosample_accession => "SAMN00001165",
		:sex => "female",
		:population_code => "NA19437"
	},
	:NA19436 =>
	{
		:biosample_accession => "SAMN00001164",
		:sex => "female",
		:population_code => "NA19436"
	},
	:NA19435 =>
	{
		:biosample_accession => "SAMN00001163",
		:sex => "female",
		:population_code => "NA19435"
	},
	:NA19434 =>
	{
		:biosample_accession => "SAMN00001162",
		:sex => "female",
		:population_code => "NA19434"
	},
	:NA19432 =>
	{
		:biosample_accession => "SAMN00001161",
		:population_code => "NA19432"
	},
	:NA19431 =>
	{
		:biosample_accession => "SAMN00001160",
		:sex => "female",
		:population_code => "NA19431"
	},
	:NA19430 =>
	{
		:biosample_accession => "SAMN00001159",
		:sex => "male",
		:population_code => "NA19430"
	},
	:NA19429 =>
	{
		:biosample_accession => "SAMN00001158",
		:sex => "male",
		:population_code => "NA19429"
	},
	:NA19428 =>
	{
		:biosample_accession => "SAMN00001157",
		:sex => "male",
		:population_code => "NA19428"
	},
	:NA19404 =>
	{
		:biosample_accession => "SAMN00001156",
		:sex => "female",
		:population_code => "NA19404"
	},
	:NA19403 =>
	{
		:biosample_accession => "SAMN00001155",
		:sex => "female",
		:population_code => "NA19403"
	},
	:NA19402 =>
	{
		:biosample_accession => "SAMN00001154",
		:population_code => "NA19402"
	},
	:NA19401 =>
	{
		:biosample_accession => "SAMN00001153",
		:sex => "female",
		:population_code => "NA19401"
	},
	:NA19399 =>
	{
		:biosample_accession => "SAMN00001152",
		:sex => "female",
		:population_code => "NA19399"
	},
	:NA19398 =>
	{
		:biosample_accession => "SAMN00001151",
		:sex => "female",
		:population_code => "NA19398"
	},
	:NA19397 =>
	{
		:biosample_accession => "SAMN00001150",
		:sex => "male",
		:population_code => "NA19397"
	},
	:NA19396 =>
	{
		:biosample_accession => "SAMN00001149",
		:sex => "female",
		:population_code => "NA19396"
	},
	:NA19395 =>
	{
		:biosample_accession => "SAMN00001148",
		:sex => "female",
		:population_code => "NA19395"
	},
	:NA19394 =>
	{
		:biosample_accession => "SAMN00001147",
		:sex => "male",
		:population_code => "NA19394"
	},
	:NA19393 =>
	{
		:biosample_accession => "SAMN00001146",
		:sex => "male",
		:population_code => "NA19393"
	},
	:NA19392 =>
	{
		:biosample_accession => "SAMN00001145",
		:population_code => "NA19392"
	},
	:NA19391 =>
	{
		:biosample_accession => "SAMN00001144",
		:sex => "female",
		:population_code => "NA19391"
	},
	:NA19390 =>
	{
		:biosample_accession => "SAMN00001143",
		:sex => "female",
		:population_code => "NA19390"
	},
	:NA19385 =>
	{
		:biosample_accession => "SAMN00001142",
		:sex => "male",
		:population_code => "NA19385"
	},
	:NA19384 =>
	{
		:biosample_accession => "SAMN00001141",
		:sex => "male",
		:population_code => "NA19384"
	},
	:NA19383 =>
	{
		:biosample_accession => "SAMN00001140",
		:sex => "male",
		:population_code => "NA19383"
	},
	:NA19382 =>
	{
		:biosample_accession => "SAMN00001139",
		:sex => "male",
		:population_code => "NA19382"
	},
	:NA19381 =>
	{
		:biosample_accession => "SAMN00001138",
		:sex => "female",
		:population_code => "NA19381"
	},
	:NA19380 =>
	{
		:biosample_accession => "SAMN00001137",
		:sex => "male",
		:population_code => "NA19380"
	},
	:NA19379 =>
	{
		:biosample_accession => "SAMN00001136",
		:sex => "female",
		:population_code => "NA19379"
	},
	:NA19378 =>
	{
		:biosample_accession => "SAMN00001135",
		:sex => "female",
		:population_code => "NA19378"
	},
	:NA19377 =>
	{
		:biosample_accession => "SAMN00001134",
		:sex => "female",
		:population_code => "NA19377"
	},
	:NA19376 =>
	{
		:biosample_accession => "SAMN00001133",
		:sex => "male",
		:population_code => "NA19376"
	},
	:NA19375 =>
	{
		:biosample_accession => "SAMN00001132",
		:sex => "male",
		:population_code => "NA19375"
	},
	:NA19374 =>
	{
		:biosample_accession => "SAMN00001131",
		:sex => "male",
		:population_code => "NA19374"
	},
	:NA19373 =>
	{
		:biosample_accession => "SAMN00001130",
		:sex => "male",
		:population_code => "NA19373"
	},
	:NA19372 =>
	{
		:biosample_accession => "SAMN00001129",
		:sex => "male",
		:population_code => "NA19372"
	},
	:NA19371 =>
	{
		:biosample_accession => "SAMN00001128",
		:sex => "male",
		:population_code => "NA19371"
	},
	:NA19360 =>
	{
		:biosample_accession => "SAMN00001127",
		:sex => "male",
		:population_code => "NA19360"
	},
	:NA19359 =>
	{
		:biosample_accession => "SAMN00001126",
		:sex => "male",
		:population_code => "NA19359"
	},
	:NA19355 =>
	{
		:biosample_accession => "SAMN00001125",
		:sex => "female",
		:population_code => "NA19355"
	},
	:NA19352 =>
	{
		:biosample_accession => "SAMN00001124",
		:sex => "male",
		:population_code => "NA19352"
	},
	:NA19351 =>
	{
		:biosample_accession => "SAMN00001123",
		:sex => "female",
		:population_code => "NA19351"
	},
	:NA19350 =>
	{
		:biosample_accession => "SAMN00001122",
		:sex => "male",
		:population_code => "NA19350"
	},
	:NA19347 =>
	{
		:biosample_accession => "SAMN00001121",
		:sex => "male",
		:population_code => "NA19347"
	},
	:NA19346 =>
	{
		:biosample_accession => "SAMN00001120",
		:sex => "male",
		:population_code => "NA19346"
	},
	:NA19338 =>
	{
		:biosample_accession => "SAMN00001119",
		:sex => "female",
		:population_code => "NA19338"
	},
	:NA19334 =>
	{
		:biosample_accession => "SAMN00001118",
		:sex => "male",
		:population_code => "NA19334"
	},
	:NA19332 =>
	{
		:biosample_accession => "SAMN00001117",
		:sex => "female",
		:population_code => "NA19332"
	},
	:NA19331 =>
	{
		:biosample_accession => "SAMN00001116",
		:sex => "male",
		:population_code => "NA19331"
	},
	:NA19328 =>
	{
		:biosample_accession => "SAMN00001115",
		:sex => "female",
		:population_code => "NA19328"
	},
	:NA19327 =>
	{
		:biosample_accession => "SAMN00001114",
		:sex => "female",
		:population_code => "NA19327"
	},
	:NA19324 =>
	{
		:biosample_accession => "SAMN00001113",
		:sex => "female",
		:population_code => "NA19324"
	},
	:NA19323 =>
	{
		:biosample_accession => "SAMN00001112",
		:sex => "female",
		:population_code => "NA19323"
	},
	:NA19321 =>
	{
		:biosample_accession => "SAMN00001111",
		:sex => "female",
		:population_code => "NA19321"
	},
	:NA19320 =>
	{
		:biosample_accession => "SAMN00001110",
		:sex => "female",
		:population_code => "NA19320"
	},
	:NA19319 =>
	{
		:biosample_accession => "SAMN00001109",
		:sex => "male",
		:population_code => "NA19319"
	},
	:NA19318 =>
	{
		:biosample_accession => "SAMN00001108",
		:sex => "male",
		:population_code => "NA19318"
	},
	:NA19317 =>
	{
		:biosample_accession => "SAMN00001107",
		:sex => "male",
		:population_code => "NA19317"
	},
	:NA19316 =>
	{
		:biosample_accession => "SAMN00001106",
		:sex => "female",
		:population_code => "NA19316"
	},
	:NA19315 =>
	{
		:biosample_accession => "SAMN00001105",
		:sex => "female",
		:population_code => "NA19315"
	},
	:NA19314 =>
	{
		:biosample_accession => "SAMN00001104",
		:sex => "female",
		:population_code => "NA19314"
	},
	:NA19313 =>
	{
		:biosample_accession => "SAMN00001103",
		:sex => "female",
		:population_code => "NA19313"
	},
	:NA19312 =>
	{
		:biosample_accession => "SAMN00001102",
		:sex => "male",
		:population_code => "NA19312"
	},
	:NA19311 =>
	{
		:biosample_accession => "SAMN00001101",
		:sex => "male",
		:population_code => "NA19311"
	},
	:NA19310 =>
	{
		:biosample_accession => "SAMN00001100",
		:sex => "female",
		:population_code => "NA19310"
	},
	:NA19309 =>
	{
		:biosample_accession => "SAMN00001099",
		:sex => "male",
		:population_code => "NA19309"
	},
	:NA19308 =>
	{
		:biosample_accession => "SAMN00001098",
		:sex => "male",
		:population_code => "NA19308"
	},
	:NA19307 =>
	{
		:biosample_accession => "SAMN00001097",
		:sex => "male",
		:population_code => "NA19307"
	},
	:NA19266 =>
	{
		:biosample_accession => "SAMN00001096",
		:population_code => "NA19266"
	},
	:NA19262 =>
	{
		:biosample_accession => "SAMN00001095",
		:population_code => "NA19262"
	},
	:NA19260 =>
	{
		:biosample_accession => "SAMN00001094",
		:population_code => "NA19260"
	},
	:NA19259 =>
	{
		:biosample_accession => "SAMN00001093",
		:population_code => "NA19259"
	},
	:NA19253 =>
	{
		:biosample_accession => "SAMN00001091",
		:population_code => "NA19253"
	},
	:NA19250 =>
	{
		:biosample_accession => "SAMN00001090",
		:population_code => "NA19250"
	},
	:NA19229 =>
	{
		:biosample_accession => "SAMN00001087",
		:population_code => "NA19229"
	},
	:NA19228 =>
	{
		:biosample_accession => "SAMN00001086",
		:population_code => "NA19228"
	},
	:NA19220 =>
	{
		:biosample_accession => "SAMN00001085",
		:population_code => "NA19220"
	},
	:NA19217 =>
	{
		:biosample_accession => "SAMN00001084",
		:population_code => "NA19217"
	},
	:NA19216 =>
	{
		:biosample_accession => "SAMN00001083",
		:population_code => "NA19216"
	},
	:NA19196 =>
	{
		:biosample_accession => "SAMN00001082",
		:population_code => "NA19196"
	},
	:NA19195 =>
	{
		:biosample_accession => "SAMN00001081",
		:population_code => "NA19195"
	},
	:NA19187 =>
	{
		:biosample_accession => "SAMN00001080",
		:population_code => "NA19187"
	},
	:NA19168 =>
	{
		:biosample_accession => "SAMN00001079",
		:population_code => "NA19168"
	},
	:NA19166 =>
	{
		:biosample_accession => "SAMN00001078",
		:population_code => "NA19166"
	},
	:NA19163 =>
	{
		:biosample_accession => "SAMN00001077",
		:population_code => "NA19163"
	},
	:NA19162 =>
	{
		:biosample_accession => "SAMN00001076",
		:population_code => "NA19162"
	},
	:NA19157 =>
	{
		:biosample_accession => "SAMN00001075",
		:population_code => "NA19157"
	},
	:NA19156 =>
	{
		:biosample_accession => "SAMN00001074",
		:population_code => "NA19156"
	},
	:NA19135 =>
	{
		:biosample_accession => "SAMN00001073",
		:population_code => "NA19135"
	},
	:NA19133 =>
	{
		:biosample_accession => "SAMN00001072",
		:population_code => "NA19133"
	},
	:NA19125 =>
	{
		:biosample_accession => "SAMN00001071",
		:population_code => "NA19125"
	},
	:NA19124 =>
	{
		:biosample_accession => "SAMN00001070",
		:population_code => "NA19124"
	},
	:NA19110 =>
	{
		:biosample_accession => "SAMN00001069",
		:population_code => "NA19110"
	},
	:NA19105 =>
	{
		:biosample_accession => "SAMN00001068",
		:population_code => "NA19105"
	},
	:NA19104 =>
	{
		:biosample_accession => "SAMN00001067",
		:population_code => "NA19104"
	},
	:NA19091 =>
	{
		:biosample_accession => "SAMN00001066",
		:sex => "male",
		:population_code => "NA19091"
	},
	:NA19090 =>
	{
		:biosample_accession => "SAMN00001065",
		:sex => "female",
		:population_code => "NA19090"
	},
	:NA19089 =>
	{
		:biosample_accession => "SAMN00001064",
		:sex => "male",
		:population_code => "NA19089"
	},
	:NA19046 =>
	{
		:biosample_accession => "SAMN00001062",
		:sex => "male",
		:population_code => "NA19046"
	},
	:NA19045 =>
	{
		:biosample_accession => "SAMN00001061",
		:population_code => "NA19045"
	},
	:NA19044 =>
	{
		:biosample_accession => "SAMN00001060",
		:sex => "male",
		:population_code => "NA19044"
	},
	:NA19043 =>
	{
		:biosample_accession => "SAMN00001059",
		:sex => "male",
		:population_code => "NA19043"
	},
	:NA19042 =>
	{
		:biosample_accession => "SAMN00001058",
		:sex => "female",
		:population_code => "NA19042"
	},
	:NA19041 =>
	{
		:biosample_accession => "SAMN00001057",
		:sex => "male",
		:population_code => "NA19041"
	},
	:NA19039 =>
	{
		:biosample_accession => "SAMN00001056",
		:population_code => "NA19039"
	},
	:NA19038 =>
	{
		:biosample_accession => "SAMN00001055",
		:sex => "female",
		:population_code => "NA19038"
	},
	:NA19037 =>
	{
		:biosample_accession => "SAMN00001054",
		:sex => "female",
		:population_code => "NA19037"
	},
	:NA19036 =>
	{
		:biosample_accession => "SAMN00001053",
		:sex => "female",
		:population_code => "NA19036"
	},
	:NA19035 =>
	{
		:biosample_accession => "SAMN00001052",
		:sex => "male",
		:population_code => "NA19035"
	},
	:NA19031 =>
	{
		:biosample_accession => "SAMN00001051",
		:sex => "male",
		:population_code => "NA19031"
	},
	:NA19030 =>
	{
		:biosample_accession => "SAMN00001050",
		:sex => "female",
		:population_code => "NA19030"
	},
	:NA19028 =>
	{
		:biosample_accession => "SAMN00001049",
		:sex => "male",
		:population_code => "NA19028"
	},
	:NA19027 =>
	{
		:biosample_accession => "SAMN00001048",
		:sex => "male",
		:population_code => "NA19027"
	},
	:NA19026 =>
	{
		:biosample_accession => "SAMN00001047",
		:sex => "male",
		:population_code => "NA19026"
	},
	:NA19025 =>
	{
		:biosample_accession => "SAMN00001046",
		:sex => "male",
		:population_code => "NA19025"
	},
	:NA19024 =>
	{
		:biosample_accession => "SAMN00001045",
		:sex => "female",
		:population_code => "NA19024"
	},
	:NA19023  =>
	{
		:biosample_accession => "SAMN00001044",
		:sex => "female",
		:population_code => "NA19023"
	},
	:NA19022  =>
	{
		:biosample_accession => "SAMN00001043",
		:population_code => "NA19022"
	},
	:NA19020 =>
	{
		:biosample_accession => "SAMN00001042",
		:sex => "male",
		:population_code => "NA19020"
	},
	:NA19019 =>
	{
		:biosample_accession => "SAMN00001041",
		:sex => "female",
		:population_code => "NA19019"
	},
	:NA19017 =>
	{
		:biosample_accession => "SAMN00001040",
		:sex => "female",
		:population_code => "NA19017"
	},
	:NA19011 =>
	{
		:biosample_accession => "SAMN00001039",
		:sex => "female",
		:population_code => "NA19011"
	},
	:NA19006 =>
	{
		:biosample_accession => "SAMN00001038",
		:sex => "male",
		:population_code => "NA19006"
	},
	:NA19004 =>
	{
		:biosample_accession => "SAMN00001037",
		:sex => "male",
		:population_code => "NA19004"
	},
	:NA18989 =>
	{
		:biosample_accession => "SAMN00001036",
		:sex => "male",
		:population_code => "NA18989"
	},
	:NA18988 =>
	{
		:biosample_accession => "SAMN00001035",
		:sex => "male",
		:population_code => "NA18988"
	},
	:NA18986 =>
	{
		:biosample_accession => "SAMN00001034",
		:sex => "male",
		:population_code => "NA18986"
	},
	:NA18985 =>
	{
		:biosample_accession => "SAMN00001033",
		:sex => "male",
		:population_code => "NA18985"
	},
	:NA18984 =>
	{
		:biosample_accession => "SAMN00001032",
		:sex => "male",
		:population_code => "NA18984"
	},
	:NA18983 =>
	{
		:biosample_accession => "SAMN00001031",
		:sex => "male",
		:population_code => "NA18983"
	},
	:NA18982 =>
	{
		:biosample_accession => "SAMN00001030",
		:sex => "male",
		:population_code => "NA18982"
	},
	:NA18950 =>
	{
		:biosample_accession => "SAMN00001029",
		:sex => "female",
		:population_code => "NA18950"
	},
	:NA18921 =>
	{
		:biosample_accession => "SAMN00001027",
		:population_code => "NA18921"
	},
	:NA18915 =>
	{
		:biosample_accession => "SAMN00001026",
		:sex => "male",
		:population_code => "NA18915"
	},
	:NA18881 =>
	{
		:biosample_accession => "SAMN00001025",
		:sex => "female",
		:population_code => "NA18881"
	},
	:NA18879 =>
	{
		:biosample_accession => "SAMN00001024",
		:sex => "male",
		:population_code => "NA18879"
	},
	:NA18878 =>
	{
		:biosample_accession => "SAMN00001023",
		:sex => "female",
		:population_code => "NA18878"
	},
	:NA18877 =>
	{
		:biosample_accession => "SAMN00001022",
		:sex => "male",
		:population_code => "NA18877"
	},
	:NA18876 =>
	{
		:biosample_accession => "SAMN00001021",
		:sex => "female",
		:population_code => "NA18876"
	},
	:NA18865 =>
	{
		:biosample_accession => "SAMN00001020",
		:sex => "male",
		:population_code => "NA18865"
	},
	:NA18864 =>
	{
		:biosample_accession => "SAMN00001019",
		:sex => "female",
		:population_code => "NA18864"
	},
	:NA18798 =>
	{
		:biosample_accession => "SAMN00001018",
		:population_code => "NA18798"
	},
	:NA18795 =>
	{
		:biosample_accession => "SAMN00001015",
		:population_code => "NA18795"
	},
	:NA18794 =>
	{
		:biosample_accession => "SAMN00001014",
		:population_code => "NA18794"
	},
	:NA18791 =>
	{
		:biosample_accession => "SAMN00001012",
		:population_code => "NA18791"
	},
	:NA18790 =>
	{
		:biosample_accession => "SAMN00001011",
		:population_code => "NA18790"
	},
	:NA18789 =>
	{
		:biosample_accession => "SAMN00001010",
		:population_code => "NA18789"
	},
	:NA18785 =>
	{
		:biosample_accession => "SAMN00001009",
		:population_code => "NA18785"
	},
	:NA18781 =>
	{
		:biosample_accession => "SAMN00001006",
		:population_code => "NA18781"
	},
	:NA18779 =>
	{
		:biosample_accession => "SAMN00001004",
		:population_code => "NA18779"
	},
	:NA18778 =>
	{
		:biosample_accession => "SAMN00001003",
		:population_code => "NA18778"
	},
	:NA18777 =>
	{
		:biosample_accession => "SAMN00001002",
		:population_code => "NA18777"
	},
	:NA18775 =>
	{
		:biosample_accession => "SAMN00001001",
		:population_code => "NA18775"
	},
	:NA18774 =>
	{
		:biosample_accession => "SAMN00001000",
		:population_code => "NA18774"
	},
	:NA18773 =>
	{
		:biosample_accession => "SAMN00000999",
		:population_code => "NA18773"
	},
	:NA18771 =>
	{
		:biosample_accession => "SAMN00000997",
		:population_code => "NA18771"
	},
	:NA18770 =>
	{
		:biosample_accession => "SAMN00000996",
		:population_code => "NA18770"
	},
	:NA18769 =>
	{
		:biosample_accession => "SAMN00000995",
		:population_code => "NA18769"
	},
	:NA18768 =>
	{
		:biosample_accession => "SAMN00000994",
		:population_code => "NA18768"
	},
	:NA18767 =>
	{
		:biosample_accession => "SAMN00000993",
		:population_code => "NA18767"
	},
	:NA18765 =>
	{
		:biosample_accession => "SAMN00000992",
		:population_code => "NA18765"
	},
	:NA18764 =>
	{
		:biosample_accession => "SAMN00000991",
		:population_code => "NA18764"
	},
	:NA18763 =>
	{
		:biosample_accession => "SAMN00000990",
		:population_code => "NA18763"
	},
	:NA18761 =>
	{
		:biosample_accession => "SAMN00000988",
		:population_code => "NA18761"
	},
	:NA18760 =>
	{
		:biosample_accession => "SAMN00000987",
		:population_code => "NA18760"
	},
	:NA18759 =>
	{
		:biosample_accession => "SAMN00000986",
		:population_code => "NA18759"
	},
	:NA18758 =>
	{
		:biosample_accession => "SAMN00000985",
		:population_code => "NA18758"
	},
	:NA18756 =>
	{
		:biosample_accession => "SAMN00000984",
		:population_code => "NA18756"
	},
	:NA18755 =>
	{
		:biosample_accession => "SAMN00000983",
		:population_code => "NA18755"
	},
	:NA18753 =>
	{
		:biosample_accession => "SAMN00000982",
		:population_code => "NA18753"
	},
	:NA18744 =>
	{
		:biosample_accession => "SAMN00000978",
		:population_code => "NA18744"
	},
	:NA18743 =>
	{
		:biosample_accession => "SAMN00000977",
		:population_code => "NA18743"
	},
	:NA18742 =>
	{
		:biosample_accession => "SAMN00000976",
		:population_code => "NA18742"
	},
	:NA18741 =>
	{
		:biosample_accession => "SAMN00000975",
		:population_code => "NA18741"
	},
	:NA18739 =>
	{
		:biosample_accession => "SAMN00000974",
		:population_code => "NA18739"
	},
	:NA18708 =>
	{
		:biosample_accession => "SAMN00000973",
		:population_code => "NA18708"
	},
	:NA18707 =>
	{
		:biosample_accession => "SAMN00000972",
		:population_code => "NA18707"
	},
	:NA18706 =>
	{
		:biosample_accession => "SAMN00000971",
		:population_code => "NA18706"
	},
	:GM18702 =>
	{
		:biosample_accession => "SAMN00000969",
		:sex => "female",
		:population_code => "GM18702"
	},
	:NA18701 =>
	{
		:biosample_accession => "SAMN00000968",
		:population_code => "NA18701"
	},
	:NA18699 =>
	{
		:biosample_accession => "SAMN00000967",
		:population_code => "NA18699"
	},
	:NA18698 =>
	{
		:biosample_accession => "SAMN00000966",
		:population_code => "NA18698"
	},
	:NA18697 =>
	{
		:biosample_accession => "SAMN00000965",
		:population_code => "NA18697"
	},
	:GM18696 =>
	{
		:biosample_accession => "SAMN00000964",
		:sex => "female",
		:population_code => "GM18696"
	},
	:GM18694 =>
	{
		:biosample_accession => "SAMN00000962",
		:sex => "female",
		:population_code => "GM18694"
	},
	:NA18692 =>
	{
		:biosample_accession => "SAMN00000960",
		:population_code => "NA18692"
	},
	:GM18691 =>
	{
		:biosample_accession => "SAMN00000959",
		:sex => "male",
		:population_code => "GM18691"
	},
	:GM18689 =>
	{
		:biosample_accession => "SAMN00000957",
		:sex => "male",
		:population_code => "GM18689"
	},
	:NA18687 =>
	{
		:biosample_accession => "SAMN00000956",
		:population_code => "NA18687"
	},
	:NA18686 =>
	{
		:biosample_accession => "SAMN00000955",
		:population_code => "NA18686"
	},
	:GM18685 =>
	{
		:biosample_accession => "SAMN00000954",
		:sex => "male",
		:population_code => "GM18685"
	},
	:NA18683 =>
	{
		:biosample_accession => "SAMN00000952",
		:population_code => "NA18683"
	},
	:GM18682 =>
	{
		:biosample_accession => "SAMN00000951",
		:sex => "male",
		:population_code => "GM18682"
	},
	:NA18679 =>
	{
		:biosample_accession => "SAMN00000950",
		:population_code => "NA18679"
	},
	:NA18677 =>
	{
		:biosample_accession => "SAMN00000949",
		:population_code => "NA18677"
	},
	:NA18675 =>
	{
		:biosample_accession => "SAMN00000948",
		:population_code => "NA18675"
	},
	:GM18674 =>
	{
		:biosample_accession => "SAMN00000947",
		:sex => "male",
		:population_code => "GM18674"
	},
	:GM18673 =>
	{
		:biosample_accession => "SAMN00000946",
		:sex => "male",
		:population_code => "GM18673"
	},
	:NA18671 =>
	{
		:biosample_accession => "SAMN00000945",
		:population_code => "NA18671"
	},
	:GM18670 =>
	{
		:biosample_accession => "SAMN00000944",
		:sex => "female",
		:population_code => "GM18670"
	},
	:NA18669 =>
	{
		:biosample_accession => "SAMN00000943",
		:population_code => "NA18669"
	},
	:NA18649 =>
	{
		:biosample_accession => "SAMN00000942",
		:population_code => "NA18649"
	},
	:NA18648 =>
	{
		:biosample_accession => "SAMN00000941",
		:sex => "male",
		:population_code => "NA18648"
	},
	:NA18646 =>
	{
		:biosample_accession => "SAMN00000940",
		:sex => "female",
		:population_code => "NA18646"
	},
	:NA18644 =>
	{
		:biosample_accession => "SAMN00000939",
		:sex => "female",
		:population_code => "NA18644"
	},
	:NA18629 =>
	{
		:biosample_accession => "SAMN00000938",
		:sex => "male",
		:population_code => "NA18629"
	},
	:NA18598 =>
	{
		:biosample_accession => "SAMN00000937",
		:population_code => "NA18598"
	},
	:NA18591 =>
	{
		:biosample_accession => "SAMN00000936",
		:sex => "female",
		:population_code => "NA18591"
	},
	:NA18583 =>
	{
		:biosample_accession => "SAMN00000935",
		:population_code => "NA18583"
	},
	:NA18580 =>
	{
		:biosample_accession => "SAMN00000933",
		:population_code => "NA18580"
	},
	:NA18575 =>
	{
		:biosample_accession => "SAMN00000932",
		:population_code => "NA18575"
	},
	:NA18574 =>
	{
		:biosample_accession => "SAMN00000931",
		:sex => "female",
		:population_code => "NA18574"
	},
	:NA18569 =>
	{
		:biosample_accession => "SAMN00000930",
		:population_code => "NA18569"
	},
	:NA18567 =>
	{
		:biosample_accession => "SAMN00000928",
		:sex => "female",
		:population_code => "NA18567"
	},
	:NA18565 =>
	{
		:biosample_accession => "SAMN00000927",
		:sex => "female",
		:population_code => "NA18565"
	},
	:NA18560 =>
	{
		:biosample_accession => "SAMN00000926",
		:sex => "female",
		:population_code => "NA18560"
	},
	:NA18553 =>
	{
		:biosample_accession => "SAMN00000925",
		:sex => "female",
		:population_code => "NA18553"
	},
	:NA18541 =>
	{
		:biosample_accession => "SAMN00000924",
		:sex => "female",
		:population_code => "NA18541"
	},
	:NA18539 =>
	{
		:biosample_accession => "SAMN00000923",
		:sex => "female",
		:population_code => "NA18539"
	},
	:NA18538 =>
	{
		:biosample_accession => "SAMN00000922",
		:sex => "female",
		:population_code => "NA18538"
	},
	:NA18535 =>
	{
		:biosample_accession => "SAMN00000921",
		:sex => "female",
		:population_code => "NA18535"
	},
	:NA18533 =>
	{
		:biosample_accession => "SAMN00000920",
		:sex => "female",
		:population_code => "NA18533"
	},
	:NA18531 =>
	{
		:biosample_accession => "SAMN00000919",
		:sex => "female",
		:population_code => "NA18531"
	},
	:NA18528 =>
	{
		:biosample_accession => "SAMN00000918",
		:sex => "female",
		:population_code => "NA18528"
	},
	:NA18527 =>
	{
		:biosample_accession => "SAMN00000917",
		:sex => "female",
		:population_code => "NA18527"
	},
	:NA18525 =>
	{
		:biosample_accession => "SAMN00000916",
		:sex => "female",
		:population_code => "NA18525"
	},
	:GM18166 =>
	{
		:biosample_accession => "SAMN00000915",
		:sex => "male",
		:population_code => "GM18166"
	},
	:NA18164 =>
	{
		:biosample_accession => "SAMN00000914",
		:population_code => "NA18164"
	},
	:GM18163 =>
	{
		:biosample_accession => "SAMN00000913",
		:sex => "male",
		:population_code => "GM18163"
	},
	:GM18162 =>
	{
		:biosample_accession => "SAMN00000912",
		:sex => "female",
		:population_code => "GM18162"
	},
	:GM18161 =>
	{
		:biosample_accession => "SAMN00000911",
		:sex => "female",
		:population_code => "GM18161"
	},
	:GM18160 =>
	{
		:biosample_accession => "SAMN00000910",
		:sex => "male",
		:population_code => "GM18160"
	},
	:GM18159 =>
	{
		:biosample_accession => "SAMN00000909",
		:sex => "female",
		:population_code => "GM18159"
	},
	:GM18158 =>
	{
		:biosample_accession => "SAMN00000908",
		:sex => "male",
		:population_code => "GM18158"
	},
	:GM18157 =>
	{
		:biosample_accession => "SAMN00000907",
		:sex => "female",
		:population_code => "GM18157"
	},
	:GM18156 =>
	{
		:biosample_accession => "SAMN00000906",
		:sex => "male",
		:population_code => "GM18156"
	},
	:GM18155 =>
	{
		:biosample_accession => "SAMN00000905",
		:sex => "male",
		:population_code => "GM18155"
	},
	:GM18154 =>
	{
		:biosample_accession => "SAMN00000904",
		:sex => "female",
		:population_code => "GM18154"
	},
	:GM18153 =>
	{
		:biosample_accession => "SAMN00000903",
		:sex => "female",
		:population_code => "GM18153"
	},
	:GM18152 =>
	{
		:biosample_accession => "SAMN00000902",
		:sex => "male",
		:population_code => "GM18152"
	},
	:GM18151 =>
	{
		:biosample_accession => "SAMN00000901",
		:sex => "female",
		:population_code => "GM18151"
	},
	:GM18150 =>
	{
		:biosample_accession => "SAMN00000900",
		:sex => "female",
		:population_code => "GM18150"
	},
	:GM18149 =>
	{
		:biosample_accession => "SAMN00000899",
		:sex => "male",
		:population_code => "GM18149"
	},
	:GM18148 =>
	{
		:biosample_accession => "SAMN00000898",
		:sex => "female",
		:population_code => "GM18148"
	},
	:GM18147 =>
	{
		:biosample_accession => "SAMN00000897",
		:sex => "male",
		:population_code => "GM18147"
	},
	:GM18146 =>
	{
		:biosample_accession => "SAMN00000896",
		:sex => "female",
		:population_code => "GM18146"
	},
	:NA18145 =>
	{
		:biosample_accession => "SAMN00000895",
		:population_code => "NA18145"
	},
	:GM18144 =>
	{
		:biosample_accession => "SAMN00000894",
		:sex => "female",
		:population_code => "GM18144"
	},
	:GM18143 =>
	{
		:biosample_accession => "SAMN00000893",
		:sex => "male",
		:population_code => "GM18143"
	},
	:GM18141 =>
	{
		:biosample_accession => "SAMN00000892",
		:sex => "male",
		:population_code => "GM18141"
	},
	:GM18140 =>
	{
		:biosample_accession => "SAMN00000891",
		:sex => "female",
		:population_code => "GM18140"
	},
	:GM18139 =>
	{
		:biosample_accession => "SAMN00000890",
		:sex => "female",
		:population_code => "GM18139"
	},
	:GM18138 =>
	{
		:biosample_accession => "SAMN00000889",
		:sex => "male",
		:population_code => "GM18138"
	},
	:GM18136 =>
	{
		:biosample_accession => "SAMN00000888",
		:sex => "male",
		:population_code => "GM18136"
	},
	:GM18135 =>
	{
		:biosample_accession => "SAMN00000887",
		:sex => "female",
		:population_code => "GM18135"
	},
	:GM18134 =>
	{
		:biosample_accession => "SAMN00000886",
		:sex => "female",
		:population_code => "GM18134"
	},
	:GM18133 =>
	{
		:biosample_accession => "SAMN00000885",
		:sex => "male",
		:population_code => "GM18133"
	},
	:GM18132 =>
	{
		:biosample_accession => "SAMN00000884",
		:sex => "male",
		:population_code => "GM18132"
	},
	:GM18131 =>
	{
		:biosample_accession => "SAMN00000883",
		:sex => "female",
		:population_code => "GM18131"
	},
	:GM18130 =>
	{
		:biosample_accession => "SAMN00000882",
		:sex => "male",
		:population_code => "GM18130"
	},
	:GM18129 =>
	{
		:biosample_accession => "SAMN00000881",
		:sex => "female",
		:population_code => "GM18129"
	},
	:GM18128 =>
	{
		:biosample_accession => "SAMN00000880",
		:sex => "female",
		:population_code => "GM18128"
	},
	:GM18127 =>
	{
		:biosample_accession => "SAMN00000879",
		:sex => "male",
		:population_code => "GM18127"
	},
	:NA18126 =>
	{
		:biosample_accession => "SAMN00000878",
		:population_code => "NA18126"
	},
	:GM18125 =>
	{
		:biosample_accession => "SAMN00000877",
		:sex => "male",
		:population_code => "GM18125"
	},
	:GM18124 =>
	{
		:biosample_accession => "SAMN00000876",
		:sex => "male",
		:population_code => "GM18124"
	},
	:NA18123 =>
	{
		:biosample_accession => "SAMN00000875",
		:population_code => "NA18123"
	},
	:GM18122 =>
	{
		:biosample_accession => "SAMN00000874",
		:sex => "male",
		:population_code => "GM18122"
	},
	:GM18120 =>
	{
		:biosample_accession => "SAMN00000873",
		:sex => "male",
		:population_code => "GM18120"
	},
	:NA18119 =>
	{
		:biosample_accession => "SAMN00000872",
		:population_code => "NA18119"
	},
	:GM18118 =>
	{
		:biosample_accession => "SAMN00000871",
		:sex => "female",
		:population_code => "GM18118"
	},
	:GM18117 =>
	{
		:biosample_accession => "SAMN00000870",
		:sex => "male",
		:population_code => "GM18117"
	},
	:NA18116 =>
	{
		:biosample_accession => "SAMN00000869",
		:population_code => "NA18116"
	},
	:GM18115 =>
	{
		:biosample_accession => "SAMN00000868",
		:sex => "female",
		:population_code => "GM18115"
	},
	:GM18114 =>
	{
		:biosample_accession => "SAMN00000867",
		:sex => "male",
		:population_code => "GM18114"
	},
	:NA18113 =>
	{
		:biosample_accession => "SAMN00000866",
		:population_code => "NA18113"
	},
	:GM18112 =>
	{
		:biosample_accession => "SAMN00000865",
		:sex => "female",
		:population_code => "GM18112"
	},
	:GM18111 =>
	{
		:biosample_accession => "SAMN00000864",
		:sex => "female",
		:population_code => "GM18111"
	},
	:GM18110 =>
	{
		:biosample_accession => "SAMN00000863",
		:sex => "female",
		:population_code => "GM18110"
	},
	:GM18109 =>
	{
		:biosample_accession => "SAMN00000862",
		:sex => "female",
		:population_code => "GM18109"
	},
	:GM18108 =>
	{
		:biosample_accession => "SAMN00000861",
		:sex => "female",
		:population_code => "GM18108"
	},
	:GM18107 =>
	{
		:biosample_accession => "SAMN00000860",
		:sex => "female",
		:population_code => "GM18107"
	},
	:GM18106 =>
	{
		:biosample_accession => "SAMN00000859",
		:sex => "male",
		:population_code => "GM18106"
	},
	:GM18105 =>
	{
		:biosample_accession => "SAMN00000858",
		:sex => "female",
		:population_code => "GM18105"
	},
	:NA18104 =>
	{
		:biosample_accession => "SAMN00000857",
		:population_code => "NA18104"
	},
	:GM18103 =>
	{
		:biosample_accession => "SAMN00000856",
		:sex => "male",
		:population_code => "GM18103"
	},
	:GM18102 =>
	{
		:biosample_accession => "SAMN00000855",
		:sex => "male",
		:population_code => "GM18102"
	},
	:NA18000 =>
	{
		:biosample_accession => "SAMN00000853",
		:population_code => "NA18000"
	},
	:GM17998 =>
	{
		:biosample_accession => "SAMN00000851",
		:sex => "female",
		:population_code => "GM17998"
	},
	:GM17994 =>
	{
		:biosample_accession => "SAMN00000847",
		:sex => "male",
		:population_code => "GM17994"
	},
	:GM17992 =>
	{
		:biosample_accession => "SAMN00000845",
		:sex => "male",
		:population_code => "GM17992"
	},
	:GM17991 =>
	{
		:biosample_accession => "SAMN00000844",
		:sex => "female",
		:population_code => "GM17991"
	},
	:GM17990 =>
	{
		:biosample_accession => "SAMN00000843",
		:sex => "female",
		:population_code => "GM17990"
	},
	:GM17989 =>
	{
		:biosample_accession => "SAMN00000842",
		:sex => "male",
		:population_code => "GM17989"
	},
	:GM17988 =>
	{
		:biosample_accession => "SAMN00000841",
		:sex => "female",
		:population_code => "GM17988"
	},
	:GM17987 =>
	{
		:biosample_accession => "SAMN00000840",
		:sex => "female",
		:population_code => "GM17987"
	},
	:GM17986 =>
	{
		:biosample_accession => "SAMN00000839",
		:sex => "male",
		:population_code => "GM17986"
	},
	:GM17983 =>
	{
		:biosample_accession => "SAMN00000838",
		:sex => "male",
		:population_code => "GM17983"
	},
	:GM17982 =>
	{
		:biosample_accession => "SAMN00000837",
		:sex => "female",
		:population_code => "GM17982"
	},
	:GM17981 =>
	{
		:biosample_accession => "SAMN00000836",
		:sex => "female",
		:population_code => "GM17981"
	},
	:GM17980 =>
	{
		:biosample_accession => "SAMN00000835",
		:sex => "male",
		:population_code => "GM17980"
	},
	:GM17979 =>
	{
		:biosample_accession => "SAMN00000834",
		:sex => "male",
		:population_code => "GM17979"
	},
	:GM17977 =>
	{
		:biosample_accession => "SAMN00000832",
		:sex => "female",
		:population_code => "GM17977"
	},
	:GM17976 =>
	{
		:biosample_accession => "SAMN00000831",
		:sex => "male",
		:population_code => "GM17976"
	},
	:GM17975 =>
	{
		:biosample_accession => "SAMN00000830",
		:sex => "male",
		:population_code => "GM17975"
	},
	:GM17974 =>
	{
		:biosample_accession => "SAMN00000829",
		:sex => "male",
		:population_code => "GM17974"
	},
	:GM17973 =>
	{
		:biosample_accession => "SAMN00000828",
		:sex => "male",
		:population_code => "GM17973"
	},
	:GM17972 =>
	{
		:biosample_accession => "SAMN00000827",
		:sex => "male",
		:population_code => "GM17972"
	},
	:GM17971 =>
	{
		:biosample_accession => "SAMN00000826",
		:sex => "female",
		:population_code => "GM17971"
	},
	:GM17970 =>
	{
		:biosample_accession => "SAMN00000825",
		:sex => "female",
		:population_code => "GM17970"
	},
	:GM17969 =>
	{
		:biosample_accession => "SAMN00000824",
		:sex => "male",
		:population_code => "GM17969"
	},
	:GM17968 =>
	{
		:biosample_accession => "SAMN00000823",
		:sex => "female",
		:population_code => "GM17968"
	},
	:GM17967 =>
	{
		:biosample_accession => "SAMN00000822",
		:sex => "male",
		:population_code => "GM17967"
	},
	:GM17966 =>
	{
		:biosample_accession => "SAMN00000821",
		:sex => "female",
		:population_code => "GM17966"
	},
	:GM17965 =>
	{
		:biosample_accession => "SAMN00000820",
		:sex => "male",
		:population_code => "GM17965"
	},
	:GM17963 =>
	{
		:biosample_accession => "SAMN00000819",
		:sex => "female",
		:population_code => "GM17963"
	},
	:GM17962 =>
	{
		:biosample_accession => "SAMN00000818",
		:sex => "female",
		:population_code => "GM17962"
	},
	:NA19256 =>
	{
		:biosample_accession => "SAMN00000575",
		:sex => "male",
		:population_code => "NA19256"
	},
	:NA19248 =>
	{
		:biosample_accession => "SAMN00000574",
		:sex => "male",
		:population_code => "NA19248"
	},
	:NA19247 =>
	{
		:biosample_accession => "SAMN00000573",
		:sex => "female",
		:population_code => "NA19247"
	},
	:NA19236 =>
	{
		:biosample_accession => "SAMN00000572",
		:sex => "male",
		:population_code => "NA19236"
	},
	:NA19235 =>
	{
		:biosample_accession => "SAMN00000571",
		:sex => "female",
		:population_code => "NA19235"
	},
	:NA19223 =>
	{
		:biosample_accession => "SAMN00000570",
		:sex => "male",
		:population_code => "NA19223"
	},
	:NA19214 =>
	{
		:biosample_accession => "SAMN00000569",
		:sex => "female",
		:population_code => "NA19214"
	},
	:NA19213 =>
	{
		:biosample_accession => "SAMN00000568",
		:sex => "male",
		:population_code => "NA19213"
	},
	:NA19198 =>
	{
		:biosample_accession => "SAMN00000567",
		:sex => "male",
		:population_code => "NA19198"
	},
	:NA19197 =>
	{
		:biosample_accession => "SAMN00000566",
		:sex => "female",
		:population_code => "NA19197"
	},
	:NA19189 =>
	{
		:biosample_accession => "SAMN00000565",
		:sex => "male",
		:population_code => "NA19189"
	},
	:NA19185 =>
	{
		:biosample_accession => "SAMN00000564",
		:sex => "female",
		:population_code => "NA19185"
	},
	:NA19184 =>
	{
		:biosample_accession => "SAMN00000563",
		:sex => "male",
		:population_code => "NA19184"
	},
	:GM19182 =>
	{
		:biosample_accession => "SAMN00000562",
		:sex => "female",
		:population_code => "GM19182"
	},
	:GM19181 =>
	{
		:biosample_accession => "SAMN00000561",
		:sex => "male",
		:population_code => "GM19181"
	},
	:GM19179 =>
	{
		:biosample_accession => "SAMN00000560",
		:sex => "female",
		:population_code => "GM19179"
	},
	:NA19175 =>
	{
		:biosample_accession => "SAMN00000559",
		:sex => "male",
		:population_code => "NA19175"
	},
	:NA19150 =>
	{
		:biosample_accession => "SAMN00000558",
		:sex => "male",
		:population_code => "NA19150"
	},
	:NA19149 =>
	{
		:biosample_accession => "SAMN00000557",
		:sex => "female",
		:population_code => "NA19149"
	},
	:NA19146 =>
	{
		:biosample_accession => "SAMN00000556",
		:sex => "male",
		:population_code => "NA19146"
	},
	:NA19130 =>
	{
		:biosample_accession => "SAMN00000555",
		:sex => "male",
		:population_code => "NA19130"
	},
	:GM19122 =>
	{
		:biosample_accession => "SAMN00000554",
		:sex => "female",
		:population_code => "GM19122"
	},
	:NA19121 =>
	{
		:biosample_accession => "SAMN00000553",
		:sex => "male",
		:population_code => "NA19121"
	},
	:NA19118 =>
	{
		:biosample_accession => "SAMN00000552",
		:sex => "female",
		:population_code => "NA19118"
	},
	:NA19117 =>
	{
		:biosample_accession => "SAMN00000551",
		:sex => "male",
		:population_code => "NA19117"
	},
	:NA19113 =>
	{
		:biosample_accession => "SAMN00000550",
		:sex => "male",
		:population_code => "NA19113"
	},
	:NA19107 =>
	{
		:biosample_accession => "SAMN00000549",
		:sex => "male",
		:population_code => "NA19107"
	},
	:NA19096 =>
	{
		:biosample_accession => "SAMN00000548",
		:sex => "male",
		:population_code => "NA19096"
	},
	:NA19095 =>
	{
		:biosample_accession => "SAMN00000547",
		:sex => "female",
		:population_code => "NA19095"
	},
	:NA19092 =>
	{
		:biosample_accession => "SAMN00000546",
		:sex => "male",
		:population_code => "NA19092"
	},
	:NA19088 =>
	{
		:biosample_accession => "SAMN00000545",
		:sex => "male",
		:population_code => "NA19088"
	},
	:NA19087 =>
	{
		:biosample_accession => "SAMN00000544",
		:sex => "female",
		:population_code => "NA19087"
	},
	:NA19086 =>
	{
		:biosample_accession => "SAMN00000543",
		:sex => "male",
		:population_code => "NA19086"
	},
	:NA19085 =>
	{
		:biosample_accession => "SAMN00000542",
		:sex => "male",
		:population_code => "NA19085"
	},
	:NA19084 =>
	{
		:biosample_accession => "SAMN00000541",
		:sex => "female",
		:population_code => "NA19084"
	},
	:NA19083 =>
	{
		:biosample_accession => "SAMN00000540",
		:sex => "male",
		:population_code => "NA19083"
	},
	:NA19082 =>
	{
		:biosample_accession => "SAMN00000539",
		:sex => "male",
		:population_code => "NA19082"
	},
	:NA19081 =>
	{
		:biosample_accession => "SAMN00000538",
		:sex => "female",
		:population_code => "NA19081"
	},
	:NA19080 =>
	{
		:biosample_accession => "SAMN00000537",
		:sex => "female",
		:population_code => "NA19080"
	},
	:NA19079 =>
	{
		:biosample_accession => "SAMN00000536",
		:sex => "male",
		:population_code => "NA19079"
	},
	:NA19078 =>
	{
		:biosample_accession => "SAMN00000535",
		:sex => "female",
		:population_code => "NA19078"
	},
	:NA19077 =>
	{
		:biosample_accession => "SAMN00000534",
		:sex => "female",
		:population_code => "NA19077"
	},
	:NA19076 =>
	{
		:biosample_accession => "SAMN00000533",
		:sex => "male",
		:population_code => "NA19076"
	},
	:NA19075 =>
	{
		:biosample_accession => "SAMN00000532",
		:sex => "male",
		:population_code => "NA19075"
	},
	:NA19074 =>
	{
		:biosample_accession => "SAMN00000531",
		:sex => "female",
		:population_code => "NA19074"
	},
	:NA19072 =>
	{
		:biosample_accession => "SAMN00000530",
		:sex => "male",
		:population_code => "NA19072"
	},
	:NA19070 =>
	{
		:biosample_accession => "SAMN00000529",
		:sex => "male",
		:population_code => "NA19070"
	},
	:NA19068 =>
	{
		:biosample_accession => "SAMN00000528",
		:sex => "male",
		:population_code => "NA19068"
	},
	:NA19067 =>
	{
		:biosample_accession => "SAMN00000527",
		:sex => "male",
		:population_code => "NA19067"
	},
	:NA19066 =>
	{
		:biosample_accession => "SAMN00000526",
		:sex => "male",
		:population_code => "NA19066"
	},
	:NA19065 =>
	{
		:biosample_accession => "SAMN00000525",
		:sex => "female",
		:population_code => "NA19065"
	},
	:NA19064 =>
	{
		:biosample_accession => "SAMN00000524",
		:sex => "female",
		:population_code => "NA19064"
	},
	:NA19063 =>
	{
		:biosample_accession => "SAMN00000523",
		:sex => "male",
		:population_code => "NA19063"
	},
	:NA19062 =>
	{
		:biosample_accession => "SAMN00000522",
		:sex => "male",
		:population_code => "NA19062"
	},
	:NA19060 =>
	{
		:biosample_accession => "SAMN00000521",
		:sex => "male",
		:population_code => "NA19060"
	},
	:NA19059 =>
	{
		:biosample_accession => "SAMN00000520",
		:sex => "female",
		:population_code => "NA19059"
	},
	:NA19058 =>
	{
		:biosample_accession => "SAMN00000519",
		:sex => "male",
		:population_code => "NA19058"
	},
	:NA19057 =>
	{
		:biosample_accession => "SAMN00000518",
		:sex => "female",
		:population_code => "NA19057"
	},
	:NA19056 =>
	{
		:biosample_accession => "SAMN00000517",
		:sex => "male",
		:population_code => "NA19056"
	},
	:NA19055 =>
	{
		:biosample_accession => "SAMN00000516",
		:sex => "male",
		:population_code => "NA19055"
	},
	:NA19054 =>
	{
		:biosample_accession => "SAMN00000515",
		:sex => "female",
		:population_code => "NA19054"
	},
	:NA19012 =>
	{
		:biosample_accession => "SAMN00000514",
		:sex => "male",
		:population_code => "NA19012"
	},
	:NA19010 =>
	{
		:biosample_accession => "SAMN00000513",
		:sex => "female",
		:population_code => "NA19010"
	},
	:NA19009 =>
	{
		:biosample_accession => "SAMN00000512",
		:sex => "male",
		:population_code => "NA19009"
	},
	:NA19007 =>
	{
		:biosample_accession => "SAMN00000511",
		:sex => "male",
		:population_code => "NA19007"
	},
	:NA19003 =>
	{
		:biosample_accession => "SAMN00000510",
		:sex => "female",
		:population_code => "NA19003"
	},
	:NA19002 =>
	{
		:biosample_accession => "SAMN00000509",
		:sex => "female",
		:population_code => "NA19002"
	},
	:NA19001 =>
	{
		:biosample_accession => "SAMN00000508",
		:sex => "female",
		:population_code => "NA19001"
	},
	:NA19000 =>
	{
		:biosample_accession => "SAMN00000507",
		:sex => "male",
		:population_code => "NA19000"
	},
	:NA18999 =>
	{
		:biosample_accession => "SAMN00000506",
		:sex => "female",
		:population_code => "NA18999"
	},
	:NA18998 =>
	{
		:biosample_accession => "SAMN00000505",
		:sex => "female",
		:population_code => "NA18998"
	},
	:NA18997 =>
	{
		:biosample_accession => "SAMN00000504",
		:sex => "female",
		:population_code => "NA18997"
	},
	:NA18995 =>
	{
		:biosample_accession => "SAMN00000503",
		:sex => "male",
		:population_code => "NA18995"
	},
	:NA18994 =>
	{
		:biosample_accession => "SAMN00000502",
		:sex => "male",
		:population_code => "NA18994"
	},
	:NA18993 =>
	{
		:biosample_accession => "SAMN00000501",
		:sex => "female",
		:population_code => "NA18993"
	},
	:NA18992 =>
	{
		:biosample_accession => "SAMN00000500",
		:sex => "female",
		:population_code => "NA18992"
	},
	:NA18991 =>
	{
		:biosample_accession => "SAMN00000499",
		:sex => "female",
		:population_code => "NA18991"
	},
	:NA18990 =>
	{
		:biosample_accession => "SAMN00000498",
		:sex => "male",
		:population_code => "NA18990"
	},
	:NA18987 =>
	{
		:biosample_accession => "SAMN00000497",
		:sex => "female",
		:population_code => "NA18987"
	},
	:NA18979 =>
	{
		:biosample_accession => "SAMN00000496",
		:sex => "female",
		:population_code => "NA18979"
	},
	:NA18978 =>
	{
		:biosample_accession => "SAMN00000495",
		:sex => "female",
		:population_code => "NA18978"
	},
	:NA18977 =>
	{
		:biosample_accession => "SAMN00000494",
		:sex => "male",
		:population_code => "NA18977"
	},
	:NA18966 =>
	{
		:biosample_accession => "SAMN00000493",
		:sex => "male",
		:population_code => "NA18966"
	},
	:NA18963 =>
	{
		:biosample_accession => "SAMN00000492",
		:sex => "female",
		:population_code => "NA18963"
	},
	:NA18962 =>
	{
		:biosample_accession => "SAMN00000491",
		:sex => "male",
		:population_code => "NA18962"
	},
	:NA18957 =>
	{
		:biosample_accession => "SAMN00000490",
		:sex => "female",
		:population_code => "NA18957"
	},
	:GM18955 =>
	{
		:biosample_accession => "SAMN00000489",
		:sex => "male",
		:population_code => "GM18955"
	},
	:NA18954 =>
	{
		:biosample_accession => "SAMN00000488",
		:sex => "female",
		:population_code => "NA18954"
	},
	:NA18946 =>
	{
		:biosample_accession => "SAMN00000487",
		:sex => "female",
		:population_code => "NA18946"
	},
	:NA18941 =>
	{
		:biosample_accession => "SAMN00000486",
		:sex => "female",
		:population_code => "NA18941"
	},
	:NA18939 =>
	{
		:biosample_accession => "SAMN00000485",
		:sex => "female",
		:population_code => "NA18939"
	},
	:NA18934 =>
	{
		:biosample_accession => "SAMN00000484",
		:sex => "male",
		:population_code => "NA18934"
	},
	:NA18933 =>
	{
		:biosample_accession => "SAMN00000483",
		:sex => "female",
		:population_code => "NA18933"
	},
	:NA18924 =>
	{
		:biosample_accession => "SAMN00000482",
		:sex => "female",
		:population_code => "NA18924"
	},
	:NA18923 =>
	{
		:biosample_accession => "SAMN00000481",
		:sex => "male",
		:population_code => "NA18923"
	},
	:NA18917 =>
	{
		:biosample_accession => "SAMN00000480",
		:sex => "male",
		:population_code => "NA18917"
	},
	:NA18910 =>
	{
		:biosample_accession => "SAMN00000479",
		:sex => "male",
		:population_code => "NA18910"
	},
	:NA18908 =>
	{
		:biosample_accession => "SAMN00000478",
		:sex => "male",
		:population_code => "NA18908"
	},
	:NA18874 =>
	{
		:biosample_accession => "SAMN00000477",
		:sex => "male",
		:population_code => "NA18874"
	},
	:NA18873 =>
	{
		:biosample_accession => "SAMN00000476",
		:sex => "female",
		:population_code => "NA18873"
	},
	:NA18868 =>
	{
		:biosample_accession => "SAMN00000475",
		:sex => "male",
		:population_code => "NA18868"
	},
	:NA18867 =>
	{
		:biosample_accession => "SAMN00000474",
		:sex => "female",
		:population_code => "NA18867"
	},
	:NA18757 =>
	{
		:biosample_accession => "SAMN00000473",
		:sex => "male",
		:population_code => "NA18757"
	},
	:NA18749 =>
	{
		:biosample_accession => "SAMN00000472",
		:sex => "male",
		:population_code => "NA18749"
	},
	:NA18748 =>
	{
		:biosample_accession => "SAMN00000471",
		:sex => "male",
		:population_code => "NA18748"
	},
	:NA18747 =>
	{
		:biosample_accession => "SAMN00000470",
		:sex => "male",
		:population_code => "NA18747"
	},
	:NA18745 =>
	{
		:biosample_accession => "SAMN00000469",
		:sex => "male",
		:population_code => "NA18745"
	},
	:NA18740 =>
	{
		:biosample_accession => "SAMN00000468",
		:sex => "male",
		:population_code => "NA18740"
	},
	:NA18647 =>
	{
		:biosample_accession => "SAMN00000467",
		:sex => "male",
		:population_code => "NA18647"
	},
	:NA18645 =>
	{
		:biosample_accession => "SAMN00000466",
		:sex => "male",
		:population_code => "NA18645"
	},
	:NA18643 =>
	{
		:biosample_accession => "SAMN00000465",
		:sex => "male",
		:population_code => "NA18643"
	},
	:NA18642 =>
	{
		:biosample_accession => "SAMN00000464",
		:sex => "female",
		:population_code => "NA18642"
	},
	:NA18641 =>
	{
		:biosample_accession => "SAMN00000463",
		:sex => "female",
		:population_code => "NA18641"
	},
	:NA18640 =>
	{
		:biosample_accession => "SAMN00000462",
		:sex => "female",
		:population_code => "NA18640"
	},
	:NA18639 =>
	{
		:biosample_accession => "SAMN00000461",
		:sex => "male",
		:population_code => "NA18639"
	},
	:NA18637 =>
	{
		:biosample_accession => "SAMN00000460",
		:sex => "male",
		:population_code => "NA18637"
	},
	:NA18636 =>
	{
		:biosample_accession => "SAMN00000459",
		:sex => "male",
		:population_code => "NA18636"
	},
	:NA18635 =>
	{
		:biosample_accession => "SAMN00000458",
		:sex => "male",
		:population_code => "NA18635"
	},
	:NA18634 =>
	{
		:biosample_accession => "SAMN00000457",
		:sex => "female",
		:population_code => "NA18634"
	},
	:NA18633 =>
	{
		:biosample_accession => "SAMN00000456",
		:sex => "male",
		:population_code => "NA18633"
	},
	:NA18632 =>
	{
		:biosample_accession => "SAMN00000455",
		:sex => "male",
		:population_code => "NA18632"
	},
	:NA18631 =>
	{
		:biosample_accession => "SAMN00000454",
		:sex => "female",
		:population_code => "NA18631"
	},
	:NA18630 =>
	{
		:biosample_accession => "SAMN00000453",
		:sex => "female",
		:population_code => "NA18630"
	},
	:NA18628 =>
	{
		:biosample_accession => "SAMN00000452",
		:sex => "female",
		:population_code => "NA18628"
	},
	:NA18627 =>
	{
		:biosample_accession => "SAMN00000451",
		:sex => "female",
		:population_code => "NA18627"
	},
	:NA18626 =>
	{
		:biosample_accession => "SAMN00000450",
		:sex => "female",
		:population_code => "NA18626"
	},
	:NA18625 =>
	{
		:biosample_accession => "SAMN00000449",
		:sex => "female",
		:population_code => "NA18625"
	},
	:NA18624 =>
	{
		:biosample_accession => "SAMN00000448",
		:sex => "male",
		:population_code => "NA18624"
	},
	:NA18623 =>
	{
		:biosample_accession => "SAMN00000447",
		:sex => "male",
		:population_code => "NA18623"
	},
	:NA18622 =>
	{
		:biosample_accession => "SAMN00000446",
		:sex => "male",
		:population_code => "NA18622"
	},
	:NA18621 =>
	{
		:biosample_accession => "SAMN00000445",
		:sex => "male",
		:population_code => "NA18621"
	},
	:NA18620 =>
	{
		:biosample_accession => "SAMN00000444",
		:sex => "male",
		:population_code => "NA18620"
	},
	:NA18619 =>
	{
		:biosample_accession => "SAMN00000443",
		:sex => "female",
		:population_code => "NA18619"
	},
	:NA18618 =>
	{
		:biosample_accession => "SAMN00000442",
		:sex => "female",
		:population_code => "NA18618"
	},
	:NA18617 =>
	{
		:biosample_accession => "SAMN00000441",
		:sex => "female",
		:population_code => "NA18617"
	},
	:NA18616 =>
	{
		:biosample_accession => "SAMN00000440",
		:sex => "female",
		:population_code => "NA18616"
	},
	:NA18615 =>
	{
		:biosample_accession => "SAMN00000439",
		:sex => "female",
		:population_code => "NA18615"
	},
	:NA18613 =>
	{
		:biosample_accession => "SAMN00000438",
		:sex => "male",
		:population_code => "NA18613"
	},
	:NA18612 =>
	{
		:biosample_accession => "SAMN00000437",
		:sex => "male",
		:population_code => "NA18612"
	},
	:NA18611 =>
	{
		:biosample_accession => "SAMN00000436",
		:sex => "male",
		:population_code => "NA18611"
	},
	:NA18610 =>
	{
		:biosample_accession => "SAMN00000435",
		:sex => "female",
		:population_code => "NA18610"
	},
	:NA18606 =>
	{
		:biosample_accession => "SAMN00000434",
		:sex => "male",
		:population_code => "NA18606"
	},
	:NA18602 =>
	{
		:biosample_accession => "SAMN00000433",
		:sex => "female",
		:population_code => "NA18602"
	},
	:NA18599 =>
	{
		:biosample_accession => "SAMN00000432",
		:sex => "female",
		:population_code => "NA18599"
	},
	:NA18597 =>
	{
		:biosample_accession => "SAMN00000431",
		:sex => "female",
		:population_code => "NA18597"
	},
	:NA18596 =>
	{
		:biosample_accession => "SAMN00000430",
		:sex => "female",
		:population_code => "NA18596"
	},
	:NA18595 =>
	{
		:biosample_accession => "SAMN00000429",
		:sex => "female",
		:population_code => "NA18595"
	},
	:NA18559 =>
	{
		:biosample_accession => "SAMN00000428",
		:sex => "male",
		:population_code => "NA18559"
	},
	:NA18557 =>
	{
		:biosample_accession => "SAMN00000427",
		:sex => "male",
		:population_code => "NA18557"
	},
	:NA18549 =>
	{
		:biosample_accession => "SAMN00000426",
		:sex => "male",
		:population_code => "NA18549"
	},
	:NA18548 =>
	{
		:biosample_accession => "SAMN00000425",
		:sex => "male",
		:population_code => "NA18548"
	},
	:NA18546 =>
	{
		:biosample_accession => "SAMN00000424",
		:sex => "male",
		:population_code => "NA18546"
	},
	:NA18544 =>
	{
		:biosample_accession => "SAMN00000423",
		:sex => "male",
		:population_code => "NA18544"
	},
	:NA18543 =>
	{
		:biosample_accession => "SAMN00000422",
		:sex => "male",
		:population_code => "NA18543"
	},
	:GM18540 =>
	{
		:biosample_accession => "SAMN00000421",
		:sex => "female",
		:population_code => "GM18540"
	},
	:NA18536 =>
	{
		:biosample_accession => "SAMN00000420",
		:sex => "male",
		:population_code => "NA18536"
	},
	:NA18534 =>
	{
		:biosample_accession => "SAMN00000419",
		:sex => "male",
		:population_code => "NA18534"
	},
	:NA18530 =>
	{
		:biosample_accession => "SAMN00000418",
		:sex => "male",
		:population_code => "NA18530"
	},
	:GM18529 =>
	{
		:biosample_accession => "SAMN00000417",
		:sex => "female",
		:population_code => "GM18529"
	},
	:GM18524 =>
	{
		:biosample_accession => "SAMN00000416",
		:sex => "male",
		:population_code => "GM18524"
	},
	:NA18488 =>
	{
		:biosample_accession => "SAMN00000415",
		:sex => "female",
		:population_code => "NA18488"
	},
	:NA18487 =>
	{
		:biosample_accession => "SAMN00000414",
		:sex => "male",
		:population_code => "NA18487"
	},
	:NA18614 =>
	{
		:biosample_accession => "SAMN00000377",
		:sex => "female",
		:population_code => "NA18614"
	}
}