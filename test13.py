#!/usr/bin/python3.6
import sys
a = "hello how are you"
print(a.split())
print(a.split("e"))

print("hello world".split())

b = a.split()
print("".join(b))
print(" ".join(b))
print(":".join(b))
print(" ".join(b))

print(' '.join(sys.argv[1:]))
