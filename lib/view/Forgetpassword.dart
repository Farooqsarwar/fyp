import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Forgetpassword Screen
class Forgetpassword extends StatefulWidget {
  const Forgetpassword({super.key});

  @override
  State<Forgetpassword> createState() => _ForgetpasswordState();
}

class _ForgetpasswordState extends State<Forgetpassword> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  final supabase = Supabase.instance.client;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> initiatePasswordReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await supabase.auth.resetPasswordForEmail(
        _emailController.text.trim(),
        redirectTo: 'app://reset-password',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset email sent! Check your inbox.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ResetPasswordPage(email: _emailController.text.trim()),
            ),
          );
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
        debugPrint('Auth error during password reset: ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An unexpected error occurred'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
        debugPrint('Unexpected error during password reset: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Forgot Password'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.lock_reset, size: 60, color: Colors.white),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Reset Your Password',
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Enter your email address to receive a reset token.',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintText: 'Enter your email',
                      hintStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.email_outlined, color: Colors.white70),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                      filled: true,
                      fillColor: Colors.white10,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email address';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                    enabled: !_isLoading,
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                    if (_formKey.currentState!.validate()) {
                      initiatePasswordReset();
                    }
                  },
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      color: Colors.yellow.shade600,
                    ),
                    child: const Center(
                      child: Text(
                        'Send Reset Token',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  child: const Text(
                    'Back to Login',
                    style: TextStyle(color: Colors.yellowAccent),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ResetPasswordPage
class ResetPasswordPage extends StatefulWidget {
  final String email;
  const ResetPasswordPage({super.key, required this.email});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.email;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showTokenSentDialog(widget.email);
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showTokenSentDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text(
          'Reset Token Sent',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'We sent a reset token to: $email',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            const Text(
              'Instructions:',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. Check your email for the 6-digit token\n'
                  '2. Copy the token from the email\n'
                  '3. Enter the token below along with your new password\n'
                  '4. Token expires in 1 hour',
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'OK',
              style: TextStyle(color: Colors.yellowAccent),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final response = await supabase.auth.verifyOTP(
        email: _emailController.text.trim(),
        token: _tokenController.text.trim(),
        type: OtpType.recovery,
      );

      if (response.session != null && mounted) {
        await supabase.auth.updateUser(
          UserAttributes(password: _passwordController.text),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password reset successfully!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
          await Future.delayed(const Duration(seconds: 3));
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/login',
                  (route) => false,
            );
          }
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        String errorMessage = e.message;
        if (e.message.contains('invalid') || e.message.contains('expired')) {
          errorMessage = 'Invalid or expired token. Please request a new one.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
        debugPrint('Auth error during password reset: ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An unexpected error occurred'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
        debugPrint('Unexpected error during password reset: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Reset Password'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.lock_reset, size: 60, color: Colors.white),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Reset Your Password',
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.email,
                  style: const TextStyle(fontSize: 16, color: Colors.white54),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Enter the 6-digit token from your email and your new password.',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: TextFormField(
                    controller: _emailController,
                    readOnly: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.email_outlined, color: Colors.white70),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                      filled: true,
                      fillColor: Colors.white10,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: TextFormField(
                    controller: _tokenController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Reset Token',
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintText: 'Enter 6-digit token',
                      hintStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.vpn_key, color: Colors.white70),
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                      filled: true,
                      fillColor: Colors.white10,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the reset token';
                      }
                      if (value.length != 6 || !RegExp(r'^\d{6}$').hasMatch(value)) {
                        return 'Enter a valid 6-digit token';
                      }
                      return null;
                    },
                    enabled: !_isLoading,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintText: 'Enter new password',
                      hintStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          color: Colors.white70,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                      filled: true,
                      fillColor: Colors.white10,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a new password';
                      }
                      if (value.length < 8) {
                        return 'Password must be at least 8 characters';
                      }
                      return null;
                    },
                    enabled: !_isLoading,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintText: 'Confirm new password',
                      hintStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                          color: Colors.white70,
                        ),
                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                      filled: true,
                      fillColor: Colors.white10,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                    enabled: !_isLoading,
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                    if (_formKey.currentState!.validate()) {
                      _resetPassword();
                    }
                  },
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      color: Colors.yellow.shade600,
                    ),
                    child: const Center(
                      child: Text(
                        'Reset Password',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  child: const Text(
                    'Back',
                    style: TextStyle(color: Colors.yellowAccent),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// VerifyEmailScreen
class VerifyEmailScreen extends StatefulWidget {
  final String email;
  const VerifyEmailScreen({super.key, required this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  bool isLoading = false;
  final supabase = Supabase.instance.client;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> verifyEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);

    try {
      final response = await supabase.auth.verifyOTP(
        email: widget.email,
        token: _otpController.text.trim(),
        type: OtpType.signup,
      );

      if (response.session != null && mounted) {
        await supabase
            .from('users')
            .update({'email_verified': true})
            .eq('email', widget.email);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email verified successfully!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
          await Future.delayed(const Duration(seconds: 3));
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/login',
                  (route) => false,
            );
          }
        }
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Database error: ${e.message}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
        debugPrint('Postgrest error during verification: $e');
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
        debugPrint('Auth error during verification: ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An unexpected error occurred'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
        debugPrint('Unexpected error during verification: $e');
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> resendVerification() async {
    setState(() => isLoading = true);
    try {
      await supabase.auth.resend(
        type: OtpType.signup,
        email: widget.email,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email resent!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
        debugPrint('Auth error during resend: ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to resend verification'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
        debugPrint('Unexpected error during resend: $e');
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Verify Email'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.email, size: 60, color: Colors.white),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Verify Your Email',
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.email,
                  style: const TextStyle(fontSize: 16, color: Colors.white54),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Check your email inbox for a 6-digit verification code.',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: TextFormField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Verification Code',
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintText: 'Enter 6-digit code',
                      hintStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.vpn_key, color: Colors.white70),
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                      filled: true,
                      fillColor: Colors.white10,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the verification code';
                      }
                      if (value.length != 6 || !RegExp(r'^\d{6}$').hasMatch(value)) {
                        return 'Enter a valid 6-digit code';
                      }
                      return null;
                    },
                    enabled: !isLoading,
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () {
                    if (_formKey.currentState!.validate()) {
                      verifyEmail();
                    }
                  },
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      color: Colors.yellow.shade600,
                    ),
                    child: const Center(
                      child: Text(
                        'Verify',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: isLoading ? null : resendVerification,
                  child: const Text(
                    'Resend Verification Email',
                    style: TextStyle(color: Colors.yellowAccent),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: const Text(
                    'Back to Signup',
                    style: TextStyle(color: Colors.yellowAccent),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}