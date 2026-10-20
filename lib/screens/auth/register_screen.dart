import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/auth_controller.dart';
import 'auth_layout.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final error = await context.read<AuthController>().register(
          username: _username.text,
          email: _email.text,
          password: _password.text,
        );
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    // Kayıt başarılı: oturum açıldı, kök ekran ana sayfaya döndü.
    navigator.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      showBack: true,
      title: 'Hesap oluştur',
      subtitle: 'Birkaç saniyede kaydol, fişlerini taramaya başla.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _username,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Kullanıcı adı',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.length < 3) return 'En az 3 karakter olmalı.';
                if (value.length > 20) return 'En fazla 20 karakter olmalı.';
                if (!RegExp(r'^[a-zA-Z0-9_.çğıöşüÇĞİÖŞÜ]+$').hasMatch(value)) {
                  return 'Sadece harf, rakam, _ ve . kullanabilirsin.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'E-posta',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v?.trim() ?? '')
                  ? null
                  : 'Geçerli bir e-posta gir.',
            ),
            const SizedBox(height: 14),
            PasswordField(
              controller: _password,
              textInputAction: TextInputAction.next,
              validator: (v) => (v ?? '').length < 6 ? 'Şifre en az 6 karakter olmalı.' : null,
            ),
            const SizedBox(height: 14),
            PasswordField(
              controller: _confirm,
              label: 'Şifre (tekrar)',
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              validator: (v) => v != _password.text ? 'Şifreler eşleşmiyor.' : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox.square(
                      dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Text('Kayıt Ol'),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Zaten hesabın var mı?'),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Giriş yap'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
