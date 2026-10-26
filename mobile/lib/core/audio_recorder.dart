import 'dart:async';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'api_client.dart';

/// Error de grabación con un mensaje listo para mostrar.
class RecordingException implements Exception {
  const RecordingException(this.message);

  final String message;
}

/// Graba la exposición con el micrófono (lógica rescatada de la primera versión del front).
/// En el teléfono graba AAC (`.m4a`) en un temporal; en el navegador, WAV. El temporal se borra
/// apenas se leen sus bytes: el audio solo vive en memoria hasta que se envía.
class ExpositionRecorder {
  ExpositionRecorder({AudioRecorder? recorder}) : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  String? _name;

  /// Nivel del micrófono de 0 a 1, para la onda de la pantalla.
  Stream<double> levels() => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 100))
      .map((a) => a.current.isFinite ? ((a.current + 50) / 50).clamp(0.0, 1.0) : 0.0);

  Future<void> start() async {
    if (!await _recorder.hasPermission()) {
      throw const RecordingException(
        'No pudimos acceder al micrófono. Revisa los permisos de la aplicación e inténtalo de nuevo.',
      );
    }
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final name = kIsWeb ? 'grabacion_$stamp.wav' : 'grabacion_$stamp.m4a';
    final path = kIsWeb ? '' : '${(await getTemporaryDirectory()).path}/$name';
    try {
      await _recorder.start(
        RecordConfig(
          encoder: kIsWeb ? AudioEncoder.wav : AudioEncoder.aacLc,
          sampleRate: kIsWeb ? 16000 : 44100,
          numChannels: 1,
          bitRate: 128000,
        ),
        path: path,
      );
    } catch (_) {
      throw const RecordingException('No pudimos iniciar la grabación. Comprueba que el micrófono esté disponible.');
    }
    _name = name;
  }

  /// Detiene la grabación y la devuelve lista para enviar.
  Future<AudioUpload> stop() async {
    final path = await _recorder.stop();
    if (path == null) throw const RecordingException('No se generó el archivo de grabación.');
    final Uint8List bytes;
    try {
      bytes = kIsWeb ? (await http.get(Uri.parse(path))).bodyBytes : await XFile(path).readAsBytes();
    } catch (_) {
      throw const RecordingException('No pudimos preparar la grabación. Inténtalo de nuevo o sube un archivo.');
    } finally {
      if (!kIsWeb) await _deleteQuietly(path);
    }
    if (bytes.isEmpty) throw const RecordingException('La grabación quedó vacía. Inténtalo otra vez.');
    return AudioUpload(name: _name ?? 'grabacion.m4a', sizeBytes: bytes.length, open: () => Stream.value(bytes));
  }

  Future<void> cancel() => _recorder.cancel();

  Future<void> dispose() => _recorder.dispose();

  static Future<void> _deleteQuietly(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // El temporal ya no existe; no hay nada que borrar.
    }
  }
}
