import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/qr/pending_qr.dart';

/// Receives a printed QR when the game was already open in this browser tab.
class QrLinkScreen extends StatefulWidget {
  const QrLinkScreen({required this.code, super.key});

  final String code;

  @override
  State<QrLinkScreen> createState() => _QrLinkScreenState();
}

class _QrLinkScreenState extends State<QrLinkScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(_continue());
  }

  Future<void> _continue() async {
    final valid = await PendingQr.saveWebRoute(widget.code);
    if (!mounted) return;
    context.go(valid ? AppRoutes.scan : AppRoutes.map);
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );
}
