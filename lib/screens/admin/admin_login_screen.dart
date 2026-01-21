import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_auth_provider.dart';
import '../../providers/user_service.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AdminAuthProvider>();
    final currentUser = context.watch<UserService>().currentUser;
    final isAuthenticated = currentUser != null;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Snow Paradise Admin',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    if (!isAuthenticated) ...[
                      const Text(
                        '관리자 계정으로 먼저 로그인해주세요.',
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: authProvider.isLoading
                              ? null
                              : () async {
                                  await context
                                      .read<UserService>()
                                      .loginWithGoogle();
                                },
                          child: const Text('Google 로그인'),
                        ),
                      ),
                    ] else ...[
                      Text(
                        '로그인: ${currentUser?.email ?? currentUser?.displayName ?? '관리자'}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: authProvider.isLoading
                            ? null
                            : () async {
                                await context.read<UserService>().signOut();
                              },
                        child: const Text('로그아웃'),
                      ),
                    ],
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Admin Password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                      ),
                      obscureText: true,
                      enabled: isAuthenticated && !authProvider.isLoading,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter password';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _handleLogin(),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: authProvider.isLoading || !isAuthenticated
                            ? null
                            : _handleLogin,
                        child: authProvider.isLoading
                            ? const CircularProgressIndicator()
                            : const Text('Login'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await context.read<AdminAuthProvider>().login(
          _passwordController.text,
        );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<AdminAuthProvider>().errorMessage ??
                'Invalid Password',
          ),
        ),
      );
    }
  }
}
