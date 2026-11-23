"""Parse Swift class context descriptors (statically) and dump vtables with method kinds."""
import struct, sys
from macho import Bin

KINDS = {0: "method", 1: "init", 2: "getter", 3: "setter", 4: "modify", 5: "read"}

class Swift:
    def __init__(self, b: Bin):
        self.b = b; self.m = b.m
        self.base = b.base
        self.segs = [(s.virtual_address, s.virtual_address + s.virtual_size, s.file_offset) for s in self.m.segments]

    def off(self, va):
        for lo, hi, fo in self.segs:
            if lo <= va < hi: return fo + (va - lo)
        return None

    def u32(self, va): return struct.unpack_from("<I", self.b.data, self.off(va))[0]
    def i32(self, va): return struct.unpack_from("<i", self.b.data, self.off(va))[0]
    def rel(self, va):
        r = self.i32(va)
        return None if r == 0 else va + r
    def cstr(self, va):
        o = self.off(va)
        if o is None: return None
        e = self.b.data.index(b"\0", o)
        return self.b.data[o:e].decode("utf8", "replace")

    def types(self):
        sec = [s for s in self.m.sections if s.name == "__swift5_types"][0]
        va = sec.virtual_address
        for i in range(sec.size // 4):
            p = va + i * 4
            t = p + self.i32(p)
            if t & 1:   # indirect
                continue
            yield t

    def parent_name(self, d):
        p = self.rel(d + 4)
        if p is None or p & 1: return ""
        try:
            fl = self.u32(p)
            if fl & 0x1F in (16, 17, 18):
                return self.parent_name(p) + self.cstr(self.rel(p + 8)) + "."
        except Exception:
            pass
        return ""

    def class_info(self, d):
        flags = self.u32(d)
        kind = flags & 0x1F
        if kind != 16: return None
        name = self.cstr(self.rel(d + 8))
        generic = bool(flags & 0x80)
        ks = flags >> 16
        has_vtable = bool(ks & 0x8000)
        has_override = bool(ks & 0x4000)
        resilient_super = bool(ks & 0x2000)
        minit = ks & 3
        p = d + 44   # after the 11 fixed u32 fields
        if generic:
            return dict(name=name, generic=True)
        if resilient_super: p += 4
        if minit == 1: p += 12
        elif minit == 2: p += 4
        info = dict(name=self.parent_name(d) + name, desc=d, generic=False, vtable=[], overrides=[])
        if has_vtable:
            voff, vsize = self.u32(p), self.u32(p + 4); p += 8
            info["vtable_offset_words"] = voff
            for i in range(vsize):
                fl = self.u32(p); impl = self.rel(p + 4)
                info["vtable"].append(dict(slot=voff + i, byte=(voff + i) * 8, kind=KINDS.get(fl & 0xF, fl & 0xF),
                                           instance=bool(fl & 0x10), dynamic=bool(fl & 0x20), asyncf=bool(fl & 0x40),
                                           impl=(impl - self.base) if impl else None))
                p += 8
        if has_override:
            n = self.u32(p); p += 4
            for i in range(n):
                impl = self.rel(p + 8)
                info["overrides"].append((impl - self.base) if impl else None)
                p += 12
        return info

    def classes(self):
        for d in self.types():
            try:
                ci = self.class_info(d)
            except Exception:
                ci = None
            if ci: yield ci

if __name__ == "__main__":
    b = Bin(sys.argv[1]); s = Swift(b)
    pats = sys.argv[2:]
    for c in s.classes():
        if any(p in c["name"] for p in pats):
            print(f"== {c['name']}  vtable@{c.get('vtable_offset_words')} n={len(c.get('vtable', []))} overrides={len(c.get('overrides', []))}")
            for e in c.get("vtable", []):
                print(f"   slot {e['slot']:3d} byte {e['byte']:#06x} {e['kind']:7s} {'async' if e['asyncf'] else ''} {hex(e['impl']) if e['impl'] else None}")
