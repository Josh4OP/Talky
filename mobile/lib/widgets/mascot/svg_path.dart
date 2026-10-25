import 'dart:ui';

/// Convierte un trazo SVG absoluto con los comandos M, L, Q, C y Z (los únicos que usa la mascota)
/// en un [Path]. Los números van separados por espacios, como en `parrot_geometry.dart`.
Path parseSvgPath(String data) {
  final tokens = data.trim().split(RegExp(r'\s+'));
  final path = Path();
  var i = 0;
  double next() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    final command = tokens[i++];
    switch (command) {
      case 'M':
        path.moveTo(next(), next());
      case 'L':
        path.lineTo(next(), next());
      case 'Q':
        path.quadraticBezierTo(next(), next(), next(), next());
      case 'C':
        path.cubicTo(next(), next(), next(), next(), next(), next());
      case 'Z':
        path.close();
      default:
        throw FormatException('Comando de trazo no admitido: $command');
    }
  }
  return path;
}
