#!/usr/bin/python3.6

import re

resub = "re.search.split()"
re = re.sub(r"\.",r"\\", resub)
print(re)