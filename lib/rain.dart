import 'dart:typed_data';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/scheduler.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:digital_rain/atlas.dart';
import 'package:flutter/widgets.dart';

class DigitalRain extends StatelessWidget {
  const DigitalRain({
    super.key,
    required this.atlas,
    this.particles = 4096,
    this.streaks = 32,
  });

  final Atlas atlas;
  final int particles;
  final int streaks;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color.fromARGB(255, 0, 0, 0),
      child: LayoutBuilder(builder: (context, constraints) {
        return _DigitalRainExtreme(
          atlas: atlas,
          size: constraints.biggest,
          particles: particles,
          streaks: streaks,
        );
      }),
    );
  }
}

class _DigitalRainExtreme extends StatefulWidget {
  const _DigitalRainExtreme({
    // ignore: unused_element
    super.key,
    required this.atlas,
    required this.size,
    this.particles = 4096,
    this.streaks = 32,
  });

  final Atlas atlas;
  final Size size;
  final int particles;
  final int streaks;

  @override
  State<_DigitalRainExtreme> createState() => _DigitalRainExtremeState();
}

class _DigitalRainExtremeState extends State<_DigitalRainExtreme>
    with SingleTickerProviderStateMixin {
  late final DigitalRainGeometry geometry;
  late final List<Raindrop> raindrops;
  late final Ticker ticker;

  @override
  void initState() {
    super.initState();
    geometry = DigitalRainGeometry(
      atlas: widget.atlas,
      length: widget.particles,
      size: widget.size,
    );

    final random = Random();

    final streaks = List.generate(widget.streaks, (_) {
      final depth = random.nextDouble() * 2000;
      final streak = Streak(
          geometry: geometry,
          speed: random.nextDouble() * 4 + 2,
          depth: depth,
          position: Offset(
            (random.nextDouble() - 0.4) * widget.size.width * 6,
            -widget.size.height - depth,
          ));
      return streak;
    });

    int lastElapsed = 0;
    final ticker = createTicker((elapsed) {
      final delta = elapsed.inMicroseconds - lastElapsed;
      geometry.transform.translate(0.0, 0.0, -0.0001 * delta);
      final z = geometry.transform.getTranslation().z;
      for (final streak in streaks) {
        streak.tick(delta / 10000);
        if (z.abs() - 200 > streak.depth) {
          streak.clear();
          final depth = random.nextDouble() * 2000;
          streak.depth = depth - z;
          streak.position = Offset(
            (random.nextDouble() - 0.4) * widget.size.width * 6,
            -widget.size.height - depth,
          );
        }
      }
      setState(() {});
      lastElapsed = elapsed.inMicroseconds;
    });

    ticker.start();
  }

  @override
  void didUpdateWidget(covariant _DigitalRainExtreme oldWidget) {
    super.didUpdateWidget(oldWidget);
    geometry.size = widget.size;
  }

  @override
  void dispose() {
    ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CustomPaint(
        isComplex: false,
        willChange: true,
        painter: DigitalRainPainter(
          atlas: widget.atlas,
          geometry: geometry,
        ),
      ),
    );
  }
}

class Raindrop {
  Raindrop({
    required this.index,
    required this.geometry,
    this.depth = 0,
  });

  final int index;
  final DigitalRainGeometry geometry;
  double depth;

  set position(Offset offset) {
    geometry.setPosition(index, offset, depth: depth);
  }

  Offset get position => geometry.getPosition(index);

  set glyph(Glyph glyph) {
    geometry.setGlyph(index, glyph);
  }
}

class Streak {
  Streak({
    required this.geometry,
    this.position = Offset.zero,
    this.depth = 0,
    this.speed = 1,
  }) : _position = position;

  final DigitalRainGeometry geometry;
  final List<Raindrop> raindrops = [];
  Offset position;
  Offset _position;
  double depth;
  double speed;
  final Random _random = Random();

  void tick(double delta) {
    _position += Offset(0, speed * delta);
    if (_position.dy - position.dy > geometry.atlas.data.style.fontSize!) {
      _position = position;
      grow();
    }
    for (final (index, raindrop) in raindrops.indexed) {
      raindrop.position =
          position + Offset(0, index * geometry.atlas.data.style.fontSize!);
    }
    if (_random.nextDouble() < 0.05 * delta) {
      mutate();
    }
  }

  void mutate() {
    if (raindrops.isEmpty) {
      return;
    }
    raindrops[_random.nextInt(raindrops.length)].glyph =
        geometry.atlas.random();
  }

  void grow() {
    final raindrop = geometry.retrieve;
    raindrop.glyph = geometry.atlas.random();
    raindrop.depth = depth;
    raindrops.add(raindrop);
  }

  void clear() {
    for (final raindrop in raindrops) {
      geometry.release(raindrop);
    }
    raindrops.clear();
  }
}

class DigitalRainGeometry {
  DigitalRainGeometry({
    required this.atlas,
    this.length = 1,
    Size size = const Size(0, 0),
    Matrix4? transform,
  })  : positions = Float32List(length * 4 * 3),
        transformed = Float32List(length * 4 * 2),
        uvs =
            Float32List.fromList(List.filled(length * 4 * 2, -double.infinity)),
        indices = Uint16List(length * 6),
        usage = Uint8List(length),
        transform = transform ?? Matrix4.identity()
          ..setEntry(3, 2, 0.005)
          ..translate(
            -size.width / 2,
            -size.height / 2,
            0,
          ) {
    final quad03d = <double>[
      1,
      0,
      0,
      atlas[0].size.width,
      0,
      0,
      0,
      atlas[0].size.height,
      0,
      atlas[0].size.width,
      atlas[0].size.height,
      -1,
    ];
    for (int i = 0; i < length * 4 * 3; i += quad03d.length) {
      positions.setRange(i, i + quad03d.length, quad03d);
    }
    final quad0 = <double>[
      0,
      0,
      atlas[0].size.width,
      0,
      0,
      atlas[0].size.height,
      atlas[0].size.width,
      atlas[0].size.height,
    ];
    for (int i = 0; i < length * 4 * 2; i += quad0.length) {
      transformed.setRange(i, i + quad0.length, quad0);
    }
    for (int i = 0; i < length; i++) {
      final index = i * 4;
      indices.setRange(i * 6, i * 6 + 6,
          [index, index + 1, index + 2, index + 1, index + 2, index + 3]);
    }
  }

  final Atlas atlas;
  final int length;
  final Float32List positions;
  final Float32List transformed;
  final Float32List uvs;
  final Uint16List indices;
  final Uint8List usage;
  final Matrix4 transform;
  final Random _random = Random();

  set size(Size size) {
    transform.setTranslation(Vector3(
      -size.width / 2,
      -size.height / 2,
      0,
    ));
  }

  Raindrop get retrieve {
    for (int i = 0; i < length; i++) {
      if (usage[i] == 0) {
        usage[i] = 1;
        return Raindrop(index: i, geometry: this);
      }
    }
    return Raindrop(
      index: _random.nextInt(length),
      geometry: this,
    );
  }

  void release(Raindrop raindrop) {
    usage[raindrop.index] = 0;
    raindrop.position = Offset.zero;
  }

  void setGlyph(int index, Glyph glyph) {
    final quad = <double>[
      glyph.offset.dx,
      glyph.offset.dy,
      glyph.offset.dx + glyph.size.width,
      glyph.offset.dy,
      glyph.offset.dx,
      glyph.offset.dy + glyph.size.height,
      glyph.offset.dx + glyph.size.width,
      glyph.offset.dy + glyph.size.height
    ];
    uvs.setRange(index * 8, index * 8 + quad.length, quad);
  }

  Offset getPosition(int index) {
    return Offset(positions[index * 4 * 3], positions[index * 4 * 3 + 1]);
  }

  void setPosition(int index, Offset offset, {double depth = 0}) {
    final array = <double>[
      offset.dx,
      offset.dy,
      depth,
      offset.dx + atlas[0].size.width,
      offset.dy,
      depth,
      offset.dx,
      offset.dy + atlas[0].size.height,
      depth,
      offset.dx + atlas[0].size.width,
      offset.dy + atlas[0].size.height,
      depth,
    ];
    positions.setRange(index * 4 * 3, index * 4 * 3 + array.length, array);
    final v1 =
        transform.perspectiveTransform(Vector3(array[0], array[1], array[2]));
    final v2 =
        transform.perspectiveTransform(Vector3(array[3], array[4], array[5]));
    final v3 =
        transform.perspectiveTransform(Vector3(array[6], array[7], array[8]));
    final v4 =
        transform.perspectiveTransform(Vector3(array[9], array[10], array[11]));
    final indexInTransformed = index * 4 * 2;
    transformed[indexInTransformed] = v1.x;
    transformed[indexInTransformed + 1] = v1.y;
    transformed[indexInTransformed + 2] = v2.x;
    transformed[indexInTransformed + 3] = v2.y;
    transformed[indexInTransformed + 4] = v3.x;
    transformed[indexInTransformed + 5] = v3.y;
    transformed[indexInTransformed + 6] = v4.x;
    transformed[indexInTransformed + 7] = v4.y;
  }
}

class DigitalRainPainter extends CustomPainter {
  DigitalRainPainter({required this.atlas, required this.geometry});

  final Atlas atlas;
  final DigitalRainGeometry geometry;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    canvas.drawVertices(
      Vertices.raw(
        VertexMode.triangles,
        geometry.transformed,
        textureCoordinates: geometry.uvs,
        indices: geometry.indices,
      ),
      BlendMode.srcOver,
      Paint()
        ..shader = ImageShader(
          atlas.textureSync!,
          TileMode.decal,
          TileMode.decal,
          Matrix4.identity().storage,
        ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
