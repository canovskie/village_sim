# Şapel görselleri

Yerleşik `image_gen` aracı kullanıldı. Referans: `assets/buildings/church.png`.
Kilise mevcut yaz/kış görsellerini kullanır; dünya ölçeği `BuildingMeta` ile büyütüldü.

Son dosyalar:

- `assets/buildings/chapel.png`: yaz, RGBA, 1304×1206.
- `assets/buildings/chapel_winter.png`: kış, RGBA, 1312×1199.

Üretim istemi:

> Use case: stylized-concept. Asset type: transparent PNG building sprite for an isometric medieval village game. Create a SMALL HUMBLE CHAPEL, clearly distinct from a large church: single short rectangular nave, simple steep muted terracotta tiled gable roof, tiny open bell-cote above entrance with one bronze bell and small wooden cross, cream plaster with rough stone foundation and a little dark timber framing, one rounded wooden door facing lower left, two small warm amber side windows facing lower right, two stone entrance steps and a modest planted pot. Match the provided reference image's detailed hand-painted pixel-textured medieval game asset style, warm materials, orthographic isometric camera showing front and right side, light from upper left. Reference image is STYLE AND CAMERA ONLY; new building must be a much simpler compact little chapel without the reference's large tower, side wing, banners or grand stained-glass facade. Entire isolated building fits frame tightly with about 2 percent clear margin, base at bottom, no scenery, no characters, no writing, no border, no watermark. Background must be genuinely transparent alpha, no opaque backdrop, no checkerboard, no ground tile or large cast shadow. Save the generated image and return its local file path.

Yaz kesiti için son düzenleme istemi:

> Use case: background-extraction. Edit target: supplied chapel sprite. Remove the entire fake white/light-gray checkerboard background and output the chapel as a cutout with ACTUAL TRANSPARENT ALPHA CHANNEL. Every background pixel including holes inside the open bell tower should have alpha 0. Keep the building, its colors, details, silhouette, proportions and camera completely unchanged. No checkerboard pattern should be painted into pixels. The output PNG must use RGBA transparency. Tight crop around the entire chapel including its cross and steps, 1% clear transparent padding.

Kış üretim istemi:

> Use case: lighting-weather. Asset type: winter variant of this exact isometric chapel PNG game sprite. Change ONLY add soft natural patches of snow on terracotta roof planes, bell-cote roof, cross upper surfaces, stone steps and flowerpot. Keep the chapel geometry, proportions, location, camera, full canvas dimensions 1304x1206, and warm amber windows exactly as reference. Snow follows roof slopes with some terracotta tiles showing. No falling flakes, no scenery, no extra ground, no text. Preserve actual RGBA transparent background and all transparent margins and holes; do not paint a checkerboard or opaque background. Same isolated building, exact same framing so seasonal crossfade stays aligned.

Kış kesiti için son düzenleme istemi:

> Remove the background. Transparent background.

Her iki nihai PNG'nin saydam ve opak piksel oranları `test/chapel_building_test.dart`
ile doğrulanır. Mevsim görselleri gerçek bina renderer'ıyla aynı dünya ölçeğinde
kontrol edildi.
