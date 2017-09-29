#!/bin/sh

for file in $@
do
	python $file > pyOut

	./pypl.pl $file | perl > plOut

	if diff pyOut plOut 
	then
		echo $file was successful
	else
		echo $file had some errors
	fi
done