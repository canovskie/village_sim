# Ev çevresi dekorları

Yerleşik `image_gen` aracıyla üretildi (2026-09-06); CLI/API kullanılmadı.
PNG'ler gerçek RGBA içerir; özgün alpha kanalı korunur. Renderer saydam kenar
boşluğunu kaynak dikdörtgeniyle dışarıda bırakır ve 384 px genişlikte yükler.

- `assets/decor/cottage_herb_planter.png`: klasik ve kiremitli köy evinin yan duvarı.
- `assets/decor/stone_lavender_trough.png`: mavi çatılı taş konutun yan cephesi.

Ev başına en fazla bir küçük çiçeklik çizilir. Bahçeli ev, usta evi, yeşil
taş konut ve konak kendi görsellerinde yeterince eşya taşır; ek dekor almaz.
Boş, yanan, ağır hasarlı evlere ve kış görünümüne çiçeklik eklenmez.
Konumlar ev sprite'ının gerçek sınırlarından hesaplanır; ayak izinin ön
köşesine rastgele sepet/odun/çamaşır çizimi kaldırılmıştır.

## Son üretim istemleri

### Ahşap çiçeklik

Create a production-ready transparent RGBA PNG sprite, not a transparency mockup: one compact low weathered oak flower planter with sage-green herbs and three small cream daisies for a medieval isometric village game. Detailed muted warm pixel-art aesthetic. Isometric 30-degree view, long front face slopes down to right. The planter occupies the center of the image. All pixels outside the planter silhouette must have alpha zero, including gaps between leaves. Sharp clean cutout. No drawn checkerboard, no white background, no colored haze, no glow, no vignette, no ground, no shadow. Genuine transparent background. Small simple compact bush, low rectangular wooden box. No text.

### Taş çiçeklik

Create a production-ready transparent RGBA PNG sprite, not a transparency mockup: one compact LOW weathered warm gray limestone rectangular flower trough with short sage-green herbs and a few pale lavender blossoms for a medieval isometric village game. Detailed muted warm pixel-art aesthetic. Isometric 30-degree view, long front face slopes up to right. The planter occupies the center of the image. All pixels outside the planter silhouette must have alpha zero, including gaps between leaves. Sharp clean cutout. No drawn checkerboard, no white background, no colored haze, no glow, no vignette, no ground, no shadow. Genuine transparent background. Small simple compact low bush, low rectangular stone box. No text.
