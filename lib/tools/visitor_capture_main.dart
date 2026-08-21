// DIŞ DÜNYA TRAFİĞİ — at arabası + kervan insanlarını gerçek köy sahnesinde
// yakalar. Çıktı: /tmp/visitor_caravan.png
import 'dart:io';

import 'package:flutter/material.dart';

import '../main.dart';
import 'capture_support.dart';

final GlobalKey _boundaryKey = GlobalKey();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  kCaptureMode = true;
  kCaptureVisitors = true;
  kCaptureVisitorsSpawned = false;
  kCaptureVisitorsFocused = false;

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FittedBox(
        fit: BoxFit.contain,
        child: MediaQuery(
          data: const MediaQueryData(
            size: Size(1200, 760),
            devicePixelRatio: 1.5,
          ),
          child: SizedBox(
            width: 1200,
            height: 760,
            child: RepaintBoundary(
              key: _boundaryKey,
              child: const VillageScene(referenceVillage: true),
            ),
          ),
        ),
      ),
    ),
  );

  var waited = 0;
  while ((!kCaptureSceneReady ||
          !kCaptureVisitorsSpawned ||
          !kCaptureVisitorsFocused) &&
      waited < 400) {
    await settleFrames(50);
    waited++;
  }
  if (!kCaptureVisitorsSpawned) exit(1);
  stdout.writeln('VISITOR_REPORT: $kCaptureVisitorReport');
  await settleFrames(1600);
  final ok = await captureBoundary(
    _boundaryKey,
    '/tmp/visitor_caravan.png',
    pixelRatio: 1.25,
  );
  exit(ok ? 0 : 1);
}
