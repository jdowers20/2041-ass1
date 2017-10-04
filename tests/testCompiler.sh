#!/bin/sh

for file in $@
do
	echo "======python test for $file======"
	python3.6 $file > pyOut
	cat pyOut

	echo "======perl test for $file======"
	./pypl.pl $file > ./tmp.pl
	cat ./tmp.pl
	echo ">>>>running<<<<<<<"
	./tmp.pl > plOut
	cat plOut

	if diff pyOut plOut 
	then
		echo $file was successful
	else
		echo $file had some errors
	fi
done