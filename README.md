# JVar

JVar (Japan Variation Database) はヒトのバリアント、アリル頻度、遺伝子型のための公的データベース。Short Genetic Variation (JVar-SNP) と Structural Variation (JVar-SV) の二部構成。  

* JVar-SNP: 50bp 以下の SNV/insertion/deletion、dbSNP 相当
* JVar-SV: 50bp より長い構造バリアント (SV)、dbVar 相当

NCBI [dbSNP](https://ncbi.nlm.nih.gov/snp)/[dbVar](https://ncbi.nlm.nih.gov/dbvar) と JVar はヒトのみが対象。[EVA (European Variation Archive)](https://www.ebi.ac.uk/eva/) はヒトとヒト以外の生物種が対象。

## データモデル

dbVar のデータモデルに dbSNP の Assay を Dataset として取り込んで拡張し SNP/SV 共通モデルを構築。BioProject/BioSample は必須。Variant は Dataset を介して Study/SampleSet (Sample) にリンク。  

![jvar-dm](https://github.com/ddbj/jvar/assets/5100160/8641c247-2548-4888-b124-503470267576)

アクセッション番号  
* JVar-SNP: study - dstd, variant - dss  
* JVar-SV: study - dstd, variant call - dssv, variant region - dsv  

SampleSet, Experiment, Dataset は内部的に連番 ID で参照。dbSNP メタデータ中では、それぞれ、ss1、e1、a1 のように区別して参照。　　

variant は mono-allelic で受付。取り扱いをシンプルにするのと TogoVar と粒度を揃えるため。  
dbSNP/dbVar は pos + variation type が同じ multi-allelic を許容。dbSNP rs と Variant region は multi。

JVar-SNP variant は公開後 dbSNP に取り込まれると、dbSNP により ss が発行され、次の build で rs にマージされる （新規であれば rs 発行）。

## 登録用エクセル

[登録用エクセル](/submission_excel/)

シート
* Study  
* SampleSet  
* Sample  
* Experiment  
* Dataset   
* Variant Call (SV)
* Variant Region (SV)

Study   
→ dbSNP CONT and PUB  
→ dbVar Submission and Study 

Variant  
* SNP: variant は VCF で登録  
* SV: エクセルシート、もしくは、VCF で登録。Variant region は任意。

VCF Guidelines  
* [dbSNP VCF Submission Format Guidelines](https://www.ncbi.nlm.nih.gov/projects/SNP/docs/dbSNP_VCF_Submission.pdf)  
* [dbVar VCF Submission Format Guidelines](https://www.ncbi.nlm.nih.gov/core/assets/dbvar/files/dbVar_VCF_Submission.pdf)
* [The Variant Call Format Specification v4.4](https://samtools.github.io/hts-specs/VCFv4.4.pdf)

## Reference sequences

[download-assembly.sh](download-assembly.sh)

* NCBI Dataset から GRCh37 latest と GRCh38 の全バージョンをダウンロード  
* REF 塩基配列チェック用に [samtools faidx](http://www.htslib.org/doc/samtools-faidx.html) で fasta のインデックス作成
* [Genome sequence report](https://www.ncbi.nlm.nih.gov/datasets/docs/v2/reference-docs/data-reports/genome-sequence/) jsonl を結合し reference sequence と CHROM チェックに使用

## VCF

reference 指定が必須。

```
##fileformat=VCFv4.1
##reference=GRCh38
```

reference の値は [/conf/ref_assembly.jsonl](/conf/ref_assembly.jsonl) で制限。

## Conversion & validation

ルール (dbVar から提供されたルール、dbSNP offline validator、独自)  
* [JVar rules](https://docs.google.com/spreadsheets/d/15pENGHA9hkl6QIueFb44fhQfQMThRB2tbvSE6hItHEU/edit#gid=576708402)

### Submission ID 指定

前提とするファイル配置 (VSUB000001 で説明)    
* submission/VSUB000001/VSUB000001_[SNP|SV].xlsx 
* submission/VSUB000001/submitted/vcf_files.vcf

-v で Submission ID (例 VSUB000001) を指定。  
```
ruby jvar-convert.rb -v VSUB000001
```

Dataset に VCF ファイルパスが記載されている場合、対象 VCF を読み込む。   
SNP or SV は study の Submission Type で判定。  

出力ファイル  
SNP  
```
submission/VSUB000001/VSUB000001/
VSUB000001_a1.vcf # dbSNP vcf per assay
VSUB000001_a2.vcf # dbSNP vcf per assay
VSUB000001_dbsnp.tsv # dbSNP metadata
VSUB000001_SNP.log.txt # validation log
VSUB000001_SNP.xlsx # jvar metadata excel

submitted/
snp-vcf-test1.vcf # submitted vcf
snp-vcf-test1.vcf.log.txt # log for submitted vcf
snp-vcf-test2.vcf # submitted vcf
snp-vcf-test2.vcf.log.txt # log for submitted vcf
```

SV (variant call がエクセルで submit された場合)     
```
VSUB000002_dbvar.xml # dbvar xml
VSUB000002_SV.log.txt # validation log
VSUB000002_SV.xlsx  # jvar metadata excel
VSUB000002.variant_call.tsv.log.txt # log for variant call validation in tsv
```

SV (variant call が VCF で submit された場合)     
```
VSUB000003_dbvar.xml # dbvar xml
VSUB000003_SV.log.txt # validation log
VSUB000003_SV.xlsx # jvar metadata excel
VSUB000003.variant_call.tsv.log.txt # log for variant call validation in tsv
VSUB000003.variant_region.tsv.log.txt # log for variant region validation in tsv

submitted/
sv-test1.vcf # submitted vcf
sv-test1.vcf.log.txt # log for submitted vcf
sv-test2.vcf # submitted vcf
sv-test2.vcf.log.txt # log for submitted vcf
```

### エクセル指定

submission に配置前の査定段階を想定。  
引数でエクセルを指定する。

```
ruby jvar-convert.rb -v VSUB000001 VSUB000001_SNP.xlsx
ruby jvar-convert.rb -v VSUB000002 VSUB000002_SV.xlsx
```

エクセルがある場所にファイルが出力される。  


### SNP

登録された VCF に dbSNP 必須項目を埋め込んだ dbSNP 用 VCF を assay (batch) 毎に生成。  
[dbSNP: How to submit](https://www.ncbi.nlm.nih.gov/snp/docs/submission/hts_launch_and_introductory_material/)

dbSNP VCF  
```
VSUB000001_a1.dbsnp.vcf
VSUB000001_a2.dbsnp.vcf
```

validation ログ  
```
VSUB000001_SNP.log.txt # validation 結果のサマリー
[vcf filename].log.txt # submit された VCF の行末に validation 結果を付加 
```

### SV

SV はシート、もしくは、VCF で登録。  
VCF はパースされた後、sheet (TSV) 経由と同じ処理で validation される。VCF は Variant call TSV に変換される。  
Variant region は任意。ない場合は JVar で Variant call から region を生成。 
Variant region が VCF で登録されることは想定していない。  

Variant call tsv
```
VSUB000001_variant_call.tsv
```

validation ログ   
```
VSUB000001_SV.log.txt # validation 結果のサマリー
[vcf filename].log.txt # submit された VCF の行末に validation 結果を付加 
```

### Singularity

[Singularity](/singularity/Singularity)

ruby プログラムのパスを書き換えた後に Singularity イメージを構築。