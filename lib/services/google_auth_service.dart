import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../app_config.dart';

/// Native Google identity session. No Firebase is used.
class GoogleAuthService extends ChangeNotifier {
  GoogleAuthService._();
  static final GoogleAuthService instance = GoogleAuthService._();

  final GoogleSignIn _google = GoogleSignIn.instance;
  GoogleSignInAccount? _account;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _events;
  bool _initialized = false;
  bool _loading = true;
  String? _error;

  GoogleSignInAccount? get account => _account;
  bool get isSignedIn => _account != null;
  bool get isLoading => _loading;
  String? get error => _error;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await _google.initialize(
        serverClientId: AppConfig.googleWebClientId.isEmpty
            ? null
            : AppConfig.googleWebClientId,
      );
      _initialized = true;
      _events = _google.authenticationEvents.listen(
        (event) {
          if (event is GoogleSignInAuthenticationEventSignIn) {
            _account = event.user;
            _error = null;
          } else if (event is GoogleSignInAuthenticationEventSignOut) {
            _account = null;
          }
          notifyListeners();
        },
        onError: (Object error) {
          _error = _friendlyError(error);
          notifyListeners();
        },
      );

      final restore = _google.attemptLightweightAuthentication();
      if (restore != null) {
        _account = await restore;
      }
    } catch (error) {
      _error = _friendlyError(error);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> signIn() async {
    if (!_initialized) await initialize();
    if (AppConfig.googleWebClientId.isEmpty) {
      throw StateError(
        'Client ID Google belum dipasang pada konfigurasi aplikasi.',
      );
    }
    if (!_google.supportsAuthenticate()) {
      throw UnsupportedError('Metode Google Sign-In tidak didukung perangkat ini.');
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _account = await _google.authenticate();
      final token = _account?.authentication.idToken;
      if (token == null || token.isEmpty) {
        _account = null;
        throw StateError('Google tidak memberikan ID token. Periksa OAuth Client ID.');
      }
    } catch (error) {
      _error = _friendlyError(error);
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<String> requireIdToken() async {
    if (!_initialized) await initialize();
    final account = _account;
    if (account == null) {
      throw StateError('Sesi Google belum aktif. Silakan masuk kembali.');
    }
    final token = account.authentication.idToken;
    if (token == null || token.isEmpty) {
      throw StateError('Sesi Google perlu diperbarui. Silakan masuk kembali.');
    }
    return token;
  }

  Future<void> signOut() async {
    await _google.signOut();
    _account = null;
    notifyListeners();
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    if (message.contains('clientConfigurationError') ||
        message.contains('serverClientId')) {
      return 'Konfigurasi Google Sign-In belum cocok. Periksa Web Client ID, nama paket Android, dan SHA-1 aplikasi.';
    }
    if (message.contains('canceled')) return 'Proses masuk Google dibatalkan.';
    return message.replaceFirst('Exception: ', '');
  }

  @override
  void dispose() {
    _events?.cancel();
    super.dispose();
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.child});
  final Widget child;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final auth = GoogleAuthService.instance;

  @override
  void initState() {
    super.initState();
    auth.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: auth,
      builder: (context, _) {
        if (auth.isLoading) {
          return const Scaffold(
            backgroundColor: Color(0xFFFAF7F0),
            body: Center(child: CircularProgressIndicator(color: Color(0xFF80612F))),
          );
        }
        if (auth.isSignedIn) return widget.child;
        return _GoogleSignInPage(auth: auth);
      },
    );
  }
}

class _GoogleSignInPage extends StatefulWidget {
  const _GoogleSignInPage({required this.auth});
  final GoogleAuthService auth;

  @override
  State<_GoogleSignInPage> createState() => _GoogleSignInPageState();
}

class _GoogleSignInPageState extends State<_GoogleSignInPage> {
  bool busy = false;
  String? message;

  Future<void> _signIn() async {
    if (busy) return;
    setState(() { busy = true; message = null; });
    try {
      await widget.auth.signIn();
    } catch (error) {
      if (mounted) setState(() => message = error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFF80612F);
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F0),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.remove_red_eye_outlined, size: 66, color: gold),
                  const SizedBox(height: 18),
                  const Text('OPTIK LENTERA',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, letterSpacing: 1.3, color: gold)),
                  const SizedBox(height: 8),
                  const Text('Masuk dengan akun Google petugas yang terdaftar.',
                    textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF746B62))),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: busy ? null : _signIn,
                      icon: busy
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.login),
                      label: Text(busy ? 'Menghubungkan…' : 'Masuk dengan Google'),
                      style: FilledButton.styleFrom(backgroundColor: gold, minimumSize: const Size.fromHeight(52)),
                    ),
                  ),
                  if (message != null || widget.auth.error != null) ...[
                    const SizedBox(height: 14),
                    Text(message ?? widget.auth.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.deepOrange, fontSize: 12)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
