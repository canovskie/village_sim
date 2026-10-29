import 'package:flutter/widgets.dart';

/// The Phosphor glyphs the game draws, as plain [IconData] over the fonts the
/// phosphor_flutter package still ships. Its own Dart classes extend IconData,
/// which Flutter has made a final class, so importing the package no longer
/// compiles. Codepoints are copied from phosphor_flutter 2.1.0. Names without a
/// suffix are the fill weight.
abstract final class PhosphorGlyphs {
  static const _pkg = 'phosphor_flutter';

  static const axe = IconData(
    0xe9fc,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const bank = IconData(
    0xe0b4,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const beerStein = IconData(
    0xeb62,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const bug = IconData(
    0xe5f4,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const caretRightBold = IconData(
    0xe13a,
    fontFamily: 'PhosphorBold',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const church = IconData(
    0xecea,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const cloudLightning = IconData(
    0xe1b2,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const cloudRain = IconData(
    0xe1b4,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const coins = IconData(
    0xe78e,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const confettiRegular = IconData(
    0xe81a,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const cow = IconData(
    0xeabe,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const crosshair = IconData(
    0xe1d6,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const crown = IconData(
    0xe614,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const cube = IconData(
    0xe1da,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const diceFive = IconData(
    0xe1ee,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const door = IconData(
    0xe61c,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const drop = IconData(
    0xe210,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const eye = IconData(
    0xe220,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const fastForward = IconData(
    0xe6a6,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const fish = IconData(
    0xe728,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const flame = IconData(
    0xe624,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const floppyDisk = IconData(
    0xe248,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const flower = IconData(
    0xe75e,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const gear = IconData(
    0xe270,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const gearSix = IconData(
    0xe272,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const grains = IconData(
    0xec68,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const hammer = IconData(
    0xe80e,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const handCoins = IconData(
    0xea8c,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const handshake = IconData(
    0xe582,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const heart = IconData(
    0xe2a8,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const hexagon = IconData(
    0xe2ae,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const house = IconData(
    0xe2c2,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const lightning = IconData(
    0xe2de,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const mapTrifold = IconData(
    0xe31a,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const moon = IconData(
    0xe330,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const mountains = IconData(
    0xe7ae,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const pause = IconData(
    0xe39e,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const plant = IconData(
    0xebae,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const play = IconData(
    0xe3d0,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const scales = IconData(
    0xe750,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const scroll = IconData(
    0xeb7a,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const shovel = IconData(
    0xe9e6,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const snowflake = IconData(
    0xe5aa,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const speakerHigh = IconData(
    0xe44a,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const speakerSlash = IconData(
    0xe45a,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const spiral = IconData(
    0xe9fa,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const stack = IconData(
    0xe466,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const star = IconData(
    0xe46a,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const storefront = IconData(
    0xe470,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const sun = IconData(
    0xe472,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const sunHorizon = IconData(
    0xe5b6,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const trash = IconData(
    0xe4a6,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const tree = IconData(
    0xe6da,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const usersThree = IconData(
    0xe68e,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const warehouse = IconData(
    0xecd4,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const windmill = IconData(
    0xe9f8,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
  static const xBold = IconData(
    0xe4f6,
    fontFamily: 'PhosphorBold',
    fontPackage: _pkg,
    matchTextDirection: true,
  );
}
