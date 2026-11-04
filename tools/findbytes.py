import sys
rom = open(sys.argv[1],'rb').read()
for h in sys.argv[2:]:
    pat = bytes.fromhex(h.replace(' ',''))
    i = rom.find(pat); hits=[]
    while i!=-1 and len(hits)<40:
        hits.append(i); i = rom.find(pat, i+1)
    print(h, len(hits), ' '.join(hex(x) for x in hits))
