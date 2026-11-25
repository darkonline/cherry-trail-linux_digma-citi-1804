#!/usr/bin/env python3
"""Show or set the kernel jitter filter ("fuzz") of the silead touchscreen.

Run as root:  sudo python3 touch-fuzz.py              -> show
              sudo python3 touch-fuzz.py 32 4         -> fuzz for ABS_MT_POSITION_X, ABS_MT_POSITION_Y
The axes are named as evtest shows them (after the x/y swap). Not persistent: a reboot resets it.
The kernel ignores a change smaller than fuzz/2, smooths changes up to 2*fuzz.
"""
import fcntl
import glob
import struct
import sys

ABS_X, ABS_Y, ABS_MT_X, ABS_MT_Y = 0x00, 0x01, 0x35, 0x36
FMT = "6i"  # struct input_absinfo: value, minimum, maximum, fuzz, flat, resolution
SIZE = struct.calcsize(FMT)


def ioc(direction, nr):
    return (direction << 30) | (SIZE << 16) | (ord("E") << 8) | nr


def eviocgabs(axis):
    return ioc(2, 0x40 + axis)  # _IOR


def eviocsabs(axis):
    return ioc(1, 0xC0 + axis)  # _IOW


def find_device():
    for name_file in sorted(glob.glob("/sys/class/input/event*/device/name")):
        with open(name_file) as f:
            if f.read().strip() == "silead_ts":
                return "/dev/input/" + name_file.split("/")[4]
    sys.exit("silead_ts not found")


def main():
    dev = find_device()
    axes = {"ABS_MT_POSITION_X": ABS_MT_X, "ABS_MT_POSITION_Y": ABS_MT_Y,
            "ABS_X": ABS_X, "ABS_Y": ABS_Y}
    with open(dev, "rb") as fd:
        if len(sys.argv) == 3:
            for axis, fuzz in ((ABS_MT_X, int(sys.argv[1])), (ABS_MT_Y, int(sys.argv[2]))):
                info = list(struct.unpack(FMT, fcntl.ioctl(fd, eviocgabs(axis), bytes(SIZE))))
                info[3] = fuzz
                fcntl.ioctl(fd, eviocsabs(axis), struct.pack(FMT, *info))
        elif len(sys.argv) != 1:
            sys.exit(__doc__)
        print(dev)
        for name, axis in axes.items():
            v, mn, mx, fuzz, flat, res = struct.unpack(FMT, fcntl.ioctl(fd, eviocgabs(axis), bytes(SIZE)))
            print(f"{name:18} min {mn:5} max {mx:5} fuzz {fuzz:3} flat {flat}")


if __name__ == "__main__":
    main()
