import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutterkit/kit/kit.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isRegistering = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (_isRegistering) {
        await authService.registerWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        await authService.signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signInWithGoogle();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email address first.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.sendPasswordResetEmail(_emailController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset email sent. Check your inbox.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: UkContainer(
            size: UkContainerSize.small,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo and Title
                    Icon(
                      Icons.cloud_upload_rounded,
                      size: 80,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    UkHeading(
                      'Firebase Hosting',
                      level: 3,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Deploy your web projects instantly',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),

                    // Error Message
                    if (_errorMessage != null) ...[
                      UkAlert(
                        message: _errorMessage!,
                        type: UkAlertType.danger,
                        dismissible: true,
                        onDismissed: () {
                          setState(() {
                            _errorMessage = null;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Email/Password Form
                    UkCard(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            UkTextField(
                              controller: _emailController,
                              label: 'Email',
                              hint: 'you@example.com',
                              prefixIcon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!value.contains('@')) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            UkTextField(
                              controller: _passwordController,
                              label: 'Password',
                              hint: 'Enter your password',
                              prefixIcon: Icons.lock_outlined,
                              isPassword: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                if (_isRegistering && value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),

                            // Forgot Password
                            if (!_isRegistering)
                              Align(
                                alignment: Alignment.centerRight,
                                child: UkButton(
                                  label: 'Forgot Password?',
                                  variant: UkButtonVariant.text,
                                  size: UkButtonSize.small,
                                  onPressed: _isLoading ? null : _resetPassword,
                                ),
                              ),
                            const SizedBox(height: 16),

                            // Sign In / Register Button
                            SizedBox(
                              width: double.infinity,
                              child: UkButton(
                                label: _isLoading
                                    ? (_isRegistering ? 'Creating Account...' : 'Signing In...')
                                    : (_isRegistering ? 'Create Account' : 'Sign In'),
                                variant: UkButtonVariant.primary,
                                size: UkButtonSize.large,
                                icon: _isLoading ? null : Icons.login,
                                onPressed: _isLoading ? null : _signInWithEmail,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Toggle Register/Login
                            UkButton(
                              label: _isRegistering
                                  ? 'Already have an account? Sign In'
                                  : "Don't have an account? Create one",
                              variant: UkButtonVariant.text,
                              size: UkButtonSize.small,
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      setState(() {
                                        _isRegistering = !_isRegistering;
                                        _errorMessage = null;
                                      });
                                    },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Divider
                    Row(
                      children: [
                        const Expanded(child: UkDivider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OR',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                        const Expanded(child: UkDivider()),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Google Sign In
                    SizedBox(
                      width: double.infinity,
                      child: UkButton(
                        label: 'Continue with Google',
                        variant: UkButtonVariant.outline,
                        size: UkButtonSize.large,
                        icon: Icons.g_mobiledata,
                        onPressed: _isLoading ? null : _signInWithGoogle,
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
}
