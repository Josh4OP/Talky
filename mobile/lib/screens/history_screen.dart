import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../core/navigation.dart';
import '../data/demo_data.dart';
import '../models/analysis_summary.dart';
import '../state/history_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/analysis_list_card.dart';
import '../widgets/app_background.dart';
import '../widgets/app_pill.dart';
import '../widgets/demo_banner.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_skeleton.dart';
import '../widgets/section_header.dart';
import '../widgets/surface_card.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final history = context.read<HistoryController>();
      history.load();
    });
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryController>();
    final filtered = _query.isEmpty
        ? history.items
        : history.items
            .where((item) => item.filename.toLowerCase().contains(_query))
            .toList(growable: false);

    return RefreshIndicator(
      onRefresh: () => history.load(refresh: true),
      color: AppColors.ocean,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32, top: 18),
        child: ContentContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                eyebrow: 'TU ACTIVIDAD',
                title: 'Historial',
                subtitle: 'Vuelve a tus análisis cuando quieras.',
                trailing: IconButton(
                  tooltip: 'Actualizar historial',
                  onPressed: () => history.load(refresh: true),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    side: const BorderSide(color: AppColors.border),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 21),
                ),
              ),
              const SizedBox(height: 18),
              if (history.demo) ...[
                const DemoBanner(),
                const SizedBox(height: 14),
              ],
              if (history.items.isNotEmpty) ...[
                _HistoryStats(history: history),
                const SizedBox(height: 14),
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre del audio',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: AppColors.inkMuted,
                    ),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpiar búsqueda',
                            onPressed: _searchController.clear,
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (history.loading && history.items.isEmpty)
                const AnalysisListSkeleton(count: 4)
              else if (history.error != null && history.items.isEmpty)
                SurfaceCard(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ErrorView(
                    compact: true,
                    mascotSize: 145,
                    title: 'No pudimos abrir tu historial',
                    message: history.error!.message,
                    onRetry: () => history.load(refresh: true),
                    secondaryLabel: 'Ver un resultado de ejemplo',
                    onSecondary: () => openDemoResult(context),
                  ),
                )
              else if (history.items.isEmpty)
                SurfaceCard(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: EmptyState(
                    mascotSize: 165,
                    title: 'Tu historial está esperando',
                    message:
                        'Cuando analices tu primera exposición, aparecerá aquí con sus métricas y recomendaciones.',
                    actionLabel: 'Hacer mi primer análisis',
                    onAction: () => openNewAnalysis(context),
                    secondaryLabel: 'Ver un resultado de ejemplo',
                    onSecondary: () => openDemoResult(context),
                  ),
                )
              else if (filtered.isEmpty)
                _NoResults(query: _searchController.text, onClear: _searchController.clear)
              else
                Column(
                  children: [
                    for (final item in filtered) ...[
                      Dismissible(
                        key: ValueKey('history-${item.id}'),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) => _askDelete(item),
                        onDismissed: (_) => _delete(item),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          decoration: BoxDecoration(
                            color: AppColors.dangerSoft,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: const Color(0xFFF3C7C7),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.delete_outline_rounded,
                                  color: AppColors.danger),
                              SizedBox(width: 8),
                              Text(
                                'Borrar',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.danger,
                                ),
                              ),
                            ],
                          ),
                        ),
                        child: AnalysisListCard(
                          item: item,
                          onTap: () => openResult(
                            context,
                            analysis: item.isDemo
                                ? DemoData.analysis(summary: item)
                                : null,
                            summary: item,
                          ),
                          onDelete: () => _confirmDelete(item),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (history.hasMore && _query.isEmpty) ...[
                      const SizedBox(height: 4),
                      OutlinedButton.icon(
                        onPressed:
                            history.loadingMore ? null : history.loadMore,
                        icon: history.loadingMore
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.expand_more_rounded, size: 19),
                        label: Text(
                          history.loadingMore
                              ? 'Cargando…'
                              : 'Cargar más análisis',
                        ),
                      ),
                    ],
                    if (history.actionError != null) ...[
                      const SizedBox(height: 12),
                      InlineError(
                        message: history.actionError!,
                        onRetry: history.clearActionError,
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _askDelete(AnalysisSummary item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar este análisis?'),
        content: Text(
          'Se eliminará «${item.cleanName}» y sus resultados del historial. '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              minimumSize: const Size(0, 44),
            ),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _confirmDelete(AnalysisSummary item) async {
    final confirmed = await _askDelete(item);
    if (!confirmed) return;
    await _delete(item);
  }

  Future<void> _delete(AnalysisSummary item) async {
    final history = context.read<HistoryController>();
    final error = await history.delete(item);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      await history.load(refresh: true);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Análisis borrado del historial.')),
    );
  }
}

class _HistoryStats extends StatelessWidget {
  const _HistoryStats({required this.history});
  final HistoryController history;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          _Stat(
            value: '${history.total}',
            label: 'análisis',
            icon: Icons.folder_open_rounded,
          ),
          const _Divider(),
          _Stat(
            value: Formatters.ppm(history.averagePpm),
            label: 'ppm promedio',
            icon: Icons.speed_rounded,
          ),
          const _Divider(),
          _Stat(
            value: '${history.totalFillers}',
            label: 'muletillas',
            icon: Icons.record_voice_over_outlined,
          ),
          if (history.demo) ...[
            const SizedBox(width: 4),
            const AppPill(
              label: 'Ejemplo',
              compact: true,
              foreground: AppColors.warning,
              background: AppColors.warningSoft,
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.icon});

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: AppColors.inkMuted),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: AppColors.border,
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query, required this.onClear});
  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(26),
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded, size: 34, color: AppColors.inkMuted),
          const SizedBox(height: 10),
          Text(
            'No encontramos «$query»',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const Text(
            'Prueba con otra parte del nombre del archivo.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12.5,
              color: AppColors.inkMuted,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onClear, child: const Text('Limpiar búsqueda')),
        ],
      ),
    );
  }
}
