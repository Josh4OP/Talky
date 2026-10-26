import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_exception.dart';
import '../core/formatters.dart';
import '../data/demo_data.dart';
import '../models/analysis_summary.dart';
import '../state/history_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/analysis_card.dart';
import '../widgets/cards.dart';
import '../widgets/mascot/talky_mascot.dart';
import '../widgets/sections.dart';
import 'result_screen.dart';

/// Historial: buscar, abrir, borrar y paginar los análisis del usuario.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.onGoHome});

  final VoidCallback onGoHome;

  void _openExample(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResultScreen(analysis: DemoData.analysis())));
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryController>();
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.sm, 0),
                child: SectionHeader(
                  eyebrow: 'TU ACTIVIDAD',
                  title: 'Historial',
                  subtitle: 'Vuelve a tus análisis cuando quieras.',
                  trailing: IconButton(
                    tooltip: 'Actualizar historial',
                    icon: const Icon(Icons.refresh_rounded, color: AppColors.action),
                    onPressed: history.loading ? null : history.refresh,
                  ),
                ),
              ),
              Expanded(child: _body(context, history)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, HistoryController history) {
    if (history.error != null && history.items.isEmpty) {
      return MascotMessage(
        mascot: const TalkyMascot(state: MascotState.sad, size: 150),
        title: 'No pudimos abrir tu historial',
        message: history.error!.message,
        action: Column(
          children: [
            FilledButton(onPressed: history.refresh, child: const Text('Reintentar')),
            TextButton(onPressed: () => _openExample(context), child: const Text('Ver un resultado de ejemplo')),
          ],
        ),
      );
    }
    if (!history.loaded && history.loading) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          for (var i = 0; i < 4; i++) ...[const SkeletonCard(), const SizedBox(height: AppSpacing.sm)],
        ],
      );
    }
    if (history.loaded && history.items.isEmpty) {
      return MascotMessage(
        mascot: const TalkyMascot(state: MascotState.normal, size: 160),
        title: 'Tu historial está esperando',
        message: 'Cuando analices tu primera exposición, aparecerá aquí con sus métricas y recomendaciones.',
        action: Column(
          children: [
            FilledButton(onPressed: onGoHome, child: const Text('Hacer mi primer análisis')),
            TextButton(onPressed: () => _openExample(context), child: const Text('Ver un resultado de ejemplo')),
          ],
        ),
      );
    }
    final visible = history.visibleItems;
    return RefreshIndicator(
      color: AppColors.action,
      onRefresh: history.refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.extentAfter < 300 && history.query.isEmpty) history.loadMore();
          return false;
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
          children: [
            if (history.showingDemo) ...[const DemoBanner(), const SizedBox(height: AppSpacing.sm)],
            _HistoryStats(history: history),
            const SizedBox(height: AppSpacing.md),
            _SearchField(value: history.query, onChanged: history.search),
            const SizedBox(height: AppSpacing.md),
            if (visible.isEmpty)
              _NoResults(query: history.query, onClear: () => history.search(''))
            else
              for (final item in visible) ...[_DismissibleItem(item: item), const SizedBox(height: AppSpacing.sm)],
            if (history.hasMore && history.query.isEmpty)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Center(child: CircularProgressIndicator(color: AppColors.action)),
              ),
          ],
        ),
      ),
    );
  }
}

class _HistoryStats extends StatelessWidget {
  const _HistoryStats({required this.history});

  final HistoryController history;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: MetricTile(value: '${history.total}', unit: 'análisis'),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: MetricTile(value: Formatters.number(history.averageWordsPerMinute, decimals: 0), unit: 'ppm promedio'),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: MetricTile(value: '${history.loadedFillers}', unit: 'muletillas'),
        ),
      ],
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final _text = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(_SearchField old) {
    super.didUpdateWidget(old);
    if (widget.value != _text.text) _text.text = widget.value;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _text,
      onChanged: widget.onChanged,
      style: AppText.body,
      decoration: InputDecoration(
        hintText: 'Buscar por nombre del audio',
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.inkMuted),
        suffixIcon: widget.value.isEmpty
            ? null
            : IconButton(
                tooltip: 'Limpiar búsqueda',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => widget.onChanged(''),
              ),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.full), borderSide: BorderSide.none),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query, required this.onClear});

  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        children: [
          Text('No encontramos «$query»', style: AppText.heading, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Prueba con otra parte del nombre del archivo.',
            style: AppText.body.copyWith(color: AppColors.inkMuted),
            textAlign: TextAlign.center,
          ),
          TextButton(onPressed: onClear, child: const Text('Limpiar búsqueda')),
        ],
      ),
    );
  }
}

class _DismissibleItem extends StatelessWidget {
  const _DismissibleItem({required this.item});

  final AnalysisSummary item;

  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('¿Borrar este análisis?', style: AppText.title),
        content: Text(
          'Se eliminará «${Formatters.cleanName(item.filename)}» y sus resultados del historial. '
          'Esta acción no se puede deshacer.',
          style: AppText.body,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _delete(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<HistoryController>().delete(item);
      messenger.showSnackBar(const SnackBar(content: Text('Análisis borrado del historial.')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _open(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final analysis = await context.read<HistoryController>().open(item);
      navigator.push(MaterialPageRoute(builder: (_) => ResultScreen(analysis: analysis)));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => _delete(context),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(AppRadius.md)),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.surface),
      ),
      child: AnalysisCard(
        item: item,
        onTap: () => _open(context),
        onDelete: () async {
          if (await _confirmDelete(context) && context.mounted) await _delete(context);
        },
      ),
    );
  }
}
