import sys
rom = open(sys.argv[1],'rb').read()
for word in sys.argv[2:]:
    w = word.encode()
    diffs = [w[k+1]-w[k] for k in range(len(w)-1)]
    hits = {}
    for i in range(len(rom)-len(w)):
        ok = True
        for k,d in enumerate(diffs):
            if rom[i+k+1]-rom[i+k] != d: ok=False; break
        if ok:
            delta = rom[i]-w[0]
            hits.setdefault(delta, []).append(i)
    top = sorted(hits.items(), key=lambda kv:-len(kv[1]))[:5]
    print(word, [(d, len(v), [hex(x) for x in v[:6]]) for d,v in top])
