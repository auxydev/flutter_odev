import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/auth_controller.dart';
import '../../widgets/otp_widgets.dart';
import 'auth_layout.dart';

enum _Step { identify, verify, newPassword }

/// Şifremi unuttum: kullanıcı adı → doğrulama kodu → yeni şifre.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialIdentifier});

  final String? initialIdentifier;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _identifyForm = GlobalKey<FormState>();
  final _passwordForm = GlobalKey<FormState>();
  late final _identifier = TextEditingController(text: widget.initialIdentifier ?? '');
  final _otp = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  late final AuthController _auth = context.read<AuthController>();
  _Step _step = _Step.identify;
  String? _error;
  String? _username;
  bool _loading = false;

  VoidCallback? _hideNotification;
  Timer? _ticker;
  Duration _remaining = Duration.zero;

  /// Yeni kod istemek için beklenmesi gereken süre.
  static const _resendAfter = Duration(seconds: 30);
  DateTime? _sentAt;

  @override
  void dispose() {
    _ticker?.cancel();
    _hideNotification?.call();
    _auth.cancelPasswordReset();
    _identifier.dispose();
    _otp.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _sendCode() {
    if (_step == _Step.identify && !_identifyForm.currentState!.validate()) return;
    final result = _auth.requestPasswordReset(_identifier.text);
    if (result.error != null) {
      setState(() => _error = result.error);
      return;
    }

    _hideNotification?.call();
    _hideNotification = showOtpNotification(context, code: result.code!, username: result.username!);
    _otp.clear();
    _sentAt = DateTime.now();
    _startTicker();
    setState(() {
      _username = result.username;
      _error = null;
      _step = _Step.verify;
    });
  }

  void _startTicker() {
    _ticker?.cancel();
    void tick() {
      final expires = _auth.otpExpiresAt;
      if (!mounted || expires == null) return;
      final left = expires.difference(DateTime.now());
      setState(() => _remaining = left.isNegative ? Duration.zero : left);
    }

    tick();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  void _verify([String? code]) {
    final value = code ?? _otp.text;
    if (value.length < 6) {
      setState(() => _error = '6 haneli kodu gir.');
      return;
    }
    final error = _auth.verifyOtp(value);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    _ticker?.cancel();
    _hideNotification?.call();
    _hideNotification = null;
    setState(() {
      _error = null;
      _step = _Step.newPassword;
    });
  }

  Future<void> _savePassword() async {
    if (!_passwordForm.currentState!.validate()) return;
    setState(() => _loading = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final error = await _auth.resetPassword(_password.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    messenger.showSnackBar(
      const SnackBar(content: Text('Şifren güncellendi. Yeni şifrenle giriş yapabilirsin.')),
    );
    navigator.pop(_username);
  }

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = switch (_step) {
      _Step.identify => (
          'Şifremi unuttum',
          'Kullanıcı adını veya e-postanı gir, sana bir doğrulama kodu gönderelim.'
        ),
      _Step.verify => (
          'Kodu gir',
          '$_username hesabı için gönderilen 6 haneli kodu gir. Kod sağ üstte görünüyor.'
        ),
      _Step.newPassword => ('Yeni şifre', 'Hesabın için yeni bir şifre belirle.'),
    };

    return AuthLayout(
      showBack: true,
      title: title,
      subtitle: subtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StepIndicator(current: _step.index),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(animation),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey(_step),
              child: switch (_step) {
                _Step.identify => _buildIdentify(),
                _Step.verify => _buildVerify(),
                _Step.newPassword => _buildNewPassword(),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentify() {
    return Form(
      key: _identifyForm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _identifier,
            autocorrect: false,
            textInputAction: TextInputAction.send,
            onFieldSubmitted: (_) => _sendCode(),
            decoration: const InputDecoration(
              labelText: 'Kullanıcı adı veya e-posta',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Kullanıcı adını gir.' : null,
          ),
          if (_error != null) _ErrorText(_error!),
          const SizedBox(height: 24),
          FilledButton(onPressed: _sendCode, child: const Text('Kod gönder')),
        ],
      ),
    );
  }

  Widget _buildVerify() {
    final scheme = Theme.of(context).colorScheme;
    final expired = _remaining == Duration.zero;
    final canResend = expired ||
        (_sentAt != null && DateTime.now().difference(_sentAt!) >= _resendAfter);
    final minutes = _remaining.inMinutes;
    final seconds = (_remaining.inSeconds % 60).toString().padLeft(2, '0');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OtpInput(
          controller: _otp,
          hasError: _error != null,
          onCompleted: _verify,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Icon(Icons.timer_outlined, size: 18, color: expired ? scheme.error : scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              expired ? 'Kodun süresi doldu' : 'Kalan süre $minutes:$seconds',
              style: TextStyle(
                color: expired ? scheme.error : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: canResend ? _sendCode : null,
              child: const Text('Tekrar gönder'),
            ),
          ],
        ),
        if (_error != null) _ErrorText(_error!),
        const SizedBox(height: 20),
        FilledButton(onPressed: expired ? null : () => _verify(), child: const Text('Doğrula')),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            _ticker?.cancel();
            _hideNotification?.call();
            _hideNotification = null;
            _auth.cancelPasswordReset();
            setState(() {
              _error = null;
              _step = _Step.identify;
            });
          },
          child: const Text('Kullanıcı adını değiştir'),
        ),
      ],
    );
  }

  Widget _buildNewPassword() {
    return Form(
      key: _passwordForm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PasswordField(
            controller: _password,
            label: 'Yeni şifre',
            textInputAction: TextInputAction.next,
            validator: (v) => (v ?? '').length < 6 ? 'Şifre en az 6 karakter olmalı.' : null,
          ),
          const SizedBox(height: 14),
          PasswordField(
            controller: _confirm,
            label: 'Yeni şifre (tekrar)',
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _savePassword(),
            validator: (v) => v != _password.text ? 'Şifreler eşleşmiyor.' : null,
          ),
          if (_error != null) _ErrorText(_error!),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _loading ? null : _savePassword,
            child: _loading
                ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Text('Şifreyi güncelle'),
          ),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 5,
              decoration: BoxDecoration(
                color: i <= current ? scheme.primary : scheme.outlineVariant,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: scheme.error),
          const SizedBox(width: 6),
          Expanded(
            child: Text(message, style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
