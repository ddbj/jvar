#!/bin/bash

ruby jvar-convert.rb -v VSUB000001 NCGM_SNP_1.xlsx -s &
pid1=$!

ruby jvar-convert.rb -v VSUB000002 NCGM_SNP_2.xlsx -s &
pid2=$!


wait $pid1
result1=$?

wait $pid2
result2=$?


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


if [ $result1 -eq 0 ] && [ $result2 -eq 0 ]
then
	echo "success 1-2"
	exit 0
else
	echo "fail 1-2"
	exit 6
fi