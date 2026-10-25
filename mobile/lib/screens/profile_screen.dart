import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/config.dart';
import '../core/preferences_controller.dart';
import '../state/history_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/app_background.dart';
import '../widgets/app_pill.dart';
import '../widgets/demo_banner.dart';
import '../widgets/info_note.dart';
import '../widgets/section_header.dart';
import '../widgets/surface_card.dart';
import '../widgets/talky_mascot.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

enum _HealthState { idle, checking, online, offline }

class _ProfileScreenState extends State<ProfileScreen> {
  _HealthState _health = _HealthState.idle;
  String? _healthMessage;

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<PreferencesController>();
    final history = context.watch<HistoryController>();
    final api = context.read<ApiClient>();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 36, top: 18),
      child: ContentContainer(
        maxWidth: 880,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              eyebrow: 'TU ESPACIO',
              title: 'Perfil y ajustes',
              subtitle: 'Preferencias, privacidad y conexión.',
            ),
            const SizedBox(height: 18),
            if (prefs.demoMode) ...[
              const DemoBanner(),
              const SizedBox(height: 14),
            ],
            _IdentityHero(
              userId: prefs.userId,
              onCopy: () => _copy(context, prefs.userId, 'Identificador copiado'),
            ),
            const SizedBox(height: 16),
            _PreferencesCard(
              reduceMotion: prefs.reduceMotion,
              demoMode: prefs.demoMode,
              onReduceMotion: prefs.setReduceMotion,
              onDemoMode: (value) async {
                await prefs.setDemoMode(value);
                await history.onModeChanged();
                if (!context.mounted) return;
                _showMessage(
                  context,
                  value
                      ? 'Modo de ejemplo activado. Los datos están marcados.'
                      : 'Modo de ejemplo desactivado. Volviste a tus datos reales.',
                );
              },
              onResetWelcome: () => _confirmWelcome(context, prefs),
            ),
            const SizedBox(height: 16),
            _ConnectionCard(
              baseUrl: api.baseUrl,
              health: _health,
              message: _healthMessage,
              onCheck: () => _checkHealth(api),
              onCopy: () => _copy(context, api.baseUrl, 'Dirección de la API copiada'),
            ),
            const SizedBox(height: 16),
            _PrivacyCard(historyCount: history.total),
            const SizedBox(height: 16),
            const _AboutCard(),
          ],
        ),
      ),
    );
  }

  Future<void> _checkHealth(ApiClient api) async {
    setState(() {
      _health = _HealthState.checking;
      _healthMessage = null;
    });
    final result = await api.checkHealth();
    if (!mounted) return;
    setState(() {
      _health = result.online ? _HealthState.online : _HealthState.offline;
      _healthMessage = result.message;
    });
  }

  Future<void> _copy(BuildContext context, String text, String confirmation) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    _showMessage(context, confirmation);
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmWelcome(
    BuildContext context,
    PreferencesController prefs,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Volver a la bienvenida?'),
        content: const Text(
          'Verás otra vez la presentación de TALKY. Tus análisis y tu '
          'identificador se conservan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ver bienvenida'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      prefs.resetOnboarding();
    }
  }
}

class _IdentityHero extends StatelessWidget {
  const _IdentityHero({required this.userId, required this.onCopy});

  final String userId;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final masked = userId.length > 18
        ? '${userId.substring(0, 12)}…${userId.substring(userId.length - 5)}'
        : userId;

    return SurfaceCard(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFEAF4FF), Color(0xFFE7FAF6)],
      ),
      borderColor: const Color(0xFFD6EBF6),
      padding: const EdgeInsets.fromLTRB(22, 20, 16, 20),
      child: Row(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white),
            ),
            child: const ClipOval(
              child: TalkyMascot(
                size: 88,
                pose: TalkyPose.wave,
                animate: true,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppPill(
                  label: 'Identidad local',
                  icon: Icons.fingerprint_rounded,
                  foreground: AppColors.turquoiseDark,
                  background: Colors.white,
                ),
                const SizedBox(height: 9),
                Text(
                  'Estudiante TALKY',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  masked,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copiar identificador',
            onPressed: onCopy,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.8),
            ),
            icon: const Icon(Icons.copy_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _PreferencesCard extends StatelessWidget {
  const _PreferencesCard({
    required this.reduceMotion,
    required this.demoMode,
    required this.onReduceMotion,
    required this.onDemoMode,
    required this.onResetWelcome,
  });

  final bool reduceMotion;
  final bool demoMode;
  final ValueChanged<bool> onReduceMotion;
  final ValueChanged<bool> onDemoMode;
  final VoidCallback onResetWelcome;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
            child: Row(
              children: [
                const Icon(Icons.tune_rounded, size: 19, color: AppColors.ocean),
                const SizedBox(width: 8),
                Text(
                  'Preferencias',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          SwitchListTile(
            value: reduceMotion,
            onChanged: onReduceMotion,
            title: const Text('Reducir animaciones'),
            subtitle: const Text(
              'Menos movimiento en la mascota y las transiciones.',
            ),
            secondary: const _TileIcon(
              icon: Icons.motion_photos_off_rounded,
              color: AppColors.ocean,
              background: AppColors.blueSoft,
            ),
            activeTrackColor: AppColors.turquoise,
          ),
          const Divider(indent: 18, endIndent: 18),
          SwitchListTile(
            value: demoMode,
            onChanged: onDemoMode,
            title: const Text('Explorar con datos de ejemplo'),
            subtitle: const Text(
              'Muestra análisis ficticios, siempre marcados como ejemplo.',
            ),
            secondary: const _TileIcon(
              icon: Icons.science_outlined,
              color: AppColors.warning,
              background: AppColors.warningSoft,
            ),
            activeTrackColor: AppColors.turquoise,
          ),
          const Divider(indent: 18, endIndent: 18),
          ListTile(
            onTap: onResetWelcome,
            leading: const _TileIcon(
              icon: Icons.waving_hand_outlined,
              color: AppColors.coralDark,
              background: AppColors.coralSoft,
            ),
            title: const Text('Volver a ver la bienvenida'),
            subtitle: const Text('Repite la presentación de Talky.'),
            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.baseUrl,
    required this.health,
    required this.message,
    required this.onCheck,
    required this.onCopy,
  });

  final String baseUrl;
  final _HealthState health;
  final String? message;
  final VoidCallback onCheck;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final (label, color, background) = switch (health) {
      _HealthState.idle => ('Sin verificar', AppColors.inkMuted, AppColors.surfaceSunken),
      _HealthState.checking => ('Comprobando…', AppColors.ocean, AppColors.blueSoft),
      _HealthState.online => ('En línea', AppColors.success, AppColors.successSoft),
      _HealthState.offline => ('Sin conexión', AppColors.danger, AppColors.dangerSoft),
    };

    return SurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _TileIcon(
                icon: Icons.dns_outlined,
                color: AppColors.ocean,
                background: AppColors.blueSoft,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Conexión con la API',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              AppPill(
                label: label,
                foreground: color,
                background: background,
                icon: health == _HealthState.checking
                    ? Icons.hourglass_top_rounded
                    : Icons.circle,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.blueMist,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    baseUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copiar dirección de la API',
                  onPressed: onCopy,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy_rounded, size: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  message ??
                      'La app se conecta al servidor configurado al compilar. '
                          'Puedes cambiarlo con API_BASE_URL.',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11.5,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                    color: AppColors.inkMuted,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              TextButton.icon(
                onPressed: health == _HealthState.checking ? null : onCheck,
                icon: health == _HealthState.checking
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_tethering_rounded, size: 17),
                label: const Text('Probar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({required this.historyCount});
  final int historyCount;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _TileIcon(
                icon: Icons.shield_outlined,
                color: AppColors.turquoiseDark,
                background: AppColors.turquoiseSoft,
              ),
              const SizedBox(width: 10),
              Text(
                'Privacidad',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _PrivacyPoint(
            icon: Icons.audio_file_outlined,
            text:
                'Tu audio se envía para transcribirse y no se guarda en el servidor.',
          ),
          const _PrivacyPoint(
            icon: Icons.text_snippet_outlined,
            text:
                'La transcripción completa no se conserva; el historial guarda métricas, síntesis y citas cortas.',
          ),
          _PrivacyPoint(
            icon: Icons.storage_outlined,
            text:
                'El historial se separa con tu identificador local. Hoy tienes $historyCount análisis guardados.',
          ),
          const _PrivacyPoint(
            icon: Icons.info_outline_rounded,
            text:
                'El identificador es una identidad declarada, no una autenticación. No compartas tu dispositivo con desconocidos.',
          ),
          const SizedBox(height: 10),
          const InfoNote(
            icon: Icons.verified_user_outlined,
            text:
                'La transcripción se procesa con proveedores externos configurados por el servidor. TALKY no vende tus datos.',
            foreground: AppColors.turquoiseDark,
            background: AppColors.turquoiseSoft,
            borderColor: Color(0xFFBFEDE6),
          ),
        ],
      ),
    );
  }
}

class _PrivacyPoint extends StatelessWidget {
  const _PrivacyPoint({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.inkMuted),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                height: 1.5,
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

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.graphic_eq_rounded,
                color: Colors.white, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TALKY · Versión ${AppConfig.appVersion}',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Asistente de oratoria · Universidad Tecnológica de Bolívar\n'
                  'Proyecto de Ingeniería de Software, 2026.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        height: 1.45,
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

class _TileIcon extends StatelessWidget {
  const _TileIcon({
    required this.icon,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}
