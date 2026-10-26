import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/config.dart';
import '../models/analysis.dart';

enum AnalysisStatus { idle, picked, processing, done, failed }

/// Flujo de un análisis: elegir audio, enviarlo y guardar el resultado o el error.
class AnalysisController extends ChangeNotifier {
  AnalysisController({required ApiClient api, required Future<AudioUpload?> Function() pickAudio})
    : _api = api,
      _pickAudio = pickAudio;

  final ApiClient _api;
  final Future<AudioUpload?> Function() _pickAudio;

  AnalysisStatus status = AnalysisStatus.idle;
  AudioUpload? audio;
  Analysis? result;
  ApiException? error;

  bool get tooLarge => (audio?.sizeBytes ?? 0) > AppConfig.maxUploadBytes;
  bool get canAnalyze => audio != null && !tooLarge && status != AnalysisStatus.processing;

  Future<void> pick() async {
    final picked = await _pickAudio();
    if (picked != null) useAudio(picked);
  }

  /// Usa un audio ya listo (por ejemplo, una grabación del micrófono).
  void useAudio(AudioUpload upload) {
    audio = upload;
    status = AnalysisStatus.picked;
    error = null;
    notifyListeners();
  }

  /// Envía el audio elegido. Devuelve el resultado o `null` si falló (el error queda en [error]).
  Future<Analysis?> analyze() async {
    final selected = audio;
    if (selected == null || !canAnalyze) return null;
    status = AnalysisStatus.processing;
    error = null;
    notifyListeners();
    try {
      result = await _api.analyze(selected);
      status = AnalysisStatus.done;
      audio = null;
      return result;
    } on ApiException catch (e) {
      error = e;
      status = AnalysisStatus.failed;
      return null;
    } finally {
      notifyListeners();
    }
  }

  void clear() {
    audio = null;
    status = AnalysisStatus.idle;
    error = null;
    notifyListeners();
  }
}
