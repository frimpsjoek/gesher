"""Cross-build function matcher: masked instruction fingerprints + structural evidence."""
import sys, json
from macho import Bin, strings_containing
from characterise import OFFS, func_strings

def mask(w):
    if (w & 0xFC000000) in (0x94000000, 0x14000000): return w & 0xFC000000          # BL / B
    if (w & 0x9F000000) in (0x90000000, 0x10000000): return w & 0x9F00001F          # ADRP / ADR
    if (w & 0xFF000010) == 0x54000000: return w & 0xFF00001F                        # B.cond
    if (w & 0x7E000000) in (0x34000000, 0x36000000): return w & 0xFF00001F          # CBZ/CBNZ/TBZ/TBNZ
    if (w & 0xFFC00000) in (0x91000000, 0xF9400000, 0xB9400000, 0xF9000000): return w & 0xFFC003FF  # ADD imm / LDR/STR imm (page offs)
    if (w & 0x3B000000) == 0x18000000: return w & 0xFF00001F                        # LDR literal
    if (w & 0xFF800000) in (0xD2800000, 0xF2800000, 0x52800000, 0x72800000): return w & 0xFFE0001F  # MOVZ/MOVK imm (hashes, discriminators)
    return w

def body(b, start, maxn=4000):
    i0 = (start - b.t0) // 4; out = []
    for k in range(i0, min(i0 + maxn, len(b.words))):
        if k > i0 and b.words[k] == 0xD503237F: break
        out.append(b.words[k])
    return out

def fingerprint(b, start, n):
    return tuple(mask(w) for w in body(b, start)[:n])

def index_all(b, n):
    idx = {}
    for i, w in enumerate(b.words):
        if w == 0xD503237F:
            st = b.t0 + i * 4
            idx.setdefault(fingerprint(b, st, n), []).append(st)
    return idx

if __name__ == "__main__":
    old, new = Bin(sys.argv[1]), Bin(sys.argv[2])
    targets = dict(OFFS)
    results = {}
    for n in (400, 160, 64, 32):
        idx = index_all(new, n)
        for k, off in targets.items():
            if k in results: continue
            st = old.func_start(off)
            if st != off: continue        # non-pacibsp leaf (accessors) -> handled elsewhere
            fp = fingerprint(old, off, n)
            if len(fp) < min(n, 24): fp_short = True
            m = idx.get(fp, [])
            if len(m) == 1:
                results[k] = (m[0], n, len(body(old, off)), len(body(new, m[0])))
    for k in targets:
        r = results.get(k)
        print(f"{k:30s} 5.0={targets[k]:#x}  ->  {hex(r[0]) if r else 'NO UNIQUE MATCH'}  {'(n=%d, len %d/%d)' % r[1:] if r else ''}")
    json.dump({k: v[0] for k, v in results.items()}, open("fp_matches.json", "w"), indent=1)
