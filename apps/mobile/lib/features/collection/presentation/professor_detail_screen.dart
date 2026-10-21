import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/di/providers.dart';
import '../../../core/models/capture.dart';
import '../../../core/models/professor.dart';
import '../../../core/widgets/widgets.dart';
import '../application/collection_view_provider.dart';
import '../domain/date_format.dart';
import 'collection_widgets.dart';

/// `/collection/:professorId` — one professor: sprite, name, rarity,
/// description (only once captured) and the capture record.
class ProfessorDetailScreen extends ConsumerWidget {
  const ProfessorDetailScreen({super.key, required this.professorId});

  /// From the `/collection/:professorId` path parameter.
  final String professorId;

  static const undiscoveredHint =
      'Encuentra a este profesor en la feria y lee su tarjeta NFC para descubrirlo';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(collectionViewProvider);
    final professor = state is CollectionData
        ? state.professorById(professorId)
        : null;
    final capture = state is CollectionData
        ? state.captureOf(professorId)
        : null;
    final captured = capture != null;

    return AppScaffold(
      title: professor != null && captured ? professor.displayName : 'Profesor',
      padding: EdgeInsets.zero,
      body: switch (state) {
        CollectionLoading() => const LoadingView(),
        CollectionError(:final error) => ErrorView.fromError(
          error,
          onRetry: () => invalidateCollection(ref),
        ),
        CollectionData() =>
          professor == null
              ? ErrorView(
                  icon: Icons.person_search,
                  message: 'No encontramos a este profesor.',
                  onRetry: () => invalidateCollection(ref),
                )
              : Column(
                  children: [
                    if (state.fromCache) const CachedDataBanner(),
                    Expanded(
                      child: _ProfessorDetail(
                        professor: professor,
                        capture: capture,
                      ),
                    ),
                  ],
                ),
      },
    );
  }
}

class _ProfessorDetail extends StatelessWidget {
  const _ProfessorDetail({required this.professor, required this.capture});

  final Professor professor;
  final Capture? capture;

  bool get captured => capture != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rarityColor = AppTheme.rarityColor(professor.rarity);
    final description = professor.description?.trim();
    final showRealName =
        captured && professor.name.trim() != professor.displayName.trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: PixelCard(
              borderColor: captured ? rarityColor : null,
              child: ProfessorSprite(
                professorId: professor.id,
                spriteUrl: professor.spriteUrl,
                size: 160,
                silhouette: !captured,
                semanticLabel: captured ? professor.displayName : null,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            captured ? professor.displayName : '???',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: captured ? AppColors.text : AppColors.textMuted,
            ),
          ),
          if (showRealName) ...[
            const SizedBox(height: 4),
            Text(
              professor.name,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Center(child: RarityBadge(professor.rarity)),
          const SizedBox(height: 20),
          PixelCard(
            child: captured
                ? Text(
                    description == null || description.isEmpty
                        ? 'Este profesor todavía no tiene descripción.'
                        : description,
                    style: theme.textTheme.bodyLarge,
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.nfc,
                        color: AppColors.accentAlt,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          ProfessorDetailScreen.undiscoveredHint,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppColors.textMuted,
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
                Text(
                  captured ? 'FICHA DE CAPTURA' : 'FICHA',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.accentText,
                  ),
                ),
                const SizedBox(height: 10),
                _StatRow(
                  icon: AppTheme.rarityIcon(professor.rarity),
                  iconColor: rarityColor,
                  label: 'Rareza',
                  value: professor.rarity.label,
                ),
                _StatRow(
                  icon: Icons.percent,
                  label: 'Prob. base de captura',
                  value: '${(professor.baseCaptureRate * 100).round()} %',
                ),
                if (capture case final c?) ...[
                  _StatRow(
                    icon: Icons.event_available,
                    iconColor: AppColors.success,
                    label: 'Capturado el',
                    value: formatDateTime(c.capturedAt),
                  ),
                  _StatRow(
                    icon: Icons.sports_baseball,
                    iconColor: AppColors.success,
                    label: 'Lanzamiento',
                    value: c.throwQuality.label,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor = AppColors.accentAlt,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 10),
          // Wrap: the value drops to its own line on narrow screens.
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 2,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                Text(value, style: theme.textTheme.titleMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
