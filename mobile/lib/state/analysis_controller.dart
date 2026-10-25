import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../data/demo_data.dart';
import '../models/analysis.dart';
import '../models/analysis_summary.dart';

enum AnalysisStatus { idle, uploading, processing, success, error }

/// Orquesta el envío del audio y el estado del análisis en curso.
class AnalysisController extends ChangeNotifier {
  AnalysisController(this._api);

  static const stageLabels = <String>[
    'Preparando tu audio',
    'Transcribiendo la exposición',
    'Evaluando ritmo, pausas y muletillas',
    'Sintetizando fortalezas y recomendaciones',
  ];

  final ApiClient _api;

  AnalysisStatus _status = AnalysisStatus.idle;
  Analysis? _analysis;
  ApiException? _error;
  Uint8List? _pendingBytes;
  String? _pendingFilename;
  int _stage = 0;
  Timer? _stageTimer;
  DateTime? _startedAt;

  AnalysisStatus get status => _status;
  Analysis? get analysis => _analysis;
  ApiException? get error => _error;
  String? get filename => _pendingFilename;
  int get stage => _stage;
  bool get canRetry => _pendingBytes != null && _pendingFilename != null;
  DateTime? get startedAt => _startedAt;

  bool get isBusy =>
      _status == AnalysisStatus.uploading || _status == AnalysisStatus.processing;

  Future<void> submit({
    required Uint8List bytes,
    required String filename,
  }) async {
    _pendingBytes = bytes;
    _pendingFilename = filename;
    _analysis = null;
    _error = null;
    _status = AnalysisStatus.uploading;
    _stage = 0;
    _startedAt = DateTime.now();
    notifyListeners();
    _startStageTicker();

    try {
      final result = await _api.uploadAnalysis(bytes: bytes, filename: filename);
      _stageTimer?.cancel();
      _analysis = result;
      _status = AnalysisStatus.success;
      _stage = stageLabels.length - 1;
      notifyListeners();
    } on ApiException catch (error) {
      _stageTimer?.cancel();
      _error = error;
      _status = AnalysisStatus.error;
      notifyListeners();
    } catch (_) {
      _stageTimer?.cancel();
      _error = const ApiException(
        message: 'Ocurrió un problema inesperado al analizar el audio.',
      );
      _status = AnalysisStatus.error;
      notifyListeners();
    }
  }

  Future<void> retry() async {
    final bytes = _pendingBytes;
    final name = _pendingFilename;
    if (bytes == null || name == null) return;
    await submit(bytes: bytes, filename: name);
  }

  void showDemo([AnalysisSummary? summary]) {
    _stageTimer?.cancel();
    _pendingBytes = null;
    _pendingFilename = summary?.filename ?? 'exposicion_final.m4a';
    _analysis = DemoData.analysis(summary: summary);
    _error = null;
    _status = AnalysisStatus.success;
    _stage = stageLabels.length - 1;
    notifyListeners();
  }

  void showSaved(Analysis analysis) {
    _stageTimer?.cancel();
    _analysis = analysis;
    _error = null;
    _status = AnalysisStatus.success;
    notifyListeners();
  }

  void reset() {
    _stageTimer?.cancel();
    _pendingBytes = null;
    _pendingFilename = null;
    _analysis = null;
    _error = null;
    _status = AnalysisStatus.idle;
    _stage = 0;
    _startedAt = null;
    notifyListeners();
  }

  void _startStageTicker() {
    _stageTimer?.cancel();
    _status = AnalysisStatus.processing;
    notifyListeners();
    _stageTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (_status != AnalysisStatus.processing) {
        timer.cancel();
        return;
      }
      if (_stage < stageLabels.length - 1) {
        _stage++;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _stageTimer?.cancel();
    super.dispose();
  }
}
