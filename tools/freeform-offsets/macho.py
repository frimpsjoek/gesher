"""Static, read-only analysis of a Freeform arm64e Mach-O (no process, no store access).
Offsets are relative to the Mach-O header (= what Gesher's verifiedBuilds uses).
"""
import struct, sys, functools, re
import lief, capstone

PACIBSP = 0xD503237F

class Bin:
    def __init__(self, path):
        self.path = path
        self.m = lief.MachO.parse(path).at(0)
        self.data = open(path, "rb").read()
        text_seg = self.m.get_segment("__TEXT")
        self.base = text_seg.virtual_address             # header vmaddr
        s = {sec.name: sec for sec in self.m.sections}
        self.text = s["__text"]; self.cstr = s["__cstring"]
        self.t0 = self.text.offset; self.tn = self.text.size
        self.words = struct.unpack_from(f"<{self.tn//4}I", self.data, self.t0)
        self.cs = capstone.Cs(capstone.CS_ARCH_ARM64, capstone.CS_MODE_ARM)
        self.uuid = str(self.m.uuid) if self.m.has_uuid else None
        self._funcs = None

    # ---- strings
    def cstrings(self, needle):
        b = needle.encode()
        lo, n = self.cstr.offset, self.cstr.size
        blob = self.data[lo:lo + n]
        out = []
        for mt in re.finditer(re.escape(b), blob):
            i = mt.start()
            if (i == 0 or blob[i-1] == 0) and (i + len(b) == n or blob[i+len(b)] == 0):
                out.append(lo + i)
        return out

    def find_bytes_in_section(self, secname, needle):
        sec = [s for s in self.m.sections if s.name == secname][0]
        blob = self.data[sec.offset:sec.offset + sec.size]
        return [sec.offset + m.start() for m in re.finditer(re.escape(needle), blob)]

    # ---- xrefs: ADRP + (ADD|LDR) within 6 insns
    @functools.lru_cache(maxsize=None)
    def adrp_index(self):
        idx = {}
        for i, w in enumerate(self.words):
            if (w & 0x9F000000) == 0x90000000:
                pc = self.t0 + i * 4
                immlo = (w >> 29) & 3; immhi = (w >> 5) & 0x7FFFF
                imm = (immhi << 2) | immlo
                if imm & (1 << 20): imm -= 1 << 21
                page = (pc & ~0xFFF) + (imm << 12)
                idx.setdefault(page, []).append((i, w & 31))
        return idx

    def xrefs(self, target):
        page, off = target & ~0xFFF, target & 0xFFF
        res = []
        for i, rd in self.adrp_index().get(page, []):
            for j in range(i + 1, min(i + 8, len(self.words))):
                w = self.words[j]
                # ADD Xd, Xn, #imm (64-bit, no shift)
                if (w & 0xFFC00000) == 0x91000000 and ((w >> 5) & 31) == rd and ((w >> 10) & 0xFFF) == off:
                    res.append(self.t0 + j * 4); break
                # LDR Xt, [Xn, #imm*8]
                if (w & 0xFFC00000) == 0xF9400000 and ((w >> 5) & 31) == rd and ((w >> 10) & 0xFFF) * 8 == off:
                    res.append(self.t0 + j * 4); break
        return res

    # ---- functions
    def func_start(self, off):
        i = (off - self.t0) // 4
        while i >= 0:
            if self.words[i] == PACIBSP: return self.t0 + i * 4
            i -= 1
        return None

    def func_starts(self):
        if self._funcs is None:
            fs = [self.t0 + i * 4 for i, w in enumerate(self.words) if w == PACIBSP]
            # LC_FUNCTION_STARTS is authoritative when present
            try:
                fs2 = sorted(f.address for f in self.m.function_starts.functions) if False else None
            except Exception:
                fs2 = None
            self._funcs = fs
        return self._funcs

    def func_by_string(self, s):
        offs = self.cstrings(s)
        if len(offs) != 1: return None, f"string count {len(offs)}"
        fns = sorted({self.func_start(x) for x in self.xrefs(offs[0])})
        if len(fns) != 1: return None, f"funcs {[hex(f) for f in fns]}"
        return fns[0], "ok"

    def disasm(self, off, n=40):
        code = self.data[off:off + n * 4]
        return [(i.address, i.mnemonic, i.op_str) for i in self.cs.disasm(code, off)]

    def bl_targets(self, start, maxn=4000):
        """BL targets from function start until next pacibsp/ret-ish boundary."""
        out = []
        i = (start - self.t0) // 4
        for k in range(i, min(i + maxn, len(self.words))):
            w = self.words[k]
            if k > i and w == PACIBSP: break
            if (w & 0xFC000000) == 0x94000000:
                imm = w & 0x3FFFFFF
                if imm & (1 << 25): imm -= 1 << 26
                out.append((self.t0 + k * 4, self.t0 + k * 4 + imm * 4))
        return out

    def callers(self, target):
        out = []
        for k, w in enumerate(self.words):
            if (w & 0xFC000000) in (0x94000000, 0x14000000):
                imm = w & 0x3FFFFFF
                if imm & (1 << 25): imm -= 1 << 26
                if self.t0 + k * 4 + imm * 4 == target: out.append(self.t0 + k * 4)
        return out

ANCHORS = {
    "fetchBoards": "Failed to fetch boardAndContainerData for board %{public}@",
    "setFavorite": "Set favorite status to [%{public}@] for board identifier: %{public}@",
    "setCanvasDotGrid": "Set canvas dot grid visible to [%{public}@] for board identifier: %{public}@",
    "setConnectorMode": "Set connector mode enabled to [%{public}@] for board identifier: %{public}@",
    "deleteBoard": "Failed to mark board as deleted",
    "undeleteBoard": "Failed to reset board deletion",
    "appendPendingChanges": "Pending changes should only come from closed transactions.",
}

if __name__ == "__main__":
    b = Bin(sys.argv[1])
    print("uuid", b.uuid, "text", hex(b.t0), hex(b.tn))
    for k, s in ANCHORS.items():
        f, why = b.func_by_string(s)
        print(f"{k:22s} {hex(f) if f else None}  {why}")

def strings_containing(b, sub):
    blob = b.data[b.cstr.offset:b.cstr.offset + b.cstr.size]
    out = []; i = 0; s = sub.encode()
    while (j := blob.find(s, i)) != -1:
        st = blob.rfind(b"\0", 0, j) + 1; en = blob.find(b"\0", j)
        out.append((b.cstr.offset + st, blob[st:en].decode("utf8", "replace"))); i = en
    return out

def funcs_for_sub(b, sub):
    res = {}
    for off, s in strings_containing(b, sub):
        for x in b.xrefs(off):
            res.setdefault(b.func_start(x), []).append(s[:70])
    return res
