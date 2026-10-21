import 'dart:async';

import 'package:flutter/material.dart';

import '../services/platform/platform_services.dart';

/// İnternet varsa hemen true döner. Yoksa "İnternet bağlantısı yok" penceresi
/// açılır ve otomatik olarak yeniden bağlanmayı dener. Bağlantı gelirse true,
/// kullanıcı "Vazgeç" derse false döner.
Future<bool> ensureOnline(BuildContext context) async {
  if (await hasInternetConnection()) return true;
  if (!context.mounted) return false;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _NoInternetDialog(),
  );
  return result ?? false;
}

enum _Phase { connecting, waiting, connected }

class _NoInternetDialog extends StatefulWidget {
  const _NoInternetDialog();

  @override
  State<_NoInternetDialog> createState() => _NoInternetDialogState();
}

class _NoInternetDialogState extends State<_NoInternetDialog> {
  static const _retryEvery = 5; // saniye
  static const _minConnectingTime = Duration(milliseconds: 1500);

  _Phase _phase = _Phase.waiting;
  int _attempt = 0;
  int _secondsLeft = _retryEvery;
  Timer? _countdown;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdown?.cancel();
    setState(() {
      _phase = _Phase.waiting;
      _secondsLeft = _retryEvery;
    });
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        _retry();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _retry() async {
    _countdown?.cancel();
    setState(() {
      _phase = _Phase.connecting;
      _attempt++;
    });
    // Kullanıcı denemeyi görebilsin diye en az 1,5 sn "bağlanılıyor" gösterilir.
    final (online, _) = await (
      hasInternetConnection(),
      Future<void>.delayed(_minConnectingTime),
    ).wait;
    if (!mounted) return;
    if (online) {
      setState(() => _phase = _Phase.connected);
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.of(context).pop(true);
    } else {
      _startCountdown();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final (icon, color, title, message) = switch (_phase) {
      _Phase.connected => (
          Icons.wifi_rounded,
          scheme.primary,
          'Bağlantı kuruldu',
          'Devam ediliyor...',
        ),
      _Phase.connecting => (
          Icons.wifi_find_rounded,
          scheme.tertiary,
          'Yeniden bağlanılıyor...',
          'Sunucuya ulaşılmaya çalışılıyor. (Deneme $_attempt)',
        ),
      _Phase.waiting => (
          Icons.wifi_off_rounded,
          scheme.error,
          'İnternet bağlantısı yok',
          'Devam etmek için internete bağlı olmalısın. Wi-Fi veya mobil verini kontrol et.',
        ),
    };

    return PopScope(
      canPop: false,
      child: AlertDialog(
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Container(
                key: ValueKey(_phase),
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: _phase == _Phase.connecting
                    ? Padding(
                        padding: const EdgeInsets.all(18),
                        child: CircularProgressIndicator(strokeWidth: 3, color: color),
                      )
                    : Icon(icon, size: 36, color: color),
              ),
            ),
            const SizedBox(height: 18),
            Text(title, textAlign: TextAlign.center, style: text.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 20),
            if (_phase == _Phase.waiting) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: TweenAnimationBuilder<double>(
                  key: ValueKey('bar$_attempt'),
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(seconds: _retryEvery),
                  builder: (_, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 6,
                    color: scheme.error,
                    backgroundColor: scheme.error.withValues(alpha: 0.12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$_secondsLeft saniye içinde yeniden denenecek'
                '${_attempt > 0 ? ' · $_attempt deneme yapıldı' : ''}',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              ),
            ],
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: _phase == _Phase.connected ? null : () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: _phase == _Phase.waiting ? _retry : null,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: const Text('Şimdi dene'),
          ),
        ],
      ),
    );
  }
}
