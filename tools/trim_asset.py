#!/usr/bin/env python3
"""
trim_asset.py
-------------
PNG asset'lerinden fazladan boşluğu kaldırır ve gerçek içerik boyutunu raporlar.

Desteklenen arka plan tipleri:
  • RGBA  — alpha=0 olan piksel satır/sütunları kesilir
  • RGB   — beyaz / açık gri arka plan flood-fill ile tespit edilir, sonra kesilir

Kullanım:
  python3 trim_asset.py dosya.png              → trimmed/ klasörüne yazar
  python3 trim_asset.py klasor/                → klasördeki tüm PNG'lere uygular
  python3 trim_asset.py dosya.png --inplace    → orijinal dosyanın üzerine yazar
  python3 trim_asset.py dosya.png --dry        → kesmez, sadece ölçüleri gösterir
"""

import sys
import os
import argparse
import numpy as np
from pathlib import Path
from collections import deque
from typing import Optional

try:
    from PIL import Image
except ImportError:
    print("Pillow yüklü değil. Çalıştır: pip3 install Pillow")
    sys.exit(1)


# ─── ARKA PLAN TESPİTİ ────────────────────────────────────────────────────────

def _make_alpha_mask(img: Image.Image) -> np.ndarray:
    """RGBA görsel için: alpha > 10 olan pikseller True döner."""
    rgba = np.array(img.convert("RGBA"))
    return rgba[:, :, 3] > 10


def _is_background_color(r, g, b, threshold=220) -> bool:
    return int(r) > threshold and int(g) > threshold and int(b) > threshold


def _erode_content(mask: np.ndarray, data: np.ndarray, threshold: int) -> np.ndarray:
    """
    İçerik maskesinin kenarındaki açık renkli pikselleri de siler.
    Gürültülü antialiasing piksellerini temizlemek için kullanılır.
    """
    import numpy as np
    result = mask.copy()
    h, w = mask.shape
    # Maske kenarındaki (içerik=True, komşu=False) pikselleri tara
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            if not result[y, x]:
                continue
            if (result[y-1,x] and result[y+1,x] and result[y,x-1] and result[y,x+1]):
                continue  # tamamen iç piksel, dokunma
            r, g, b = int(data[y, x, 0]), int(data[y, x, 1]), int(data[y, x, 2])
            if _is_background_color(r, g, b, threshold - 30):
                result[y, x] = False
    return result


def _flood_fill_bg(data: np.ndarray, threshold=220) -> np.ndarray:
    """
    RGB/RGBA görsel için tüm kenar piksellerinden BFS flood-fill ile arka plan maskesi üretir.
    Geri dönüş: arka plan olan piksel = True, içerik = False.
    """
    h, w = data.shape[:2]
    bg = np.zeros((h, w), dtype=bool)
    q = deque()

    # Tüm kenar pikselleri (4 köşe değil, tüm çerçeve)
    edge_pixels = (
        [(0, x) for x in range(w)] +
        [(h - 1, x) for x in range(w)] +
        [(y, 0) for y in range(1, h - 1)] +
        [(y, w - 1) for y in range(1, h - 1)]
    )
    for sy, sx in edge_pixels:
        r, g, b = data[sy, sx, 0], data[sy, sx, 1], data[sy, sx, 2]
        if _is_background_color(r, g, b, threshold) and not bg[sy, sx]:
            q.append((sy, sx))
            bg[sy, sx] = True

    while q:
        y, x = q.popleft()
        for ny, nx in [(y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)]:
            if 0 <= ny < h and 0 <= nx < w and not bg[ny, nx]:
                r, g, b = data[ny, nx, 0], data[ny, nx, 1], data[ny, nx, 2]
                if _is_background_color(r, g, b, threshold):
                    bg[ny, nx] = True
                    q.append((ny, nx))

    return bg  # True = arka plan


def content_mask(img: Image.Image, threshold: int = 220) -> np.ndarray:
    """İçerik olan pikseller True, arka plan False döner."""
    if img.mode == "RGBA":
        alpha = np.array(img)[:, :, 3]
        if alpha.min() == 0:
            # Alpha kanalı var — önce alpha maskesi, sonra RGB flood-fill ile kalıntıları temizle
            alpha_mask = alpha > 10
            rgb = np.array(img.convert("RGB"))
            bg = _flood_fill_bg(rgb, threshold)
            return alpha_mask & ~bg
    rgb = np.array(img.convert("RGB"))
    return ~_flood_fill_bg(rgb, threshold)


# ─── BOUNDING BOX ─────────────────────────────────────────────────────────────

def bounding_box(mask: np.ndarray):
    """İçerik maskesinden (True=içerik) sıkı bounding box döner: (top, left, bottom, right)"""
    rows = np.any(mask, axis=1)
    cols = np.any(mask, axis=0)
    if not rows.any():
        return None  # tamamen boş
    top    = int(np.argmax(rows))
    bottom = int(len(rows) - np.argmax(rows[::-1]))
    left   = int(np.argmax(cols))
    right  = int(len(cols) - np.argmax(cols[::-1]))
    return top, left, bottom, right


# ─── TEK DOSYA İŞLE ───────────────────────────────────────────────────────────

def process(src: Path, dst: Optional[Path], dry: bool, threshold: int = 220) -> dict:
    img = Image.open(src)
    orig_w, orig_h = img.size

    mask = content_mask(img, threshold)
    box  = bounding_box(mask)

    if box is None:
        return {"file": src.name, "status": "BOŞ", "orig": (orig_w, orig_h)}

    top, left, bottom, right = box
    new_w = right - left
    new_h = bottom - top

    saved_px  = orig_w * orig_h - new_w * new_h
    saved_pct = saved_px / (orig_w * orig_h) * 100

    result = {
        "file":      src.name,
        "status":    "OK",
        "orig":      (orig_w, orig_h),
        "trimmed":   (new_w, new_h),
        "box":       (left, top, right, bottom),   # PIL crop formatı: L,T,R,B
        "saved_pct": saved_pct,
    }

    if not dry and dst is not None:
        # RGBA olarak kes ve kaydet
        rgba = img.convert("RGBA")
        # Arka planı şeffafa çevir (RGBA modunda bile olsa)
        arr = np.array(rgba)
        arr[~mask, 3] = 0
        cleaned = Image.fromarray(arr, "RGBA")
        cropped = cleaned.crop((left, top, right, bottom))
        dst.parent.mkdir(parents=True, exist_ok=True)
        cropped.save(dst, "PNG")
        result["saved_to"] = str(dst)

    return result


def _fmt(r: dict) -> str:
    if r["status"] == "BOŞ":
        return f"  ⚠  {r['file']}  →  TAMAMEN BOŞ"
    orig_w, orig_h   = r["orig"]
    trim_w, trim_h   = r["trimmed"]
    l, t, ri, b     = r["box"]
    pct              = r["saved_pct"]
    saved_to         = f"  →  {r.get('saved_to', '(dry)')}"
    return (
        f"  ✓  {r['file']}\n"
        f"     Orijinal : {orig_w} × {orig_h} px\n"
        f"     Trimmed  : {trim_w} × {trim_h} px  "
        f"(kırpılan alan: %{pct:.1f})\n"
        f"     BBox     : sol={l} üst={t} sağ={ri} alt={b}{saved_to}"
    )


# ─── ANA ──────────────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("input",  help="PNG dosyası veya klasör yolu")
    ap.add_argument("--inplace", action="store_true",
                    help="Orijinal dosyanın üzerine yaz")
    ap.add_argument("--dry",     action="store_true",
                    help="Sadece ölçüleri göster, dosyaya yazma")
    ap.add_argument("--out", default=None,
                    help="Çıktı klasörü (varsayılan: 'trimmed/' alt klasörü)")
    ap.add_argument("--threshold", type=int, default=220,
                    help="Arka plan beyazlık eşiği 0-255 (varsayılan: 220, düşürdükçe daha agresif)")
    args = ap.parse_args()

    src_path = Path(args.input)

    # Dosya listesi
    if src_path.is_dir():
        files = sorted(src_path.glob("*.png")) + sorted(src_path.glob("*.PNG"))
    elif src_path.is_file():
        files = [src_path]
    else:
        print(f"Hata: '{src_path}' bulunamadı.")
        sys.exit(1)

    if not files:
        print("PNG dosyası bulunamadı.")
        sys.exit(0)

    print(f"\n{'─'*60}")
    print(f"  trim_asset  —  {len(files)} dosya")
    print(f"{'─'*60}\n")

    for f in files:
        if args.dry:
            dst = None
        elif args.inplace:
            dst = f
        else:
            out_dir = Path(args.out) if args.out else f.parent / "trimmed"
            dst = out_dir / f.name

        r = process(f, dst, dry=args.dry, threshold=args.threshold)
        print(_fmt(r))
        print()

    print(f"{'─'*60}\n")


if __name__ == "__main__":
    main()
