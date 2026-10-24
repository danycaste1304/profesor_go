import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/config/app_config.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/models/models.dart';
import '../../../core/repositories/mock_professor_repository.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_card.dart';
import '../../../core/widgets/pixel_frame_painter.dart';
import '../../../core/widgets/pixel_icons.dart';
import '../../../core/widgets/pixel_pill.dart';
import '../../../core/widgets/progress_bar.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../avatar/avatar_style.dart';
import '../../map/presentation/widgets/avatar.dart';
import '../../../core/widgets/pixel_icon.dart';

/// Keep in sync with `version:` in pubspec.yaml (no package_info_plus to
/// avoid an extra dependency).
const String kAppVersion = '0.1.0';

/// Player profile: identity, avatar appearance, collection progress, sign-out
/// and (demo only) a confirmed reset of local progress.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  static const Key logoutKey = Key('profile_logout');
  static const Key resetDemoKey = Key('profile_reset_demo');
  static const Key collectionKey = Key('profile_collection');
  static const Key avatarPreviewKey = Key('profile_avatar_preview');
  static const Key avatarSurpriseKey = Key('profile_avatar_surprise');

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _resetting = false;

  Future<void> _signOut() async {
    final messenger = ScaffoldMessenger.of(context);
    // On success the auth stream emits null and the router goes to /login.
    final ok = await ref.read(authControllerProvider.notifier).signOut();
    if (ok || !mounted) return;
    final error = ref.read(authControllerProvider).error;
    messenger.showSnackBar(
      SnackBar(
        content: Text(error ?? AppException.messages[AppException.unknown]!),
      ),
    );
  }

  Future<void> _resetDemoProgress() async {
    final repo = ref.read(professorRepositoryProvider);
    if (repo is! MockProfessorRepository || _resetting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Reiniciar la Profedex?'),
        content: const Text(
          'Se borrarán las capturas y encuentros de esta demo. '
          'Tu avatar, música y sesión seguirán igual.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reiniciar'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _resetting = true);
    try {
      await repo.state.reset();
      if (!mounted) return;
      invalidateCollection(ref);
      messenger.showSnackBar(
        const SnackBar(content: Text('Profedex demo reiniciada')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(AppException.from(e).message)),
      );
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  Future<void> _updateAvatar(Future<void> Function() change) async {
    try {
      await change();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar tu avatar')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(profileProvider);
    final progressAsync = ref.watch(collectionProgressProvider);
    final auth = ref.watch(authControllerProvider);
    final avatarStyle = ref.watch(avatarStyleProvider);
    final textTheme = Theme.of(context).textTheme;

    final profile = profileAsync.value;
    final email = profile?.email ?? user?.email ?? '';
    final name =
        profile?.nameOrEmail ?? _fallbackName(user?.displayName, email);
    final isAdmin = profile?.role == UserRole.admin;
    final showDemoTools =
        AppConfig.isDemoMode &&
        ref.watch(professorRepositoryProvider) is MockProfessorRepository;

    return AppScaffold(
      title: 'Perfil',
      homeFallback: true,
      body: ListView(
        children: [
          if (profileAsync.hasError) ...[
            _InlineError(
              message: AppException.from(profileAsync.error!).message,
              onRetry: () => ref.invalidate(profileProvider),
            ),
            const SizedBox(height: 16),
          ],
          PixelCard(
            borderColor: AppColors.accentAlt,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('TU PERSONAJE', style: textTheme.titleMedium),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      key: ProfileScreen.avatarPreviewKey,
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        border: Border.all(color: Colors.transparent, width: 2),
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                      ),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          switchInCurve: Curves.easeOutBack,
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(scale: animation, child: child),
                          child: PixelAvatar(
                            key: ValueKey(avatarStyle),
                            size: 104,
                            semanticLabel: 'Avatar del jugador',
                            style: avatarStyle,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Semantics(
                        label: 'Jugador $name, $email',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: textTheme.titleLarge,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (email.isNotEmpty && email != name) ...[
                              const SizedBox(height: 4),
                              Text(
                                email,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textMuted,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            if (isAdmin || AppConfig.isDemoMode) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  if (isAdmin)
                                    const PixelPill(
                                      label: 'Admin',
                                      icon: PixelIcons.shield,
                                      color: AppColors.accentText,
                                      tinted: true,
                                      semanticLabel: 'Admin',
                                    ),
                                  if (AppConfig.isDemoMode)
                                    const PixelPill(
                                      label: 'Modo demo',
                                      icon: PixelIcons.flask,
                                      color: AppColors.accentAlt,
                                      tinted: true,
                                      semanticLabel: 'Modo demo',
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _AvatarChoices(
                  title: 'PEINADO',
                  choices: [
                    _AvatarChoice(
                      key: const Key('avatar_hair_short'),
                      label: 'Corto',
                      selected: avatarStyle.hair == AvatarHair.short,
                      onTap: () => unawaited(
                        _updateAvatar(
                          () => ref
                              .read(avatarStyleProvider.notifier)
                              .setHair(AvatarHair.short),
                        ),
                      ),
                    ),
                    _AvatarChoice(
                      key: const Key('avatar_hair_curls'),
                      label: 'Rizos',
                      selected: avatarStyle.hair == AvatarHair.curls,
                      onTap: () => unawaited(
                        _updateAvatar(
                          () => ref
                              .read(avatarStyleProvider.notifier)
                              .setHair(AvatarHair.curls),
                        ),
                      ),
                    ),
                    _AvatarChoice(
                      key: const Key('avatar_hair_ponytail'),
                      label: 'Coleta',
                      selected: avatarStyle.hair == AvatarHair.ponytail,
                      onTap: () => unawaited(
                        _updateAvatar(
                          () => ref
                              .read(avatarStyleProvider.notifier)
                              .setHair(AvatarHair.ponytail),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _AvatarChoices(
                  title: 'ROPA',
                  choices: [
                    _AvatarChoice(
                      key: const Key('avatar_outfit_turquoise'),
                      label: 'Menta',
                      swatch: const Color(0xFF67D1CA),
                      selected: avatarStyle.outfit == AvatarOutfit.turquoise,
                      onTap: () => unawaited(
                        _updateAvatar(
                          () => ref
                              .read(avatarStyleProvider.notifier)
                              .setOutfit(AvatarOutfit.turquoise),
                        ),
                      ),
                    ),
                    _AvatarChoice(
                      key: const Key('avatar_outfit_pink'),
                      label: 'Rosa',
                      swatch: const Color(0xFFFF93B4),
                      selected: avatarStyle.outfit == AvatarOutfit.pink,
                      onTap: () => unawaited(
                        _updateAvatar(
                          () => ref
                              .read(avatarStyleProvider.notifier)
                              .setOutfit(AvatarOutfit.pink),
                        ),
                      ),
                    ),
                    _AvatarChoice(
                      key: const Key('avatar_outfit_lilac'),
                      label: 'Lila',
                      swatch: const Color(0xFFAD9BF0),
                      selected: avatarStyle.outfit == AvatarOutfit.lilac,
                      onTap: () => unawaited(
                        _updateAvatar(
                          () => ref
                              .read(avatarStyleProvider.notifier)
                              .setOutfit(AvatarOutfit.lilac),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _AvatarChoices(
                  title: 'ACCESORIO',
                  choices: [
                    _AvatarChoice(
                      key: const Key('avatar_accessory_cap'),
                      label: 'Gorra',
                      selected: avatarStyle.accessory == AvatarAccessory.cap,
                      onTap: () => unawaited(
                        _updateAvatar(
                          () => ref
                              .read(avatarStyleProvider.notifier)
                              .setAccessory(AvatarAccessory.cap),
                        ),
                      ),
                    ),
                    _AvatarChoice(
                      key: const Key('avatar_accessory_glasses'),
                      label: 'Lentes',
                      selected:
                          avatarStyle.accessory == AvatarAccessory.glasses,
                      onTap: () => unawaited(
                        _updateAvatar(
                          () => ref
                              .read(avatarStyleProvider.notifier)
                              .setAccessory(AvatarAccessory.glasses),
                        ),
                      ),
                    ),
                    _AvatarChoice(
                      key: const Key('avatar_accessory_bow'),
                      label: 'Moño',
                      selected: avatarStyle.accessory == AvatarAccessory.bow,
                      onTap: () => unawaited(
                        _updateAvatar(
                          () => ref
                              .read(avatarStyleProvider.notifier)
                              .setAccessory(AvatarAccessory.bow),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                PixelButton(
                  key: ProfileScreen.avatarSurpriseKey,
                  label: 'Sorpréndeme',
                  icon: PixelIcons.sparkles,
                  variant: PixelButtonVariant.secondary,
                  onPressed: () => unawaited(
                    _updateAvatar(
                      () => ref.read(avatarStyleProvider.notifier).surprise(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PixelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('MI PROFEDEX', style: textTheme.titleMedium),
                const SizedBox(height: 12),
                progressAsync.when(
                  data: (p) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ProgressBar(
                        value: p.captured,
                        total: p.total,
                        label: 'Profesores capturados',
                        color: p.completed ? AppColors.success : null,
                      ),
                      if (p.completed) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const PixelIcon(
                              PixelIcons.trophy,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '¡Profedex completa!',
                                style: textTheme.bodyLarge?.copyWith(
                                  color: AppColors.success,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  loading: () => const ProgressBar(
                    value: 0,
                    total: 0,
                    label: 'Profesores capturados',
                    showPercent: false,
                  ),
                  error: (e, _) => _InlineError(
                    message: AppException.from(e).message,
                    onRetry: () => ref.invalidate(collectionProgressProvider),
                  ),
                ),
                const SizedBox(height: 16),
                PixelButton(
                  key: ProfileScreen.collectionKey,
                  label: 'Ver Profedex',
                  icon: PixelIcons.book,
                  variant: PixelButtonVariant.secondary,
                  onPressed: () => context.go(AppRoutes.collection),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          PixelButton(
            key: ProfileScreen.logoutKey,
            label: 'Cerrar sesión',
            icon: PixelIcons.logout,
            variant: PixelButtonVariant.danger,
            loading: auth.loading,
            onPressed: _signOut,
          ),
          if (showDemoTools) ...[
            const SizedBox(height: 24),
            PixelCard(
              borderColor: AppColors.accentAlt,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const PixelIcon(
                        PixelIcons.build,
                        color: AppColors.accentAlt,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'OPCIONES DE DEMO',
                          style: textTheme.titleMedium?.copyWith(
                            color: AppColors.accentAlt,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Puedes empezar otra partida sin perder tu avatar ni la música.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  PixelButton(
                    key: ProfileScreen.resetDemoKey,
                    label: 'Reiniciar Profedex demo',
                    icon: PixelIcons.restart,
                    variant: PixelButtonVariant.secondary,
                    loading: _resetting,
                    onPressed: _resetDemoProgress,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'Profesor GO v$kAppVersion',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  static String _fallbackName(String? displayName, String email) {
    final n = displayName?.trim();
    if (n != null && n.isNotEmpty) return n;
    final at = email.indexOf('@');
    if (at > 0) return email.substring(0, at);
    return email.isEmpty ? 'Jugador' : email;
  }
}

class _AvatarChoices extends StatelessWidget {
  const _AvatarChoices({required this.title, required this.choices});

  final String title;
  final List<_AvatarChoice> choices;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(fontSize: 20, color: AppColors.textMuted),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var index = 0; index < choices.length; index++) ...[
              if (index > 0) const SizedBox(width: 8),
              Expanded(child: choices[index]),
            ],
          ],
        ),
      ],
    );
  }
}

class _AvatarChoice extends StatelessWidget {
  const _AvatarChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.swatch,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? swatch;

  @override
  Widget build(BuildContext context) {
    const block = PixelFramePainter.defaultPixel;
    final face = selected ? const Color(0xFFFFF1BC) : AppColors.surface;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: CustomPaint(
        painter: PixelFramePainter(
          face: face,
          outline: AppColors.text,
          highlight: Color.lerp(face, Colors.white, 0.5)!,
          shade: Color.lerp(face, AppColors.text, 0.3)!,
          // The selected choice reads as pressed in (sunken), like the
          // rarity filter chips.
          pressed: selected,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            // The frame itself is the press feedback; no ripple.
            splashFactory: NoSplash.splashFactory,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                // Keeps the content centered in the face, not in the slab.
                padding: EdgeInsets.fromLTRB(
                  8,
                  selected ? block : 0,
                  8,
                  selected ? 0 : block,
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (swatch != null) ...[
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: swatch,
                              border: Border.all(color: AppColors.text),
                            ),
                          ),
                          const SizedBox(width: 5),
                        ],
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontSize: 20, color: AppColors.text),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact error line with a retry action (fits inside a card).
class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const PixelIcon(PixelIcons.error, color: AppColors.danger),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ),
        TextButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    );
  }
}
