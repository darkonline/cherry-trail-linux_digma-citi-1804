#!/usr/bin/env python3
"""citi1804: copy the user's wallpaper to /var/lib/citi1804/wallpaper.png.

That PNG is used by the login screen (phrog, through a GSettings default) and by phoc as the
picture under the startup spinner. Run as the normal user; started by
citi1804-wallpaper.path whenever the settings file changes, and once at login.
Does nothing if the wallpaper did not change since the last run.
"""
import os
import sys
from urllib.parse import unquote, urlparse

import gi
gi.require_version("Gdk", "4.0")
gi.require_version("GdkPixbuf", "2.0")
from gi.repository import Gdk, GdkPixbuf, Gio  # noqa: E402

OUT = "/var/lib/citi1804/wallpaper.png"
SIDE = 1920  # the short side; covers the 1200x1920 screen in both orientations
STAMP = os.path.join(os.path.expanduser("~"), ".cache", "citi1804", "wallpaper.stamp")


def current_wallpaper():
    bg = Gio.Settings.new("org.gnome.desktop.background")
    ui = Gio.Settings.new("org.gnome.desktop.interface")
    key = "picture-uri-dark" if ui.get_string("color-scheme") == "prefer-dark" else "picture-uri"
    uri = bg.get_string(key) or bg.get_string("picture-uri")
    url = urlparse(uri)
    return unquote(url.path) if url.scheme in ("file", "") else None


def main():
    if not os.access(os.path.dirname(OUT), os.W_OK):
        return 0  # not the owner of the directory (e.g. the login screen user)
    src = current_wallpaper()
    if not src or not os.path.isfile(src) or os.path.realpath(src) == OUT:
        return 0
    stamp = f"{src}\n{os.stat(src).st_mtime_ns}\n"
    try:
        with open(STAMP) as f:
            if f.read() == stamp and os.path.exists(OUT):
                return 0
    except OSError:
        pass

    tmp = OUT + ".tmp.png"
    Gdk.Texture.new_from_filename(src).save_to_png(tmp)  # any format GTK reads (JPEG XL, SVG, ...)
    pb = GdkPixbuf.Pixbuf.new_from_file(tmp)
    s = SIDE / min(pb.get_width(), pb.get_height())
    w, h = max(SIDE, round(pb.get_width() * s)), max(SIDE, round(pb.get_height() * s))
    pb.scale_simple(w, h, GdkPixbuf.InterpType.BILINEAR).savev(tmp, "png", [], [])
    os.chmod(tmp, 0o644)
    os.replace(tmp, OUT)

    os.makedirs(os.path.dirname(STAMP), exist_ok=True)
    with open(STAMP, "w") as f:
        f.write(stamp)
    print(f"wallpaper {src} -> {OUT} ({w}x{h})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
