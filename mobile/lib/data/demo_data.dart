import '../models/analysis.dart';
import '../models/analysis_summary.dart';

/// Datos de demostración, generados localmente y marcados con `isDemo`.
///
/// Sirven para explorar la interfaz cuando todavía no hay un backend
/// disponible. Nunca se presentan como resultados reales del usuario.
abstract final class DemoData {
  static List<AnalysisSummary> get summaries {
    final now = DateTime.now();
    return [
      AnalysisSummary(
        id: 'demo-exposicion',
        filename: 'exposicion_final.m4a',
        createdAt: now.subtract(const Duration(hours: 3)),
        duracionS: 312.4,
        ppm: 128.5,
        totalMuletillas: 13,
        isDemo: true,
      ),
      AnalysisSummary(
        id: 'demo-proyecto',
        filename: 'sustentacion_proyecto.wav',
        createdAt: now.subtract(const Duration(days: 1, hours: 2)),
        duracionS: 248.0,
        ppm: 142.0,
        totalMuletillas: 19,
        isDemo: true,
      ),
      AnalysisSummary(
        id: 'demo-entrevista',
        filename: 'practica_entrevista.mp3',
        createdAt: now.subtract(const Duration(days: 4)),
        duracionS: 186.2,
        ppm: 104.0,
        totalMuletillas: 8,
        isDemo: true,
      ),
      AnalysisSummary(
        id: 'demo-clase',
        filename: 'exposicion_clase.ogg',
        createdAt: now.subtract(const Duration(days: 9)),
        duracionS: 421.8,
        ppm: 155.0,
        totalMuletillas: 26,
        isDemo: true,
      ),
    ];
  }

  static Analysis analysis({AnalysisSummary? summary}) {
    final base = summary ?? summaries.first;
    return Analysis(
      id: base.id,
      createdAt: base.createdAt,
      duracionS: base.duracionS,
      ppm: base.ppm,
      ritmo: const [
        131.0,
        120.0,
        140.0,
        122.0,
        118.0,
        137.0,
        129.0,
        126.0,
        145.0,
        133.0,
        124.0,
        0.0,
      ],
      pausas: const PauseStats(
        pausasLargas: 4,
        segundosEnPausas: 9.6,
        pausaMaximaS: 3.1,
        pausasPorMinuto: 0.8,
      ),
      muletillas: const {
        'eh': 7,
        'o sea': 4,
        'entonces': 2,
      },
      muletillasPorMinuto: 2.5,
      transcripcionRecortada: false,
      coherencia: const Coherence(
        windows: 12,
        meanAdjacentSimilarity: 0.52,
        topicJumps: [4],
        repeatedPairs: [
          RepeatedPair(a: 2, b: 9, similarity: 0.88),
        ],
      ),
      eventosAcusticos: const AcousticEvents(
        muletillas: [
          AcousticFiller(
            start: 12.3,
            end: 12.8,
            texto: 'eh',
            source: 'both',
            confianza: 'alta',
          ),
          AcousticFiller(
            start: 88.4,
            end: 89.0,
            texto: 'eh',
            source: 'acustico',
            confianza: 'media',
          ),
        ],
        tarareos: [
          HumEvent(start: 40.1, end: 41.0, confidence: 0.82),
        ],
      ),
      advertencias: const [
        'La coherencia temática se calculó con un modelo de respaldo.',
      ],
      modelosUsados: const [
        'groq:openai/gpt-oss-20b',
        'groq:openai/gpt-oss-120b',
      ],
      modelosFallidos: const {},
      puntajes: const {
        'organizacion': ScoreStat(
          mediana: 7,
          min: 6,
          max: 8,
          desacuerdo: false,
        ),
        'claridad': ScoreStat(
          mediana: 6,
          min: 5,
          max: 7,
          desacuerdo: false,
        ),
        'repeticion': ScoreStat(
          mediana: 5,
          min: 3,
          max: 7,
          desacuerdo: true,
        ),
      },
      sintesis: const Synthesis(
        resumen:
            'La exposición tiene una estructura reconocible y una idea central clara. El ritmo es adecuado, aunque aparecen muletillas en los cambios de idea y algunas pausas largas que cortan el hilo. Con ajustes pequeños puedes sonar más seguro y fluido.',
        fortalezas: [
          'Presentas la idea principal desde el inicio y mantienes un hilo conductor.',
          'El ritmo promedio es adecuado: no hablas ni demasiado rápido ni demasiado lento.',
          'Cierras con una conclusión que recuerda el propósito de la exposición.',
        ],
        aspectosPorMejorar: [
          'Repites «eh» y «o sea» justo antes de comenzar una idea nueva.',
          'Hay cuatro pausas largas que podrían convertirse en transiciones breves.',
          'La sección de ejemplos repite una idea que ya habías explicado.',
        ],
        recomendaciones: [
          'Practica la transición entre tus dos primeras ideas en voz alta durante un minuto.',
          'Sustituye la muletilla por una pausa corta de medio segundo: el silencio también comunica.',
          'Prepara una frase bisagra para pasar de la teoría al ejemplo.',
        ],
      ),
      evidencias: const [
        Evidence(
          afirmacion: 'La introducción presenta el tema con claridad.',
          cita:
              'Hoy quiero explicarles cómo una buena retroalimentación cambia la forma en que estudiamos.',
          verificada: true,
        ),
        Evidence(
          afirmacion: 'Se repite una idea al pasar al ejemplo.',
          cita:
              'Y como les decía, la retroalimentación cambia la forma en que estudiamos, entonces en este ejemplo vemos que cambia la forma en que estudiamos.',
          verificada: true,
        ),
        Evidence(
          afirmacion: 'El cierre recupera la idea central.',
          cita:
              'En resumen, escuchar lo que hacemos bien y lo que podemos mejorar es lo que nos permite avanzar.',
          verificada: true,
        ),
      ],
      verificacion: const Verification(tasa: 0.83, descartadas: 2),
      porModelo: const {},
      isDemo: true,
    );
  }
}
