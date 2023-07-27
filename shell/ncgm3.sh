#!/bin/bash

ruby jvar-convert.rb -v VSUB000006 NCGM_SNP_6.xlsx -s &
pid6=$!

ruby jvar-convert.rb -v VSUB000007 NCGM_SNP_7.xlsx -s &
pid7=$!

ruby jvar-convert.rb -v VSUB000008 NCGM_SNP_8.xlsx -s &
pid8=$!

ruby jvar-convert.rb -v VSUB000009 NCGM_SNP_9.xlsx -s &
pid9=$!


wait $pid6
result6=$?

wait $pid7
result7=$?

wait $pid8
result8=$?

wait $pid9
result9=$?


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


if [ $result6 -eq 0 ] && [ $result7 -eq 0 ] && [ $result8 -eq 0 ] && [ $result9 -eq 0 ]
then
	echo "success 6-9"
	exit 0
else
	echo "fail 6-9"
	exit 6
fi