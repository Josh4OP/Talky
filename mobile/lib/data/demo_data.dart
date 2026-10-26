import '../models/analysis.dart';
import '../models/analysis_summary.dart';

/// Datos de ejemplo creados por la app y marcados con `isDemo`.
///
/// Sirven para mostrar la interfaz sin servidor o sin cuota de Groq.
/// Nunca se presentan como resultados reales: la interfaz los marca con un aviso.
abstract final class DemoData {
  static List<AnalysisSummary> get summaries {
    final now = DateTime.now();
    return [
      AnalysisSummary(
        id: 'demo-exposicion',
        filename: 'exposicion_final.m4a',
        createdAt: now.subtract(const Duration(hours: 3)),
        durationS: 312.4,
        wordsPerMinute: 128.5,
        totalFillers: 13,
        isDemo: true,
      ),
      AnalysisSummary(
        id: 'demo-proyecto',
        filename: 'sustentacion_proyecto.wav',
        createdAt: now.subtract(const Duration(days: 1, hours: 2)),
        durationS: 248.0,
        wordsPerMinute: 142.0,
        totalFillers: 19,
        isDemo: true,
      ),
      AnalysisSummary(
        id: 'demo-entrevista',
        filename: 'practica_entrevista.mp3',
        createdAt: now.subtract(const Duration(days: 4)),
        durationS: 186.2,
        wordsPerMinute: 104.0,
        totalFillers: 8,
        isDemo: true,
      ),
      AnalysisSummary(
        id: 'demo-clase',
        filename: 'exposicion_clase.ogg',
        createdAt: now.subtract(const Duration(days: 9)),
        durationS: 421.8,
        wordsPerMinute: 155.0,
        totalFillers: 26,
        isDemo: true,
      ),
    ];
  }

  static Analysis analysis({AnalysisSummary? summary}) {
    final base = summary ?? summaries.first;
    return Analysis(
      id: base.id,
      createdAt: base.createdAt,
      durationS: base.durationS,
      wordsPerMinute: base.wordsPerMinute,
      rhythm: const [131, 120, 140, 122, 118, 137, 129, 126, 145, 133, 124, 0],
      pauses: const Pauses(longPauses: 4, secondsInPauses: 9.6, longestS: 3.1, perMinute: 0.8),
      fillers: const {'eh': 7, 'o sea': 4, 'entonces': 2},
      fillersPerMinute: 2.5,
      transcriptTrimmed: false,
      coherence: const Coherence(windows: 12, meanSimilarity: 0.52, topicJumps: 1, repeatedPairs: 1),
      acousticEvents: null,
      warnings: const [],
      scores: const {
        'organizacion': Score(median: 7, min: 6, max: 8, disagreement: false),
        'claridad': Score(median: 6, min: 5, max: 7, disagreement: false),
        'repeticion': Score(median: 5, min: 3, max: 7, disagreement: true),
      },
      synthesis: const Synthesis(
        summary:
            'La exposición tiene una estructura reconocible y una idea central clara. El ritmo es adecuado, aunque '
            'aparecen muletillas en los cambios de idea y algunas pausas largas que cortan el hilo. Con ajustes '
            'pequeños puedes sonar más seguro y fluido.',
        strengths: [
          'Presentas la idea principal desde el inicio y mantienes un hilo conductor.',
          'El ritmo promedio es adecuado: no hablas ni demasiado rápido ni demasiado lento.',
          'Cierras con una conclusión que recuerda el propósito de la exposición.',
        ],
        improvements: [
          'Repites «eh» y «o sea» justo antes de comenzar una idea nueva.',
          'Hay cuatro pausas largas que podrían convertirse en transiciones breves.',
          'La sección de ejemplos repite una idea que ya habías explicado.',
        ],
        recommendations: [
          'Practica la transición entre tus dos primeras ideas en voz alta durante un minuto.',
          'Sustituye la muletilla por una pausa corta de medio segundo: el silencio también comunica.',
          'Prepara una frase bisagra para pasar de la teoría al ejemplo.',
        ],
      ),
      evidences: const [
        Evidence(
          claim: 'La introducción presenta el tema con claridad.',
          quote: 'Hoy quiero explicarles cómo una buena retroalimentación cambia la forma en que estudiamos.',
        ),
        Evidence(
          claim: 'Se repite una idea al pasar al ejemplo.',
          quote:
              'Y como les decía, la retroalimentación cambia la forma en que estudiamos, entonces en este ejemplo '
              'vemos que cambia la forma en que estudiamos.',
        ),
        Evidence(
          claim: 'El cierre recupera la idea central.',
          quote: 'En resumen, escuchar lo que hacemos bien y lo que podemos mejorar es lo que nos permite avanzar.',
        ),
      ],
      verification: const Verification(rate: 0.83, discarded: 2),
      isDemo: true,
    );
  }
}
