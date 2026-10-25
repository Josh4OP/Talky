import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../state/analysis_controller.dart';
import '../state/history_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/mascot/talky_mascot.dart';
import 'processing_screen.dart';
import 'result_screen.dart';

/// Inicio: elegir el audio y enviarlo.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onShowHistory});

  final VoidCallback onShowHistory;

  Future<void> _analyze(BuildContext context) async {
    final controller = context.read<AnalysisController>();
    final history = context.read<HistoryController>();
    final navigator = Navigator.of(context);
    final pending = controller.analyze();
    navigator.push(MaterialPageRoute(builder: (_) => const ProcessingScreen()));
    final result = await pending;
    if (!context.mounted) return;
    navigator.pop();
    if (result != null) {
      history.refresh();
      navigator.push(MaterialPageRoute(builder: (_) => ResultScreen(analysis: result)));
    } else if (controller.error != null) {
      await showDialog<void>(
        context: context,
        builder: (context) => _ErrorDialog(message: controller.error!.message),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AnalysisController>();
    final audio = controller.audio;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.lg),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TALKY', style: AppText.overline.copyWith(color: AppColors.action)),
                    const SizedBox(height: AppSpacing.xs),
                    Semantics(header: true, child: Text('Hola, practiquemos tu exposición', style: AppText.title)),
                  ],
                ),
              ),
              const TalkyMascot(state: MascotState.normal, size: 128),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Sube la grabación y te digo cómo te fue: muletillas, ritmo, pausas y claridad.',
            style: AppText.body.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          _PickArea(
            fileLabel: audio == null ? null : '${audio.name}  ·  ${Formatters.fileSize(audio.sizeBytes)}',
            tooLarge: controller.tooLarge,
            onTap: controller.status == AnalysisStatus.processing ? null : controller.pick,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: controller.canAnalyze ? () => _analyze(context) : null,
            icon: const Icon(Icons.graphic_eq_rounded),
            label: const Text('Analizar'),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.inkMuted),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Tu audio se envía para transcribirse y no se guarda.',
                  style: AppText.caption.copyWith(color: AppColors.inkMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: TextButton(onPressed: onShowHistory, child: const Text('Ver mis análisis anteriores')),
          ),
        ],
      ),
    );
  }
}

class _PickArea extends StatelessWidget {
  const _PickArea({required this.fileLabel, required this.tooLarge, required this.onTap});

  final String? fileLabel;
  final bool tooLarge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: fileLabel == null ? 'Elegir audio' : 'Cambiar audio. Elegido: $fileLabel',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.tint60, width: 2),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.tint20,
                  child: Icon(Icons.upload_rounded, color: AppColors.action, size: 28),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(fileLabel == null ? 'Elegir audio' : 'Cambiar audio', style: AppText.heading),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'MP3, WAV, M4A, OGG, FLAC o WEBM, hasta 100 MB',
                  style: AppText.caption.copyWith(color: AppColors.inkMuted),
                  textAlign: TextAlign.center,
                ),
                if (fileLabel != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.tint20,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.graphic_eq_rounded, size: 20, color: AppColors.action),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(fileLabel!, style: AppText.caption, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                ],
                if (tooLarge) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Este archivo pasa de 100 MB. Recórtalo o elige otro.',
                    style: AppText.caption.copyWith(color: AppColors.danger),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorDialog extends StatelessWidget {
  const _ErrorDialog({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      icon: const TalkyMascot(state: MascotState.surprised, size: 120),
      title: Text('No se pudo analizar', style: AppText.title, textAlign: TextAlign.center),
      content: Text(message, style: AppText.body, textAlign: TextAlign.center),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Entendido'))],
    );
  }
}
