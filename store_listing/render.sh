#!/bin/sh
# Renders the Play assets from src/ into export/ (24-bit PNG, no alpha).
# Needs Google Chrome and Python with Pillow.
set -e
cd "$(dirname "$0")"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
SRC="file://$PWD/src"
shoot() { # url width height out
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
    --allow-file-access-from-files --virtual-time-budget=3000 \
    --window-size="$2,$3" --screenshot="$4" "$1" >/dev/null 2>&1
}
names="tracking blocking focus-session daily-limits schedules weekly-progress focus-habit"
i=1
for name in $names; do
  shoot "$SRC/shot.html?n=$i" 1080 1920 "export/phone/0$i-$name.png"
  i=$((i + 1))
done
shoot "$SRC/feature_graphic.html" 1024 500 export/feature-graphic.png
shoot "$SRC/facebook_poster.html" 1080 1350 export/facebook-poster.png
shoot "$SRC/linkedin_post.html" 1200 1200 export/linkedin-post.png
python3 - <<'EOF'
from pathlib import Path
from PIL import Image
files = sorted(Path('export/phone').glob('*.png'))
for f in files + [Path(p) for p in ('export/feature-graphic.png', 'export/facebook-poster.png', 'export/linkedin-post.png')]:
    Image.open(f).convert('RGB').save(f, optimize=True)  # Play: no alpha
# Preview of the whole set: feature graphic above the 7 screenshots.
shots = [Image.open(f).resize((360, 640), Image.LANCZOS) for f in files]
gap, w = 24, 7 * 360 + 8 * 24
sheet = Image.new('RGB', (w, 2 * gap + 500 + gap + 640 + gap), '#141B1E')
sheet.paste(Image.open('export/feature-graphic.png'), ((w - 1024) // 2, 2 * gap))
for i, s in enumerate(shots):
    sheet.paste(s, (gap + i * (360 + gap), 3 * gap + 500))
sheet.save('export/preview.png', optimize=True)
EOF
echo "Rendered into $PWD/export"
