import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/di/providers.dart';
import '../../../core/models/professor.dart';
import '../../../core/models/rarity.dart';
import '../../../core/widgets/widgets.dart';
import '../application/collection_view_provider.dart';
import '../domain/collection_filter.dart';
import 'collection_widgets.dart';
import 'rarity_filter_provider.dart';

/// `/collection` — the Profedex: progress header, rarity filter and the grid
/// of captured professors / silhouettes.
class CollectionScreen extends ConsumerWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(collectionViewProvider);
    return AppScaffold(
      title: 'Mi Profedex',
      padding: EdgeInsets.zero,
      bottomBar: PixelButton(
        label: 'Volver al mapa',
        icon: PixelIcons.map,
        variant: PixelButtonVariant.secondary,
        onPressed: () => context.go(AppRoutes.map),
      ),
      body: switch (state) {
        CollectionLoading() => const LoadingView(message: 'Cargando Profedex…'),
        CollectionError(:final error) => ErrorView.fromError(
          error,
          onRetry: () => invalidateCollection(ref),
        ),
        CollectionData() => _CollectionBody(data: state),
      },
    );
  }
}

class _CollectionBody extends ConsumerWidget {
  const _CollectionBody({required this.data});

  final CollectionData data;

  Future<void> _refresh(WidgetRef ref) async {
    invalidateCollection(ref);
    try {
      await Future.wait<Object?>([
        ref.read(professorsProvider.future),
        ref.read(myCapturesProvider.future),
      ]);
    } catch (_) {
      // The view state falls back to cached data + banner; nothing to do.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(rarityFilterProvider);
    final visible = filterProfessors(data.professors, filter);

    return Column(
      children: [
        if (data.fromCache) const CachedDataBanner(),
        // Thin activity line while a silent refresh (e.g. after a capture)
        // replaces the data already on screen.
        if (data.refreshing)
          const LinearProgressIndicator(minHeight: 3)
        else
          const SizedBox(height: 3),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.accent,
            backgroundColor: AppColors.surface,
            onRefresh: () => _refresh(ref),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: CollectionHeader(
                      progress: data.progress,
                      byRarity: data.byRarity,
                    ),
                  ),
                ),
                if (data.progress.completed)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    sliver: SliverToBoxAdapter(
                      child: _CompletedCard(
                        onTap: () => context.push(AppRoutes.completion),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: _FilterRow(
                    selected: filter,
                    onSelected: ref.read(rarityFilterProvider.notifier).select,
                  ),
                ),
                if (data.professors.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: ErrorView(
                      icon: PixelIcons.school,
                      message: 'Aún no hay profesores en la feria. Vuelve a intentarlo más tarde.',
                      onRetry: () => _refresh(ref),
                    ),
                  )
                else if (visible.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyFilter(rarity: filter),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    sliver: _ProfessorGrid(
                      professors: visible,
                      isCaptured: data.isCaptured,
                      onTap: (p) =>
                          context.push(AppRoutes.professorDetail(p.id)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.selected, required this.onSelected});

  final Rarity? selected;
  final ValueChanged<Rarity?> onSelected;

  @override
  Widget build(BuildContext context) {
    final options = <Rarity?>[null, ...Rarity.values];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          for (final rarity in options) ...[
            RarityFilterChip(
              key: Key('filter-${rarityFilterValue(rarity)}'),
              rarity: rarity,
              selected: rarity == selected,
              onSelected: () => onSelected(rarity),
            ),
            if (rarity != options.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _ProfessorGrid extends StatelessWidget {
  const _ProfessorGrid({
    required this.professors,
    required this.isCaptured,
    required this.onTap,
  });

  final List<Professor> professors;
  final bool Function(String professorId) isCaptured;
  final ValueChanged<Professor> onTap;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.crossAxisExtent < 560 ? 2 : 3;
        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            mainAxisExtent: 219,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final professor = professors[index];
            return ProfessorCard(
              key: Key('professor-${professor.id}'),
              professor: professor,
              captured: isCaptured(professor.id),
              onTap: () => onTap(professor),
            );
          }, childCount: professors.length),
        );
      },
    );
  }
}

/// Grid cell: sprite (silhouette when not captured), name or "???", rarity.
class ProfessorCard extends StatelessWidget {
  const ProfessorCard({
    super.key,
    required this.professor,
    required this.captured,
    required this.onTap,
  });

  final Professor professor;
  final bool captured;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rarityColor = AppTheme.rarityColor(professor.rarity);
    final name = captured ? professor.displayName : '???';
    return PixelCard(
      padding: const EdgeInsets.all(10),
      borderColor: captured ? rarityColor : null,
      onTap: onTap,
      semanticLabel: captured
          ? '${professor.displayName}, ${professor.rarity.label}, capturado'
          : 'Profesor sin descubrir, ${professor.rarity.label}',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ProfessorSprite(
            professorId: professor.id,
            spriteUrl: professor.spriteUrl,
            size: 88,
            silhouette: !captured,
            semanticLabel: captured ? professor.displayName : null,
          ),
          const SizedBox(height: 8),
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: captured ? AppColors.text : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          // Shrinks on narrow cells ("LEGENDARIA" in a 2-column grid).
          FittedBox(
            fit: BoxFit.scaleDown,
            child: RarityBadge(professor.rarity, compact: true),
          ),
        ],
      ),
    );
  }
}

class _CompletedCard extends StatelessWidget {
  const _CompletedCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PixelCard(
      borderColor: AppColors.success,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      onTap: onTap,
      semanticLabel: 'Profedex completa. Ver logro',
      child: Row(
        children: [
          const PixelIcon(PixelIcons.trophy, color: AppColors.success),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '¡Profedex completa!',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: AppColors.success),
            ),
          ),
          const Text(
            'VER LOGRO',
            style: TextStyle(
              color: AppColors.accentAlt,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 0,
            ),
          ),
          const PixelIcon(PixelIcons.chevronRight, color: AppColors.accentAlt),
        ],
      ),
    );
  }
}

class _EmptyFilter extends StatelessWidget {
  const _EmptyFilter({required this.rarity});

  final Rarity? rarity;

  @override
  Widget build(BuildContext context) {
    final label = rarityFilterLabel(rarity).toLowerCase();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PixelIcon(PixelIcons.searchOff, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              'No hay profesores de rareza $label en la feria.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
