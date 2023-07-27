#!/bin/bash

ruby jvar-convert.rb -v VSUB000010 NCGM_SNP_10.xlsx -s &
pid10=$!

ruby jvar-convert.rb -v VSUB000011 NCGM_SNP_11.xlsx -s &
pid11=$!

ruby jvar-convert.rb -v VSUB000012 NCGM_SNP_12.xlsx -s &
pid12=$!

ruby jvar-convert.rb -v VSUB000013 NCGM_SNP_13.xlsx -s &
pid13=$!

ruby jvar-convert.rb -v VSUB000014 NCGM_SNP_14.xlsx -s &
pid14=$!


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


if [ $result10 -eq 0 ] && [ $result11 -eq 0 ] && [ $result12 -eq 0 ] && [ $result13 -eq 0 ] && [ $result14 -eq 0 ]
then
	echo "success 10-14"
	exit 0
else
	echo "fail 10-14"
	exit 6
fi