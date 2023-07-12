import 'package:digital_rain/atlas.dart';
import 'package:digital_rain/rain.dart';
import 'package:flutter/widgets.dart';

Future<void> main() async {
  final atlas = Atlas();

  runApp(const AtlasVisualizer());
  await atlas.texture;

  runApp(DigitalRain(
    atlas: atlas,
    particles: 20000,
    streaks: 200,
  ));
}
