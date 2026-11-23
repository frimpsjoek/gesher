"""Characterise Gesher's hand-found 5.0 offsets so they can be re-found on other builds."""
import sys, json
from macho import Bin, strings_containing
from swiftmeta import Swift

OFFS = dict(storeInit=0x877cc0, fetchBoards=0x808a44, makeNewBoard=0x131c270, allocInitBoard=0x13131b4,
            makeTransaction=0x135b8d0, markNewBoard=0x695e64, mergeDatabaseChanges=0x12fd5fc,
            appendPendingChanges=0x6deb78, setFavorite=0x80c390, setCanvasDotGrid=0x80f1c4,
            setConnectorMode=0x80f878, deleteBoard=0x7fe608, undeleteBoard=0x800dbc,
            boardCRDTDataMetadataAccessor=0xde3594, insertStyleCopyHelper=0x66f874, insertStyleTypeAccessor=0xde3ee0)

def func_strings(b, start, maxn=6000):
    """cstrings referenced (ADRP+ADD) inside function body."""
    out = []
    i0 = (start - b.t0) // 4
    for k in range(i0, min(i0 + maxn, len(b.words))):
        w = b.words[k]
        if k > i0 and w == 0xD503237F: break
        if (w & 0x9F000000) == 0x90000000:
            pc = b.t0 + k * 4
            immlo = (w >> 29) & 3; immhi = (w >> 5) & 0x7FFFF
            imm = (immhi << 2) | immlo
            if imm & (1 << 20): imm -= 1 << 21
            page = (pc & ~0xFFF) + (imm << 12); rd = w & 31
            for j in range(k + 1, min(k + 8, len(b.words))):
                w2 = b.words[j]
                if (w2 & 0xFFC00000) == 0x91000000 and ((w2 >> 5) & 31) == rd:
                    t = page + ((w2 >> 10) & 0xFFF)
                    if b.cstr.offset <= t < b.cstr.offset + b.cstr.size:
                        e = b.data.index(b"\0", t); out.append(b.data[t:e].decode("utf8", "replace")[:90])
                    break
    return out

def vt_index(s):
    idx = {}
    for c in s.classes():
        for e in c.get("vtable", []):
            if e["impl"]: idx.setdefault(e["impl"], []).append((c["name"], e["slot"], e["kind"]))
        for o in c.get("overrides", []):
            if o: idx.setdefault(o, []).append((c["name"], "override", ""))
    return idx

if __name__ == "__main__":
    b = Bin(sys.argv[1]); s = Swift(b); vt = vt_index(s)
    for k, off in OFFS.items():
        st = b.func_start(off)
        body = b.disasm(off, 6)
        callers = b.callers(off)
        print(f"== {k} {off:#x}  pacibsp_start={'yes' if st == off else hex(st) if st else None}  callers={len(callers)} {[hex(c) for c in callers[:4]]}")
        print("   vtable:", vt.get(off))
        print("   strings:", func_strings(b, off)[:6])
        print("   head:", "; ".join(f"{m} {o}" for _, m, o in body[:6]))
