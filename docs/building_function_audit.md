# Dikilebilir bina işlev auditi

Bu matris `kBuildingFunctions` özetlerinden değil; bina tick'leri, iş yerleri,
NPC rutinleri, yerleşim kuralları, kanun/zanâat kapıları, tüccar, hastalık,
suç, kronik ve hane sistemleri izlenerek çıkarıldı. Tekrar oranı kesin bir
denge skoru değil; ana çıktı ve pasif etkinin başka bir binayla ne kadar
örtüştüğünü gösteren kısa audit tahminidir.

| Bina | Ana çıktı | Pasif etki | Aktif oyuncu kararı | Yerleşim kararı | Bağlı sistemler | Tekrar |
|---|---|---|---|---|---|---:|
| Ateş Yeri | Kuruluş ocağı, ısı ve ışık | Gece toplanması; çadır ısısı | Odun/kömür stoğunu koru | Mahallenin merkezi, açık alan | Kuruluş, kış, barınak, sosyal rutin | %10 |
| Çadır | 1 yatak | Düşük konfor | Ucuz erken barınak seçimi | Yanan ocağa yakın | Konut, kış, moral | %25 (konut) |
| Köy Evi | 2 yatak | Kendi ocağı, su deposu | Standart konut yatırımı | Mahalle/komşuluk | Konut, su, hane, servet | %35 (konut) |
| Taş Konut — Mavi | 3 yatak | Konfor ve servet çarpanı | Çatı rengi (kozmetik) | Mahalle | Konut, su, hane, servet, moral | %100 (Yeşil) |
| Taş Konut — Yeşil | 3 yatak | Konfor ve servet çarpanı | Çatı rengi (kozmetik) | Mahalle | Konut, su, hane, servet, moral | %100 (Mavi) |
| Konak | 4 yatak | Lüks konfor ve daha yüksek servet | Pahalı/yoğun konut | Görünür, geniş alan | Konut, hane, servet, moral | %45 (konut) |
| Oduncu Kulübesi | Odun ve yeniden dikim | Ormanı yeniler | İşçi/kamp alanı | Ağaç menzili zorunlu | İş, kaynak kutusu, ormancılık | %10 |
| Maden Ocağı | Taş, demir, kömür | Damarı işaretler | İşçi ve çıkarılacak damar | Damar üstü zorunlu | İş, maden düğümleri, yakıt/ticaret | %15 |
| Balıkçı Kulübesi | Yiyecek | Balıkçı iş yeri | İşçi | Kıyıya yakınlık yolu kısaltır | İş, kıyı, yiyecek | %25 (yiyecek) |
| Değirmen | Balyadan +2 yiyecek | İlk iki değirmen verim verir | Değirmenci ata | Tarla/teslim hattına yakın | Tarla, balya, taşıyıcı, işçi | %10 |
| Ağıl | Süt/yiyecek | Hayvan barınağı | Hayvan satın al, çoban ata | Açık otlak | Hayvan, yem, çoban, sürü dilekçeleri | %20 |
| Tavuk Kümesi | Yumurta/yiyecek | Periyodik yumurta | Tavuk satın al | Açık dolaşım alanı | Hayvan, yumurta, yiyecek | %30 (yiyecek) |
| Çiçekçi Kulübesi | Çiçek bahçesi | Amenite morali | Çiçekçi ata | Açık zemin | İş, dekor, arı, moral | %35 (moral) |
| Arı Kovanı | Bal | Çiçekle 1–3× hız | Kovan-çiçek düzeni | Çiçek menzili | Bal, tüccar, dekor | %10 |
| Terzi | Dikilmiş giysi | Kışlık/normal görünüm geçişi | Giysi önceliği | Teslim hattı | Kış, giysi, NPC görseli | %10 |
| Pazar | Fazlayı altına çevirir | Koşullu pasif gelir | Kaynağı elle sat | Menzilsiz; depo hattı yararlı | Ekonomi, stok, tüccar | %20 (ticaret) |
| Depo | +180 stok tavanı | Teslim çapası | Lojistik ağ kur | Üretime yakın | Stok, taşıyıcı, teslim slotu | %10 |
| Ahır (Yük) | +%15 taşıyıcı hızı | Köy çapı lojistik | Lojistiğe yatırım | Konum etkisiz; avlu okunurluğu | Taşıyıcı sistemi | %100 (eski Han) |
| Han | **Audit öncesi:** +%15 taşıyıcı hızı | **Audit öncesi:** Ahır kopyası | Pahalı ikinci lojistik binası | Açık avlu | Lore tüccar diyordu; sim bağı yoktu | **%100** |
| Belediye | Yönetişim koltuğu | Zanaat arşivi | Divan/vergi/hüküm | Meydan | Divan, kanun, hane, zanaat hafızası | %15 |
| Kuyu | Ev suyu | Amenite morali, su dolumu | Su altyapısı | Evlerin ortası | Konut suyu, moral | %55 (Şadırvan) |
| Şadırvan | Ev suyu | Amenite morali ve gündüz toplanma | Meydan amenitesi | Ev/açık alan | Konut suyu, sosyal rutin, moral | %70 (Kuyu) |
| Taverna | Sosyal hedef | En yüksek amenite morali | Festival/yerel sosyal merkez | Evlerin arası | NPC rutinleri, moral, festival | %35 (moral) |
| Kilise | Cenaze ve mezarlık | Moral; hastalık/yaralanma bakımı | İnanç yatırımı | Mezar için boşluk | Cenaze, şifa, inanç, kanun | %30 |
| Kütüphane | Zanaatı kayıptan korur | Amenite morali | Kurumsal hafıza yatırımı | Meydana/evlere yakın | Zanaat kaybı, kronik, moral | %20 |
| Hamam | **Audit öncesi:** amenite morali | Kütüphane/Şadırvanla aynı +0.10 ağırlık | Yalnız inşa kararı | Konum etkisizdi | Yalnız moral | **%95** |
| Anıt | **Audit öncesi:** amenite morali | Daha küçük +0.06 ağırlık | Yalnız inşa kararı | Açık/görünür (mekaniksiz) | Moral ve genel inanç kapısı | **%90** |
| Türbe | Amenite morali | İnanç/kanun kapısı | İnanç yatırımı | Sakin/açık alan | İnanç zanaatı, kanun kapıları, moral | %75 (Kilise) |
| Çan Kulesi | **Audit öncesi:** amenite morali | +0.08 ağırlık | Yalnız inşa kararı | Merkez/açık (mekaniksiz) | Moral ve genel inanç kapısı | **%90** |
| Sokak Feneri | Gece ışığı | Yerel aydınlatma | Yol/mahalle aydınlat | Karanlık rota | Aydınlatma/render | %10 |

## Audit kararı

En yüksek tekrar ve en zayıf sahne karşılığı Hamam, Anıt, Çan Kulesi
ve Han'daydı. Türbe de moral tekrarı taşıyor; ancak mevcut inanç zanaatı ve
kanun kapılarıyla tematik bir sistem bağı var. Dört bina sınırında, hiçbir
ziyaretçi bağı olmayan ve Ahırı birebir kopyalayan Han daha zayıf bulundu.

Uygulama sonrası yeni kimlikler:

- Hamam: menzilli, ihtiyaç halinde otomatik yanan, odun karşılığı koruyucu
  ve iyileştirici bakım.
- Anıt: dikildiği anın rejim + baskın hane kimliğini hem kendi yazısında
  hem Vakanüvis kroniğinde kalıcılaştıran tarihsel belge.
- Çan Kulesi: 12 tile içindeki tamamlanmış suçta çalan ve muhafızın
  müdahale menzilini %60 genişleten yerel alarm.
- Han: tüccarı avlusuna çeken, ziyaret aralığını %35 kısaltan ve
  konaklamayı %55 uzatan ziyaret/ticaret altyapısı.

Taş Konutlar veri modelinde ayrı görsel assetler olarak kaldı. Maliyet,
kapasite, konfor ve bütün simülasyon davranışları aynı; function ve lore bunu
açıkça "kozmetik varyant" diye söylüyor.
