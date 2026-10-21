import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// E-posta servisi olmadığı için doğrulama kodunu ekranın sağ üstünde,
/// gelen bir bildirim gibi gösterir. Dönen fonksiyon bildirimi kapatır.
VoidCallback showOtpNotification(
  BuildContext context, {
  required String code,
  required String username,
  Duration visibleFor = const Duration(seconds: 45),
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  var removed = false;
  void remove() {
    if (removed) return;
    removed = true;
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (_) => _OtpNotification(
      code: code,
      username: username,
      visibleFor: visibleFor,
      onClosed: remove,
    ),
  );
  overlay.insert(entry);
  return remove;
}

class _OtpNotification extends StatefulWidget {
  const _OtpNotification({
    required this.code,
    required this.username,
    required this.visibleFor,
    required this.onClosed,
  });

  final String code;
  final String username;
  final Duration visibleFor;
  final VoidCallback onClosed;

  @override
  State<_OtpNotification> createState() => _OtpNotificationState();
}

class _OtpNotificationState extends State<_OtpNotification> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  )..forward();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.visibleFor, _close);
  }

  Future<void> _close() async {
    _timer?.cancel();
    if (!mounted) return;
    await _anim.reverse();
    widget.onClosed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final top = MediaQuery.paddingOf(context).top + 10;
    final width = (MediaQuery.sizeOf(context).width - 24).clamp(0.0, 320.0);
    final curve = CurvedAnimation(parent: _anim, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);

    return Positioned(
      top: top,
      right: 12,
      width: width,
      child: SlideTransition(
        position: Tween(begin: const Offset(1.1, 0), end: Offset.zero).animate(curve),
        child: FadeTransition(
          opacity: _anim,
          child: Material(
            color: scheme.surface,
            elevation: 12,
            shadowColor: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: brandGradient,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Icons.mark_email_unread_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fiş Takip · şimdi',
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.username} için doğrulama kodu',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: widget.code));
                            ScaffoldMessenger.maybeOf(context)
                                ?.showSnackBar(const SnackBar(content: Text('Kod kopyalandı.')));
                          },
                          child: Text(
                            widget.code,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 6,
                              color: scheme.primary,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                        Text(
                          'Kod 3 dakika geçerli · kopyalamak için dokun',
                          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Kapat',
                    visualDensity: VisualDensity.compact,
                    onPressed: _close,
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 6 kutulu doğrulama kodu girişi (altta gizli tek bir TextField çalışır).
class OtpInput extends StatefulWidget {
  const OtpInput({
    super.key,
    required this.controller,
    this.length = 6,
    this.onCompleted,
    this.hasError = false,
  });

  final TextEditingController controller;
  final int length;
  final ValueChanged<String>? onCompleted;
  final bool hasError;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _focus.addListener(() => setState(() {}));
  }

  void _onChanged() {
    setState(() {});
    if (widget.controller.text.length == widget.length) {
      widget.onCompleted?.call(widget.controller.text);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = widget.controller.text;

    return SizedBox(
      height: 60,
      child: Stack(
        children: [
          // Gerçek giriş alanı: klavye, yapıştırma ve SMS otomatik doldurma için.
          // Opacity(0) yerine şeffaf yazı kullanılır; aksi halde web'de klavye bağlanmaz.
          Positioned.fill(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              autofocus: true,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              maxLength: widget.length,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              showCursor: false,
              enableInteractiveSelection: false,
              style: const TextStyle(color: Colors.transparent, fontSize: 1),
              decoration: const InputDecoration(
                counterText: '',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          IgnorePointer(
            child: Row(
              children: [
                for (var i = 0; i < widget.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: _box(scheme, i, text)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _box(ColorScheme scheme, int i, String text) {
    final filled = i < text.length;
    final active = _focus.hasFocus && i == text.length.clamp(0, widget.length - 1);
    final borderColor = widget.hasError
        ? scheme.error
        : active
            ? scheme.primary
            : filled
                ? scheme.primary.withValues(alpha: 0.4)
                : scheme.outlineVariant;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 60,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark(context) ? scheme.surfaceContainer : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: active ? 2 : 1.2),
      ),
      child: Text(
        filled ? text[i] : '',
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
      ),
    );
  }
}
