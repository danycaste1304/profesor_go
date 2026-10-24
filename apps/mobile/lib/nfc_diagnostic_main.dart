import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/errors/app_exception.dart';
import 'core/nfc/nfc_service.dart';
import 'core/nfc/real_nfc_service.dart';

/// Standalone field tool. Build with `-t lib/nfc_diagnostic_main.dart`.
/// It reads NFC locally and never signs in or sends a tag ID to Supabase.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _DiagnosticApp());
}

class _DiagnosticApp extends StatelessWidget {
  const _DiagnosticApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Profesor GO · Diagnóstico NFC',
    theme: ThemeData(
      colorSchemeSeed: const Color(0xFF263964),
      useMaterial3: true,
    ),
    home: const _DiagnosticScreen(),
  );
}

class _DiagnosticScreen extends StatefulWidget {
  const _DiagnosticScreen();

  @override
  State<_DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<_DiagnosticScreen> {
  final RealNfcService _nfc = RealNfcService(
    timeout: const Duration(seconds: 30),
  );
  final List<({String identifier, String? uid})> _reads = [];
  NfcAvailability? _availability;
  String? _message;
  bool _scanning = false;
  bool _readerReady = false;

  @override
  void initState() {
    super.initState();
    unawaited(_checkAvailability());
  }

  @override
  void dispose() {
    unawaited(_nfc.cancel());
    super.dispose();
  }

  Future<void> _checkAvailability() async {
    final availability = await _nfc.availability();
    if (!mounted) return;
    setState(() => _availability = availability);
  }

  Future<void> _scan() async {
    if (_scanning) return;
    setState(() {
      _scanning = true;
      _readerReady = false;
      _message = 'Activando el lector NFC… Espera antes de acercar el beacon.';
    });
    try {
      final identifier = await _nfc.scanTag(
        onReady: () {
          if (!mounted) return;
          setState(() {
            _readerReady = true;
            _message = 'Acerca el beacon a la antena NFC de la parte trasera del Android; gíralo si no responde.';
          });
        },
      );
      if (!mounted) return;
      final uid = _nfc.lastTagUid;
      setState(() {
        if (identifier == null) {
          _message = 'No hubo lectura en 30 segundos. Mueve el beacon lentamente por la parte trasera del teléfono.';
        } else if (_reads.any(
          (read) =>
              read.identifier == identifier || (uid != null && read.uid == uid),
        )) {
          _message =
              'Este mismo beacon ya está en la lista. ID: $identifier · UID: ${uid ?? 'no disponible'}';
        } else {
          _reads.add((identifier: identifier, uid: uid));
          _message =
              'Beacon ${_reads.length.toString().padLeft(2, '0')} leído. ID: $identifier · UID: ${uid ?? 'no disponible'}';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = AppException.from(error).message);
    } finally {
      if (mounted) {
        setState(() {
          _scanning = false;
          _readerReady = false;
        });
      }
      await _checkAvailability();
    }
  }

  Future<void> _copyList() async {
    final lines = [
      for (var i = 0; i < _reads.length; i++)
        '${(i + 1).toString().padLeft(2, '0')}: ${_reads[i].identifier} | UID: ${_reads[i].uid ?? 'no disponible'}',
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (mounted) setState(() => _message = 'Lista copiada al portapapeles.');
  }

  @override
  Widget build(BuildContext context) {
    final status = switch (_availability) {
      null => 'Comprobando NFC…',
      NfcAvailability.available => 'NFC activado',
      NfcAvailability.disabled => 'NFC desactivado: actívalo en Ajustes',
      NfcAvailability.unsupported => 'Este Android no admite NFC',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Prueba NFC · Profesor GO')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Diagnóstico local de los beacons Estimote. Lee los beacons etiquetados en orden 01–10. No requiere cuenta ni internet.',
            ),
            const SizedBox(height: 16),
            Text(status, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed:
                  _availability == NfcAvailability.available && !_scanning
                  ? _scan
                  : null,
              icon: const Icon(Icons.nfc),
              label: Text(
                _scanning
                    ? (_readerReady
                          ? 'Esperando beacon…'
                          : 'Activando lector NFC…')
                    : 'Leer un beacon',
              ),
            ),
            TextButton(
              onPressed: _scanning ? null : _checkAvailability,
              child: const Text('Volver a comprobar NFC'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              SelectableText(_message!),
            ],
            const SizedBox(height: 24),
            Text(
              'Leídos: ${_reads.length}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _reads.length; i++)
              ListTile(
                title: Text('Beacon ${(i + 1).toString().padLeft(2, '0')}'),
                subtitle: SelectableText(
                  '${_reads[i].identifier}\nUID: ${_reads[i].uid ?? 'no disponible'}',
                ),
              ),
            if (_reads.isNotEmpty)
              OutlinedButton.icon(
                onPressed: _copyList,
                icon: const Icon(Icons.copy),
                label: const Text('Copiar lista de identificadores'),
              ),
          ],
        ),
      ),
    );
  }
}
