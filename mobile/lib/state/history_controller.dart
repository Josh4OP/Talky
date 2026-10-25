import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../models/analysis.dart';
import '../models/analysis_summary.dart';

/// Historial paginado del usuario (`limit=20`).
class HistoryController extends ChangeNotifier {
  HistoryController({required ApiClient api}) : _api = api;

  static const pageSize = 20;

  final ApiClient _api;

  final List<AnalysisSummary> items = [];
  int total = 0;
  bool loading = false;
  bool loaded = false;
  ApiException? error;

  bool get hasMore => items.length < total;

  Future<void> refresh() async {
    items.clear();
    total = 0;
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

  Future<Analysis> open(String id) => _api.getAnalysis(id);

  /// Quita el elemento de inmediato y lo devuelve a su lugar si la API falla.
  Future<void> delete(AnalysisSummary item) async {
    final index = items.indexOf(item);
    if (index < 0) return;
    items.removeAt(index);
    total -= 1;
    notifyListeners();
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
}
