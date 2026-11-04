import sys, re, collections
rom = open(sys.argv[1],'rb').read()
minlen = int(sys.argv[2]); pat = re.compile(sys.argv[3]) if len(sys.argv)>3 else None
banks = collections.Counter(); out=[]
for m in re.finditer(rb'[\x20-\x7e]{%d,}' % minlen, rom):
    s = m.group().decode()
    if sum(c.isalpha() for c in s) < len(s)*0.6: continue
    banks[m.start()>>16]+=1
    if pat and pat.search(s): out.append((m.start(), s))
for o,s in out[:80]: print(hex(o), s)
print('banks:', ' '.join(f'{b:02x}:{n}' for b,n in sorted(banks.items()) if n>20))
