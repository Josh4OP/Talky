import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../models/analysis.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/cards.dart';
import '../widgets/charts.dart';
import '../widgets/mascot/talky_mascot.dart';
import '../widgets/sections.dart';

/// Resultado de un análisis. Toda sección sin datos se oculta.
class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.analysis});

  final Analysis analysis;

  static const _aspects = {
    'organizacion': ('Organización', 'Cómo se ordenan y conectan tus ideas.'),
    'claridad': ('Claridad', 'Qué tan fácil es seguir tu explicación.'),
    'repeticion': ('Repetición', 'Cuánto vuelves sobre la misma idea.'),
  };

  @override
  Widget build(BuildContext context) {
    final a = analysis;
    final synthesis = a.synthesis;
    const gap = SizedBox(height: AppSpacing.lg);
    const small = SizedBox(height: AppSpacing.sm);
    final scores = [
      for (final entry in _aspects.entries)
        if (a.scores[entry.key] case final score?) (entry.value, score),
    ];
    final verificationRate = a.verification?.rate;
    return Scaffold(
      appBar: AppBar(title: Text(a.isDemo ? 'Resultado de ejemplo' : 'Resultado del análisis')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
              children: [
                if (a.isDemo) ...[
                  const DemoBanner(
                    message:
                        'Este resultado es un ejemplo creado por la app. No proviene de tu voz ni de tu historial.',
                  ),
                  small,
                ],
                _Hero(summary: synthesis?.summary ?? ''),
                small,
                _KeyMetrics(analysis: a),
                if (scores.isNotEmpty) ...[
                  gap,
                  const SectionHeader(
                    eyebrow: 'PUNTAJES',
                    title: 'Cómo se percibe tu exposición',
                    subtitle: 'Cada tarjeta muestra la mediana de los modelos y el rango en el que coinciden.',
                  ),
                  for (final ((label, description), score) in scores) ...[
                    ScoreCard(
                      aspect: label,
                      description: description,
                      score: score.median,
                      range: score.min != null && score.max != null ? (score.min!, score.max!) : null,
                      note: score.disagreement ? 'Los modelos no coinciden del todo en este puntaje.' : null,
                    ),
                    small,
                  ],
                ],
                if (a.fillers.isNotEmpty) ...[
                  gap,
                  SectionHeader(
                    eyebrow: 'MULETILLAS',
                    title: 'Palabras que se repiten',
                    subtitle:
                        'Detectadas en la transcripción, de mayor a menor frecuencia. ${a.totalFillers} en total.',
                  ),
                  SectionCard(child: FillerChart(counts: a.fillers)),
                ],
                if (RhythmChart.visibleWindows(a.rhythm).length > 1) ...[
                  gap,
                  const SectionHeader(
                    eyebrow: 'RITMO',
                    title: 'Tu velocidad al hablar',
                    subtitle: 'Palabras por minuto cada 30 segundos. La franja clara es el rango adecuado.',
                  ),
                  SectionCard(child: RhythmChart(windows: a.rhythm)),
                ],
                if (a.pauses case final pauses?) ...[
                  gap,
                  const SectionHeader(eyebrow: 'PAUSAS', title: 'Los silencios también cuentan'),
                  _PausesCard(pauses: pauses),
                ],
                if (a.acousticEvents case final events?) ...[
                  gap,
                  const SectionHeader(
                    eyebrow: 'EVENTOS DE VOZ',
                    title: 'Lo que se escuchó',
                    subtitle: 'Muletillas vocales y tatareos detectados en el audio, con el momento en que ocurren.',
                  ),
                  _EventsCard(events: events),
                ],
                if (a.coherence case final coherence?) ...[
                  gap,
                  const SectionHeader(eyebrow: 'COHERENCIA', title: 'El hilo de tus ideas'),
                  _CoherenceCard(coherence: coherence),
                ],
                if (synthesis != null &&
                    (synthesis.strengths.isNotEmpty ||
                        synthesis.improvements.isNotEmpty ||
                        synthesis.recommendations.isNotEmpty)) ...[
                  gap,
                  const SectionHeader(eyebrow: 'RETROALIMENTACIÓN', title: 'Qué mantener y qué ajustar'),
                  if (synthesis.strengths.isNotEmpty) ...[
                    SectionCard(
                      title: 'Fortalezas',
                      child: BulletList(items: synthesis.strengths, color: AppColors.success),
                    ),
                    small,
                  ],
                  if (synthesis.improvements.isNotEmpty) ...[
                    SectionCard(
                      title: 'Aspectos por mejorar',
                      child: BulletList(items: synthesis.improvements, color: AppColors.warning),
                    ),
                    small,
                  ],
                  if (synthesis.recommendations.isNotEmpty)
                    SectionCard(
                      title: 'Recomendaciones',
                      child: BulletList(items: synthesis.recommendations),
                    ),
                ],
                if (a.evidences.isNotEmpty) ...[
                  gap,
                  SectionHeader(
                    eyebrow: 'EVIDENCIAS',
                    title: 'Lo que lo respalda',
                    subtitle: verificationRate == null
                        ? 'Citas cortas de tu transcripción.'
                        : 'Citas verificadas de tu transcripción · ${Formatters.percent(verificationRate)} de '
                              'coincidencia.',
                  ),
                  _EvidenceCard(evidences: a.evidences),
                ],
                if (a.warnings.isNotEmpty || a.transcriptTrimmed) ...[gap, _WarningsCard(analysis: a)],
                gap,
                Text(
                  'Talky analiza señales observables del habla. No evalúa tu valor como persona ni sustituye la '
                  'retroalimentación de tu docente.',
                  style: AppText.caption.copyWith(color: AppColors.inkMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.summary});

  final String summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppPill(label: 'ANÁLISIS COMPLETADO'),
        const SizedBox(height: AppSpacing.sm),
        Semantics(header: true, child: Text('Así te escuchó Talky.', style: AppText.display)),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const TalkyMascot(state: MascotState.talking, size: 112),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: SpeechBubble(
                text: summary.isEmpty
                    ? 'Una mirada a lo que ya haces bien y a lo que puedes ajustar en tu próxima exposición.'
                    : summary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KeyMetrics extends StatelessWidget {
  const _KeyMetrics({required this.analysis});

  final Analysis analysis;

  @override
  Widget build(BuildContext context) {
    final a = analysis;
    return MetricRow(
      children: [
        Expanded(
          child: MetricTile(value: Formatters.duration(a.durationS), unit: 'duración'),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: MetricTile(
            value: Formatters.number(a.wordsPerMinute, decimals: 0),
            unit: 'palabras/min',
            label: Formatters.pace(a.wordsPerMinute),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: MetricTile(value: Formatters.number(a.fillersPerMinute), unit: 'muletillas/min'),
        ),
      ],
    );
  }
}

/// Fondo de las métricas que van dentro de una tarjeta blanca.
const _soft = AppColors.canvas;

class _PausesCard extends StatelessWidget {
  const _PausesCard({required this.pauses});

  final Pauses pauses;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MetricRow(
            children: [
              MetricTile(value: '${pauses.longPauses}', unit: 'pausas largas', background: _soft),
              MetricTile(value: '${Formatters.number(pauses.longestS)} s', unit: 'pausa más larga', background: _soft),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          MetricRow(
            children: [
              MetricTile(
                value: '${Formatters.number(pauses.secondsInPauses)} s',
                unit: 'tiempo en silencio',
                background: _soft,
              ),
              MetricTile(value: Formatters.number(pauses.perMinute), unit: 'pausas por minuto', background: _soft),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Una pausa breve puede dar énfasis. Varias pausas largas seguidas pueden cortar el hilo de tu explicación.',
            style: AppText.caption.copyWith(color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _CoherenceCard extends StatelessWidget {
  const _CoherenceCard({required this.coherence});

  final Coherence coherence;

  @override
  Widget build(BuildContext context) {
    final similarity = coherence.meanSimilarity;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MetricRow(
            children: [
              if (similarity != null)
                MetricTile(
                  value: Formatters.percent(similarity),
                  unit: 'similitud entre ideas seguidas',
                  background: _soft,
                ),
              MetricTile(value: '${coherence.topicJumps}', unit: 'saltos de tema', background: _soft),
              MetricTile(value: '${coherence.repeatedPairs}', unit: 'ideas repetidas', background: _soft),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Es una señal orientativa calculada a partir de la transcripción, no una nota.',
            style: AppText.caption.copyWith(color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _EventsCard extends StatelessWidget {
  const _EventsCard({required this.events});

  final AcousticEvents events;

  @override
  Widget build(BuildContext context) {
    final all = [...events.fillers, ...events.hums]..sort((x, y) => x.startS.compareTo(y.startS));
    return SectionCard(
      child: all.isEmpty
          ? Text('No encontramos tatareos ni muletillas vocales.', style: AppText.body)
          : Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final e in all)
                  Chip(
                    label: Text('«${e.label}»  ${Formatters.duration(e.startS)}', style: AppText.caption),
                    backgroundColor: AppColors.tint20,
                    side: BorderSide.none,
                  ),
              ],
            ),
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({required this.evidences});

  final List<Evidence> evidences;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final e in evidences)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: const Border(left: BorderSide(color: AppColors.primary, width: 4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (e.claim.isNotEmpty) ...[Text(e.claim, style: AppText.bodyStrong), const SizedBox(height: 4)],
                Text(
                  '«${e.quote}»',
                  style: AppText.body.copyWith(fontStyle: FontStyle.italic, color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _WarningsCard extends StatelessWidget {
  const _WarningsCard({required this.analysis});

  final Analysis analysis;

  @override
  Widget build(BuildContext context) {
    final notes = [
      if (analysis.transcriptTrimmed) 'La exposición era larga: los modelos leyeron el inicio y el final.',
      ...analysis.warnings,
    ];
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(Icons.info_outline_rounded, color: AppColors.warning),
          title: Text('Avisos (${notes.length})', style: AppText.heading),
          childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
          children: [BulletList(items: notes, color: AppColors.warning)],
        ),
      ),
    );
  }
}
