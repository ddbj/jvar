#!/bin/bash

ruby jvar-convert.rb -v VSUB000015 NCGM_SNP_15.xlsx -s &
pid15=$!

ruby jvar-convert.rb -v VSUB000016 NCGM_SNP_16.xlsx -s &
pid16=$!

ruby jvar-convert.rb -v VSUB000017 NCGM_SNP_17.xlsx -s &
pid17=$!

ruby jvar-convert.rb -v VSUB000018 NCGM_SNP_18.xlsx -s &
pid18=$!

wait $pid15
result15=$?

wait $pid16
result16=$?

wait $pid17
result17=$?

wait $pid18
result18=$?


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


if [ $result15 -eq 0 ] && [ $result16 -eq 0 ] && [ $result17 -eq 0 ] && [ $result18 -eq 0 ]
then
	echo "success 15-18"
	exit 0
else
	echo "fail 15-18"
	exit 6
fi