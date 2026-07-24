#!/usr/bin/env python3
"""preview/ui/manifest.json → gezilebilir UI önizleme galerisi.

İki çıktı üretir:
  • preview/ui/index.html   — yerel galeri; PNG'lere ve assets/fonts'a GÖRECELİ
                              başvurur (tam çözünürlük, dosya şişmez).
  • <scratch>/ui_gallery_artifact.html — tek dosya; görseller webp data URI,
                              fontlar subset'li woff2 data URI (paylaşılabilir).

Çalıştır:  python3 tools/build_ui_gallery.py
"""
import base64
import io
import json
import os
import sys
from pathlib import Path

from PIL import Image
from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parent.parent
UI = ROOT / 'preview' / 'ui'
FONTS = ROOT / 'assets' / 'fonts'

# Galeri sırası — oyuncunun karşılaşma sırası: önce ekranlar, sonra oyun içi
# katman, sonra derinleşen paneller, en sonda geliştirici/tasarım iç yüzeyleri.
GROUP_ORDER = [
    ('Ekranlar', 'Oyunun kapıları — menü, kayıt, ayarlar, açılış sinematiği.'),
    ('Oyun İçi HUD', 'Dünyanın üstünde duran katman: kaynak, inşa, görev, hane.'),
    ('Paneller', 'Tıklayınca açılan derin yüzeyler — köylü, bina, nüfus defteri.'),
    ('Yönetişim', 'Divan, Kanunname ve politik pusula: kararın verildiği yer.'),
    ('Modallar', 'Oyunu bekleten anlar — dilekçe, olay kararı, imparatorluk.'),
    ('Geliştirici', 'Yalnız dev yapılarında görünen test yüzeyleri.'),
    ('Tasarım Sistemi', 'Bütün yüzeylerin beslendiği ortak parçalar.'),
]

# Alt yüzeylerde geçen Türkçe karakterler + tipografik işaretler.
SUBSET_TEXT = (
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
    'ÂÇĞİIÖŞÜâçğıiöşü'
    ' .,:;!?\'"“”‘’()[]{}/\\|-–—_+=*&%#@·•×→←↑↓°′″…'
)


def subset_font(path: Path, text: str) -> str:
    """Fontu yalnız kullanılan karakterlere indirip woff2 data URI döndürür."""
    font = TTFont(str(path))
    opts = subset.Options()
    opts.layout_features = ['*']
    opts.notdef_outline = True
    opts.recalc_bounds = True
    opts.drop_tables = []
    sub = subset.Subsetter(options=opts)
    sub.populate(text=text)
    sub.subset(font)
    font.flavor = 'woff2'
    buf = io.BytesIO()
    font.save(buf)
    return 'data:font/woff2;base64,' + base64.b64encode(buf.getvalue()).decode()


def webp_data_uri(path: Path, max_w: int = 1180, quality: int = 74) -> str:
    im = Image.open(path).convert('RGB')
    if im.width > max_w:
        im = im.resize((max_w, round(im.height * max_w / im.width)), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, 'WEBP', quality=quality, method=6)
    return 'data:image/webp;base64,' + base64.b64encode(buf.getvalue()).decode()


def esc(s: str) -> str:
    return (s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
             .replace('"', '&quot;'))


CSS = """
:root {
  --ground:#0C0D0F; --plate:#14161A; --raised:#1C1F24; --well:#08090B;
  --hairline:#2E333A; --ink:#F0EEE9; --ink-mid:#BEBAB2; --ink-lo:#87817A;
  --ember:#E49139; --ember-soft:#F3B978; --gold:#D9C15E;
  --shadow:0 18px 40px -24px rgba(0,0,0,.9);
  color-scheme:dark;
}
@media (prefers-color-scheme: light) {
  :root {
    --ground:#E8E6E1; --plate:#F7F6F3; --raised:#FFFFFF; --well:#DEDBD4;
    --hairline:#D3CFC7; --ink:#17191C; --ink-mid:#4B4E54; --ink-lo:#77736C;
    --ember:#A85C16; --ember-soft:#C3781F; --gold:#87721F;
    --shadow:0 14px 34px -22px rgba(30,26,20,.55);
    color-scheme:light;
  }
}
:root[data-theme="dark"] {
  --ground:#0C0D0F; --plate:#14161A; --raised:#1C1F24; --well:#08090B;
  --hairline:#2E333A; --ink:#F0EEE9; --ink-mid:#BEBAB2; --ink-lo:#87817A;
  --ember:#E49139; --ember-soft:#F3B978; --gold:#D9C15E;
  --shadow:0 18px 40px -24px rgba(0,0,0,.9);
  color-scheme:dark;
}
:root[data-theme="light"] {
  --ground:#E8E6E1; --plate:#F7F6F3; --raised:#FFFFFF; --well:#DEDBD4;
  --hairline:#D3CFC7; --ink:#17191C; --ink-mid:#4B4E54; --ink-lo:#77736C;
  --ember:#A85C16; --ember-soft:#C3781F; --gold:#87721F;
  --shadow:0 14px 34px -22px rgba(30,26,20,.55);
  color-scheme:light;
}

* { box-sizing:border-box; }
body {
  margin:0; background:var(--ground); color:var(--ink);
  font-family:'Spectral', 'Iowan Old Style', Palatino, Georgia, serif;
  font-size:16px; line-height:1.6;
  -webkit-font-smoothing:antialiased;
}
.wrap { max-width:1360px; margin:0 auto; padding:0 28px 96px; }

/* ── Başlık ─────────────────────────────────────────────────────────── */
header.hero { position:relative; padding:64px 0 34px; overflow:hidden; }
.mosaic {
  position:absolute; inset:0 -28px auto; height:190px; display:flex; gap:4px;
  opacity:.20; pointer-events:none; filter:saturate(.7);
  -webkit-mask-image:linear-gradient(to bottom, #000 0%, transparent 92%);
  mask-image:linear-gradient(to bottom, #000 0%, transparent 92%);
}
.mosaic img { height:100%; width:auto; object-fit:cover; flex:0 0 auto; }
.hero-inner { position:relative; }
.eyebrow {
  font-family:'Cinzel', Georgia, serif; font-size:11px; letter-spacing:.34em;
  text-transform:uppercase; color:var(--ember); margin:0 0 14px;
}
h1 {
  font-family:'Cinzel', Georgia, serif; font-weight:600;
  font-size:clamp(34px, 5.4vw, 60px); line-height:1.04; margin:0;
  letter-spacing:.01em; text-wrap:balance;
}
.lede { max-width:62ch; color:var(--ink-mid); margin:18px 0 0; font-size:17px; }
.meta {
  display:flex; flex-wrap:wrap; gap:26px; margin-top:26px;
  padding-top:20px; border-top:1px solid var(--hairline);
}
.meta div { display:flex; flex-direction:column; gap:2px; }
.meta .n {
  font-family:'Cinzel', Georgia, serif; font-size:26px; color:var(--ink);
  font-variant-numeric:tabular-nums;
}
.meta .k {
  font-size:10px; letter-spacing:.18em; text-transform:uppercase;
  color:var(--ink-lo);
}

/* ── Filtre çubuğu ──────────────────────────────────────────────────── */
nav.filters {
  position:sticky; top:0; z-index:20; display:flex; flex-wrap:wrap; gap:8px;
  padding:14px 0; margin-bottom:8px;
  background:color-mix(in srgb, var(--ground) 92%, transparent);
  backdrop-filter:blur(9px);
  border-bottom:1px solid var(--hairline);
}
.chip {
  font-family:'Cinzel', Georgia, serif; font-size:11px; letter-spacing:.14em;
  text-transform:uppercase; color:var(--ink-mid); cursor:pointer;
  background:var(--plate); border:1px solid var(--hairline); border-radius:999px;
  padding:7px 15px; transition:color .18s, border-color .18s, background .18s;
}
.chip:hover { color:var(--ink); border-color:var(--ink-lo); }
.chip[aria-pressed="true"] {
  color:var(--ground); background:var(--ember); border-color:var(--ember);
}
:root[data-theme="light"] .chip[aria-pressed="true"],
:root:not([data-theme]) .chip[aria-pressed="true"] { color:var(--plate); }
@media (prefers-color-scheme: dark) {
  :root:not([data-theme]) .chip[aria-pressed="true"] { color:var(--ground); }
}
.chip:focus-visible, .plate:focus-visible, .theme-btn:focus-visible {
  outline:2px solid var(--ember); outline-offset:3px;
}
.theme-btn {
  margin-left:auto; background:none; border:1px solid var(--hairline);
  border-radius:999px; color:var(--ink-mid); cursor:pointer;
  font-family:'Cinzel', Georgia, serif; font-size:11px; letter-spacing:.14em;
  text-transform:uppercase; padding:7px 15px;
}

/* ── Bölümler ───────────────────────────────────────────────────────── */
section { padding-top:46px; scroll-margin-top:74px; }
.sec-head {
  display:flex; align-items:baseline; gap:16px; flex-wrap:wrap;
  border-bottom:1px solid var(--hairline); padding-bottom:12px; margin-bottom:22px;
}
.sec-head h2 {
  font-family:'Cinzel', Georgia, serif; font-size:19px; letter-spacing:.12em;
  text-transform:uppercase; margin:0; font-weight:600;
}
.sec-head .count {
  font-size:11px; letter-spacing:.16em; color:var(--ember);
  font-variant-numeric:tabular-nums;
}
.sec-head p { margin:0; color:var(--ink-lo); font-size:14px; flex:1 1 340px; }

.grid { display:grid; gap:20px; grid-template-columns:repeat(auto-fill, minmax(330px, 1fr)); }
.plate {
  display:flex; flex-direction:column; text-align:left; padding:0; cursor:zoom-in;
  background:var(--plate); border:1px solid var(--hairline); border-radius:4px;
  color:inherit; font:inherit; overflow:hidden;
  transition:border-color .2s, transform .2s, box-shadow .2s;
}
.plate:hover { border-color:var(--ember); transform:translateY(-3px); box-shadow:var(--shadow); }
.well {
  background:var(--well); border-bottom:1px solid var(--hairline);
  display:flex; align-items:center; justify-content:center;
  aspect-ratio:16/10; overflow:hidden; padding:12px;
}
.well img { max-width:100%; max-height:100%; object-fit:contain; display:block; }
.cap { padding:14px 16px 16px; display:flex; flex-direction:column; gap:7px; }
.cap h3 {
  font-family:'Cinzel', Georgia, serif; font-size:14px; margin:0; font-weight:600;
  letter-spacing:.03em; text-wrap:balance;
}
.cap p { margin:0; font-size:13.5px; line-height:1.5; color:var(--ink-mid); }
.code {
  margin-top:2px; display:flex; gap:10px; align-items:center; flex-wrap:wrap;
  font-family:ui-monospace, SFMono-Regular, Menlo, monospace; font-size:10.5px;
  letter-spacing:.02em; color:var(--ink-lo);
}
.code b { color:var(--gold); font-weight:400; }

/* ── Büyütme ────────────────────────────────────────────────────────── */
.box {
  position:fixed; inset:0; z-index:60; display:none;
  background:color-mix(in srgb, var(--ground) 88%, black);
  backdrop-filter:blur(6px);
}
.box[open] { display:flex; flex-direction:column; }
.box-bar {
  display:flex; align-items:center; gap:16px; padding:14px 22px;
  border-bottom:1px solid var(--hairline);
}
.box-bar h4 {
  font-family:'Cinzel', Georgia, serif; font-size:14px; letter-spacing:.08em;
  margin:0; font-weight:600;
}
.box-bar .code { margin:0; }
.box-bar button {
  background:none; border:1px solid var(--hairline); border-radius:999px;
  color:var(--ink-mid); cursor:pointer; font:inherit; font-size:13px;
  padding:4px 13px; line-height:1.4;
}
.box-bar button:hover { color:var(--ink); border-color:var(--ink-lo); }
.box-bar .nav { margin-left:auto; display:flex; gap:8px; }
.box-img { flex:1; min-height:0; display:flex; align-items:center; justify-content:center; padding:22px; }
.box-img img { max-width:100%; max-height:100%; object-fit:contain; }

footer {
  margin-top:64px; padding-top:20px; border-top:1px solid var(--hairline);
  color:var(--ink-lo); font-size:13px; display:flex; gap:22px; flex-wrap:wrap;
}
footer code {
  font-family:ui-monospace, SFMono-Regular, Menlo, monospace; font-size:12px;
  color:var(--ink-mid);
}
@media (prefers-reduced-motion: reduce) {
  * { transition:none !important; }
  .plate:hover { transform:none; }
}
@media (max-width: 620px) {
  .wrap { padding:0 16px 64px; }
  header.hero { padding-top:40px; }
}
"""

JS = """
(function () {
  var plates = Array.prototype.slice.call(document.querySelectorAll('.plate'));
  var box = document.getElementById('box');
  var boxImg = document.getElementById('boxImg');
  var boxTitle = document.getElementById('boxTitle');
  var boxCode = document.getElementById('boxCode');
  var idx = -1;

  function open(i) {
    idx = (i + plates.length) % plates.length;
    var p = plates[idx];
    boxImg.src = p.querySelector('img').src;
    boxImg.alt = p.dataset.title;
    boxTitle.textContent = p.dataset.title;
    boxCode.innerHTML = '<b>' + p.dataset.id + '</b> · ' + p.dataset.size;
    box.setAttribute('open', '');
    document.body.style.overflow = 'hidden';
  }
  function close() {
    box.removeAttribute('open');
    document.body.style.overflow = '';
    if (idx >= 0) plates[idx].focus();
  }
  plates.forEach(function (p, i) {
    p.addEventListener('click', function () { open(i); });
    p.addEventListener('keydown', function (e) {
      if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); open(i); }
    });
  });
  document.getElementById('boxClose').addEventListener('click', close);
  document.getElementById('boxPrev').addEventListener('click', function () { open(idx - 1); });
  document.getElementById('boxNext').addEventListener('click', function () { open(idx + 1); });
  box.addEventListener('click', function (e) { if (e.target === box || e.target.parentNode === box) close(); });
  document.addEventListener('keydown', function (e) {
    if (!box.hasAttribute('open')) return;
    if (e.key === 'Escape') close();
    if (e.key === 'ArrowRight') open(idx + 1);
    if (e.key === 'ArrowLeft') open(idx - 1);
  });

  // Başlık mozaiği — plaka görsellerinin klonu (aynı kaynak, ek yük yok).
  var mosaic = document.getElementById('mosaic');
  plates.forEach(function (p) {
    var c = p.querySelector('img').cloneNode(false);
    c.removeAttribute('loading');
    c.alt = '';
    mosaic.appendChild(c);
  });

  // Grup süzgeci
  var chips = Array.prototype.slice.call(document.querySelectorAll('.chip'));
  chips.forEach(function (c) {
    c.addEventListener('click', function () {
      var g = c.dataset.group;
      chips.forEach(function (o) { o.setAttribute('aria-pressed', String(o === c)); });
      document.querySelectorAll('section').forEach(function (s) {
        s.hidden = !(g === 'all' || s.dataset.group === g);
      });
    });
  });

  // Tema düğmesi — sistem tercihini geçersiz kılar (kök üstünde data-theme).
  var tb = document.getElementById('themeBtn');
  tb.addEventListener('click', function () {
    var cur = document.documentElement.getAttribute('data-theme');
    if (!cur) {
      cur = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    }
    document.documentElement.setAttribute('data-theme', cur === 'dark' ? 'light' : 'dark');
  });
})();
"""


def build(entries, img_src, font_css, title):
    groups = {}
    for e in entries:
        groups.setdefault(e['group'], []).append(e)
    ordered = [(g, d, groups[g]) for g, d in GROUP_ORDER if g in groups]
    for g in groups:
        if g not in [x[0] for x in ordered]:
            ordered.append((g, '', groups[g]))

    chips = ['<button class="chip" data-group="all" aria-pressed="true">Tümü</button>']
    for g, _d, items in ordered:
        chips.append('<button class="chip" data-group="{0}" aria-pressed="false">{0}</button>'
                     .format(esc(g)))
    chips.append('<button class="theme-btn" id="themeBtn">Tema</button>')

    secs = []
    for si, (g, d, items) in enumerate(ordered):
        cards = []
        for e in items:
            cards.append(
                '<div class="plate" role="button" tabindex="0" data-id="{id}" '
                'data-title="{title}" data-size="{w}×{h}" '
                'aria-label="{title} — büyüt">'
                '<div class="well"><img src="{src}" alt="{title}" loading="lazy" /></div>'
                '<div class="cap"><h3>{title}</h3>{note}'
                '<span class="code"><b>{id}</b> · {w}×{h}</span></div></div>'.format(
                    id=esc(e['id']), title=esc(e['title']),
                    note=('<p>' + esc(e['note']) + '</p>') if e['note'] else '',
                    w=int(e['w']), h=int(e['h']), src=img_src(e)))
        secs.append(
            '<section id="g-{anchor}" data-group="{g}">'
            '<div class="sec-head"><h2>{g}</h2>'
            '<span class="count">{n:02d} yüzey</span><p>{d}</p></div>'
            '<div class="grid">{cards}</div></section>'.format(
                anchor=si, g=esc(g), n=len(items), d=esc(d),
                cards=''.join(cards)))

    body = """
<div class="wrap">
  <header class="hero">
    <div class="mosaic" id="mosaic" aria-hidden="true"></div>
    <div class="hero-inner">
      <p class="eyebrow">Arayüz Envanteri</p>
      <h1>Köy Simülasyonu<br />Ekran Föyü</h1>
      <p class="lede">Oyunun oyuncuya gösterdiği her yüzey — menüler, oyun içi
      katman, paneller, yönetişim defterleri, modallar ve geliştirici araçları —
      gerçek fontlar ve gerçek bileşenlerle, tek geçişte yakalandı. Plakaya
      dokun, tam ölçüde aç; ok tuşlarıyla gez.</p>
      <div class="meta">
        <div><span class="n">{n}</span><span class="k">Yüzey</span></div>
        <div><span class="n">{ng}</span><span class="k">Grup</span></div>
        <div><span class="n">2×</span><span class="k">Piksel Oranı</span></div>
      </div>
    </div>
  </header>

  <nav class="filters" aria-label="Grup süzgeci">{chips}</nav>
  {secs}

  <footer>
    <span>Yakalama: <code>flutter run -d macos -t lib/tools/ui_gallery_capture_main.dart</code></span>
    <span>Tek yüzeyi tazele: <code>ONLY=&lt;kimlik&gt;</code></span>
  </footer>
</div>

<div class="box" id="box" role="dialog" aria-modal="true" aria-label="Büyütülmüş yüzey">
  <div class="box-bar">
    <h4 id="boxTitle"></h4>
    <span class="code" id="boxCode"></span>
    <span class="nav">
      <button id="boxPrev" aria-label="Önceki yüzey">‹ Önceki</button>
      <button id="boxNext" aria-label="Sonraki yüzey">Sonraki ›</button>
      <button id="boxClose" aria-label="Kapat">Kapat ✕</button>
    </span>
  </div>
  <div class="box-img"><img id="boxImg" src="" alt="" /></div>
</div>
""".format(chips=''.join(chips), secs=''.join(secs),
           n=len(entries), ng=len(ordered))

    return {'css': font_css + CSS, 'body': body, 'title': title}


def main():
    entries = json.load(open(UI / 'manifest.json'))
    title = 'Köy Simülasyonu — Ekran Föyü'

    # ── Yerel galeri: göreceli PNG + göreceli font (dosya küçük kalsın) ──
    rel_fonts = """
@font-face { font-family:'Cinzel'; src:url('../../assets/fonts/Cinzel-VF.ttf') format('truetype');
  font-weight:400 900; font-display:swap; }
@font-face { font-family:'Spectral'; src:url('../../assets/fonts/Spectral-Regular.ttf') format('truetype');
  font-weight:400; font-display:swap; }
@font-face { font-family:'Spectral'; src:url('../../assets/fonts/Spectral-SemiBold.ttf') format('truetype');
  font-weight:600; font-display:swap; }
"""
    local = build(entries, lambda e: e['file'], rel_fonts, title)
    (UI / 'index.html').write_text(
        '<!doctype html>\n<html lang="tr">\n<head>\n<meta charset="utf-8" />\n'
        '<meta name="viewport" content="width=device-width, initial-scale=1" />\n'
        '<title>{t}</title>\n<style>{css}</style>\n</head>\n<body>\n{body}\n'
        '<script>{js}</script>\n</body>\n</html>\n'.format(
            t=esc(title), css=local['css'], body=local['body'], js=JS),
        encoding='utf-8')
    print('yerel galeri →', UI / 'index.html')

    # ── Artifact: her şey gömülü ─────────────────────────────────────────
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else UI / 'ui_gallery_artifact.html'
    cinzel = subset_font(FONTS / 'Cinzel-VF.ttf', SUBSET_TEXT)
    spectral = subset_font(FONTS / 'Spectral-Regular.ttf', SUBSET_TEXT)
    spectral_sb = subset_font(FONTS / 'Spectral-SemiBold.ttf', SUBSET_TEXT)
    inline_fonts = (
        "@font-face{{font-family:'Cinzel';src:url({c}) format('woff2');"
        "font-weight:400 900;font-display:swap;}}"
        "@font-face{{font-family:'Spectral';src:url({s}) format('woff2');"
        "font-weight:400;font-display:swap;}}"
        "@font-face{{font-family:'Spectral';src:url({sb}) format('woff2');"
        "font-weight:600;font-display:swap;}}"
    ).format(c=cinzel, s=spectral, sb=spectral_sb)

    cache = {}

    def data_src(e):
        if e['id'] not in cache:
            cache[e['id']] = webp_data_uri(UI / e['file'])
        return cache[e['id']]

    art = build(entries, data_src, inline_fonts, title)
    out.write_text(
        '<title>{t}</title>\n<style>{css}</style>\n{body}\n<script>{js}</script>\n'
        .format(t=esc(title), css=art['css'], body=art['body'], js=JS),
        encoding='utf-8')
    print('artifact →', out, '{:.1f} MB'.format(os.path.getsize(out) / 1e6))


if __name__ == '__main__':
    main()
