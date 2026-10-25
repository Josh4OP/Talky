import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_exception.dart';
import '../core/formatters.dart';
import '../models/analysis_summary.dart';
import '../state/history_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/cards.dart';
import '../widgets/mascot/talky_mascot.dart';
import 'result_screen.dart';

/// Historial: abrir, borrar y paginar los análisis del usuario.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.onGoHome});

  final VoidCallback onGoHome;

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryController>();
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.sm),
            child: Semantics(header: true, child: Text('Tus análisis', style: AppText.title)),
          ),
          Expanded(child: _body(context, history)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, HistoryController history) {
    if (history.error != null && history.items.isEmpty) {
      return MascotMessage(
        mascot: const TalkyMascot(state: MascotState.sad, size: 150),
        title: 'No pudimos cargar tu historial',
        message: history.error!.message,
        action: FilledButton(onPressed: history.refresh, child: const Text('Reintentar')),
      );
    }
    if (!history.loaded && history.loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.action));
    }
    if (history.loaded && history.items.isEmpty) {
      return MascotMessage(
        mascot: const TalkyMascot(state: MascotState.normal, size: 160),
        title: 'Aún no tienes análisis',
        message: 'Cuando analices una exposición, aparecerá aquí para que veas cómo vas mejorando.',
        action: FilledButton(onPressed: onGoHome, child: const Text('Analizar un audio')),
      );
    }
    return RefreshIndicator(
      color: AppColors.action,
      onRefresh: history.refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.extentAfter < 300) history.loadMore();
          return false;
        },
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
          itemCount: history.items.length + (history.hasMore ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, i) {
            if (i == history.items.length) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Center(child: CircularProgressIndicator(color: AppColors.action)),
              );
            }
            return _HistoryItem(item: history.items[i]);
          },
        ),
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({required this.item});

  final AnalysisSummary item;

  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('¿Borrar este análisis?', style: AppText.title),
        content: Text('Se borrará "${item.filename}" de tu historial. No se puede deshacer.', style: AppText.body),
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
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _open(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final analysis = await context.read<HistoryController>().open(item.id);
      navigator.push(MaterialPageRoute(builder: (_) => ResultScreen(analysis: analysis)));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = [
      Formatters.date(item.createdAt),
      '${item.totalFillers} muletillas',
      if (item.wordsPerMinute != null) '${Formatters.number(item.wordsPerMinute, decimals: 0)} ppm',
    ].where((d) => d.isNotEmpty).join('  ·  ');
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
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => _open(context),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: AppColors.tint20, borderRadius: BorderRadius.circular(AppRadius.sm)),
                  child: const Icon(Icons.graphic_eq_rounded, color: AppColors.action),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.filename, style: AppText.bodyStrong, overflow: TextOverflow.ellipsis),
                      Text(details, style: AppText.caption.copyWith(color: AppColors.inkMuted)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Borrar análisis',
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.inkMuted),
                  onPressed: () async {
                    if (await _confirmDelete(context) && context.mounted) await _delete(context);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
