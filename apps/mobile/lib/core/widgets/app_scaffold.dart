import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';

/// Scaffold with the app background, safe area and consistent padding.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.leading,
    this.showAppBar = true,
    this.showBackButton = true,
    this.homeFallback = false,
    this.padding = const EdgeInsets.all(16),
    this.bottomBar,
    this.floatingActionButton,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
  });

  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showAppBar;

  /// Whether the AppBar adds its automatic back arrow when the screen was
  /// pushed. Turn it off when the body already has its own way back (e.g. a
  /// "Volver al mapa" button in [bottomBar]).
  final bool showBackButton;

  /// When the screen was reached with `go` (empty back stack) the AppBar has no
  /// automatic back arrow; this adds one that returns to the map.
  final bool homeFallback;
  final EdgeInsetsGeometry padding;

  /// Optional bar pinned under the body (e.g. primary actions).
  final Widget? bottomBar;
  final Widget? floatingActionButton;
  final Color? backgroundColor;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final fallbackLeading = leading == null && homeFallback && !context.canPop()
        ? BackButton(onPressed: () => context.go(AppRoutes.map))
        : leading;
    return Scaffold(
      backgroundColor: backgroundColor ?? AppColors.background,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: showAppBar
          ? AppBar(
              title: title == null ? null : Text(title!.toUpperCase()),
              actions: actions,
              leading: fallbackLeading,
              automaticallyImplyLeading: showBackButton,
            )
          : null,
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(padding: padding, child: body),
            ),
            if (bottomBar != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: bottomBar,
              ),
          ],
        ),
      ),
    );
  }
}
