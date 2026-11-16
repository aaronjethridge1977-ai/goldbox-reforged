#!/usr/bin/env python3
"""termvid.py <script log> <script timing> <out.mkv> [hold seconds]: renders a `script --log-timing` recording
(plain lines, no escape codes) as a terminal video, 1280x800, 30 fps, lossless (ffv1), at the recorded pace.
The home folder is shown as ~ (no user name on screen). Chat 36, showcase item 4."""
import os, re, subprocess, sys
from PIL import Image, ImageDraw, ImageFont

log, tim, out = sys.argv[1:4]
hold = float(sys.argv[4]) if len(sys.argv) > 4 else 4.0
data = open(log, "rb").read()
first_nl = data.index(b"\n") + 1          # skip "Script started ..." (not in the timing's byte count)
events, t, pos = [], 0.0, first_nl
for line in open(tim):
    d, n = line.split()[:2]
    t += float(d); n = int(n)
    events.append((t, data[pos:pos + n].decode("utf-8", "replace"))); pos += n
W, H, FPS = 1280, 800, 30
font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 24)
LH, X0, Y0 = 32, 28, 24
rows = (H - 2 * Y0) // LH
home = os.path.expanduser("~")
p = subprocess.Popen(["ffmpeg", "-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "%dx%d" % (W, H),
                      "-r", str(FPS), "-i", "-", "-c:v", "ffv1", out], stdin=subprocess.PIPE)
text, ei, end = "", 0, events[-1][0] + hold
for f in range(int(end * FPS) + 1):
    now = f / FPS
    while ei < len(events) and events[ei][0] <= now:
        text += events[ei][1]; ei += 1
    shown = text.replace(home, "~").replace("\r", "")
    lines = shown.split("\n")[-rows:]
    im = Image.new("RGB", (W, H), (16, 18, 22))
    dr = ImageDraw.Draw(im)
    for i, ln in enumerate(lines):
        col = (120, 220, 120) if "MATCH" in ln or "0 differences" in ln or "18/18" in ln else (220, 220, 220)
        if ln.startswith("$"):
            col = (130, 180, 255)
        dr.text((X0, Y0 + i * LH), ln, font=font, fill=col)
    if int(now * 2) % 2 == 0:              # cursor
        cx = X0 + int(dr.textlength(lines[-1], font=font))
        dr.rectangle([cx + 2, Y0 + (len(lines) - 1) * LH + 4, cx + 14, Y0 + len(lines) * LH - 4], fill=(200, 200, 200))
    p.stdin.write(im.tobytes())
p.stdin.close(); p.wait()
print("%s: %.1f s" % (out, end))
