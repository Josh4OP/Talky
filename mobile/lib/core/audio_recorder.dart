import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'api_client.dart';

/// Error de grabación con un mensaje listo para mostrar.
class RecordingException implements Exception {
  const RecordingException(this.message);

  final String message;
}

/// Graba la exposición con el micrófono (lógica rescatada de la primera versión del front).
///
/// En el teléfono graba AAC (`.m4a`) en un temporal, que se borra apenas se leen sus bytes.
/// En el navegador recibe PCM en flujo y arma el WAV aquí: el codificador WAV de `record_web` copia
/// toda la grabación con cada bloque y congela la app a los pocos segundos, y el WebM de
/// `MediaRecorder` sale con unos segundos de más. El audio solo vive en memoria hasta que se envía.
class ExpositionRecorder {
  ExpositionRecorder({AudioRecorder? recorder}) : _recorder = recorder ?? AudioRecorder();

  static const webSampleRate = 16000;

  final AudioRecorder _recorder;
  final _pcm = BytesBuilder(copy: false);
  Future<void>? _pcmDone;
  String? _name;

  /// Nivel del micrófono de 0 a 1, unas 16 veces por segundo, para la onda de la pantalla.
  Stream<double> levels() => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 60))
      .map((a) => a.current.isFinite ? ((a.current + 50) / 50).clamp(0.0, 1.0) : 0.0);

  Future<void> start() async {
    if (!await _recorder.hasPermission()) {
      throw const RecordingException(
        'No pudimos acceder al micrófono. Revisa los permisos de la aplicación e inténtalo de nuevo.',
      );
    }
    final stamp = DateTime.now().millisecondsSinceEpoch;
    try {
      if (kIsWeb) {
        _pcm.clear();
        final stream = await _recorder.startStream(
          const RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: webSampleRate, numChannels: 1),
        );
        _pcmDone = stream.listen(_pcm.add).asFuture<void>();
        _name = 'grabacion_$stamp.wav';
      } else {
        final name = 'grabacion_$stamp.m4a';
        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 44100, numChannels: 1),
          path: '${(await getTemporaryDirectory()).path}/$name',
        );
        _name = name;
      }
    } catch (_) {
      throw const RecordingException('No pudimos iniciar la grabación. Comprueba que el micrófono esté disponible.');
    }
  }

  /// Detiene la grabación y la devuelve lista para enviar.
  Future<AudioUpload> stop() async {
    final Uint8List bytes;
    try {
      bytes = kIsWeb ? await _stopWeb() : await _stopFile();
    } on RecordingException {
      rethrow;
    } catch (_) {
      throw const RecordingException('No pudimos preparar la grabación. Inténtalo de nuevo o sube un archivo.');
    }
    if (bytes.length <= 44) {
      throw const RecordingException('La grabación quedó vacía. Inténtalo otra vez.');
    }
    return AudioUpload(name: _name ?? 'grabacion.wav', sizeBytes: bytes.length, open: () => Stream.value(bytes));
  }

  Future<Uint8List> _stopWeb() async {
    await _recorder.stop();
    // El plugin cierra el flujo al detenerse; se espera a que llegue el último bloque.
    await _pcmDone?.timeout(const Duration(seconds: 2), onTimeout: () {});
    _pcmDone = null;
    return wavFromPcm16(_pcm.takeBytes(), sampleRate: webSampleRate);
  }

  Future<Uint8List> _stopFile() async {
    final path = await _recorder.stop();
    if (path == null) throw const RecordingException('No se generó el archivo de grabación.');
    try {
      return await XFile(path).readAsBytes();
    } finally {
      await _deleteQuietly(path);
    }
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

/// Agrega el encabezado WAV (PCM de 16 bits, mono) a las muestras crudas.
Uint8List wavFromPcm16(Uint8List pcm, {required int sampleRate, int channels = 1}) {
  const bytesPerSample = 2;
  final header = ByteData(44);
  void ascii(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      header.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  header.setUint32(4, 36 + pcm.length, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, channels, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * channels * bytesPerSample, Endian.little);
  header.setUint16(32, channels * bytesPerSample, Endian.little);
  header.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  header.setUint32(40, pcm.length, Endian.little);
  return (BytesBuilder(copy: false)
        ..add(header.buffer.asUint8List())
        ..add(pcm))
      .takeBytes();
}
