/// Ateş etrafına kurulan saz yatağı. Evsiz köylü sazlığı biçip depodan saz
/// harcayarak kurar; geceleri sahibi bu yatakta uyur (ev yerine geçici
/// barınak). Pure visual — gameplay engeli değil, decor seviyesinde çizilir.
class ReedBed {
  /// Tile konumu (ateş etrafı ring slotu).
  final double gridX;
  final double gridY;

  /// Bu yatağı kullanan köylü (VillagerEntity — döngüsel import önlemek için
  /// Object?). null = sahipsiz, başka bir evsiz sahiplenebilir.
  Object? owner;

  ReedBed({required this.gridX, required this.gridY, this.owner});

  /// Isometric depth — decor seviyesinde; üstünde yatan köylüden geride kalır
  /// (köylü yatağın üstünde çizilir).
  double get depth => gridX + gridY + 0.35;
}
