# How to Use

## セットアップから実行方法

### Requirements
* ruby 3.0
* samtools

```
git clone -b how-to-user git@github.com:ddbj/jvar.git
cd jvar
bundle install
```
### リファレンス配列の取得と準備

以下のコマンドを実行すると、./referenceディレクトリに*.fna, *.fna.fai, ref_sequence_report.jsonlが作成される

```
$ bash download-assembly.sh
$ ls reference/
GCF_000001405.25.fna  GCF_000001405.25.fna.fai  GCF_000001405.40.fna  GCF_000001405.40.fna.fai  ref_sequence_report.jsonl
```

### バリデーションと各種ファイル出力

testデータを入力にしたjvar-convert.rbの実行方法は以下の通り

* SNPデータの実行テスト
    * 

* SVデータの実行テスト
    * `ruby jvar-convert.rb -v VSUB000001 test/excel/SV_vcf_test1.xlsx`
    * `ruby jvar-convert.rb -v VSUB000001 test/excel/SV_vcf_acc_test2.xlsx`
    * `ruby jvar-convert.rb -v VSUB000001 test/excel/SV_vcf_end_test2.xlsx`

## スパコンでコンテナでの利用する場合

TODO: singularityのビルド環境と方法の記載と.sifファイルの配置先と実行コマンドを記載
