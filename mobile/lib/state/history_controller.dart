import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../data/demo_data.dart';
import '../models/analysis.dart';
import '../models/analysis_summary.dart';
import 'preferences_controller.dart';

/// Historial paginado del usuario (`limit=20`), con búsqueda por nombre y modo de ejemplo.
class HistoryController extends ChangeNotifier {
  HistoryController({required ApiClient api, required PreferencesController preferences})
    : _api = api,
      _preferences = preferences {
    _demo = preferences.demoMode;
    preferences.addListener(_onPreferences);
  }

  static const pageSize = 20;

  final ApiClient _api;
  final PreferencesController _preferences;
  late bool _demo;

  final List<AnalysisSummary> items = [];
  int total = 0;
  bool loading = false;
  bool loaded = false;
  ApiException? error;
  String query = '';

  bool get hasMore => !_demo && items.length < total;
  bool get showingDemo => _demo;

  /// Elementos cargados cuyo nombre contiene la búsqueda (sin distinguir mayúsculas).
  List<AnalysisSummary> get visibleItems {
    final q = query.trim().toLowerCase();
    return q.isEmpty
        ? items
        : [
            for (final i in items)
              if (i.filename.toLowerCase().contains(q)) i,
          ];
  }

  /// Promedio de palabras por minuto de los análisis cargados; `null` si ninguno lo tiene.
  double? get averageWordsPerMinute {
    final values = [for (final i in items) ?i.wordsPerMinute];
    return values.isEmpty ? null : values.reduce((a, b) => a + b) / values.length;
  }

  int get loadedFillers => items.fold(0, (sum, i) => sum + i.totalFillers);

  void search(String value) {
    query = value;
    notifyListeners();
  }

  Future<void> refresh() async {
    items.clear();
    total = 0;
    if (_demo) {
      items.addAll(DemoData.summaries);
      total = items.length;
      loaded = true;
      error = null;
      notifyListeners();
      return;
    }
    await _load();
  }

  Future<void> loadMore() async {
    if (loading || !hasMore) return;
    await _load();
  }

  Future<void> _load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final page = await _api.listAnalyses(limit: pageSize, offset: items.length);
      items.addAll(page.items);
      total = page.total;
      loaded = true;
    } on ApiException catch (e) {
      error = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<Analysis> open(AnalysisSummary item) async =>
      item.isDemo ? DemoData.analysis(summary: item) : _api.getAnalysis(item.id);

  /// Quita el elemento de inmediato y lo devuelve a su lugar si la API falla.
  Future<void> delete(AnalysisSummary item) async {
    final index = items.indexOf(item);
    if (index < 0) return;
    items.removeAt(index);
    total -= 1;
    notifyListeners();
    if (item.isDemo) return;
    try {
      await _api.deleteAnalysis(item.id);
    } on ApiException catch (e) {
      // 404: ya no existía, así que quitarlo de la lista era lo correcto.
      if (e.statusCode == 404) return;
      items.insert(index, item);
      total += 1;
      notifyListeners();
      rethrow;
    }
  }

  void _onPreferences() {
    if (_preferences.demoMode == _demo) return;
    _demo = _preferences.demoMode;
    query = '';
    refresh();
  }

  @override
  void dispose() {
    _preferences.removeListener(_onPreferences);
    super.dispose();
  }
}
