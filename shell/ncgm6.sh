#!/bin/bash

ruby jvar-convert.rb -v VSUB000019 NCGM_SNP_19.xlsx -s &
pid19=$!

ruby jvar-convert.rb -v VSUB000020 NCGM_SNP_20.xlsx -s &
pid20=$!

ruby jvar-convert.rb -v VSUB000021 NCGM_SNP_21.xlsx -s &
pid21=$!

ruby jvar-convert.rb -v VSUB000022 NCGM_SNP_22.xlsx -s &
pid22=$!

ruby jvar-convert.rb -v VSUB000023 NCGM_SNP_chrX.xlsx -s &
pidX=$!

wait $pid19
result19=$?

wait $pid20
result20=$?

wait $pid21
result21=$?

wait $pid22
result22=$?

wait $pidX
resultX=$?


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

if [ $resultX -eq 0 ]
then
	echo `date`
	echo "chrX finished"
fi


if [ $result19 -eq 0 ] && [ $result20 -eq 0 ] && [ $result21 -eq 0 ] && [ $result22 -eq 0 ] && [ $resultX -eq 0 ]
then
	echo "success 19-22,X"
	exit 0
else
	echo "fail 19-22,X"
	exit 6
fi
