#!/usr/bin/python3.6
import sys
def printer(x,y):
    print(x)
    print(y)
    return x+1

i = 0
j = 0
while (i < 5):
	i = printer(i,j)
	j += 1
	if (j == 10): break;