import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/leave_provider.dart';
import '../../services/biometric_service.dart';
import '../../utils/error_handler.dart';
import '../history/attendance_history_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _biometricService = BiometricService();
  bool _canUseBiometric = false;
  bool _biometricEnabled = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final canUse = await _biometricService.canUseBiometric();
    final isEnabled = await _biometricService.isBiometricEnabled();
    
    setState(() {
      _canUseBiometric = canUse;
      _biometricEnabled = isEnabled;
    });
  }

  Future<void> _toggleBiometric(bool value) async {
    debugPrint('Toggle biometric called with value: $value');
    debugPrint('Can use biometric: $_canUseBiometric');
    
    if (!_canUseBiometric) {
      debugPrint('Device does not support biometric');
      ErrorHandler.showErrorSnackBar(
        context,
        'Perangkat tidak mendukung biometrik atau belum ada sidik jari/wajah yang terdaftar',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (value) {
        debugPrint('Enabling biometric...');
        
        // Show confirmation dialog
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Aktifkan Login Biometrik'),
            content: const Text(
              'Anda perlu memasukkan password untuk mengaktifkan login biometrik.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Lanjutkan'),
              ),
            ],
          ),
        );

        if (confirmed != true) {
          setState(() => _isLoading = false);
          return;
        }

        // Show password input dialog
        if (!mounted) {
          setState(() => _isLoading = false);
          return;
        }

        final password = await showDialog<String>(
          context: context,
          builder: (context) => _PasswordInputDialog(),
        );

        debugPrint('Password dialog result: ${password != null ? "Got password" : "Cancelled"}');

        if (password != null && mounted) {
          final authProvider = context.read<AuthProvider>();
          final email = authProvider.user?.email ?? '';
          
          if (email.isEmpty) {
            setState(() => _isLoading = false);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Email user tidak ditemukan'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
          
          debugPrint('Attempting to save credentials for email: $email');
          
          // Save credentials
          try {
            debugPrint('Saving credentials - Email: $email, Password length: ${password.length}');
            
            await _biometricService.enableBiometric(
              email: email,
              password: password,
            );
            
            debugPrint('enableBiometric() completed');
            
            // Verify credentials were saved
            final savedCreds = await _biometricService.getSavedCredentials();
            final isEnabled = await _biometricService.isBiometricEnabled();
            
            debugPrint('Verification - isEnabled: $isEnabled, hasCreds: ${savedCreds != null}');
            if (savedCreds != null) {
              debugPrint('Saved email matches: ${savedCreds['email'] == email}');
            }
            
            setState(() {
              _biometricEnabled = true;
              _isLoading = false;
            });
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Login biometrik berhasil diaktifkan!'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          } catch (e) {
            debugPrint('Error saving credentials: $e');
            debugPrint('Error stack trace: ${StackTrace.current}');
            setState(() => _isLoading = false);
            if (mounted) {
              ErrorHandler.showErrorDialog(
                context,
                e,
                onRetry: () => _toggleBiometric(value),
              );
            }
          }
        } else {
          debugPrint('Password dialog cancelled');
          setState(() => _isLoading = false);
        }
      } else {
        // Disable biometric
        await _biometricService.disableBiometric();
        setState(() {
          _biometricEnabled = false;
          _isLoading = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login biometrik dinonaktifkan'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ErrorHandler.showErrorDialog(
          context,
          e,
          onRetry: () => _toggleBiometric(value),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil & Pengaturan'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Informasi Pengguna',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  _buildInfoRow('Nama', user?.name ?? '-'),
                  const SizedBox(height: 12),
                  _buildInfoRow('Email', user?.email ?? '-'),
                  const SizedBox(height: 12),
                  _buildInfoRow('NIP', user?.nip ?? '-'),
                  const SizedBox(height: 12),
                  _buildInfoRow('Role', user?.role ?? '-'),
                  if (user?.department != null) ...[
                    const SizedBox(height: 12),
                    _buildInfoRow('Departemen', user!.department!),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Keamanan',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Login dengan Biometrik'),
                    subtitle: _canUseBiometric
                        ? const Text('Gunakan sidik jari atau Face ID untuk login')
                        : const Text('Perangkat tidak mendukung biometrik'),
                    value: _biometricEnabled,
                    onChanged: _canUseBiometric && !_isLoading ? _toggleBiometric : null,
                    secondary: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.fingerprint),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('Riwayat Absensi'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AttendanceHistoryScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.red.shade50,
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Keluar',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Keluar'),
                    content: const Text('Apakah Anda yakin ingin keluar?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Batal'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Keluar'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && mounted) {
                  // Clear all provider data before logout
                  context.read<AttendanceProvider>().clear();
                  context.read<LeaveProvider>().clear();
                  
                  await authProvider.logout();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

class _PasswordInputDialog extends StatefulWidget {
  @override
  State<_PasswordInputDialog> createState() => _PasswordInputDialogState();
}

class _PasswordInputDialogState extends State<_PasswordInputDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Masukkan Password'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Masukkan password Anda untuk verifikasi',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _passwordController.text);
            }
          },
          child: const Text('Aktifkan'),
        ),
      ],
    );
  }
}
