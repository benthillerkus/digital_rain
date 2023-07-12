import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/widgets.dart' hide Image;

class AtlasData {
  final String _chars;
  final TextStyle style;

  const AtlasData({
    String chars =
        "ﾊﾐﾋｰｳｼﾅﾓﾆｻﾜﾂｵﾘｱﾎﾃﾏｹﾒｴｶｷﾑﾕﾗｾﾈｽﾀﾇﾍﾊﾐﾋｰｳｼﾅﾓﾆｻﾜﾂｵﾘｱﾎﾃﾏｹﾒｴｶｷﾑﾕﾗｾﾈｽﾀﾇﾍ1234567890+-*%<>.,:;",
    this.style = const TextStyle(
      fontSize: 32,
      color: Color.fromRGBO(255, 255, 255, 1),
      shadows: [Shadow(blurRadius: 8, color: Color.fromRGBO(0, 255, 170, 1))],
      fontFamily: "monospace",
    ),
  }) : _chars = chars;

  @override
  String toString() => _chars;

  int get length => _chars.runes.length;

  List<String> get runes =>
      _chars.runes.map(String.fromCharCode).toList(growable: false);

  String operator [](int index) => runes[index];

  Future<Image> draw(Size size) async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    AtlasPainter(this).paint(canvas, size);
    final picture = recorder.endRecording();

    return await picture.toImage(size.width.toInt(), size.height.toInt());
  }

    Offset offsetOfIndex(int index, Size size) {
    return Offset(
      (index * style.fontSize!) % size.width,
      ((index * style.fontSize!) / size.height).floor() *
          style.fontSize!,
    );
  }

  AtlasData copyWith({
    String? chars,
    TextStyle? style,
  }) =>
      AtlasData(
        chars: chars ?? _chars,
        style: style ?? this.style,
      );

  @override
  bool operator ==(Object other) =>
      other is AtlasData &&
      other.runtimeType == runtimeType &&
      other.style == style &&
      other._chars == _chars;

  @override
  int get hashCode => Object.hashAllUnordered([_chars, style]);
}

typedef Glyph = ({Offset offset, String char, TextStyle style, Size size});

class Atlas {
  Atlas({
    this.data = const AtlasData(),
    this.size = const Size(512, 512),
  }) {
    _renderer.complete(data.draw(size));
    texture.then((value) => _texture = value);
  }

  final AtlasData data;
  final Size size;
  final Random _random = Random();

  int? _length;
  int get length => _length ??= data.length;

  List<String>? _runes;
  List<String> get runes => _runes ??= data.runes;

  Offset offsetOfIndex(int index) => data.offsetOfIndex(index, size);
  Offset offsetOfEmpty() => offsetOfIndex(length);

  Glyph random() {
    final index = _random.nextInt(length);
    return (
        char: runes[index],
        style: data.style,
        offset: offsetOfIndex(index),
        size: Size.square(data.style.fontSize!),
      );
  }

  Glyph operator [](int index) => (
        char: runes[index],
        style: data.style,
        offset: offsetOfIndex(index),
        size: Size.square(data.style.fontSize!),
      );

  final Completer<Image> _renderer = Completer<Image>();

  Image? _texture;
  Future<Image> get texture => _renderer.future;
  Image? get textureSync => _texture;

  @override
  bool operator ==(Object other) =>
      other is Atlas &&
      other.runtimeType == runtimeType &&
      other.size == size &&
      other.data == data;

  @override
  int get hashCode => Object.hashAllUnordered([size, data]);
}

class AtlasVisualizer extends StatelessWidget {
  const AtlasVisualizer({super.key, this.atlas = const AtlasData()});

  final AtlasData atlas;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox.square(
        dimension: 512,
        child: DecoratedBox(
          decoration: BoxDecoration(
              border:
                  Border.all(color: const Color.fromARGB(255, 255, 255, 255))),
          child: CustomPaint(
            isComplex: true,
            willChange: false,
            painter: AtlasPainter(atlas, debug: true),
          ),
        ),
      ),
    );
  }
}

class AtlasPainter extends CustomPainter {
  const AtlasPainter(this.atlas, {this.debug = false});

  final AtlasData atlas;
  final bool debug;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (index, char) in atlas.runes.indexed) {
      final painter = TextPainter(
        text: TextSpan(
          text: char,
          style: atlas.style.copyWith(fontSize: atlas.style.fontSize! * 0.8),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        textScaleFactor: 1,
        maxLines: 1,
      )..layout();

      painter.paint(
        canvas,
        atlas.offsetOfIndex(index, size) -
            Offset(painter.width / 2, painter.height / 2) +
            Offset(atlas.style.fontSize! / 2, atlas.style.fontSize! / 2),
      );
    }

    if (!debug) return;
    for (int i = 0; i < size.width; i += atlas.style.fontSize!.floor()) {
      canvas.drawLine(
        Offset(i.toDouble(), 0),
        Offset(i.toDouble(), size.height),
        Paint()
          ..color = const Color.fromRGBO(255, 255, 255, 0.5)
          ..strokeWidth = 1,
      );
      canvas.drawLine(
        Offset(0, i.toDouble()),
        Offset(size.width, i.toDouble()),
        Paint()
          ..color = const Color.fromRGBO(255, 255, 255, 0.5)
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(AtlasPainter oldDelegate) => atlas != oldDelegate.atlas;
}
