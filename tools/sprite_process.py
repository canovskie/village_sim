"""Sprite post-process: split N-variant ChatGPT export into separate transparent PNGs."""
import sys
import os
from PIL import Image, ImageFilter
import numpy as np


def detect_checker_colors(arr: np.ndarray) -> list:
    """Auto-detect the two dominant achromatic checker colors from image edges."""
    H, W, _ = arr.shape
    strip_h = min(40, H // 10)
    strip_w = min(40, W // 10)
    samples = np.concatenate([
        arr[:strip_h, :].reshape(-1, 3),
        arr[-strip_h:, :].reshape(-1, 3),
        arr[:, :strip_w].reshape(-1, 3),
        arr[:, -strip_w:].reshape(-1, 3),
    ])
    spread = samples.max(axis=1).astype(int) - samples.min(axis=1).astype(int)
    samples = samples[spread <= 5]
    if len(samples) == 0:
        return [(254, 254, 254), (238, 238, 238)]
    binned = (samples // 4) * 4
    view = binned.view([('', binned.dtype)] * 3).ravel()
    unique, counts = np.unique(view, return_counts=True)
    top = sorted(zip(counts.tolist(), unique.tolist()), reverse=True)[:8]
    picks = []
    for _, col in top:
        col = tuple(int(c) for c in col)
        if not picks:
            picks.append(col)
        else:
            if abs(sum(col) / 3 - sum(picks[0]) / 3) >= 5:
                picks.append(col)
                break
    if len(picks) < 2:
        v = sum(picks[0]) / 3
        offset = -16 if v > 128 else 16
        picks.append(tuple(max(0, min(255, c + offset)) for c in picks[0]))
    return picks


def remove_checker_bg(img_rgb: Image.Image,
                      bg_colors=None,
                      tolerance: float = 14.0,
                      erode_px: int = 3) -> Image.Image:
    """Convert ChatGPT checker background to transparent alpha.

    Strategy that AVOIDS the white halo halo:
      1. Hard threshold on distance-to-checker (binary in/out)
      2. Erode opaque region by `erode_px` px to bite away the
         contaminated edge band where pixels are mixed with checker grey
      3. Light gaussian blur on alpha for sub-pixel AA
      4. Color despill: any pixel whose alpha is now partial (0-254)
         gets its RGB replaced with the nearest fully-opaque pixel's
         RGB (so the AA band isn't tinted by leftover bg grey)
    """
    arr = np.array(img_rgb).astype(np.int16)
    H, W, _ = arr.shape

    if bg_colors is None:
        bg_colors = detect_checker_colors(arr.astype(np.uint8))
        print(f"  auto-detected bg colors: {bg_colors}", flush=True)

    dists = []
    for c in bg_colors:
        c_arr = np.array(c, dtype=np.int16)
        d = np.linalg.norm(arr - c_arr, axis=2)
        dists.append(d)
    near_bg = np.minimum.reduce(dists)

    # Step 1: binary mask
    opaque = (near_bg > tolerance)
    alpha = (opaque.astype(np.uint8)) * 255
    alpha_img = Image.fromarray(alpha, mode='L')

    # Step 2: erosion (= MinFilter on alpha). Each step shrinks 1px.
    for _ in range(erode_px):
        alpha_img = alpha_img.filter(ImageFilter.MinFilter(3))

    # Step 3: AA blur
    alpha_img = alpha_img.filter(ImageFilter.GaussianBlur(radius=0.6))

    # Step 4: color despill — replace RGB of any non-fully-opaque pixel
    # with the closest fully-opaque pixel's RGB (Chebyshev distance via
    # iterative max-filter on a masked image). This is a small in-painting
    # over a 1-2 px AA band — cheap.
    rgb = arr.astype(np.uint8)
    rgb_img = Image.fromarray(rgb, mode='RGB')
    # Build "is fully opaque" mask
    alpha_np = np.array(alpha_img)
    fully_opaque = alpha_np >= 250
    # For each non-fully-opaque pixel, copy from nearest fully-opaque neighbor.
    # Implementation: iterative grow — set non-opaque pixels to 0 in a copy,
    # then run max filter so opaque pixels "spread" into them. Up to 3 passes.
    masked = rgb.copy()
    masked[~fully_opaque] = 0
    spread = Image.fromarray(masked, mode='RGB')
    for _ in range(3):
        spread = spread.filter(ImageFilter.MaxFilter(3))
    spread_arr = np.array(spread)
    # Combine: keep original RGB where fully opaque, use spread RGB elsewhere
    new_rgb = np.where(fully_opaque[..., None], rgb, spread_arr)

    # Step 5: shadow halo cleanup. ChatGPT bakes "15% opacity shadow blob"
    # as flat pale grey on white BG — when we composite onto dark grass, that
    # pale grey reads as a bright white halo. Detect achromatic pale pixels
    # (the only pure-grey areas a sprite should have are this baked shadow)
    # and replace with warm dark + reduce alpha so it renders as a real
    # soft drop shadow. Saturation guard keeps cream petals/highlights safe.
    rgb_i = new_rgb.astype(np.int16)
    r_ch, g_ch, b_ch = rgb_i[..., 0], rgb_i[..., 1], rgb_i[..., 2]
    lum = (r_ch + g_ch + b_ch) / 3.0
    sat_range = np.maximum.reduce([r_ch, g_ch, b_ch]) - np.minimum.reduce([r_ch, g_ch, b_ch])
    # Petal/cream parts of objects have sat_range ≥ 25; baked halo
    # is desaturated warm-tan (sat 6-18). Filter window covers halo
    # without biting petals. Cap alpha very low so halo reads as
    # a barely-visible soft shadow instead of a bright pale ring.
    halo = (alpha_np > 16) & (sat_range <= 18) & (lum >= 150)
    new_rgb[halo] = [42, 31, 26]
    alpha_np[halo] = np.minimum(alpha_np[halo], 20).astype(np.uint8)

    # Zero RGB of fully-transparent pixels — otherwise the despill leaves
    # pale grey RGB at alpha=0 positions, which LANCZOS resize later
    # smears back into sprite edges, recreating the pale halo we just killed.
    new_rgb[alpha_np == 0] = 0

    rgba = np.dstack([new_rgb.astype(np.uint8), alpha_np.astype(np.uint8)])
    return Image.fromarray(rgba, mode='RGBA')


def split_columns(img: Image.Image, n: int) -> list:
    """Split into n columns. If RGBA, refine cut points to the deepest alpha gap
    near the nominal boundary (so we don't slice through an object)."""
    W, H = img.size
    nominal = [round(W * i / n) for i in range(n + 1)]
    if img.mode != 'RGBA' or n < 2:
        return [img.crop((nominal[i], 0, nominal[i + 1], H)) for i in range(n)]

    alpha = np.array(img.split()[3])
    col_opacity = alpha.sum(axis=0).astype(np.float32)  # per-column total alpha

    cut_points = [0]
    for i in range(1, n):
        target = nominal[i]
        search_radius = W // (n * 3)
        lo = max(1, target - search_radius)
        hi = min(W - 1, target + search_radius)
        # Find column index with minimum opacity in this window (the gap between objects)
        window = col_opacity[lo:hi]
        best = lo + int(np.argmin(window))
        cut_points.append(best)
    cut_points.append(W)

    return [img.crop((cut_points[i], 0, cut_points[i + 1], H)) for i in range(n)]


def remove_small_islands(img_rgba: Image.Image, min_area_ratio: float = 0.01) -> Image.Image:
    """Remove tiny opaque islands smaller than min_area_ratio of total opaque area
    (e.g. fragments of neighboring sprites that bled into this column)."""
    arr = np.array(img_rgba)
    alpha = arr[:, :, 3]
    mask = alpha > 16

    # Connected components via simple flood-fill labeling
    from collections import deque
    H, W = mask.shape
    labels = np.zeros((H, W), dtype=np.int32)
    label = 0
    sizes = {}
    for sy in range(H):
        for sx in range(W):
            if mask[sy, sx] and labels[sy, sx] == 0:
                label += 1
                q = deque([(sy, sx)])
                labels[sy, sx] = label
                size = 0
                while q:
                    y, x = q.popleft()
                    size += 1
                    for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                        ny, nx = y + dy, x + dx
                        if 0 <= ny < H and 0 <= nx < W and mask[ny, nx] and labels[ny, nx] == 0:
                            labels[ny, nx] = label
                            q.append((ny, nx))
                sizes[label] = size

    if not sizes:
        return img_rgba
    max_size = max(sizes.values())
    min_keep = max(8, int(max_size * min_area_ratio))
    keep_mask = np.zeros_like(mask)
    for lbl, sz in sizes.items():
        if sz >= min_keep:
            keep_mask |= (labels == lbl)

    new_alpha = np.where(keep_mask, alpha, 0).astype(np.uint8)
    arr[:, :, 3] = new_alpha
    return Image.fromarray(arr, mode='RGBA')


def _kill_pale_halo(img_rgba: Image.Image) -> Image.Image:
    """Final pass: any pixel with low saturation and high luminance gets
    pushed to dark-warm-low-alpha. LANCZOS resize creates these as edge
    blending artifacts even when the source had none."""
    arr = np.array(img_rgba).astype(np.int16)
    r, g, b, a = arr[..., 0], arr[..., 1], arr[..., 2], arr[..., 3]
    sat = np.maximum.reduce([r, g, b]) - np.minimum.reduce([r, g, b])
    lum = (r + g + b) / 3.0
    halo = (a > 16) & (sat <= 22) & (lum >= 140)
    arr[halo, 0] = 42
    arr[halo, 1] = 31
    arr[halo, 2] = 26
    arr[halo, 3] = np.minimum(arr[halo, 3], 25)
    arr[arr[..., 3] == 0, 0:3] = 0
    return Image.fromarray(arr.astype(np.uint8), mode='RGBA')


def trim_and_resize(img_rgba: Image.Image, target_w: int, target_h: int, padding: int = 8) -> Image.Image:
    """Trim transparent margin, then resize content to fit target (w,h) minus padding."""
    # Pre-resize: zero RGB of transparent pixels so LANCZOS doesn't smear
    # ghost colors into sprite edges.
    arr = np.array(img_rgba)
    arr[arr[..., 3] == 0, 0:3] = 0
    img_rgba = Image.fromarray(arr, mode='RGBA')

    bbox = img_rgba.getbbox()
    if bbox is None:
        return img_rgba.resize((target_w, target_h), Image.LANCZOS)
    trimmed = img_rgba.crop(bbox)
    tw, th = trimmed.size
    inner_w = target_w - 2 * padding
    inner_h = target_h - 2 * padding
    scale = min(inner_w / tw, inner_h / th)
    new_w = max(1, int(round(tw * scale)))
    new_h = max(1, int(round(th * scale)))
    resized = trimmed.resize((new_w, new_h), Image.LANCZOS)
    # Post-resize: kill any pale blend artifacts LANCZOS created at edges.
    resized = _kill_pale_halo(resized)
    canvas = Image.new('RGBA', (target_w, target_h), (0, 0, 0, 0))
    canvas.paste(resized, ((target_w - new_w) // 2, (target_h - new_h) // 2), resized)
    return canvas


def process(src_path: str, out_dir: str, base_name: str,
            n_variants: int, target_w: int, target_h: int,
            bg_colors=None,
            tolerance: float = 14.0):
    img = Image.open(src_path).convert('RGB')
    rgba = remove_checker_bg(img, bg_colors=bg_colors, tolerance=tolerance)
    cols = split_columns(rgba, n_variants)
    os.makedirs(out_dir, exist_ok=True)
    out_paths = []
    for i, col in enumerate(cols):
        cleaned = remove_small_islands(col)
        final = trim_and_resize(cleaned, target_w, target_h)
        out_path = os.path.join(out_dir, f'{base_name}_{i}.png')
        final.save(out_path, 'PNG')
        out_paths.append(out_path)
    return out_paths


if __name__ == '__main__':
    src = sys.argv[1]
    out_dir = sys.argv[2]
    base_name = sys.argv[3]
    n_variants = int(sys.argv[4])
    # 5th arg = WxH like "256x128" or just "128" for square
    size_arg = sys.argv[5]
    if 'x' in size_arg:
        w, h = (int(s) for s in size_arg.split('x'))
    else:
        w = h = int(size_arg)
    paths = process(src, out_dir, base_name, n_variants, w, h)
    for p in paths:
        print(p)
