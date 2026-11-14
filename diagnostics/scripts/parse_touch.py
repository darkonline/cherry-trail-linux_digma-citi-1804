"""Decode a raw Linux evdev dump (cat /dev/input/eventN) from x86_64.

Groups events into separate taps (split by pauses) and prints the raw
coordinates of each tap, plus any key events.
Usage: python -I parse_touch.py <touch.bin>
"""
import struct
import sys
import statistics

EV_SYN, EV_KEY, EV_ABS = 0, 1, 3
ABS_NAMES = {0x00: "ABS_X", 0x01: "ABS_Y", 0x2F: "MT_SLOT", 0x30: "MT_TOUCH_MAJOR",
             0x32: "MT_WIDTH_MAJOR", 0x35: "MT_POSITION_X", 0x36: "MT_POSITION_Y",
             0x39: "MT_TRACKING_ID", 0x3A: "MT_PRESSURE"}
KEY_NAMES = {125: "KEY_LEFTMETA", 0x14A: "BTN_TOUCH", 102: "KEY_HOME", 172: "KEY_HOMEPAGE"}
REC = struct.Struct("<qqHHi")
GAP = 0.8  # seconds of silence that separates two taps


def main():
    data = open(sys.argv[1], "rb").read()
    n = len(data) // REC.size
    print(f"file bytes {len(data)}, records {n}, leftover {len(data) % REC.size}")
    if n == 0:
        print("no events recorded")
        return
    events = []
    for i in range(n):
        sec, usec, etype, code, value = REC.unpack_from(data, i * REC.size)
        events.append((sec + usec / 1e6, etype, code, value))
    t0 = events[0][0]
    types = {}
    for _, etype, code, _ in events:
        types[(etype, code)] = types.get((etype, code), 0) + 1
    print("event kinds seen:")
    for (etype, code), cnt in sorted(types.items()):
        name = ABS_NAMES.get(code, hex(code)) if etype == EV_ABS else (
            KEY_NAMES.get(code, f"key {code}") if etype == EV_KEY else f"type{etype}/{code}")
        print(f"   type {etype} {name}: {cnt}")

    taps, cur, last_t = [], [], None
    for ev in events:
        if last_t is not None and ev[0] - last_t > GAP and cur:
            taps.append(cur)
            cur = []
        cur.append(ev)
        last_t = ev[0]
    if cur:
        taps.append(cur)

    allx, ally = [], []
    print(f"\ntaps found: {len(taps)}")
    for idx, tap in enumerate(taps, 1):
        xs = [v for _, t, c, v in tap if t == EV_ABS and c in (0x35,)]
        ys = [v for _, t, c, v in tap if t == EV_ABS and c in (0x36,)]
        slots = sorted({v for _, t, c, v in tap if t == EV_ABS and c == 0x2F})
        keys = [(KEY_NAMES.get(c, f"key {c}"), v) for _, t, c, v in tap if t == EV_KEY]
        allx += xs
        ally += ys
        def desc(vals):
            if not vals:
                return "none"
            return f"first {vals[0]} median {int(statistics.median(vals))} min {min(vals)} max {max(vals)} (n={len(vals)})"
        print(f"#{idx}: t={tap[0][0] - t0:6.2f}s dur={tap[-1][0] - tap[0][0]:.2f}s events={len(tap)}")
        print(f"     X: {desc(xs)}")
        print(f"     Y: {desc(ys)}")
        if slots:
            print(f"     slots: {slots}")
        if keys:
            print(f"     keys: {keys}")
    if allx and ally:
        print(f"\noverall X range {min(allx)}..{max(allx)}, Y range {min(ally)}..{max(ally)}")


if __name__ == "__main__":
    main()
