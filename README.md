# JVar

JVar (Japan Variation Database) はヒトのバリアント、頻度、遺伝子型のための公的データベース。  
Short Genetic Variation (JVar-SNP) と Structural Variation (JVar-SV) の二部構成。  

* JVar-SNP: 50bp 以下の SNV/insertion/deletion、dbSNP 相当
* JVar-SV: 50bp より長い構造バリアント (SV)、dbVar 相当

[EVA (European Variation Archive)](https://www.ebi.ac.uk/eva/) はヒトとヒト以外の生物種が対象。  
NCBI [dbSNP](https://ncbi.nlm.nih.gov/snp)/[dbVar](https://ncbi.nlm.nih.gov/dbvar) と JVar はヒトのみが対象。

## データモデル

dbVar のデータモデルに dbSNP の Assay を取り込んで拡張し SNP/SV 共通モデルを構築。  
BioProject/BioSample が必須。  
Variant は Assay を介して Study/SampleSet (Sample) にリンク。  

![jvar-dm](https://github.com/ddbj/jvar/assets/5100160/a4cbf8cf-f066-4ec2-8cd7-36c790ffd890)

アクセッション番号  
* JVar-SNP: study - dstd, variant - dss  
* JVar-SV: study - dstd, variant call - dssv, variant region - dsv  

SampleSet, Experiment, Assay は内部的に連番 ID で参照。  
dbSNP はメタデータ中で、それぞれ、ss1、e1、a1 のように区別して参照。　　

variant は mono-allelic で受付。取り扱いをシンプルにするのと TogoVar と粒度を揃えるため。  
dbSNP/dbVar は pos + variation type が同じ multi-allelic を許容。  
mono は rs にマージされると multi になる。variant call は region に multi にマージできる。

JVar-SNP variant は公開後 dbSNP に取り込まれると、dbSNP により ss が発行され、次の build で rs にマージ（新規であれば rs 発行） される。

## 登録用エクセル

[登録用エクセル](/submission_excel/JVar_v1.2.xlsx)

シート
* Study  
* SampleSet  
* Sample  
* Experiment  
* Assay  
* Variant Call (SV)
* Variant Region (SV)

Study 
→ dbSNP CONT & PUB  
→ dbVar Submission & Study 

Variant  
* SNP: variant は VCF で登録  
* SV: エクセルシート、もしくは、VCF で登録。Variant region は任意。

VCF Guidelines  
* [dbSNP VCF Submission Format Guidelines](https://www.ncbi.nlm.nih.gov/projects/SNP/docs/dbSNP_VCF_Submission.pdf)  
* [dbVar VCF Submission Format Guidelines](https://www.ncbi.nlm.nih.gov/core/assets/dbvar/files/dbVar_VCF_Submission.pdf)
* [The Variant Call Format Specification v4.4](https://samtools.github.io/hts-specs/VCFv4.4.pdf)

## Conversion & validation

-v で Submission ID (例 VSUB000001) を指定。
```
ruby jvar-convert.rb -v VSUB000001 JVar.xlsx
```

Assay に VCF ファイルパスが記載されている場合、対象 VCF を読み込む。   
SNP or SV は study の Submission Type で判定。  

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

