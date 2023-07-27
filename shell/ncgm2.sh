#!/bin/bash

ruby jvar-convert.rb -v VSUB000003 NCGM_SNP_3.xlsx -s &
pid3=$!

ruby jvar-convert.rb -v VSUB000004 NCGM_SNP_4.xlsx -s &
pid4=$!

ruby jvar-convert.rb -v VSUB000005 NCGM_SNP_5.xlsx -s &
pid5=$!


wait $pid3
result3=$?

wait $pid4
result4=$?

wait $pid5
result5=$?


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


if [ $result3 -eq 0 ] && [ $result4 -eq 0 ] && [ $result5 -eq 0 ]
then
	echo "success 3-5"
	exit 0
else
	echo "fail 3-5"
	exit 6
fi