import 'package:flutter/material.dart';

import '../systems/village_lessons.dart';
import 'app_ui.dart';
import 'semantic_icon.dart';

/// ORTA OYUN DERS KARTI — kuruluştan sonra açılan bir sistemin tek açıklaması.
///
/// Kuruluş öğreticisi bir PARMAKTIR (spot, ekranı karartır, "şu kartı seç"
/// der). Bu bir KARTTIR ve farkı bilinçli: oyuncu artık oynamayı biliyor,
/// bilmediği şey karşısına yeni çıkan sistemin ne olduğu. O yüzden ekranı
/// karartmaz, tıklamayı engellemez, kendiliğinden kaybolmaz — okunur, kapanır
/// ve bir daha görünmez.
///
/// İki bölüm: NE OLDU (sistemin kendisi) ve NE YAPACAKSIN (eylem). İkincisi
/// olmadan kart bir tabeladır; oyuncu bilgiyi alır ama elinde bir kol olduğunu
/// öğrenmez.
class LessonCard extends StatelessWidget {
  final Lesson lesson;
  final VoidCallback onClose;

  const LessonCard({super.key, required this.lesson, required this.onClose});

  @override
  Widget build(BuildContext context) {
    // TELEFONDA YÜKSEKLİK BÜTÇESİ. Kart masaüstünde yazıldı ve orada rahat
    // duruyordu; iPhone 11 yatayda (414 px, güvenli alandan sonra ~360) en
    // uzun ders 30 piksel taşıyordu — sarı-siyah şerit. Metni kısaltmak
    // yanlış çözüm olurdu (ders zaten kısa; kısaltılan şey EYLEM olurdu).
    // Doğru çözüm: başlık sabit, gövde kayar.
    final screen = MediaQuery.sizeOf(context);
    final maxH = (screen.height - 132).clamp(180.0, 460.0);
    final maxW = (screen.width - 32).clamp(240.0, 380.0);

    return AppReveal(
      child: AppPanel(
        width: maxW,
        accent: AppUi.gold,
        padding: EdgeInsets.zero,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Üst şerit: ikon + başlık + "köyün defteri" etiketi + kapat
              Container(
                padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
                decoration: BoxDecoration(
                  border: const Border(
                    bottom: BorderSide(color: AppUi.line, width: 1),
                  ),
                  gradient: LinearGradient(
                    colors: [
                      AppUi.gold.withValues(alpha: 0.14),
                      AppUi.gold.withValues(alpha: 0.0),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    SemanticIcon(lesson.icon,
                        size: 17, color: AppUi.gold, fallback: GameIconData.scroll),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'KÖYÜN ÂDETİ',
                            style: AppUi.label.copyWith(
                              fontSize: 8.5,
                              color: AppUi.textLo,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            lesson.title,
                            style: AppUi.body.copyWith(
                              fontSize: 13,
                              color: AppUi.textHi,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onClose,
                      iconSize: 16,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 30,
                        minHeight: 30,
                      ),
                      icon: const Icon(Icons.close, color: AppUi.textLo),
                      tooltip: 'Kapat',
                    ),
                  ],
                ),
              ),
              // GÖVDE KAYAR, başlık ve kapat düğmesi sabit kalır. Kartın
              // tamamını kaydırılabilir yapmak telefonda "Anladım"ı ekran
              // dışında bırakırdı.
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lesson.body,
                        style: AppUi.body.copyWith(
                          fontSize: 11.5,
                          color: AppUi.textMid,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 11),
                      // NE YAPACAKSIN — solunda altın bir şeritle ayrılır ki göz
                      // onu gövde metninden ayırsın: asıl okunması gereken bu.
                      //
                      // Şerit bir Border DEĞİL ayrı bir Container. Tek kenarlı
                      // (non-uniform) bir Border ile borderRadius aynı kutuda
                      // Flutter'da assert attırır ve panel hiç çizilmez — bu
                      // projede birden çok kez "panel bozuk" diye yaşandı
                      // (bkz. feedback_ui_render_traps).
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppUi.radiusSm),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(width: 2, color: AppUi.gold),
                              Expanded(
                                child: Container(
                                  color: AppUi.surface0,
                                  padding: const EdgeInsets.fromLTRB(
                                    10,
                                    9,
                                    10,
                                    10,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'NE YAPABİLİRSİN',
                                        style: AppUi.label.copyWith(
                                          fontSize: 8.5,
                                          color: AppUi.gold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        lesson.action,
                                        style: AppUi.body.copyWith(
                                          fontSize: 11.5,
                                          color: AppUi.textHi,
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: AppButton(label: 'Anladım', onTap: onClose),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
