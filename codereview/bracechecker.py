#!/usr/bin/env python
# -*- coding: utf-8 -*-
# python 3
# spec at http://xahlee.org/comp/validate_matching_brackets.html
# 2011-07-17
# by Raymond Hettinger

input_dir = "/home/xdajog/android/cm_kk/kernel/samsung/i927/drivers/usb/gadget/"

import os, re

def check_balance(characters):
    '''Return -1 if all delimiters are balanced or
       the char number of the first delimiter mismatch.

    '''
    openers = {
        '(': ')',
        '{': '}',
        '[': ']'
        }
    closers = set(openers.values())
    stack = []
    for i, c in enumerate(characters, start=1):
        if c in openers:
            stack.append(openers[c])
        elif c in closers:
            if not stack or c != stack.pop():
                return i
    if stack:
        print("MISMATCH AT:")
        print(stack)
        return i
    return -1

def scan(directory, encoding='utf-8'):
    for dirpath, dirnames, filenames in os.walk(directory):
        for filename in filenames:
            fullname = os.path.join(dirpath, filename)
            print ( "processing:" + fullname)
            with open(fullname, 'r', encoding=encoding) as f:
                try:
                    characters = f.read()
                except UnicodeDecodeError:
                    continue
            position = check_balance(characters)
            if position >= 0:
                print('{0!r}: {1}'.format(position, fullname))

scan(input_dir)

print ("done")
