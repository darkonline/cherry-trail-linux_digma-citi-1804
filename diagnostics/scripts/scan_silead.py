"""Scan a Silead Windows driver for embedded GSL firmware tables.

Firmware is stored as little-endian (u32 address, u32 value) records.
A page starts with address 0xf0 (value = page number) followed by
registers 0x00..0x7c in steps of 4.
Usage: python -I scan_silead.py <SileadTouch.sys> [out_dir]
"""
import struct
import sys
import os
import hashlib


def valid_addr(a):
    return a == 0xF0 or (a < 0x80 and a % 4 == 0)


def find_runs(data, min_records=64):
    runs = []
    n = len(data)
    for align in range(4):
        i = align
        while i + 8 <= n:
            a = struct.unpack_from("<I", data, i)[0]
            if a != 0xF0:
                i += 4
                continue
            j = i
            while j + 8 <= n and valid_addr(struct.unpack_from("<I", data, j)[0]):
                j += 8
            count = (j - i) // 8
            if count >= min_records:
                runs.append((i, j, count))
                i = j
            else:
                i += 4
    runs.sort()
    return runs


def main():
    path = sys.argv[1]
    out_dir = sys.argv[2] if len(sys.argv) > 2 else None
    data = open(path, "rb").read()
    print("file size", len(data), "sha256", hashlib.sha256(data).hexdigest())
    runs = find_runs(data)
    print("candidate tables:", len(runs))
    for idx, (s, e, c) in enumerate(runs):
        blob = data[s:e]
        recs = [struct.unpack_from("<II", blob, k) for k in range(0, len(blob), 8)]
        pages = [v for a, v in recs if a == 0xF0]
        print(f"#{idx}: offset 0x{s:x}-0x{e:x} records {c} bytes {len(blob)} "
              f"pages {len(pages)} first {pages[:6]} last {pages[-3:]}")
        print("   first records:", [(hex(a), hex(v)) for a, v in recs[:4]])
        print("   after table  :", data[e:e + 32].hex())
        if out_dir:
            name = os.path.join(out_dir, f"silead_table_{idx}.fw")
            open(name, "wb").write(blob)
            print("   saved", name, hashlib.sha256(blob).hexdigest()[:16])


if __name__ == "__main__":
    main()
