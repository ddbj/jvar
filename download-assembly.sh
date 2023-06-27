#! /bin/sh

# Download RefSeq assemblies, genome fasta and summary jsonl from GRCh37.p13 (Jun 28, 2013) to GRCh38.p14 (Feb 3, 2022).
curl -OJX GET "https://api.ncbi.nlm.nih.gov/datasets/v2alpha/genome/accession/GCF_000001405.25/download?include_annotation_type=GENOME_FASTA,SEQUENCE_REPORT&filename=GCF_000001405.25.zip" -H "Accept: application/zip"
# curl -OJX GET "https://api.ncbi.nlm.nih.gov/datasets/v2alpha/genome/accession/GCF_000001405.26/download?include_annotation_type=GENOME_FASTA,SEQUENCE_REPORT&filename=GCF_000001405.26.zip" -H "Accept: application/zip"
# curl -OJX GET "https://api.ncbi.nlm.nih.gov/datasets/v2alpha/genome/accession/GCF_000001405.27/download?include_annotation_type=GENOME_FASTA,SEQUENCE_REPORT&filename=GCF_000001405.27.zip" -H "Accept: application/zip"
# curl -OJX GET "https://api.ncbi.nlm.nih.gov/datasets/v2alpha/genome/accession/GCF_000001405.28/download?include_annotation_type=GENOME_FASTA,SEQUENCE_REPORT&filename=GCF_000001405.28.zip" -H "Accept: application/zip"
# curl -OJX GET "https://api.ncbi.nlm.nih.gov/datasets/v2alpha/genome/accession/GCF_000001405.29/download?include_annotation_type=GENOME_FASTA,SEQUENCE_REPORT&filename=GCF_000001405.29.zip" -H "Accept: application/zip"
# curl -OJX GET "https://api.ncbi.nlm.nih.gov/datasets/v2alpha/genome/accession/GCF_000001405.30/download?include_annotation_type=GENOME_FASTA,SEQUENCE_REPORT&filename=GCF_000001405.30.zip" -H "Accept: application/zip"
# curl -OJX GET "https://api.ncbi.nlm.nih.gov/datasets/v2alpha/genome/accession/GCF_000001405.31/download?include_annotation_type=GENOME_FASTA,SEQUENCE_REPORT&filename=GCF_000001405.31.zip" -H "Accept: application/zip"
# curl -OJX GET "https://api.ncbi.nlm.nih.gov/datasets/v2alpha/genome/accession/GCF_000001405.32/download?include_annotation_type=GENOME_FASTA,SEQUENCE_REPORT&filename=GCF_000001405.32.zip" -H "Accept: application/zip"
# curl -OJX GET "https://api.ncbi.nlm.nih.gov/datasets/v2alpha/genome/accession/GCF_000001405.33/download?include_annotation_type=GENOME_FASTA,SEQUENCE_REPORT&filename=GCF_000001405.33.zip" -H "Accept: application/zip"
# curl -OJX GET "https://api.ncbi.nlm.nih.gov/datasets/v2alpha/genome/accession/GCF_000001405.34/download?include_annotation_type=GENOME_FASTA,SEQUENCE_REPORT&filename=GCF_000001405.34.zip" -H "Accept: application/zip"
# curl -OJX GET "https://api.ncbi.nlm.nih.gov/datasets/v2alpha/genome/accession/GCF_000001405.35/download?include_annotation_type=GENOME_FASTA,SEQUENCE_REPORT&filename=GCF_000001405.35.zip" -H "Accept: application/zip"
# curl -OJX GET "https://api.ncbi.nlm.nih.gov/datasets/v2alpha/genome/accession/GCF_000001405.36/download?include_annotation_type=GENOME_FASTA,SEQUENCE_REPORT&filename=GCF_000001405.36.zip" -H "Accept: application/zip"
# curl -OJX GET "https://api.ncbi.nlm.nih.gov/datasets/v2alpha/genome/accession/GCF_000001405.37/download?include_annotation_type=GENOME_FASTA,SEQUENCE_REPORT&filename=GCF_000001405.37.zip" -H "Accept: application/zip"
# curl -OJX GET "https://api.ncbi.nlm.nih.gov/datasets/v2alpha/genome/accession/GCF_000001405.38/download?include_annotation_type=GENOME_FASTA,SEQUENCE_REPORT&filename=GCF_000001405.38.zip" -H "Accept: application/zip"
# curl -OJX GET "https://api.ncbi.nlm.nih.gov/datasets/v2alpha/genome/accession/GCF_000001405.39/download?include_annotation_type=GENOME_FASTA,SEQUENCE_REPORT&filename=GCF_000001405.39.zip" -H "Accept: application/zip"
curl -OJX GET "https://api.ncbi.nlm.nih.gov/datasets/v2alpha/genome/accession/GCF_000001405.40/download?include_annotation_type=GENOME_FASTA,SEQUENCE_REPORT&filename=GCF_000001405.40.zip" -H "Accept: application/zip"

# mkdir
mkdir GCF_000001405.25
# mkdir GCF_000001405.26
# mkdir GCF_000001405.27
# mkdir GCF_000001405.28
# mkdir GCF_000001405.29
# mkdir GCF_000001405.30
# mkdir GCF_000001405.31
# mkdir GCF_000001405.32
# mkdir GCF_000001405.33
# mkdir GCF_000001405.34
# mkdir GCF_000001405.35
# mkdir GCF_000001405.36
# mkdir GCF_000001405.37
# mkdir GCF_000001405.38
# mkdir GCF_000001405.39
mkdir GCF_000001405.40

# move zip into dir
mv GCF_000001405.25.zip GCF_000001405.25
# mv GCF_000001405.26.zip GCF_000001405.26
# mv GCF_000001405.27.zip GCF_000001405.27
# mv GCF_000001405.28.zip GCF_000001405.28
# mv GCF_000001405.29.zip GCF_000001405.29
# mv GCF_000001405.30.zip GCF_000001405.30
# mv GCF_000001405.31.zip GCF_000001405.31
# mv GCF_000001405.32.zip GCF_000001405.32
# mv GCF_000001405.33.zip GCF_000001405.33
# mv GCF_000001405.34.zip GCF_000001405.34
# mv GCF_000001405.35.zip GCF_000001405.35
# mv GCF_000001405.36.zip GCF_000001405.36
# mv GCF_000001405.37.zip GCF_000001405.37
# mv GCF_000001405.38.zip GCF_000001405.38
# mv GCF_000001405.39.zip GCF_000001405.39
mv GCF_000001405.40.zip GCF_000001405.40

# unzip into dir
unzip GCF_000001405.25/GCF_000001405.25.zip -d GCF_000001405.25
# unzip GCF_000001405.26/GCF_000001405.26.zip -d GCF_000001405.26
# unzip GCF_000001405.27/GCF_000001405.27.zip -d GCF_000001405.27
# unzip GCF_000001405.28/GCF_000001405.28.zip -d GCF_000001405.28
# unzip GCF_000001405.29/GCF_000001405.29.zip -d GCF_000001405.29
# unzip GCF_000001405.30/GCF_000001405.30.zip -d GCF_000001405.30
# unzip GCF_000001405.31/GCF_000001405.31.zip -d GCF_000001405.31
# unzip GCF_000001405.32/GCF_000001405.32.zip -d GCF_000001405.32
# unzip GCF_000001405.33/GCF_000001405.33.zip -d GCF_000001405.33
# unzip GCF_000001405.34/GCF_000001405.34.zip -d GCF_000001405.34
# unzip GCF_000001405.35/GCF_000001405.35.zip -d GCF_000001405.35
# unzip GCF_000001405.36/GCF_000001405.36.zip -d GCF_000001405.36
# unzip GCF_000001405.37/GCF_000001405.37.zip -d GCF_000001405.37
# unzip GCF_000001405.38/GCF_000001405.38.zip -d GCF_000001405.38
# unzip GCF_000001405.39/GCF_000001405.39.zip -d GCF_000001405.39
unzip GCF_000001405.40/GCF_000001405.40.zip -d GCF_000001405.40

# move fasta and summary under dir
mv GCF_000001405.25/ncbi_dataset/data/GCF_000001405.25/*fna GCF_000001405.25
mv GCF_000001405.25/ncbi_dataset/data/GCF_000001405.25/*jsonl GCF_000001405.25
# mv GCF_000001405.26/ncbi_dataset/data/GCF_000001405.26/*fna GCF_000001405.26
# mv GCF_000001405.26/ncbi_dataset/data/GCF_000001405.26/*jsonl GCF_000001405.26
# mv GCF_000001405.27/ncbi_dataset/data/GCF_000001405.27/*fna GCF_000001405.27
# mv GCF_000001405.27/ncbi_dataset/data/GCF_000001405.27/*jsonl GCF_000001405.27
# mv GCF_000001405.28/ncbi_dataset/data/GCF_000001405.28/*fna GCF_000001405.28
# mv GCF_000001405.28/ncbi_dataset/data/GCF_000001405.28/*jsonl GCF_000001405.28
# mv GCF_000001405.29/ncbi_dataset/data/GCF_000001405.29/*fna GCF_000001405.29
# mv GCF_000001405.29/ncbi_dataset/data/GCF_000001405.29/*jsonl GCF_000001405.29
# mv GCF_000001405.30/ncbi_dataset/data/GCF_000001405.30/*fna GCF_000001405.30
# mv GCF_000001405.30/ncbi_dataset/data/GCF_000001405.30/*jsonl GCF_000001405.30
# mv GCF_000001405.31/ncbi_dataset/data/GCF_000001405.31/*fna GCF_000001405.31
# mv GCF_000001405.31/ncbi_dataset/data/GCF_000001405.31/*jsonl GCF_000001405.31
# mv GCF_000001405.32/ncbi_dataset/data/GCF_000001405.32/*fna GCF_000001405.32
# mv GCF_000001405.32/ncbi_dataset/data/GCF_000001405.32/*jsonl GCF_000001405.32
# mv GCF_000001405.33/ncbi_dataset/data/GCF_000001405.33/*fna GCF_000001405.33
# mv GCF_000001405.33/ncbi_dataset/data/GCF_000001405.33/*jsonl GCF_000001405.33
# mv GCF_000001405.34/ncbi_dataset/data/GCF_000001405.34/*fna GCF_000001405.34
# mv GCF_000001405.34/ncbi_dataset/data/GCF_000001405.34/*jsonl GCF_000001405.34
# mv GCF_000001405.35/ncbi_dataset/data/GCF_000001405.35/*fna GCF_000001405.35
# mv GCF_000001405.35/ncbi_dataset/data/GCF_000001405.35/*jsonl GCF_000001405.35
# mv GCF_000001405.36/ncbi_dataset/data/GCF_000001405.36/*fna GCF_000001405.36
# mv GCF_000001405.36/ncbi_dataset/data/GCF_000001405.36/*jsonl GCF_000001405.36
# mv GCF_000001405.37/ncbi_dataset/data/GCF_000001405.37/*fna GCF_000001405.37
# mv GCF_000001405.37/ncbi_dataset/data/GCF_000001405.37/*jsonl GCF_000001405.37
# mv GCF_000001405.38/ncbi_dataset/data/GCF_000001405.38/*fna GCF_000001405.38
# mv GCF_000001405.38/ncbi_dataset/data/GCF_000001405.38/*jsonl GCF_000001405.38
# mv GCF_000001405.39/ncbi_dataset/data/GCF_000001405.39/*fna GCF_000001405.39
# mv GCF_000001405.39/ncbi_dataset/data/GCF_000001405.39/*jsonl GCF_000001405.39
mv GCF_000001405.40/ncbi_dataset/data/GCF_000001405.40/*fna GCF_000001405.40
mv GCF_000001405.40/ncbi_dataset/data/GCF_000001405.40/*jsonl GCF_000001405.40

# index genome fasta
cd GCF_000001405.25
samtools faidx GCF_000001405.25_GRCh37.p13_genomic.fna
cd ..
# cd GCF_000001405.26
# samtools faidx GCF_000001405.26_GRCh38_genomic.fna
# cd ..
# cd GCF_000001405.27
# samtools faidx GCF_000001405.27_GRCh38.p1_genomic.fna
# cd ..
# cd GCF_000001405.28
# samtools faidx GCF_000001405.28_GRCh38.p2_genomic.fna
# cd ..
# cd GCF_000001405.29
# samtools faidx GCF_000001405.29_GRCh38.p3_genomic.fna
# cd ..
# cd GCF_000001405.30
# samtools faidx GCF_000001405.30_GRCh38.p4_genomic.fna
# cd ..
# cd GCF_000001405.31
# samtools faidx GCF_000001405.31_GRCh38.p5_genomic.fna
# cd ..
# cd GCF_000001405.32
# samtools faidx GCF_000001405.32_GRCh38.p6_genomic.fna
# cd ..
# cd GCF_000001405.33
# samtools faidx GCF_000001405.33_GRCh38.p7_genomic.fna
# cd ..
# cd GCF_000001405.34
# samtools faidx GCF_000001405.34_GRCh38.p8_genomic.fna
# cd ..
# cd GCF_000001405.35
# samtools faidx GCF_000001405.35_GRCh38.p9_genomic.fna
# cd ..
# cd GCF_000001405.36
# samtools faidx GCF_000001405.36_GRCh38.p10_genomic.fna
# cd ..
# cd GCF_000001405.37
# samtools faidx GCF_000001405.37_GRCh38.p11_genomic.fna
# cd ..
# cd GCF_000001405.38
# samtools faidx GCF_000001405.38_GRCh38.p12_genomic.fna
# cd ..
# cd GCF_000001405.39
# samtools faidx GCF_000001405.39_GRCh38.p13_genomic.fna
# cd ..
cd GCF_000001405.40
samtools faidx GCF_000001405.40_GRCh38.p14_genomic.fna
cd ..

# collect references
mkdir reference
cp GCF_000001405*/*fna reference/
cp GCF_000001405*/*fai reference/
cat GCF_000001405*/*jsonl > reference/ref_sequence_report.jsonl 
