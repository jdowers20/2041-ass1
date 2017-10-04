#!/usr/bin/python3
# written by andrewt@cse.unsw.edu.au, adapted
# retrive course codes

import fileinput, re

course_names = []
for line in open("course_codes"):
    m = re.match(r'(\S+)\s+(.*\S)', line)
    if m:
        course_names.append(m.group(2))

for course in course_names:
    print("%s"%(course))