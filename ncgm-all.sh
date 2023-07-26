#!/bin/bash

ruby jvar-convert.rb -v VSUB000023 NCGM_SNP_chrX.xlsx -s &
pid1=$!

ruby jvar-convert.rb -v VSUB000022 NCGM_SNP_22.xlsx -s &
pid2=$!

ruby jvar-convert.rb -v VSUB000021 NCGM_SNP_21.xlsx -s &
pid3=$!

ruby jvar-convert.rb -v VSUB000020 NCGM_SNP_20.xlsx -s &
pid4=$!

ruby jvar-convert.rb -v VSUB000019 NCGM_SNP_19.xlsx -s &
pid5=$!

ruby jvar-convert.rb -v VSUB000018 NCGM_SNP_18.xlsx -s &
pid6=$!

ruby jvar-convert.rb -v VSUB000017 NCGM_SNP_17.xlsx -s &
pid7=$!

ruby jvar-convert.rb -v VSUB000016 NCGM_SNP_16.xlsx -s &
pid8=$!

ruby jvar-convert.rb -v VSUB000015 NCGM_SNP_15.xlsx -s &
pid9=$!

ruby jvar-convert.rb -v VSUB000014 NCGM_SNP_14.xlsx -s &
pid10=$!

ruby jvar-convert.rb -v VSUB000013 NCGM_SNP_13.xlsx -s &
pid11=$!

ruby jvar-convert.rb -v VSUB000012 NCGM_SNP_12.xlsx -s &
pid12=$!

ruby jvar-convert.rb -v VSUB000011 NCGM_SNP_11.xlsx -s &
pid13=$!

ruby jvar-convert.rb -v VSUB000010 NCGM_SNP_10.xlsx -s &
pid14=$!

ruby jvar-convert.rb -v VSUB000009 NCGM_SNP_9.xlsx -s &
pid15=$!

ruby jvar-convert.rb -v VSUB000008 NCGM_SNP_8.xlsx -s &
pid16=$!

ruby jvar-convert.rb -v VSUB000007 NCGM_SNP_7.xlsx -s &
pid17=$!

ruby jvar-convert.rb -v VSUB000006 NCGM_SNP_6.xlsx -s &
pid18=$!

ruby jvar-convert.rb -v VSUB000005 NCGM_SNP_5.xlsx -s &
pid19=$!

ruby jvar-convert.rb -v VSUB000004 NCGM_SNP_4.xlsx -s &
pid20=$!

ruby jvar-convert.rb -v VSUB000003 NCGM_SNP_3.xlsx -s &
pid21=$!

ruby jvar-convert.rb -v VSUB000002 NCGM_SNP_2.xlsx -s &
pid22=$!

ruby jvar-convert.rb -v VSUB000001 NCGM_SNP_1.xlsx -s &
pid23=$!

wait $pid1
result1=$?

wait $pid2
result2=$?

wait $pid3
result3=$?

wait $pid4
result4=$?

wait $pid5
result5=$?

wait $pid6
result6=$?

wait $pid7
result7=$?

wait $pid8
result8=$?

wait $pid9
result9=$?

wait $pid10
result10=$?

wait $pid11
result11=$?

wait $pid12
result12=$?

wait $pid13
result13=$?

wait $pid14
result14=$?

wait $pid15
result15=$?

wait $pid16
result16=$?

wait $pid17
result17=$?

wait $pid18
result18=$?

wait $pid19
result19=$?

wait $pid20
result20=$?

wait $pid21
result21=$?

wait $pid22
result22=$?

wait $pid23
result23=$?

if [ $result1 -eq 0 ]
then
	echo `date`
	echo "chr1 finished"
fi

if [ $result2 -eq 0 ]
then
	echo `date`
	echo "chr2 finished"
fi

if [ $result3 -eq 0 ]
then
	echo `date`
	echo "chr3 finished"
fi

if [ $result4 -eq 0 ]
then
	echo `date`
	echo "chr4 finished"
fi

if [ $result5 -eq 0 ]
then
	echo `date`
	echo "chr5 finished"
fi

if [ $result6 -eq 0 ]
then
	echo `date`
	echo "chr6 finished"
fi

if [ $result7 -eq 0 ]
then
	echo `date`
	echo "chr7 finished"
fi

if [ $result8 -eq 0 ]
then
	echo `date`
	echo "chr8 finished"
fi

if [ $result9 -eq 0 ]
then
	echo `date`
	echo "chr9 finished"
fi

if [ $result10 -eq 0 ]
then
	echo `date`
	echo "chr10 finished"
fi

if [ $result11 -eq 0 ]
then
	echo `date`
	echo "chr11 finished"
fi

if [ $result12 -eq 0 ]
then
	echo `date`
	echo "chr12 finished"
fi

if [ $result13 -eq 0 ]
then
	echo `date`
	echo "chr13 finished"
fi

if [ $result14 -eq 0 ]
then
	echo `date`
	echo "chr14 finished"
fi

if [ $result15 -eq 0 ]
then
	echo `date`
	echo "chr15 finished"
fi

if [ $result16 -eq 0 ]
then
	echo `date`
	echo "chr16 finished"
fi

if [ $result17 -eq 0 ]
then
	echo `date`
	echo "chr17 finished"
fi

if [ $result18 -eq 0 ]
then
	echo `date`
	echo "chr18 finished"
fi

if [ $result19 -eq 0 ]
then
	echo `date`
	echo "chr19 finished"
fi

if [ $result20 -eq 0 ]
then
	echo `date`
	echo "chr20 finished"
fi

if [ $result21 -eq 0 ]
then
	echo `date`
	echo "chr21 finished"
fi

if [ $result22 -eq 0 ]
then
	echo `date`
	echo "chr22 finished"
fi

if [ $result23 -eq 0 ]
then
	echo `date`
	echo "chrX finished"
fi

if [ $result1 -eq 0 ] && [ $result2 -eq 0 ] && [ $result3 -eq 0 ] && [ $result4 -eq 0 ] && [ $result5 -eq 0 ] && [ $result6 -eq 0 ] && [ $result7 -eq 0 ] && [ $result8 -eq 0 ] && [ $result9 -eq 0 ] && [ $result10 -eq 0 ] && [ $result11 -eq 0 ] && [ $result12 -eq 0 ] && [ $result13 -eq 0 ] && [ $result14 -eq 0 ] && [ $result15 -eq 0 ] && [ $result16 -eq 0 ] && [ $result17 -eq 0 ] && [ $result18 -eq 0 ] && [ $result19 -eq 0 ] && [ $result20 -eq 0 ] && [ $result21 -eq 0 ] && [ $result22 -eq 0 ] && [ $result23 -eq 0 ]
then
	echo "success"
	exit 0
else
	echo "fail"
	exit 6
fi