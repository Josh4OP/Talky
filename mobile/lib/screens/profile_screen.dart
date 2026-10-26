import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/config.dart';
import '../core/formatters.dart';
import '../state/history_controller.dart';
import '../state/preferences_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/cards.dart';
import '../widgets/mascot/talky_mascot.dart';
import '../widgets/sections.dart';

/// Perfil y ajustes (pantalla de la primera versión del front, con la estética y la sesión actuales).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _replayWelcome(BuildContext context) async {
    final prefs = context.read<PreferencesController>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('¿Volver a la bienvenida?', style: AppText.title),
        content: Text(
          'Verás otra vez la presentación de TALKY. Tus análisis y tu sesión se conservan.',
          style: AppText.body,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Ver bienvenida')),
        ],
      ),
    );
    if (confirmed == true) await prefs.setWelcomeSeen(false);
  }

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<PreferencesController>();
    final history = context.watch<HistoryController>();
    final messenger = ScaffoldMessenger.of(context);
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
            children: [
              const SectionHeader(
                eyebrow: 'TU ESPACIO',
                title: 'Perfil y ajustes',
                subtitle: 'Preferencias, privacidad y conexión.',
              ),
              const SizedBox(height: AppSpacing.sm),
              const _IdentityCard(),
              const SizedBox(height: AppSpacing.md),
              SectionCard(
                title: 'Preferencias',
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Reducir animaciones', style: AppText.bodyStrong),
                      subtitle: Text(
                        'Menos movimiento en la mascota y las transiciones.',
                        style: AppText.caption.copyWith(color: AppColors.inkMuted),
                      ),
                      value: prefs.reduceMotion,
                      onChanged: prefs.setReduceMotion,
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Explorar con datos de ejemplo', style: AppText.bodyStrong),
                      subtitle: Text(
                        'Muestra análisis ficticios, siempre marcados como ejemplo.',
                        style: AppText.caption.copyWith(color: AppColors.inkMuted),
                      ),
                      value: prefs.demoMode,
                      onChanged: (value) async {
                        await prefs.setDemoMode(value);
                        messenger
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: Text(
                                value
                                    ? 'Modo de ejemplo activado. Los datos están marcados.'
                                    : 'Modo de ejemplo desactivado. Volviste a tus datos reales.',
                              ),
                            ),
                          );
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.waving_hand_outlined, color: AppColors.action),
                      title: Text('Volver a ver la bienvenida', style: AppText.bodyStrong),
                      subtitle: Text(
                        'Repite la presentación de Talky.',
                        style: AppText.caption.copyWith(color: AppColors.inkMuted),
                      ),
                      onTap: () => _replayWelcome(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const _ConnectionCard(),
              const SizedBox(height: AppSpacing.md),
              SectionCard(
                title: 'Privacidad',
                child: BulletList(
                  items: [
                    'Tu audio se envía para transcribirse y no se guarda en el servidor.',
                    'La transcripción completa no se conserva; el historial guarda métricas, síntesis y citas cortas.',
                    'El historial se separa con la sesión de este dispositivo. Hoy tienes ${history.total} análisis '
                        'guardados.',
                    'La sesión es anónima: no hay cuenta ni contraseña. Si borras los datos de la app, pierdes el '
                        'acceso a ese historial.',
                    'La transcripción se procesa con proveedores externos configurados por el servidor. TALKY no vende '
                        'tus datos.',
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'TALKY · Asistente de oratoria · Universidad Tecnológica de Bolívar\n'
                'Proyecto de Ingeniería de Software, 2026.',
                style: AppText.caption.copyWith(color: AppColors.inkMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard();

  @override
  Widget build(BuildContext context) {
    final session = context.read<ApiClient>().session;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.tint20, borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Row(
        children: [
          const TalkyMascot(state: MascotState.normal, size: 80),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppPill(label: 'SESIÓN DE ESTE DISPOSITIVO', background: AppColors.surface),
                const SizedBox(height: AppSpacing.xs),
                Text('Estudiante TALKY', style: AppText.heading),
                FutureBuilder<DateTime?>(
                  future: session.expiresAt(),
                  builder: (context, snapshot) => Text(
                    snapshot.data == null
                        ? 'Sesión anónima y privada.'
                        : 'Sesión anónima. Se renueva sola; vence el ${Formatters.date(snapshot.data)}.',
                    style: AppText.caption.copyWith(color: AppColors.inkMuted),
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

enum _Health { idle, checking, online, offline }

class _ConnectionCard extends StatefulWidget {
  const _ConnectionCard();

  @override
  State<_ConnectionCard> createState() => _ConnectionCardState();
}

class _ConnectionCardState extends State<_ConnectionCard> {
  var _health = _Health.idle;

  Future<void> _check() async {
    setState(() => _health = _Health.checking);
    try {
      await context.read<ApiClient>().health();
      if (mounted) setState(() => _health = _Health.online);
    } on ApiException {
      if (mounted) setState(() => _health = _Health.offline);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (_health) {
      _Health.idle => ('Sin verificar', AppColors.inkMuted),
      _Health.checking => ('Comprobando…', AppColors.action),
      _Health.online => ('En línea', AppColors.success),
      _Health.offline => ('Sin conexión', AppColors.danger),
    };
    return SectionCard(
      title: 'Conexión con la API',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, size: 12, color: color),
              const SizedBox(width: AppSpacing.sm),
              Text(label, style: AppText.bodyStrong.copyWith(color: color)),
              const Spacer(),
              TextButton.icon(
                onPressed: _health == _Health.checking ? null : _check,
                icon: const Icon(Icons.wifi_tethering_rounded),
                label: const Text('Probar'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(child: SelectableText(AppConfig.apiBaseUrl, style: AppText.body)),
              IconButton(
                tooltip: 'Copiar dirección de la API',
                icon: const Icon(Icons.copy_rounded, color: AppColors.action),
                onPressed: () async {
                  await Clipboard.setData(const ClipboardData(text: AppConfig.apiBaseUrl));
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('Dirección de la API copiada')));
                  }
                },
              ),
            ],
          ),
          Text(
            'La app se conecta al servidor configurado al compilar. Puedes cambiarlo con API_BASE_URL.',
            style: AppText.caption.copyWith(color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}
