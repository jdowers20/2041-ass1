
#!/usr/bin/python3.6
import fileinput, re, sys
for line in sys.stdin.readlines():
    line = re.sub(r'[aeiou]', '', line)
    print(line, end=",\n")
    m = re.match(r'(.*),(.*)', line)
    if not m:
        continue
    first_name = m.group(1)
    print(first_name)

course_names = {}
for line in open("course_codes"):
    m = re.match(r'(\S+)\s+(.*\S)', line)
    if m:
        print(m.group(1), m.group(2));
