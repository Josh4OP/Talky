import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../core/config.dart';
import '../core/formatters.dart';
import '../core/navigation.dart';
import '../state/analysis_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/app_background.dart';
import '../widgets/app_pill.dart';
import '../widgets/gradient_button.dart';
import '../widgets/info_note.dart';
import '../widgets/surface_card.dart';
import '../widgets/talky_mascot.dart';
import '../widgets/waveform.dart';
import 'processing_screen.dart';

enum _AudioSource { record, upload }

class _SelectedAudio {
  const _SelectedAudio({
    required this.bytes,
    required this.filename,
    required this.size,
    required this.source,
    this.durationS,
  });

  final Uint8List bytes;
  final String filename;
  final int size;
  final _AudioSource source;
  final double? durationS;
}

class NewAnalysisScreen extends StatefulWidget {
  const NewAnalysisScreen({super.key});

  @override
  State<NewAnalysisScreen> createState() => _NewAnalysisScreenState();
}

class _NewAnalysisScreenState extends State<NewAnalysisScreen> {
  final AudioRecorder _recorder = AudioRecorder();

  _AudioSource _source = _AudioSource.record;
  _SelectedAudio? _selected;
  bool _isRecording = false;
  bool _isStarting = false;
  bool _isPicking = false;
  String? _recordError;
  String? _fileError;
  int _elapsed = 0;
  Timer? _timer;
  String? _recordingName;

  @override
  void dispose() {
    _timer?.cancel();
    if (_isRecording) {
      unawaited(_recorder.cancel());
    }
    unawaited(_recorder.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final oversize = (_selected?.size ?? 0) > AppConfig.maxUploadMb * 1024 * 1024;
    final canAnalyze =
        _selected != null && !oversize && !_isRecording && !_isStarting;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(onBack: () => Navigator.of(context).maybePop()),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: ContentContainer(
                    maxWidth: 860,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        const AppPill(
                          label: 'PASO 1 DE 2',
                          icon: Icons.mic_none_rounded,
                          foreground: AppColors.turquoiseDark,
                          background: AppColors.turquoiseSoft,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Prepara tu exposición',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Elige cómo quieres compartir tu audio. Talky se encarga del resto.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.inkMuted,
                              ),
                        ),
                        const SizedBox(height: 22),
                        _SourceSelector(
                          source: _source,
                          onChanged: (value) {
                            setState(() {
                              _source = value;
                              _fileError = null;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: _source == _AudioSource.record
                              ? _RecordPanel(
                                  key: const ValueKey('record-panel'),
                                  isRecording: _isRecording,
                                  isStarting: _isStarting,
                                  elapsed: _elapsed,
                                  selected: _selected,
                                  error: _recordError,
                                  onRecord: _startRecording,
                                  onStop: _stopRecording,
                                  onRemove: _clearSelected,
                                )
                              : _UploadPanel(
                                  key: const ValueKey('upload-panel'),
                                  isPicking: _isPicking,
                                  selected: _selected,
                                  error: _fileError,
                                  onPick: _pickFile,
                                  onRemove: _clearSelected,
                                ),
                        ),
                        if (_selected != null) ...[
                          const SizedBox(height: 14),
                          _SelectedFileCard(
                            selected: _selected!,
                            oversize: oversize,
                            onRemove: _clearSelected,
                          ),
                        ],
                        const SizedBox(height: 18),
                        const _RecordingTips(),
                        const SizedBox(height: 18),
                        const InfoNote(
                          text:
                              'Tu audio se envía para transcribirse y no se guarda. Talky solo conserva las métricas y recomendaciones del análisis.',
                        ),
                        const SizedBox(height: 22),
                        GradientButton(
                          label: 'Analizar mi exposición',
                          icon: Icons.auto_awesome_rounded,
                          expand: true,
                          onPressed: canAnalyze ? _submit : null,
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            _isRecording
                                ? 'Detén la grabación para continuar.'
                                : 'Esto toma entre 30 y 60 segundos.',
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: TextButton.icon(
                            onPressed: () => openDemoResult(context),
                            icon: const Icon(Icons.science_outlined, size: 17),
                            label: const Text('Ver un resultado de ejemplo'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startRecording() async {
    if (_isStarting) return;
    setState(() {
      _isStarting = true;
      _recordError = null;
      _fileError = null;
    });

    try {
      final allowed = await _recorder.hasPermission();
      if (!allowed) {
        setState(() {
          _recordError =
              'No pudimos acceder al micrófono. Revisa los permisos de la aplicación e inténtalo de nuevo.';
        });
        return;
      }

      final stamp = DateTime.now().millisecondsSinceEpoch;
      final name = kIsWeb ? 'grabacion_$stamp.wav' : 'grabacion_$stamp.m4a';
      String path = '';
      if (!kIsWeb) {
        final directory = await getTemporaryDirectory();
        path = '${directory.path}/$name';
      }

      await _recorder.start(
        RecordConfig(
          encoder: kIsWeb ? AudioEncoder.wav : AudioEncoder.aacLc,
          sampleRate: 44100,
          numChannels: 1,
          bitRate: 128000,
        ),
        path: path,
      );

      _recordingName = name;
      setState(() {
        _isRecording = true;
        _elapsed = 0;
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _elapsed++);
      });
    } catch (error) {
      setState(() {
        _recordError =
            'No pudimos iniciar la grabación. Comprueba que el micrófono esté disponible.';
      });
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    _timer?.cancel();
    setState(() => _isRecording = false);

    try {
      final path = await _recorder.stop();
      if (path == null) {
        setState(() => _recordError = 'No se generó el archivo de grabación.');
        return;
      }

      Uint8List bytes;
      if (kIsWeb) {
        final response = await http.get(Uri.parse(path));
        bytes = response.bodyBytes;
      } else {
        bytes = await XFile(path).readAsBytes();
      }

      if (bytes.isEmpty) {
        setState(() => _recordError = 'La grabación quedó vacía. Inténtalo otra vez.');
        return;
      }

      final name = _recordingName ?? 'grabacion.m4a';
      setState(() {
        _selected = _SelectedAudio(
          bytes: bytes,
          filename: name,
          size: bytes.length,
          source: _AudioSource.record,
          durationS: _elapsed.toDouble(),
        );
        _recordError = null;
        _fileError = null;
      });
    } catch (_) {
      setState(() {
        _recordError =
            'No pudimos preparar la grabación. Inténtalo de nuevo o sube un archivo.';
      });
    }
  }

  Future<void> _pickFile() async {
    if (_isPicking) return;
    setState(() {
      _isPicking = true;
      _fileError = null;
    });

    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: AppConfig.supportedExtensions,
      );
      if (file == null) return;

      final extension = file.extension?.toLowerCase();
      if (extension == null ||
          !AppConfig.supportedExtensions.contains(extension)) {
        setState(() {
          _fileError =
              'Ese formato no está admitido. Usa ${AppConfig.supportedExtensions.map((e) => e.toUpperCase()).join(', ')}.';
        });
        return;
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        setState(() => _fileError = 'No pudimos leer el archivo seleccionado.');
        return;
      }
      final size = await file.length() ?? bytes.length;

      setState(() {
        _selected = _SelectedAudio(
          bytes: bytes,
          filename: file.name,
          size: size,
          source: _AudioSource.upload,
        );
        _recordError = null;
        _fileError = null;
      });
    } catch (_) {
      setState(() {
        _fileError = 'No pudimos abrir el archivo. Inténtalo de nuevo.';
      });
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _clearSelected() {
    setState(() {
      _selected = null;
      _fileError = null;
      _recordError = null;
    });
  }

  void _submit() {
    final selected = _selected;
    if (selected == null) return;
    context.read<AnalysisController>().submit(
          bytes: selected.bytes,
          filename: selected.filename,
        );
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ProcessingScreen()),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Volver',
            onPressed: onBack,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surface,
              side: const BorderSide(color: AppColors.border),
            ),
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
          ),
          const Spacer(),
          const AppPill(
            label: 'Audio para analizar',
            icon: Icons.lock_outline_rounded,
            foreground: AppColors.inkSoft,
            background: Colors.white,
          ),
        ],
      ),
    );
  }
}

class _SourceSelector extends StatelessWidget {
  const _SourceSelector({required this.source, required this.onChanged});

  final _AudioSource source;
  final ValueChanged<_AudioSource> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 520;
        final record = _SourceOption(
          icon: Icons.mic_rounded,
          title: 'Grabar ahora',
          subtitle: 'Usa el micrófono de tu dispositivo',
          selected: source == _AudioSource.record,
          onTap: () => onChanged(_AudioSource.record),
          accent: AppColors.ocean,
          background: AppColors.blueSoft,
        );
        final upload = _SourceOption(
          icon: Icons.upload_file_rounded,
          title: 'Subir audio',
          subtitle: 'Elige un archivo que ya tengas',
          selected: source == _AudioSource.upload,
          onTap: () => onChanged(_AudioSource.upload),
          accent: AppColors.turquoiseDark,
          background: AppColors.turquoiseSoft,
        );

        if (stack) {
          return Column(
            children: [
              record,
              const SizedBox(height: 10),
              upload,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: record),
            const SizedBox(width: 12),
            Expanded(child: upload),
          ],
        );
      },
    );
  }
}

class _SourceOption extends StatelessWidget {
  const _SourceOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    required this.accent,
    required this.background,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$title. $subtitle',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: selected ? background.withValues(alpha: 0.7) : AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? accent : AppColors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected ? Colors.white : background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 21, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 14,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? accent : Colors.transparent,
                  border: Border.all(
                    color: selected ? accent : AppColors.borderStrong,
                    width: 1.6,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check_rounded,
                        size: 13, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordPanel extends StatelessWidget {
  const _RecordPanel({
    super.key,
    required this.isRecording,
    required this.isStarting,
    required this.elapsed,
    required this.selected,
    required this.error,
    required this.onRecord,
    required this.onStop,
    required this.onRemove,
  });

  final bool isRecording;
  final bool isStarting;
  final int elapsed;
  final _SelectedAudio? selected;
  final String? error;
  final VoidCallback onRecord;
  final VoidCallback onStop;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final recorded = selected?.source == _AudioSource.record;

    return SurfaceCard(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 600;
          final mascot = SizedBox(
            width: wide ? 170 : double.infinity,
            height: wide ? 190 : 140,
            child: const TalkyMascot(
              size: 190,
              pose: TalkyPose.listening,
              animate: true,
            ),
          );

          final controls = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppPill(
                label: isRecording
                    ? 'GRABANDO'
                    : recorded
                        ? 'GRABACIÓN LISTA'
                        : 'LISTO PARA ESCUCHAR',
                icon: isRecording
                    ? Icons.fiber_manual_record_rounded
                    : Icons.graphic_eq_rounded,
                foreground:
                    isRecording ? AppColors.danger : AppColors.turquoiseDark,
                background:
                    isRecording ? AppColors.dangerSoft : AppColors.turquoiseSoft,
              ),
              const SizedBox(height: 10),
              Text(
                isRecording
                    ? 'Talky te está escuchando'
                    : recorded
                        ? 'Tu grabación está lista'
                        : 'Cuando quieras, empieza a hablar',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 19,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                isRecording
                    ? 'Habla como si estuvieras frente a tu clase. Al terminar, pulsa detener.'
                    : recorded
                        ? 'Escucha el resumen con Talky o graba otra versión si lo prefieres.'
                        : 'Pulsa el micrófono y presenta tu tema. No leas: explícalo con tus palabras.',
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12.5,
                  height: 1.5,
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: 14),
              Waveform(active: isRecording, height: 52),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    Formatters.recordingClock(elapsed),
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: isRecording ? AppColors.ink : AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isRecording)
                    const Text(
                      'en vivo',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.danger,
                      ),
                    ),
                  const Spacer(),
                  _RecordButton(
                    recording: isRecording,
                    busy: isStarting,
                    onTap: isRecording ? onStop : onRecord,
                  ),
                ],
              ),
              if (recorded) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onRecord,
                      icon: const Icon(Icons.refresh_rounded, size: 17),
                      label: const Text('Grabar de nuevo'),
                    ),
                    TextButton.icon(
                      onPressed: onRemove,
                      icon: const Icon(Icons.delete_outline_rounded, size: 17),
                      label: const Text('Quitar audio'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 10),
                InfoNote(
                  text: error!,
                  icon: Icons.mic_off_rounded,
                  foreground: AppColors.danger,
                  background: AppColors.dangerSoft,
                  borderColor: const Color(0xFFF3C7C7),
                ),
              ],
            ],
          );

          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                mascot,
                const SizedBox(width: 14),
                Expanded(child: controls),
              ],
            );
          }
          return Column(
            children: [
              mascot,
              const SizedBox(height: 4),
              controls,
            ],
          );
        },
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  const _RecordButton({
    required this.recording,
    required this.busy,
    required this.onTap,
  });

  final bool recording;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = recording ? AppColors.danger : AppColors.ocean;
    return Semantics(
      button: true,
      label: recording ? 'Detener grabación' : 'Empezar grabación',
      child: GestureDetector(
        onTap: busy ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.30),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: busy
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  recording ? Icons.stop_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: 30,
                ),
        ),
      ),
    );
  }
}

class _UploadPanel extends StatelessWidget {
  const _UploadPanel({
    super.key,
    required this.isPicking,
    required this.selected,
    required this.error,
    required this.onPick,
    required this.onRemove,
  });

  final bool isPicking;
  final _SelectedAudio? selected;
  final String? error;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final uploaded = selected?.source == _AudioSource.upload;

    return Column(
      children: [
        SurfaceCard(
          padding: const EdgeInsets.all(24),
          onTap: isPicking ? null : onPick,
          semanticLabel: 'Seleccionar un archivo de audio',
          child: Column(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: AppColors.turquoiseSoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: isPicking
                    ? const Padding(
                        padding: EdgeInsets.all(18),
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : const Icon(
                        Icons.upload_file_rounded,
                        size: 29,
                        color: AppColors.turquoiseDark,
                      ),
              ),
              const SizedBox(height: 13),
              Text(
                uploaded ? 'Elige otro archivo' : 'Selecciona un audio',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 15,
                    ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Toca aquí para buscar en tu dispositivo.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: 12),
              AppPill(
                label:
                    '${AppConfig.supportedExtensions.map((e) => e.toUpperCase()).join(' · ')}  ·  máx. ${AppConfig.uploadLimitLabel}',
                icon: Icons.audio_file_outlined,
                compact: true,
              ),
            ],
          ),
        ),
        if (uploaded) ...[
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline_rounded, size: 17),
            label: const Text('Quitar archivo'),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 10),
          InfoNote(
            text: error!,
            icon: Icons.error_outline_rounded,
            foreground: AppColors.danger,
            background: AppColors.dangerSoft,
            borderColor: const Color(0xFFF3C7C7),
          ),
        ],
      ],
    );
  }
}

class _SelectedFileCard extends StatelessWidget {
  const _SelectedFileCard({
    required this.selected,
    required this.oversize,
    required this.onRemove,
  });

  final _SelectedAudio selected;
  final bool oversize;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: oversize ? AppColors.dangerSoft : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: oversize ? const Color(0xFFF3C7C7) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: oversize ? Colors.white : AppColors.blueSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              selected.source == _AudioSource.record
                  ? Icons.mic_rounded
                  : Icons.audio_file_rounded,
              size: 21,
              color: oversize ? AppColors.danger : AppColors.ocean,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selected.filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontSize: 12.5,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${Formatters.fileSize(selected.size)} · '
                  '${selected.source == _AudioSource.record ? 'Grabación' : 'Archivo'}'
                  '${selected.durationS == null ? '' : ' · ${Formatters.duration(selected.durationS)}'}',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: oversize ? AppColors.danger : AppColors.inkMuted,
                  ),
                ),
                if (oversize) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Supera el límite de ${AppConfig.uploadLimitLabel}. Elige un audio más liviano.',
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Quitar audio',
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _RecordingTips extends StatelessWidget {
  const _RecordingTips();

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TalkyMascot(
            size: 74,
            pose: TalkyPose.thinking,
            animate: false,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Antes de empezar',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 5),
                const Text(
                  'Busca un lugar tranquilo, mantén el micrófono cerca y habla como en una exposición real. No necesitas guion: la naturalidad también se analiza.',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11.5,
                    height: 1.5,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
