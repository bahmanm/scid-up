#!/usr/bin/env python3
import re, sys, pathlib

ARROW = re.compile(r'\[%\s*draw\s+arrow\s*,([a-h][1-8]),([a-h][1-8]),([A-Za-z]+)\]')
CIRC  = re.compile(r'\[%\s*draw\s+circle\s*,([a-h][1-8]),([A-Za-z]+)\]')
COL   = {'red':'R','blue':'B','yellow':'Y','green':'G','orange':'O','cyan':'C'}

def mapc(c): return COL.get(c.lower(), 'G')

def convert(text:str)->str:
    text = ARROW.sub(lambda m: f"[%cal {mapc(m[3])}{m[1]}{m[2]}]", text)
    text = CIRC.sub(lambda m: f"[%csl {mapc(m[2])}{m[1]}]", text)
    return text

def main(inp, out=None):
    with open(inp, encoding='utf8') as f: data=f.read()
    new = convert(data)
    (open(out,'w',encoding='utf8') if out else sys.stdout).write(new)

if __name__=="__main__":
    if len(sys.argv)<2: sys.exit("usage: conv_marker.py IN [OUT]")
    main(*sys.argv[1:])
