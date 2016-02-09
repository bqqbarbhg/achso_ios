#!/usr/bin/env python

import sys, re

RE_PARSE = re.compile(r'@parse\(([a-zA-Z0-9_./]+)\)')
RE_FILENAME = re.compile(r'[A-Za-z0-9_]+\.swift')

def makelink(match):
    text = match.group(0)
    dest = text.lower().replace('.', '')
    return '[{}](#{})'.format(text, dest)

output = []

with open(sys.argv[1], 'r') as basefile:
    for line in basefile:
        line = line.rstrip()
        match =  RE_PARSE.search(line)
        if not match:
            output.append(line)
            continue

        path = match.group(1)
        filename = path.split('/')[-1]
        output.append(RE_PARSE.sub(filename, line))

        with open(path, 'r') as parsefile:
            try:
                lineit = iter(parsefile)
                if next(lineit).strip() != '/*':
                    continue
                if next(lineit).strip() != '':
                    continue

                for line in lineit:
                    line = line.rstrip()
                    if line == '*/':
                        break

                    line = RE_FILENAME.sub(makelink, line)

                    output.append(line)

            except StopIteration:
                pass
            

with open(sys.argv[2], 'w') as outfile:
    outfile.write('\n'.join(output))

