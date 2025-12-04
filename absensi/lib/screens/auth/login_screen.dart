import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/biometric_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _biometricService = BiometricService();
  bool _obscurePassword = true;
  bool _canUseBiometric = false;
  bool _biometricEnabled = false;
  bool _isBiometricLoading = false;

  @override
  void initState() {
    super.initState();
    debugPrint('LoginScreen: initState');
    WidgetsBinding.instance.addObserver(this);
    _checkBiometric();
  }

  @override
  void dispose() {
    debugPrint('LoginScreen: dispose');
    WidgetsBinding.instance.removeObserver(this);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('LoginScreen: lifecycle state changed to $state, mounted: $mounted');
    // Only process if still mounted and widget is active
    if (state == AppLifecycleState.resumed && mounted) {
      // Re-check biometric when app comes back to foreground
      _checkBiometric();
    }
  }

  Future<void> _checkBiometric() async {
    if (!mounted) {
      debugPrint('_checkBiometric: widget not mounted, skipping');
      return;
    }
    
    debugPrint('=== LOGIN SCREEN: _checkBiometric START ===');
    final canUse = await _biometricService.canUseBiometric();
    final isEnabled = await _biometricService.isBiometricEnabled();
    
    // Also check if credentials exist
    final credentials = await _biometricService.getSavedCredentials();
    debugPrint('LoginScreen check results:');
    debugPrint('  - canUseBiometric: $canUse');
    debugPrint('  - isBiometricEnabled: $isEnabled');
    debugPrint('  - hasCredentials: ${credentials != null}');
    if (credentials != null) {
      debugPrint('  - saved email: ${credentials['email']}');
    }
    
    if (mounted) {
      setState(() {
        _canUseBiometric = canUse;
        _biometricEnabled = isEnabled;
      });
      final willShowButton = canUse && isEnabled;
      debugPrint('=== LOGIN SCREEN: Biometric button visible: $willShowButton ===');
    }
  }
  
  Future<void> _testBiometric() async {
    debugPrint('=== TEST BIOMETRIC BUTTON CLICKED ===');
    try {
      final result = await _biometricService.authenticate(
        reason: 'Test biometric authentication',
      );
      debugPrint('Test biometric result: $result');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result ? 'Biometrik berhasil!' : 'Biometrik dibatalkan atau gagal'),
            backgroundColor: result ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Test biometric error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleBiometricLogin() async {
    if (_isBiometricLoading) {
      debugPrint('Biometric login already in progress, ignoring');
      return;
    }

    // Runtime guards: ensure device supports biometrics and has enrollment
    if (!_canUseBiometric) {
      debugPrint('Runtime guard: Device does not support biometrics');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perangkat Anda tidak mendukung biometrik'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    setState(() => _isBiometricLoading = true);
    
    try {
      debugPrint('=== BIOMETRIC LOGIN START ===');
      
      // Step 1: Check credentials first
      debugPrint('Step 1 - Checking for saved credentials...');
      final credentials = await _biometricService.getSavedCredentials();
      debugPrint('Step 1 - Retrieved credentials: ${credentials != null ? "Found (${credentials['email']})" : "Not found"}');
      
      if (credentials == null) {
        setState(() => _isBiometricLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kredensial tidak ditemukan. Silakan aktifkan biometrik di Profile.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      
      // Step 2: Small delay to ensure UI is ready
      debugPrint('Step 2 - Waiting for UI to be ready...');
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (!mounted) {
        setState(() => _isBiometricLoading = false);
        return;
      }
      
      // Step 3: Authenticate with biometric
      debugPrint('Step 3 - Starting biometric authentication...');
      
      // Additional guard: check available biometrics before prompting
      try {
        final types = await _biometricService.getAvailableBiometrics();
        debugPrint('Available biometrics at runtime: $types');
        if (types.isEmpty) {
          setState(() => _isBiometricLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tidak ada biometrik yang terdaftar. Tambahkan sidik jari/wajah di Pengaturan.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 4),
              ),
            );
          }
          return;
        }
      } catch (e) {
        debugPrint('Error checking available biometrics: $e');
      }
      
      try {
        final authenticated = await _biometricService.authenticate(
          reason: 'Verifikasi identitas Anda untuk login',
        );
        debugPrint('Step 3 - Biometric authentication result: $authenticated');
        
        if (!authenticated) {
          setState(() => _isBiometricLoading = false);
          debugPrint('Biometric authentication cancelled or failed');
          // Don't show snackbar for user cancellation - it's expected behavior
          return;
        }
      } catch (e) {
        setState(() => _isBiometricLoading = false);
        debugPrint('Step 3 - Biometric authentication exception: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error autentikasi: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      
      // Step 4: Login with saved credentials
      if (!mounted) {
        setState(() => _isBiometricLoading = false);
        return;
      }
      
      debugPrint('Step 4 - Attempting login with saved credentials...');
      final authProvider = context.read<AuthProvider>();
      
      try {
        final success = await authProvider.login(
          credentials['email']!,
          credentials['password']!,
        );
        debugPrint('Step 4 - Login result: $success');
        
        if (mounted) {
          setState(() => _isBiometricLoading = false);
          
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Login berhasil!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 1),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Step 4 - Login error: $e');
        
        if (mounted) {
          setState(() => _isBiometricLoading = false);
          
          String errorMessage = 'Login gagal';
          if (e.toString().contains('401') || e.toString().contains('Unauthorized')) {
            errorMessage = 'Email atau password salah. Silakan aktifkan ulang biometrik di Profile.';
          } else if (e.toString().contains('DioException') || e.toString().contains('SocketException')) {
            errorMessage = 'Tidak dapat terhubung ke server';
          } else {
            errorMessage = 'Login gagal: ${e.toString()}';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
      
      debugPrint('=== BIOMETRIC LOGIN END ===');
    } catch (e) {
      debugPrint('Biometric login unexpected error: $e');
      if (mounted) {
        setState(() => _isBiometricLoading = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    
    try {
      final success = await authProvider.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (success && mounted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login berhasil!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );
        }
        // Navigation handled by main.dart
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Login gagal';
        
        if (e.toString().contains('401')) {
          errorMessage = 'Email atau password salah';
        } else if (e.toString().contains('DioException')) {
          errorMessage = 'Tidak dapat terhubung ke server';
        } else {
          errorMessage = 'Login gagal: ${e.toString()}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.fingerprint,
                    size: 80,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Absen MNC University',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Masuk dengan akun Anda',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Email harus diisi';
                      }
                      if (!value.contains('@')) {
                        return 'Email tidak valid';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password harus diisi';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, _) {
                      return ElevatedButton(
                        onPressed: authProvider.isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: authProvider.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Masuk'),
                      );
                    },
                  ),
                  if (_canUseBiometric && _biometricEnabled) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'atau',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _isBiometricLoading ? null : () {
                        debugPrint('Biometric button clicked!');
                        _handleBiometricLogin();
                      },
                      icon: _isBiometricLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.fingerprint, size: 28),
                      label: Text(_isBiometricLoading
                          ? 'Memproses...'
                          : 'Login dengan Biometrik'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                  if (_canUseBiometric && !_biometricEnabled) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Aktifkan login biometrik di Profile setelah login',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  // Debug test button (only in debug mode)
                  if (!bool.fromEnvironment('dart.vm.product')) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _testBiometric,
                      icon: const Icon(Icons.bug_report),
                      label: const Text('Test Biometrik'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey,
                      ),
                    ),
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
