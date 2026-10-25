import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../models/analysis.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/cards.dart';
import '../widgets/charts.dart';
import '../widgets/mascot/talky_mascot.dart';

/// Resultado de un análisis. Toda sección sin datos se oculta.
class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.analysis});

  final Analysis analysis;

  static const _aspects = {'organizacion': 'Organización', 'claridad': 'Claridad', 'repeticion': 'Repetición'};

  @override
  Widget build(BuildContext context) {
    final a = analysis;
    final synthesis = a.synthesis;
    const gap = SizedBox(height: AppSpacing.md);
    return Scaffold(
      appBar: AppBar(title: const Text('Tu resultado')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
          children: [
            _Summary(text: synthesis?.summary ?? ''),
            gap,
            _KeyMetrics(analysis: a),
            for (final entry in _aspects.entries)
              if (a.scores[entry.key] case final score?) ...[
                gap,
                ScoreCard(
                  aspect: entry.value,
                  score: score.median,
                  note: score.disagreement ? 'Los modelos no coinciden del todo en este puntaje.' : null,
                ),
              ],
            if (a.fillers.isNotEmpty) ...[
              gap,
              SectionCard(
                title: 'Muletillas',
                subtitle: '${a.totalFillers} en total',
                child: FillerChart(counts: a.fillers),
              ),
            ],
            if (RhythmChart.visibleWindows(a.rhythm).length > 1) ...[
              gap,
              SectionCard(
                title: 'Ritmo a lo largo de la exposición',
                subtitle: 'Palabras por minuto cada 30 segundos. La franja clara es el rango adecuado.',
                child: RhythmChart(windows: a.rhythm),
              ),
            ],
            if (a.pauses case final pauses?) ...[gap, _PausesCard(pauses: pauses)],
            if (a.acousticEvents case final events?) ...[gap, _EventsCard(events: events)],
            if (synthesis != null && synthesis.strengths.isNotEmpty) ...[
              gap,
              SectionCard(
                title: 'Fortalezas',
                child: BulletList(items: synthesis.strengths, color: AppColors.success),
              ),
            ],
            if (synthesis != null && synthesis.improvements.isNotEmpty) ...[
              gap,
              SectionCard(
                title: 'Aspectos por mejorar',
                child: BulletList(items: synthesis.improvements, color: AppColors.warning),
              ),
            ],
            if (synthesis != null && synthesis.recommendations.isNotEmpty) ...[
              gap,
              SectionCard(
                title: 'Recomendaciones',
                child: BulletList(items: synthesis.recommendations),
              ),
            ],
            if (a.evidences.isNotEmpty) ...[gap, _EvidenceCard(evidences: a.evidences)],
            if (a.warnings.isNotEmpty || a.transcriptTrimmed) ...[gap, _WarningsCard(analysis: a)],
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const TalkyMascot(state: MascotState.talking, size: 112),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: SpeechBubble(text: text.isEmpty ? 'Aquí tienes cómo te fue en tu exposición.' : text)),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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

class _PausesCard extends StatelessWidget {
  const _PausesCard({required this.pauses});

  final Pauses pauses;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Pausas largas',
      subtitle: 'Silencios de un segundo o más.',
      child: Row(
        children: [
          Expanded(
            child: MetricTile(value: '${pauses.longPauses}', unit: 'pausas largas'),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: MetricTile(value: '${Formatters.number(pauses.longestS)} s', unit: 'la más larga'),
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
      title: 'Sonidos detectados',
      subtitle: 'Muletillas vocales y tatareos, con el momento en que ocurren.',
      child: all.isEmpty
          ? Text('No encontramos tatareos ni muletillas vocales.', style: AppText.body)
          : Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final e in all)
                  Chip(
                    label: Text('${e.label}  ${Formatters.duration(e.startS)}', style: AppText.caption),
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
    return SectionCard(
      title: 'En tus propias palabras',
      subtitle: 'Frases de tu exposición que respaldan los comentarios.',
      child: Column(
        children: [
          for (final e in evidences)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: const Border(left: BorderSide(color: AppColors.primary, width: 4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('"${e.quote}"', style: AppText.body.copyWith(fontStyle: FontStyle.italic)),
                  if (e.claim.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(e.claim, style: AppText.caption.copyWith(color: AppColors.inkMuted)),
                  ],
                ],
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
