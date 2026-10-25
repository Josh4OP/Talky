import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../core/navigation.dart';
import '../data/demo_data.dart';
import '../state/history_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/analysis_list_card.dart';
import '../widgets/app_background.dart';
import '../widgets/demo_banner.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_view.dart';
import '../widgets/info_note.dart';
import '../widgets/loading_skeleton.dart';
import '../widgets/metric_tile.dart';
import '../widgets/section_header.dart';
import '../widgets/surface_card.dart';
import '../widgets/talky_logo.dart';
import '../widgets/talky_mascot.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onOpenHistory,
    required this.onOpenProfile,
  });

  final VoidCallback onOpenHistory;
  final VoidCallback onOpenProfile;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<HistoryController>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryController>();

    return RefreshIndicator(
      onRefresh: () => history.load(refresh: true),
      color: AppColors.ocean,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        child: ContentContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              _TopBar(onAvatarTap: widget.onOpenProfile),
              const SizedBox(height: 26),
              if (history.demo) ...[
                const DemoBanner(),
                const SizedBox(height: 20),
              ],
              _Greeting(onOpenHistory: widget.onOpenHistory),
              const SizedBox(height: 22),
              _HeroCard(onTap: () => openNewAnalysis(context)),
              const SizedBox(height: 18),
              _StatsStrip(history: history),
              const SizedBox(height: 30),
              SectionHeader(
                eyebrow: 'ACTIVIDAD',
                title: 'Análisis recientes',
                subtitle: 'Tu progreso, ordenado por fecha.',
                trailing: TextButton(
                  onPressed: widget.onOpenHistory,
                  child: const Text('Ver historial'),
                ),
              ),
              const SizedBox(height: 14),
              _RecentAnalyses(
                history: history,
                onSeeAll: widget.onOpenHistory,
              ),
              const SizedBox(height: 26),
              const _TipCard(),
              const SizedBox(height: 18),
              const InfoNote(
                text:
                    'Tu audio se envía para transcribirse y no se guarda. El historial conserva métricas, síntesis y citas cortas.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onAvatarTap});

  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const TalkyLogo(markSize: 38),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded, size: 13, color: AppColors.turquoiseDark),
              SizedBox(width: 5),
              Text(
                'Sesión local',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Semantics(
          button: true,
          label: 'Abrir perfil y ajustes',
          child: InkWell(
            onTap: onAvatarTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: AppColors.turquoiseGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.turquoise.withValues(alpha: 0.22),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.onOpenHistory});
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                Formatters.greeting(DateTime.now()),
                style: text.titleSmall?.copyWith(
                  color: AppColors.turquoiseDark,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                hour < 19
                    ? '¿Qué tal si practicamos hoy?'
                    : 'Cierra el día practicando tu voz.',
                style: text.headlineMedium?.copyWith(
                  fontSize: 28,
                  letterSpacing: -0.8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        IconButton(
          tooltip: 'Ver historial',
          onPressed: onOpenHistory,
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surface,
            side: const BorderSide(color: AppColors.border),
          ),
          icon: const Icon(Icons.history_rounded, size: 21),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      gradient: AppColors.heroGradient,
      borderColor: Colors.transparent,
      radius: 26,
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 680;
          final copy = Padding(
            padding: EdgeInsets.fromLTRB(
              wide ? 30 : 22,
              wide ? 30 : 24,
              wide ? 8 : 22,
              wide ? 30 : 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                      Icon(Icons.auto_awesome_rounded,
                          size: 13, color: Color(0xFF8DF0E2)),
                      SizedBox(width: 6),
                      Text(
                        'NUEVO ANÁLISIS',
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
                const SizedBox(height: 16),
                Text(
                  'Tu voz, un poco\nmás segura.',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontSize: wide ? 36 : 31,
                        height: 1.06,
                      ),
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 390),
                  child: Text(
                    'Graba o sube tu exposición y descubre qué comunicas bien y qué puedes ajustar.',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13.5,
                      height: 1.55,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.80),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.oceanDark,
                    minimumSize: const Size(0, 50),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 13,
                    ),
                    shadowColor: Colors.transparent,
                  ),
                  icon: const Icon(Icons.mic_rounded, size: 19),
                  label: const Text('Comenzar análisis'),
                ),
              ],
            ),
          );

          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                copy,
                SizedBox(
                  height: 138,
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16, bottom: 0),
                      child: Transform.translate(
                        offset: const Offset(0, 14),
                        child: const TalkyMascot(
                          size: 170,
                          pose: TalkyPose.wave,
                          animate: true,
                        ),
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
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10, right: 8),
                    child: const TalkyMascot(
                      size: 250,
                      pose: TalkyPose.wave,
                      animate: true,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.history});
  final HistoryController history;

  @override
  Widget build(BuildContext context) {
    final hasData = history.items.isNotEmpty;
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 15),
      child: Row(
        children: [
          Expanded(
            child: MetricTile(
              label: 'Análisis',
              value: hasData ? '${history.total}' : '—',
              icon: Icons.folder_open_rounded,
              color: AppColors.ocean,
              background: AppColors.blueSoft,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: MetricTile(
              label: 'Ritmo prom.',
              value: hasData
                  ? '${Formatters.ppm(history.averagePpm)} ppm'
                  : '—',
              icon: Icons.speed_rounded,
              color: AppColors.turquoiseDark,
              background: AppColors.turquoiseSoft,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: MetricTile(
              label: 'Muletillas',
              value: hasData ? '${history.totalFillers}' : '—',
              icon: Icons.record_voice_over_outlined,
              color: AppColors.coralDark,
              background: AppColors.coralSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard();

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
      color: AppColors.blueMist,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const TalkyMascot(
            size: 78,
            pose: TalkyPose.thinking,
            animate: false,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 15,
                      color: AppColors.turquoiseDark,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'TIP DE TALKY',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: AppColors.turquoiseDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  'Antes de grabar, di en voz alta la idea que quieres que tu '
                  'público recuerde. Te ayudará a no perder el hilo.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        height: 1.5,
                        color: AppColors.inkSoft,
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

class _RecentAnalyses extends StatelessWidget {
  const _RecentAnalyses({required this.history, required this.onSeeAll});

  final HistoryController history;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (history.loading && history.items.isEmpty) {
      return const AnalysisListSkeleton(count: 3);
    }

    if (history.error != null && history.items.isEmpty) {
      return SurfaceCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            InlineError(
              message: history.error!.message,
              onRetry: () => history.load(refresh: true),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => openDemoResult(context),
              icon: const Icon(Icons.science_outlined, size: 18),
              label: const Text('Ver un resultado de ejemplo'),
            ),
          ],
        ),
      );
    }

    if (history.items.isEmpty) {
      return SurfaceCard(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: EmptyState(
          compact: true,
          mascotSize: 140,
          title: 'Tu primera exposición empieza aquí',
          message:
              'Graba unos minutos de práctica o sube un audio. Talky te dirá qué hacer distinto la próxima vez.',
          actionLabel: 'Crear mi primer análisis',
          onAction: () => openNewAnalysis(context),
          secondaryLabel: 'Ver un resultado de ejemplo',
          onSecondary: () => openDemoResult(context),
        ),
      );
    }

    final recent = history.items.take(3).toList();
    return Column(
      children: [
        for (var i = 0; i < recent.length; i++) ...[
          AnalysisListCard(
            item: recent[i],
            onTap: () => openResult(
              context,
              analysis: recent[i].isDemo
                  ? DemoData.analysis(summary: recent[i])
                  : null,
              summary: recent[i],
            ),
          ),
          if (i != recent.length - 1) const SizedBox(height: 10),
        ],
        if (history.items.length > 3 || history.hasMore) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onSeeAll,
            icon: const Icon(Icons.expand_more_rounded, size: 18),
            label: const Text('Ver todos los análisis'),
          ),
        ],
      ],
    );
  }
}
