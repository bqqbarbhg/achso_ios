#!/usr/bin/env python

import sys, re, glob

RE_PARSE = re.compile(r'@parse\(([a-zA-Z0-9_./*]+)\)')
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

        paths = glob.glob(match.group(1))

        for path in paths:
            filename = path.split('/')[-1]
            output.append(RE_PARSE.sub(filename, line))

            with open(path, 'r') as parsefile:
                try:
                    lineit = iter(parsefile)
                    if next(lineit).strip() != '/*':
                        continue
                    if next(lineit).strip() != '':
                        continue

                    for pline in lineit:
                        pline = pline.rstrip()
                        if pline == '*/':
                            break

                        pline = RE_FILENAME.sub(makelink, pline)

                        output.append(pline)

                except StopIteration:
                    pass
            

with open(sys.argv[2], 'w') as outfile:
    outfile.write('\n'.join(output))

