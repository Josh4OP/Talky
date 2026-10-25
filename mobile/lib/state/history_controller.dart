import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/config.dart';
import '../core/preferences_controller.dart';
import '../data/demo_data.dart';
import '../models/analysis_summary.dart';

/// Historial paginado del usuario. En modo demostración usa datos locales
/// claramente marcados y nunca los mezcla con resultados reales.
class HistoryController extends ChangeNotifier {
  HistoryController(this._api, this._preferences);

  final ApiClient _api;
  final PreferencesController _preferences;

  final List<AnalysisSummary> _items = [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _initialized = false;
  ApiException? _error;
  String? _actionError;
  int _total = 0;
  bool _demo = false;

  List<AnalysisSummary> get items => List.unmodifiable(_items);
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get initialized => _initialized;
  ApiException? get error => _error;
  String? get actionError => _actionError;
  int get total => _total;
  bool get demo => _demo;
  bool get hasMore => _items.length < _total;

  int get totalFillers =>
      _items.fold(0, (sum, item) => sum + item.totalMuletillas);

  double? get averagePpm {
    final values =
        _items.map((item) => item.ppm).whereType<double>().toList(growable: false);
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  Future<void> load({bool refresh = false}) async {
    if (_loading) return;
    if (_initialized && !refresh) return;

    _demo = _preferences.demoMode;
    _error = null;

    if (_demo) {
      _items
        ..clear()
        ..addAll(DemoData.summaries);
      _total = _items.length;
      _initialized = true;
      notifyListeners();
      return;
    }

    _loading = true;
    notifyListeners();

    try {
      final page = await _api.fetchHistory(
        limit: AppConfig.pageSize,
        offset: 0,
      );
      _items
        ..clear()
        ..addAll(page.items);
      _total = page.total;
      _initialized = true;
      _error = null;
    } on ApiException catch (error) {
      _error = error;
      _initialized = true;
    } catch (_) {
      _error = const ApiException(
        message: 'No pudimos cargar tu historial. Inténtalo de nuevo.',
      );
      _initialized = true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_demo || _loading || _loadingMore || !hasMore) return;

    _loadingMore = true;
    _actionError = null;
    notifyListeners();

    try {
      final page = await _api.fetchHistory(
        limit: AppConfig.pageSize,
        offset: _items.length,
      );
      _items.addAll(page.items);
      _total = page.total;
    } on ApiException catch (error) {
      _actionError = error.message;
    } catch (_) {
      _actionError = 'No pudimos cargar más análisis.';
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  /// Devuelve `null` si se borró correctamente o el mensaje de error.
  Future<String?> delete(AnalysisSummary item) async {
    if (_demo) {
      _items.removeWhere((element) => element.id == item.id);
      _total = _items.length;
      notifyListeners();
      return null;
    }

    try {
      await _api.deleteAnalysis(item.id);
      _items.removeWhere((element) => element.id == item.id);
      _total = (_total - 1).clamp(0, 1 << 30);
      notifyListeners();
      return null;
    } on ApiException catch (error) {
      return error.message;
    } catch (_) {
      return 'No pudimos borrar el análisis. Inténtalo de nuevo.';
    }
  }

  Future<void> onModeChanged() async {
    _initialized = false;
    _items.clear();
    _total = 0;
    _error = null;
    await load(refresh: true);
  }

  void clearActionError() {
    if (_actionError == null) return;
    _actionError = null;
    notifyListeners();
  }
}
