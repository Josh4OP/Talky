import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/formatters.dart';
import '../data/demo_data.dart';
import '../models/analysis.dart';
import '../models/analysis_summary.dart';
import '../theme/app_colors.dart';
import '../widgets/app_background.dart';
import '../widgets/app_pill.dart';
import '../widgets/demo_banner.dart';
import '../widgets/error_view.dart';
import '../widgets/filler_chart.dart';
import '../widgets/gradient_button.dart';
import '../widgets/info_note.dart';
import '../widgets/metric_tile.dart';
import '../widgets/rhythm_chart.dart';
import '../widgets/score_card.dart';
import '../widgets/section_header.dart';
import '../widgets/surface_card.dart';
import '../widgets/talky_logo.dart';
import '../widgets/talky_mascot.dart';
import 'new_analysis_screen.dart';

/// Pantalla de resultados. Puede recibir un [Analysis] ya cargado (por ejemplo
/// al terminar un análisis) o solo un [AnalysisSummary], en cuyo caso pide el
/// detalle a la API. Los datos de ejemplo se generan localmente y se marcan.
class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, this.analysis, this.summary});

  final Analysis? analysis;
  final AnalysisSummary? summary;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  Analysis? _analysis;
  ApiException? _error;
  bool _loading = true;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _resolve();
  }

  void _resolve() {
    final direct = widget.analysis;
    if (direct != null) {
      _analysis = direct;
      _loading = false;
      return;
    }

    final summary = widget.summary;
    if (summary == null) {
      _loading = false;
      _error = const ApiException(
        message: 'No encontramos los datos de este análisis.',
        retryable: false,
      );
      return;
    }

    if (summary.isDemo) {
      _analysis = DemoData.analysis(summary: summary);
      _loading = false;
      return;
    }

    _fetch(summary.id);
  }

  Future<void> _fetch(String id) async {
    try {
      final result = await context.read<ApiClient>().fetchAnalysis(id);
      if (!mounted) return;
      setState(() {
        _analysis = result;
        _error = null;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = const ApiException(
          message: 'No pudimos abrir este análisis. Inténtalo de nuevo.',
        );
        _loading = false;
      });
    }
  }

  void _retry() {
    final summary = widget.summary;
    if (summary == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    _fetch(summary.id);
  }

  @override
  Widget build(BuildContext context) {
    final analysis = _analysis;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(
                onBack: () => Navigator.of(context).maybePop(),
                demo: analysis?.isDemo ?? widget.summary?.isDemo ?? false,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 34),
                  child: ContentContainer(
                    maxWidth: 1040,
                    child: _loading
                        ? const _LoadingView()
                        : analysis == null
                            ? _ErrorState(
                                error: _error,
                                onRetry: widget.summary == null ? null : _retry,
                                onBack: () =>
                                    Navigator.of(context).maybePop(),
                              )
                            : _ResultBody(analysis: analysis),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack, required this.demo});

  final VoidCallback onBack;
  final bool demo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
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
          const SizedBox(width: 8),
          const TalkyLogo(markSize: 34),
          const Spacer(),
          AppPill(
            label: demo ? 'Resultado de ejemplo' : 'Resultado del análisis',
            icon: demo
                ? Icons.science_outlined
                : Icons.auto_awesome_rounded,
            foreground:
                demo ? AppColors.warning : AppColors.turquoiseDark,
            background:
                demo ? AppColors.warningSoft : AppColors.turquoiseSoft,
          ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 90),
      child: Column(
        children: [
          const SizedBox(
            width: 46,
            height: 46,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 20),
          Text(
            'Abriendo tu análisis…',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          const Text(
            'Estamos recuperando las métricas y recomendaciones guardadas.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12.5,
              color: AppColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.error,
    required this.onRetry,
    required this.onBack,
  });

  final ApiException? error;
  final VoidCallback? onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 30),
      child: ErrorView(
        title: 'No pudimos abrir el resultado',
        message: error?.message ??
            'Este análisis no está disponible en este momento.',
        onRetry: onRetry,
        secondaryLabel: 'Volver',
        onSecondary: onBack,
      ),
    );
  }
}

class _ResultBody extends StatelessWidget {
  const _ResultBody({required this.analysis});

  final Analysis analysis;

  @override
  Widget build(BuildContext context) {
    final synthesis = analysis.sintesis;
    final hasSummary = (synthesis?.resumen.isNotEmpty ?? false);
    final hasLists = synthesis != null &&
        (synthesis.fortalezas.isNotEmpty ||
            synthesis.aspectosPorMejorar.isNotEmpty ||
            synthesis.recomendaciones.isNotEmpty);
    final scores = _orderedScores(analysis.puntajes);
    final pauses = analysis.pausas;
    final acoustic = analysis.eventosAcusticos;
    final coherence = analysis.coherencia;
    final warnings = analysis.advertencias;
    final hasNotes = warnings.isNotEmpty ||
        analysis.modelosFallidos.isNotEmpty ||
        analysis.transcripcionRecortada ||
        analysis.modelosUsados.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        if (analysis.isDemo) ...[
          const DemoBanner(
            message:
                'Este resultado es un ejemplo creado por la app. No proviene de tu voz ni de tu historial.',
          ),
          const SizedBox(height: 16),
        ],
        _Hero(analysis: analysis),
        const SizedBox(height: 26),
        if (hasSummary) ...[
          _Section(
            eyebrow: 'LO ESENCIAL',
            title: 'En pocas palabras',
            child: SurfaceCard(
              padding: const EdgeInsets.all(20),
              child: Text(
                synthesis!.resumen,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 15,
                      height: 1.6,
                      color: AppColors.inkSoft,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 22),
        ],
        _KeyMetrics(analysis: analysis),
        const SizedBox(height: 26),
        if (scores.isNotEmpty) ...[
          _Section(
            eyebrow: 'PUNTAJES',
            title: 'Cómo se percibe tu exposición',
            subtitle:
                'Cada tarjeta muestra la mediana de los modelos y el rango en el que coinciden.',
            child: _ScoreGrid(scores: scores),
          ),
          const SizedBox(height: 26),
        ],
        _Section(
          eyebrow: 'MULETILLAS',
          title: 'Palabras que se repiten',
          subtitle:
              'Muletillas detectadas en la transcripción, de mayor a menor frecuencia.',
          child: SurfaceCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppPill(
                      label:
                          '${analysis.totalMuletillas} en total',
                      icon: Icons.record_voice_over_outlined,
                      foreground: AppColors.coralDark,
                      background: AppColors.coralSoft,
                    ),
                    const Spacer(),
                    if (analysis.muletillasPorMinuto != null)
                      Text(
                        '${Formatters.score(analysis.muletillasPorMinuto)} por minuto',
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkMuted,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                FillerChart(analysis: analysis),
              ],
            ),
          ),
        ),
        const SizedBox(height: 26),
        if (analysis.ritmo.isNotEmpty) ...[
          _Section(
            eyebrow: 'RITMO',
            title: 'Tu velocidad al hablar',
            subtitle:
                'Palabras por minuto por ventana de 30 segundos. Las ventanas finales en silencio se ocultan.',
            child: SurfaceCard(
              padding: const EdgeInsets.fromLTRB(14, 20, 18, 8),
              child: RhythmChart(values: analysis.ritmo),
            ),
          ),
          const SizedBox(height: 26),
        ],
        if (pauses != null) ...[
          _Section(
            eyebrow: 'PAUSAS',
            title: 'Los silencios también cuentan',
            child: _PausesCard(pauses: pauses),
          ),
          const SizedBox(height: 26),
        ],
        if (acoustic != null && !acoustic.isEmpty) ...[
          _Section(
            eyebrow: 'EVENTOS DE VOZ',
            title: 'Lo que se escuchó',
            subtitle:
                'Muletillas vocales y tatareos detectados por el análisis acústico, con el segundo en que ocurren.',
            child: _AcousticCard(events: acoustic),
          ),
          const SizedBox(height: 26),
        ],
        if (coherence != null) ...[
          _Section(
            eyebrow: 'COHERENCIA',
            title: 'El hilo de tus ideas',
            child: _CoherenceCard(coherence: coherence),
          ),
          const SizedBox(height: 26),
        ],
        if (hasLists) ...[
          _SynthesisLists(synthesis: synthesis),
          const SizedBox(height: 26),
        ],
        if (analysis.evidencias.isNotEmpty) ...[
          _Section(
            eyebrow: 'EVIDENCIAS',
            title: 'Lo que lo respalda',
            subtitle: analysis.verificacion?.tasa == null
                ? 'Citas cortas de tu transcripción.'
                : 'Citas verificadas de tu transcripción · ${Formatters.percent(analysis.verificacion!.tasa)} de coincidencia.',
            child: Column(
              children: [
                for (var i = 0; i < analysis.evidencias.length; i++) ...[
                  _EvidenceTile(evidence: analysis.evidencias[i]),
                  if (i != analysis.evidencias.length - 1)
                    const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          const SizedBox(height: 26),
        ],
        if (hasNotes) ...[
          _WarningsCard(analysis: analysis),
          const SizedBox(height: 20),
        ],
        const InfoNote(
          text:
              'Talky analiza señales observables del habla. No evalúa tu valor como persona ni sustituye la retroalimentación de tu docente.',
          foreground: AppColors.inkSoft,
        ),
        const SizedBox(height: 26),
        _ContinueCard(isDemo: analysis.isDemo),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.analysis});

  final Analysis analysis;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      gradient: AppColors.heroGradient,
      borderColor: Colors.transparent,
      radius: 28,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            const Positioned(
              right: -70,
              top: -80,
              child: _Glow(size: 260, color: Color(0x3319C7B3)),
            ),
            const Positioned(
              right: 120,
              bottom: -110,
              child: _Glow(size: 220, color: Color(0x26FFFFFF)),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 720;
                final copy = Padding(
                  padding: EdgeInsets.fromLTRB(
                    wide ? 30 : 22,
                    wide ? 30 : 24,
                    wide ? 12 : 22,
                    wide ? 30 : 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              size: 13,
                              color: Color(0xFF8DF0E2),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'ANÁLISIS COMPLETADO',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        'Así te escuchó\nTalky.',
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              color: Colors.white,
                              fontSize: wide ? 38 : 31,
                              height: 1.05,
                            ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        'Una mirada a lo que ya haces bien y a lo que puedes ajustar en tu próxima exposición.',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          height: 1.55,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.80),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _HeroMeta(
                            icon: Icons.timer_outlined,
                            label: Formatters.durationLong(analysis.duracionS),
                          ),
                          _HeroMeta(
                            icon: Icons.speed_rounded,
                            label:
                                '${Formatters.ppm(analysis.ppm)} ppm · ${Formatters.ppmShortLabel(analysis.ppm)}',
                          ),
                          if (analysis.createdAt != null)
                            _HeroMeta(
                              icon: Icons.calendar_today_outlined,
                              label: Formatters.dateTime(analysis.createdAt!),
                            ),
                        ],
                      ),
                    ],
                  ),
                );

                if (!wide) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      copy,
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Transform.translate(
                            offset: const Offset(0, 12),
                            child: const TalkyMascot(
                              size: 185,
                              pose: TalkyPose.celebrate,
                              animate: true,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 6, child: copy),
                    Expanded(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: const TalkyMascot(
                          size: 235,
                          pose: TalkyPose.celebrate,
                          animate: true,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

class _HeroMeta extends StatelessWidget {
  const _HeroMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyMetrics extends StatelessWidget {
  const _KeyMetrics({required this.analysis});

  final Analysis analysis;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      MetricTile(
        label: 'Duración',
        value: Formatters.duration(analysis.duracionS),
        caption: 'audio analizado',
        icon: Icons.timer_outlined,
        color: AppColors.ocean,
        background: AppColors.blueSoft,
      ),
      MetricTile(
        label: 'Ritmo',
        value: '${Formatters.ppm(analysis.ppm)} ppm',
        caption: Formatters.ppmLabel(analysis.ppm),
        icon: Icons.speed_rounded,
        color: AppColors.turquoiseDark,
        background: AppColors.turquoiseSoft,
      ),
      MetricTile(
        label: 'Muletillas',
        value: '${analysis.totalMuletillas}',
        caption: analysis.muletillasPorMinuto == null
            ? 'detectadas'
            : '${Formatters.score(analysis.muletillasPorMinuto)} por minuto',
        icon: Icons.record_voice_over_outlined,
        color: AppColors.coralDark,
        background: AppColors.coralSoft,
      ),
      MetricTile(
        label: 'Pausas largas',
        value:
            analysis.pausas?.pausasLargas?.toString() ?? '—',
        caption: analysis.pausas?.pausaMaximaS == null
            ? 'sin dato'
            : 'máx. ${Formatters.duration(analysis.pausas!.pausaMaximaS)}',
        icon: Icons.more_horiz_rounded,
        color: AppColors.warning,
        background: AppColors.warningSoft,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 860
            ? 4
            : width >= 500
                ? 2
                : 1;
        final itemWidth = (width - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final tile in tiles)
              SizedBox(width: itemWidth, child: tile),
          ],
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.eyebrow,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          eyebrow: eyebrow,
          title: title,
          subtitle: subtitle,
        ),
        const SizedBox(height: 13),
        child,
      ],
    );
  }
}

class _ScoreGrid extends StatelessWidget {
  const _ScoreGrid({required this.scores});

  final List<MapEntry<String, ScoreStat>> scores;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 860
            ? 3
            : width >= 520
                ? 2
                : 1;
        final itemWidth = (width - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final entry in scores)
              SizedBox(
                width: itemWidth,
                child: _ScoreCardFor(
                  key: ValueKey('score-${entry.key}'),
                  name: entry.key,
                  score: entry.value,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ScoreCardFor extends StatelessWidget {
  const _ScoreCardFor({
    super.key,
    required this.name,
    required this.score,
  });

  final String name;
  final ScoreStat score;

  @override
  Widget build(BuildContext context) {
    final (title, description, icon, color, background) = switch (name) {
      'organizacion' => (
          'Organización',
          'Cómo se ordenan y conectan tus ideas.',
          Icons.account_tree_outlined,
          AppColors.ocean,
          AppColors.blueSoft,
        ),
      'claridad' => (
          'Claridad',
          'Qué tan fácil es seguir tu explicación.',
          Icons.light_mode_outlined,
          AppColors.turquoiseDark,
          AppColors.turquoiseSoft,
        ),
      'repeticion' => (
          'Repetición',
          'Cuánto vuelves sobre la misma idea.',
          Icons.repeat_rounded,
          AppColors.coralDark,
          AppColors.coralSoft,
        ),
      _ => (
          _prettyKey(name),
          'Puntaje estimado por los modelos del análisis.',
          Icons.insights_rounded,
          AppColors.warning,
          AppColors.warningSoft,
        ),
    };

    return ScoreCard(
      title: title,
      description: description,
      score: score,
      color: color,
      background: background,
      icon: icon,
    );
  }
}

class _PausesCard extends StatelessWidget {
  const _PausesCard({required this.pauses});

  final PauseStats pauses;

  @override
  Widget build(BuildContext context) {
    final stats = <Widget>[
      _StatBox(
        label: 'Pausas largas',
        value: pauses.pausasLargas?.toString() ?? '—',
        icon: Icons.more_horiz_rounded,
        color: AppColors.ocean,
        background: AppColors.blueSoft,
      ),
      _StatBox(
        label: 'Pausa más larga',
        value: Formatters.duration(pauses.pausaMaximaS),
        icon: Icons.timelapse_rounded,
        color: AppColors.turquoiseDark,
        background: AppColors.turquoiseSoft,
      ),
      _StatBox(
        label: 'Tiempo en silencio',
        value: Formatters.duration(pauses.segundosEnPausas),
        icon: Icons.hourglass_bottom_rounded,
        color: AppColors.coralDark,
        background: AppColors.coralSoft,
      ),
      _StatBox(
        label: 'Pausas por minuto',
        value: pauses.pausasPorMinuto == null
            ? '—'
            : Formatters.score(pauses.pausasPorMinuto),
        icon: Icons.speed_rounded,
        color: AppColors.warning,
        background: AppColors.warningSoft,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const surfacePadding = 16.0;
        final width = constraints.maxWidth - surfacePadding * 2;
        final columns = width >= 700
            ? 4
            : width >= 380
                ? 2
                : 1;
        final itemWidth = (width - (columns - 1) * 10) / columns;
        return SurfaceCard(
          padding: const EdgeInsets.all(surfacePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final stat in stats)
                    SizedBox(width: itemWidth, child: stat),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Una pausa breve puede dar énfasis. Varias pausas largas seguidas pueden cortar el hilo de tu explicación.',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11.5,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.background,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: background.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 20,
              height: 1,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
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

class _AcousticCard extends StatelessWidget {
  const _AcousticCard({required this.events});

  final AcousticEvents events;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (events.muletillas.isNotEmpty) ...[
            _SubTitle(
              icon: Icons.record_voice_over_outlined,
              label:
                  'Muletillas vocales · ${events.muletillas.length}',
              color: AppColors.coralDark,
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < events.muletillas.length; i++) ...[
              _EventRow(
                time: events.muletillas[i].start,
                text: '«${events.muletillas[i].texto}»',
                detail: _sourceLabel(events.muletillas[i].source),
                confidence: events.muletillas[i].confianza,
                color: AppColors.coralDark,
                background: AppColors.coralSoft,
              ),
              if (i != events.muletillas.length - 1)
                const SizedBox(height: 8),
            ],
          ],
          if (events.muletillas.isNotEmpty && events.tarareos.isNotEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(),
            ),
          if (events.tarareos.isNotEmpty) ...[
            _SubTitle(
              icon: Icons.music_note_rounded,
              label: 'Tatareos · ${events.tarareos.length}',
              color: AppColors.ocean,
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < events.tarareos.length; i++) ...[
              _EventRow(
                time: events.tarareos[i].start,
                text: 'Tatareo',
                detail: events.tarareos[i].end == null ||
                        events.tarareos[i].start == null
                    ? null
                    : '${Formatters.duration(events.tarareos[i].end! - events.tarareos[i].start!)} de duración',
                confidence: events.tarareos[i].confidence == null
                    ? null
                    : Formatters.percent(events.tarareos[i].confidence),
                color: AppColors.ocean,
                background: AppColors.blueSoft,
              ),
              if (i != events.tarareos.length - 1)
                const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }

  String? _sourceLabel(String source) => switch (source) {
        'both' => 'Detectada en audio y texto',
        'acustico' => 'Detectada en el audio',
        'texto' => 'Detectada en la transcripción',
        _ => null,
      };
}

class _SubTitle extends StatelessWidget {
  const _SubTitle({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.time,
    required this.text,
    required this.detail,
    required this.confidence,
    required this.color,
    required this.background,
  });

  final double? time;
  final String text;
  final String? detail;
  final String? confidence;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 68,
          padding: const EdgeInsets.symmetric(vertical: 5),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            time == null ? '—' : Formatters.duration(time),
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              if (detail != null || confidence != null) ...[
                const SizedBox(height: 2),
                Text(
                  [
                    ?detail,
                    if (confidence != null) 'confianza $confidence',
                  ].join(' · '),
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 10.5,
                    height: 1.4,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CoherenceCard extends StatelessWidget {
  const _CoherenceCard({required this.coherence});

  final Coherence coherence;

  @override
  Widget build(BuildContext context) {
    final hasPairs = coherence.repeatedPairs.isNotEmpty;
    final hasJumps = coherence.topicJumps.isNotEmpty;

    return SurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _CoherenceMetric(
                  label: 'Similitud entre ideas seguidas',
                  value: Formatters.percent(coherence.meanAdjacentSimilarity),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CoherenceMetric(
                  label: 'Saltos de tema',
                  value: coherence.topicJumps.length.toString(),
                ),
              ),
            ],
          ),
          if (hasJumps) ...[
            const SizedBox(height: 14),
            Text(
              'Ventanas con un cambio de tema: ${coherence.topicJumps.join(', ')}.',
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11.5,
                height: 1.45,
                color: AppColors.inkMuted,
              ),
            ),
          ],
          if (hasPairs) ...[
            const SizedBox(height: 12),
            for (final pair in coherence.repeatedPairs)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.link_rounded,
                      size: 14,
                      color: AppColors.inkMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Las ventanas ${pair.a ?? '—'} y ${pair.b ?? '—'} '
                        'se parecen${pair.similarity == null ? '' : ' (${Formatters.percent(pair.similarity)})'}.',
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11.5,
                          height: 1.45,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 8),
          const Text(
            'Es una señal orientativa calculada a partir de la transcripción, no una nota.',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 10.5,
              height: 1.4,
              color: AppColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoherenceMetric extends StatelessWidget {
  const _CoherenceMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 24,
            height: 1,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: AppColors.ocean,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 10.5,
            height: 1.35,
            fontWeight: FontWeight.w600,
            color: AppColors.inkMuted,
          ),
        ),
      ],
    );
  }
}

class _SynthesisLists extends StatelessWidget {
  const _SynthesisLists({required this.synthesis});

  final Synthesis synthesis;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          eyebrow: 'TU PRÓXIMA VEZ',
          title: 'Qué mantener y qué ajustar',
          subtitle:
              'Sugerencias basadas en lo que se escuchó en esta exposición.',
        ),
        const SizedBox(height: 13),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 820;
            final cards = <Widget>[
              if (synthesis.fortalezas.isNotEmpty)
                _ListCard(
                  title: 'Fortalezas',
                  icon: Icons.thumb_up_alt_outlined,
                  color: AppColors.success,
                  background: AppColors.successSoft,
                  items: synthesis.fortalezas,
                ),
              if (synthesis.aspectosPorMejorar.isNotEmpty)
                _ListCard(
                  title: 'Aspectos por mejorar',
                  icon: Icons.trending_up_rounded,
                  color: AppColors.warning,
                  background: AppColors.warningSoft,
                  items: synthesis.aspectosPorMejorar,
                ),
              if (synthesis.recomendaciones.isNotEmpty)
                _ListCard(
                  title: 'Recomendaciones',
                  icon: Icons.lightbulb_outline_rounded,
                  color: AppColors.ocean,
                  background: AppColors.blueSoft,
                  items: synthesis.recomendaciones,
                ),
            ];

            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    Expanded(child: cards[i]),
                    if (i != cards.length - 1) const SizedBox(width: 12),
                  ],
                ],
              );
            }

            return Column(
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  cards[i],
                  if (i != cards.length - 1) const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.background,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color color;
  final Color background;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: color),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 14,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < items.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    items[i],
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12.5,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),
              ],
            ),
            if (i != items.length - 1) const SizedBox(height: 9),
          ],
        ],
      ),
    );
  }
}

class _EvidenceTile extends StatelessWidget {
  const _EvidenceTile({required this.evidence});

  final Evidence evidence;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  evidence.afirmacion,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontSize: 12.5,
                        color: AppColors.ink,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              AppPill(
                label: evidence.verificada ? 'Verificada' : 'Sin verificar',
                icon: evidence.verificada
                    ? Icons.verified_outlined
                    : Icons.help_outline_rounded,
                compact: true,
                foreground: evidence.verificada
                    ? AppColors.success
                    : AppColors.inkMuted,
                background: evidence.verificada
                    ? AppColors.successSoft
                    : AppColors.surfaceSunken,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
            decoration: BoxDecoration(
              color: AppColors.blueMist,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              '«${evidence.cita}»',
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12.5,
                height: 1.55,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
                color: AppColors.inkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningsCard extends StatelessWidget {
  const _WarningsCard({required this.analysis});

  final Analysis analysis;

  @override
  Widget build(BuildContext context) {
    final warnings = analysis.advertencias;
    final failed = analysis.modelosFallidos.keys.toList();

    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.warningSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: AppColors.warning,
            ),
          ),
          title: Text(
            warnings.isEmpty ? 'Notas técnicas' : 'Avisos del análisis',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          subtitle: Text(
            warnings.isEmpty
                ? 'Modelos y detalles del procesamiento.'
                : '${warnings.length} ${warnings.length == 1 ? 'aviso' : 'avisos'} para interpretar mejor el resultado.',
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.inkMuted,
            ),
          ),
          children: [
            if (analysis.transcripcionRecortada) ...[
              const _WarningLine(
                text:
                    'La transcripción se recortó por longitud. Las métricas se calculan sobre la parte conservada.',
              ),
              const SizedBox(height: 8),
            ],
            for (final warning in warnings) ...[
              _WarningLine(text: warning),
              const SizedBox(height: 8),
            ],
            if (failed.isNotEmpty) ...[
              _WarningLine(
                text:
                    'Algunos modelos no respondieron: ${failed.join(', ')}. El resultado usa los que sí respondieron.',
              ),
              const SizedBox(height: 8),
            ],
            if (analysis.modelosUsados.isNotEmpty)
              Text(
                'Modelos usados: ${analysis.modelosUsados.join(' · ')}',
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 10.5,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  color: AppColors.inkMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WarningLine extends StatelessWidget {
  const _WarningLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 5),
          child: Icon(
            Icons.circle,
            size: 5,
            color: AppColors.warning,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11.5,
              height: 1.5,
              fontWeight: FontWeight.w500,
              color: AppColors.inkSoft,
            ),
          ),
        ),
      ],
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.isDemo});

  final bool isDemo;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFEAF4FF), Color(0xFFE7FAF6)],
      ),
      borderColor: const Color(0xFFD6EBF6),
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 620;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isDemo
                    ? 'Ahora prueba con tu propia voz'
                    : 'La próxima versión se practica',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 19,
                    ),
              ),
              const SizedBox(height: 5),
              Text(
                isDemo
                    ? 'Graba o sube una exposición real para recibir tus propias métricas.'
                    : 'Vuelve cuando quieras: cada intento deja una señal nueva para mejorar.',
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  GradientButton(
                    label: isDemo ? 'Crear mi análisis' : 'Analizar otro audio',
                    icon: Icons.mic_rounded,
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => const NewAnalysisScreen(),
                        ),
                      );
                    },
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context)
                          .popUntil((route) => route.isFirst);
                    },
                    icon: const Icon(Icons.home_outlined, size: 18),
                    label: const Text('Volver al inicio'),
                  ),
                ],
              ),
            ],
          );

          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Transform.translate(
                    offset: const Offset(8, -4),
                    child: const TalkyMascot(
                      size: 110,
                      pose: TalkyPose.wave,
                      animate: false,
                    ),
                  ),
                ),
                copy,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: copy),
              const SizedBox(width: 12),
              const TalkyMascot(
                size: 150,
                pose: TalkyPose.wave,
                animate: true,
              ),
            ],
          );
        },
      ),
    );
  }
}

List<MapEntry<String, ScoreStat>> _orderedScores(
  Map<String, ScoreStat> scores,
) {
  const preferred = ['organizacion', 'claridad', 'repeticion'];
  final entries = scores.entries.toList();
  entries.sort((a, b) {
    final indexA = preferred.indexOf(a.key);
    final indexB = preferred.indexOf(b.key);
    if (indexA == -1 && indexB == -1) return a.key.compareTo(b.key);
    if (indexA == -1) return 1;
    if (indexB == -1) return -1;
    return indexA.compareTo(indexB);
  });
  return entries;
}

String _prettyKey(String key) {
  final clean = key.replaceAll('_', ' ').trim();
  if (clean.isEmpty) return 'Puntaje';
  return clean[0].toUpperCase() + clean.substring(1);
}
