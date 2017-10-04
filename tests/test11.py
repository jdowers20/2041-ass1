#!/usr/bin/python3.6

import sys

testDict = {}
testDict["name"] = "test";
print(testDict["name"])
#print(sys.stdin.readlines(), end =   '')

count = {}
for line in sys.stdin.readlines():
    course = line
    if (defined count[course]):
        count[course] += 1
    else:
        count[course] = 1

for course in sorted(count.keys()):
    print("%s has %s students enrolled"%(course, count[course]))