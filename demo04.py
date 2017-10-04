
#!/usr/bin/python3
# written by andrewt@cse.unsw.edu.au as a COMP2041 lecture example
# Count the number of lines on standard input and find all digits

import sys

lines = sys.stdin.readlines()
line_count = len(lines)
re = re.search(r"\d",lines)
print(len(re))
print("%d lines" % line_count)