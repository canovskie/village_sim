import 'package:flutter/material.dart';

import '../entities/villager_entity.dart';
import '../entities/villager_job.dart';
import '../entities/work_site.dart';
import 'app_ui.dart';
import 'mobile_ui.dart';
import 'work_crew.dart';

/// BİNASIZ İŞ YERİ KARTI — tarla, böğürtlenlik, şantiye, yol işi.
///
/// Bina paneli ayakta duran bir yapının künyesidir; bu kart onun binasız
/// kardeşi. Var olma sebebi tek bir ilkeyi bozmamak: YUVA FİZİKSEL BİR YERDE
/// DURUR. Toplayıcının binası yoktur ama böğürtlenliği vardır; inşaatçının
/// binası yoktur ama şantiyesi vardır. Bu işleri bir listeye sürseydik iş
/// verme yine "yersiz bir seçim" olurdu — kaçtığımız şeyin ta kendisi.
///
/// Bina panelinden sade: künye satırı yok, eylem şeridi yok. Burada tek bir
/// soru var — kaç el.
class WorkSitePanel extends StatelessWidget {
  final WorkSite site;

  /// İş yerinin bir cümlelik hâli — "12 parsel · 3 tanesi hasat vaktinde".
  final String? subtitle;

  final VoidCallback onClose;
  final void Function(WorkSite)? onAddHand;
  final void Function(WorkSite, VillagerEntity)? onRemoveHand;
  final void Function(VillagerEntity)? onSelectVillager;

  /// Öğreticinin gösterdiği iş yeri kimliği — eşleşirse ilk boş yuva
  /// spot hedefi olur.

  const WorkSitePanel({
    super.key,
    required this.site,
    required this.onClose,
    this.subtitle,
    this.onAddHand,
    this.onRemoveHand,
    this.onSelectVillager,
  });

  @override
  Widget build(BuildContext context) {
    final compact = useCompactGameUi(context);
    return GestureDetector(
      onTap: () {},
      behavior: HitTestBehavior.opaque,
      child: AppReveal(
        child: SizedBox(
          width: compact
              ? MobileUi.sheetWidth(MediaQuery.sizeOf(context))
              : 326,
          child: AppPanel(
            accent: site.starving ? AppUi.rust : AppUi.accent,
            padding: EdgeInsets.zero,
            borderRadius: compact
                ? BorderRadius.circular(MobileUi.radius)
                : null,
            // MOBİL: bina paneliyle aynı sayfa dili — yuvanın yüksekliğini
            // DOLDURUR (min olsaydı ekranın ortasında havada asılı kalırdı).
            child: Column(
              mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(),
                Container(height: 1, color: AppUi.line),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: WorkCrewSection(
                      site: site,
                                  onAddHand: onAddHand == null
                          ? null
                          : () => onAddHand!(site),
                      onRemoveHand: (v) => onRemoveHand?.call(site, v),
                      onSelect: onSelectVillager,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
    child: Row(
      children: [
        Container(
          width: 46,
          height: 38,
          decoration: BoxDecoration(
            color: AppUi.surface0,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppUi.line, width: 1),
          ),
          alignment: Alignment.center,
          child: Text(site.role.icon, style: const TextStyle(fontSize: 18)),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                site.label,
                style: AppUi.title.copyWith(fontSize: 15),
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: AppUi.body.copyWith(fontSize: 11, color: AppUi.textLo),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 6),
        AppIconButton(icon: GameIconData.close, size: 26, onTap: onClose),
      ],
    ),
  );
}
