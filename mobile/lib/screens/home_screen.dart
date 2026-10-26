import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_exception.dart';
import '../core/audio_recorder.dart';
import '../core/formatters.dart';
import '../data/demo_data.dart';
import '../models/analysis.dart';
import '../state/analysis_controller.dart';
import '../state/history_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/analysis_card.dart';
import '../widgets/mascot/talky_mascot.dart';
import '../widgets/sections.dart';
import 'processing_screen.dart';
import 'result_screen.dart';

/// Inicio: saludo, nuevo análisis (grabar o subir) y análisis recientes.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onShowHistory});

  final VoidCallback onShowHistory;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<HistoryController>().refresh();
    });
  }

  Future<void> _analyze() async {
    final controller = context.read<AnalysisController>();
    final history = context.read<HistoryController>();
    final navigator = Navigator.of(context);
    final pending = controller.analyze();
    unawaited(pending.then((result) => result != null ? history.refresh() : null));
    final failed = await navigator.push<bool>(MaterialPageRoute(builder: (_) => ProcessingScreen(pending: pending)));
    if (failed == true && mounted && controller.error != null) {
      await showDialog<void>(
        context: context,
        builder: (_) => AnalysisErrorDialog(message: controller.error!.message),
      );
    }
  }

  void _openExample() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResultScreen(analysis: DemoData.analysis())));
  }

  Future<void> _open(Future<Analysis> loading) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final analysis = await loading;
      navigator.push(MaterialPageRoute(builder: (_) => ResultScreen(analysis: analysis)));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryController>();
    final recent = history.items.take(3).toList();
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
            children: [
              const _Greeting(),
              const SizedBox(height: AppSpacing.lg),
              _NewAnalysisCard(onAnalyze: _analyze),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: TextButton.icon(
                  onPressed: _openExample,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('Ver un resultado de ejemplo'),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SectionHeader(
                eyebrow: 'ACTIVIDAD',
                title: 'Análisis recientes',
                subtitle: 'Tu progreso, ordenado por fecha.',
                trailing: TextButton(onPressed: widget.onShowHistory, child: const Text('Ver historial')),
              ),
              if (history.showingDemo) ...[const DemoBanner(), const SizedBox(height: AppSpacing.sm)],
              if (!history.loaded && history.loading)
                for (var i = 0; i < 2; i++) ...[const SkeletonCard(), const SizedBox(height: AppSpacing.sm)]
              else if (recent.isEmpty)
                Text(
                  'Todavía no tienes análisis. El primero aparecerá aquí.',
                  style: AppText.body.copyWith(color: AppColors.inkMuted),
                )
              else
                for (final item in recent) ...[
                  AnalysisCard(item: item, onTap: () => _open(history.open(item))),
                  const SizedBox(height: AppSpacing.sm),
                ],
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.inkMuted),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Tu audio se envía para transcribirse y no se guarda. El historial conserva métricas, síntesis y '
                      'citas cortas.',
                      style: AppText.caption.copyWith(color: AppColors.inkMuted),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(Formatters.greeting(now).toUpperCase(), style: AppText.overline.copyWith(color: AppColors.action)),
              const SizedBox(height: AppSpacing.xs),
              Semantics(
                header: true,
                child: Text(
                  now.hour < 19 ? '¿Qué tal si practicamos hoy?' : 'Cierra el día practicando tu voz.',
                  style: AppText.title,
                ),
              ),
            ],
          ),
        ),
        const TalkyMascot(state: MascotState.normal, size: 112),
      ],
    );
  }
}

/// Tarjeta "Nuevo análisis": grabar con el micrófono o subir un archivo, y enviar.
class _NewAnalysisCard extends StatefulWidget {
  const _NewAnalysisCard({required this.onAnalyze});

  final VoidCallback onAnalyze;

  @override
  State<_NewAnalysisCard> createState() => _NewAnalysisCardState();
}

enum _Mode { upload, record }

class _NewAnalysisCardState extends State<_NewAnalysisCard> {
  var _mode = _Mode.upload;
  ExpositionRecorder? _recorder;
  Stream<double>? _levels;
  Timer? _clock;
  int _seconds = 0;
  bool _recording = false;
  bool _busy = false;
  String? _recordError;

  @override
  void dispose() {
    _clock?.cancel();
    final recorder = _recorder;
    if (recorder != null) {
      if (_recording) recorder.cancel();
      recorder.dispose();
    }
    super.dispose();
  }

  Future<void> _startRecording() async {
    setState(() {
      _busy = true;
      _recordError = null;
    });
    final recorder = _recorder ??= ExpositionRecorder();
    try {
      await recorder.start();
      if (!mounted) return;
      setState(() {
        _recording = true;
        _seconds = 0;
        _levels = recorder.levels().asBroadcastStream();
      });
      _clock = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _seconds++));
    } on RecordingException catch (e) {
      if (mounted) setState(() => _recordError = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stopRecording() async {
    _clock?.cancel();
    setState(() {
      _recording = false;
      _busy = true;
    });
    try {
      final upload = await _recorder!.stop();
      if (mounted) context.read<AnalysisController>().useAudio(upload);
    } on RecordingException catch (e) {
      if (mounted) setState(() => _recordError = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AnalysisController>();
    final audio = controller.audio;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: AppPill(label: 'NUEVO ANÁLISIS'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Tu voz, un poco más segura.', style: AppText.title),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Graba o sube tu exposición y descubre qué comunicas bien y qué puedes ajustar.',
            style: AppText.body.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          _ModeToggle(selected: _mode, onChanged: _recording || _busy ? null : (mode) => setState(() => _mode = mode)),
          const SizedBox(height: AppSpacing.md),
          if (_mode == _Mode.upload)
            _PickArea(
              tooLarge: controller.tooLarge,
              onTap: controller.status == AnalysisStatus.processing ? null : controller.pick,
            )
          else
            _RecordArea(
              recording: _recording,
              busy: _busy,
              seconds: _seconds,
              levels: _levels,
              error: _recordError,
              onStart: _startRecording,
              onStop: _stopRecording,
            ),
          if (audio != null) ...[
            const SizedBox(height: AppSpacing.md),
            _SelectedAudio(label: '${audio.name}  ·  ${Formatters.fileSize(audio.sizeBytes)}'),
          ],
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: controller.canAnalyze && !_recording ? widget.onAnalyze : null,
            icon: const Icon(Icons.graphic_eq_rounded),
            label: const Text('Analizar mi exposición'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _recording ? 'Detén la grabación para continuar.' : 'Esto toma entre 30 y 60 segundos.',
            style: AppText.caption.copyWith(color: AppColors.inkMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Selector "Subir archivo / Grabar" con los colores de marca.
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.selected, required this.onChanged});

  final _Mode selected;
  final ValueChanged<_Mode>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.tint20, borderRadius: BorderRadius.circular(AppRadius.full)),
      child: Row(
        children: [
          for (final (mode, icon, label) in const [
            (_Mode.upload, Icons.upload_rounded, 'Subir archivo'),
            (_Mode.record, Icons.mic_none_rounded, 'Grabar'),
          ])
            Expanded(
              child: Semantics(
                button: true,
                selected: mode == selected,
                child: GestureDetector(
                  onTap: onChanged == null ? null : () => onChanged!(mode),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: mode == selected ? AppColors.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 18, color: mode == selected ? AppColors.action : AppColors.inkMuted),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: AppText.bodyStrong.copyWith(
                            fontSize: 14,
                            color: mode == selected ? AppColors.action : AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PickArea extends StatelessWidget {
  const _PickArea({required this.tooLarge, required this.onTap});

  final bool tooLarge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.canvas,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.tint60, width: 2),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.tint20,
                child: Icon(Icons.upload_rounded, color: AppColors.action, size: 26),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('Elegir audio', style: AppText.heading),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'MP3, WAV, M4A, OGG, FLAC o WEBM, hasta 100 MB',
                style: AppText.caption.copyWith(color: AppColors.inkMuted),
                textAlign: TextAlign.center,
              ),
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
    );
  }
}

class _RecordArea extends StatelessWidget {
  const _RecordArea({
    required this.recording,
    required this.busy,
    required this.seconds,
    required this.levels,
    required this.error,
    required this.onStart,
    required this.onStop,
  });

  final bool recording;
  final bool busy;
  final int seconds;
  final Stream<double>? levels;
  final String? error;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Column(
        children: [
          Semantics(
            button: true,
            label: recording ? 'Detener grabación' : 'Empezar a grabar',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: busy ? null : (recording ? onStop : onStart),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: recording ? AppColors.danger : AppColors.action,
                  shape: BoxShape.circle,
                ),
                child: busy
                    ? const Padding(
                        padding: EdgeInsets.all(22),
                        child: CircularProgressIndicator(color: AppColors.surface, strokeWidth: 3),
                      )
                    : Icon(recording ? Icons.stop_rounded : Icons.mic_rounded, color: AppColors.surface, size: 34),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            recording ? 'Grabando  ${Formatters.duration(seconds.toDouble())}' : 'Toca para grabar tu exposición',
            style: AppText.bodyStrong.copyWith(color: recording ? AppColors.danger : AppColors.ink),
          ),
          if (recording && levels != null) ...[
            const SizedBox(height: AppSpacing.md),
            RecordingWaveform(levels: levels!),
          ],
          if (error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              error!,
              style: AppText.caption.copyWith(color: AppColors.danger),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _SelectedAudio extends StatelessWidget {
  const _SelectedAudio({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: AppColors.tint20, borderRadius: BorderRadius.circular(AppRadius.full)),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, size: 20, color: AppColors.action),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(label, style: AppText.caption, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

/// Diálogo de error del análisis, con la mascota sorprendida.
class AnalysisErrorDialog extends StatelessWidget {
  const AnalysisErrorDialog({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      icon: const TalkyMascot(state: MascotState.surprised, size: 120),
      title: Text('No pudimos completar el análisis', style: AppText.title, textAlign: TextAlign.center),
      content: Text(message, style: AppText.body, textAlign: TextAlign.center),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Entendido'))],
    );
  }
}
