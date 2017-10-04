#!/usr/bin/python3.6

#Echo, adapted from week 9 challenges

import sys

words = []
for arg in sys.argv[1:]:
	words.append(arg)

for word in words:
	if (word != words[0]):
		print(" ", end='')
	print(word, end='')

print("")