#!/usr/bin/python3.6

i = 0
while (i < 4): print(i);i = i + 1

while(i < 6):
	i = i + 1
	print(i)

if (i == 6):
	print(i);
	i = i + 1 ; print(i)

while i < 10:
	i = i + 1;
	if (i % 2 == 0):
		continue;
	print(i)

while i < 15:
	j = 0
	while j < 5: print(j); j = j + 1
	i = i + 1
	if j == 5:
		break


print(i)
