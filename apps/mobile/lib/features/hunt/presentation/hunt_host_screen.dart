import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../app/theme.dart';
import '../../../core/config/app_config.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/hunt/hunt_service.dart';
import '../../../core/location/lat_lng.dart';
import '../../../core/location/location_service.dart';
import '../../../core/widgets/widgets.dart';

/// Foreground-only publisher for a 30-minute campus hunt. If the professor
/// leaves this screen, students stop seeing a location after 30 seconds.
class HuntHostScreen extends ConsumerStatefulWidget {
  const HuntHostScreen({super.key});

  @override
  ConsumerState<HuntHostScreen> createState() => _HuntHostScreenState();
}

class _HuntHostScreenState extends ConsumerState<HuntHostScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  HuntSession? _session;
  String? _error;
  bool _busy = false;
  bool _publishing = false;
  bool _foreground = true;
  DateTime? _lastSentAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!AppConfig.isDemoMode) unawaited(_loadSession());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && _session != null) unawaited(_publishLocation());
  }

  Future<void> _loadSession() async {
    try {
      final session = await ref.read(huntServiceProvider).myActiveSession();
      if (!mounted || session == null) return;
      setState(() => _session = session);
      _schedulePublishing();
      unawaited(_publishLocation());
    } catch (e) {
      if (mounted) setState(() => _error = AppException.from(e).message);
    }
  }

  Future<bool> _hasLocationPermission() async {
    final status = await ref.read(locationServiceProvider).checkAndRequest();
    if (status == LocationStatus.available) return true;
    if (mounted) {
      setState(
        () => _error = status == LocationStatus.serviceDisabled
            ? 'Activa la ubicación del teléfono antes de iniciar la búsqueda.'
            : 'Autoriza la ubicación para compartirla durante la búsqueda.',
      );
    }
    return false;
  }

  Future<void> _start(HuntPublisher publisher) async {
    if (_busy || !await _hasLocationPermission()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await ref
          .read(huntServiceProvider)
          .start(publisher.professorId);
      if (!mounted) return;
      setState(() => _session = session);
      _schedulePublishing();
      unawaited(_publishLocation());
    } catch (e) {
      if (mounted) setState(() => _error = AppException.from(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _schedulePublishing() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      final session = _session;
      if (session == null) return;
      if (!session.isActiveAt(DateTime.now().toUtc())) {
        _timer?.cancel();
        setState(() => _session = null);
        return;
      }
      if (_foreground) unawaited(_publishLocation());
      setState(() {}); // refresh countdown and last-update label
    });
  }

  Future<void> _publishLocation() async {
    final session = _session;
    if (!mounted || !_foreground || session == null || _publishing) return;
    if (!session.isActiveAt(DateTime.now().toUtc())) return;
    _publishing = true;
    try {
      final point = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (!mounted || _session?.id != session.id) return;
      if (point.accuracy > 100) {
        setState(
          () => _error =
              'La señal GPS es imprecisa. Muévete a un espacio abierto.',
        );
        return;
      }
      final updated = await ref
          .read(huntServiceProvider)
          .updateLocation(
            session.id,
            LatLng(point.latitude, point.longitude),
            point.accuracy,
          );
      if (mounted && _session?.id == session.id) {
        setState(() {
          _session = updated;
          _lastSentAt = DateTime.now();
          _error = null;
        });
        ref.invalidate(activeHuntsProvider);
      }
    } catch (e) {
      if (mounted) setState(() => _error = AppException.from(e).message);
    } finally {
      _publishing = false;
    }
  }

  Future<void> _stop() async {
    final session = _session;
    if (_busy || session == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(huntServiceProvider).stop(session.id);
      _timer?.cancel();
      if (mounted) {
        setState(() {
          _session = null;
          _lastSentAt = null;
        });
        ref.invalidate(activeHuntsProvider);
      }
    } catch (e) {
      if (mounted) setState(() => _error = AppException.from(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final publisher = ref.watch(huntPublisherProvider);
    final session = _session;
    final remaining = session?.endsAt.difference(DateTime.now().toUtc());
    final minutes = remaining == null
        ? 0
        : (remaining.inSeconds.clamp(0, 1800) / 60).ceil();

    return AppScaffold(
      title: 'Búsqueda del profesor',
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            PixelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    publisher.value?.professorName ?? 'Compartir ubicación',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    session == null
                        ? 'Activa una búsqueda de 30 minutos. Solo se mostrará '
                              'tu ubicación actual a los jugadores con sesión.'
                        : 'Búsqueda activa · quedan aproximadamente $minutes min',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    session == null
                        ? 'Mantén tu tarjeta NFC contigo para que puedan registrar el hallazgo.'
                        : _lastSentAt == null
                        ? 'Esperando una ubicación GPS precisa…'
                        : 'Última ubicación enviada: '
                              '${_lastSentAt!.hour.toString().padLeft(2, '0')}:'
                              '${_lastSentAt!.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Mantén esta pantalla abierta. Si el teléfono se bloquea, '
                    'tu marcador desaparecerá hasta que vuelva a actualizarse.',
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              PixelCard(
                borderColor: AppColors.danger,
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (publisher.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (publisher.hasError)
              const Text(
                'No se pudo comprobar la autorización. Inténtalo de nuevo.',
              )
            else if (publisher.value == null)
              const Text('Tu cuenta aún no está vinculada con un profesor.')
            else if (session == null)
              PixelButton(
                label: 'Iniciar 30 minutos',
                loading: _busy,
                onPressed: () => _start(publisher.value!),
              )
            else
              PixelButton(
                label: 'Detener búsqueda',
                variant: PixelButtonVariant.secondary,
                loading: _busy,
                onPressed: _stop,
              ),
          ],
        ),
      ),
    );
  }
}
