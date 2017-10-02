#!/bin/sh

for file in $@
do
	echo "python test for $file"
	python $file > pyOut

	echo "perl test for $file"
	./pypl.pl $file | perl > plOut

	if diff pyOut plOut 
	then
		echo $file was successful
	else
		echo $file had some errors
	fi
done