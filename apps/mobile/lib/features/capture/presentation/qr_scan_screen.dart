import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../app/router.dart';
import '../../../core/qr/pending_qr.dart';

/// Uses the camera in Android and Safari. The printed URL is never routed
/// through GoRouter, so the secret stays out of the app's navigation history.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  bool _processing = false;
  String? _message;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null) return;
    final code = PendingQr.parse(value);
    if (code == null) {
      if (_message == null) {
        setState(() => _message = 'Este QR no es de Profesor GO.');
      }
      return;
    }
    _processing = true;
    await PendingQr.save(code);
    if (mounted) context.go(AppRoutes.scan);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Escanear QR')),
    body: SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Apunta la cámara al QR impreso del profesor.'),
          ),
          Expanded(
            child: MobileScanner(
              onDetect: _onDetect,
              errorBuilder: (context, error) {
                final message = switch (error.errorCode) {
                  MobileScannerErrorCode.permissionDenied =>
                    'No hay permiso de cámara. Actívalo en el navegador o usa '
                        'la cámara del iPhone para abrir el QR impreso.',
                  MobileScannerErrorCode.unsupported =>
                    'La cámara de este dispositivo no admite el lector. '
                        'Puedes abrir el QR con la cámara del sistema.',
                  _ =>
                    'No se pudo iniciar la cámara. Comprueba el permiso '
                        'y vuelve a intentarlo.',
                };
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(message, textAlign: TextAlign.center),
                  ),
                );
              },
            ),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_message!, textAlign: TextAlign.center),
            ),
        ],
      ),
    ),
  );
}
