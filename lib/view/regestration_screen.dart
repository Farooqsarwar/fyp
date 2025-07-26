import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'Login_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  bool isObscured = true;
  bool retypeIsObscured = true;
  bool isLoading = false;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController retypePasswordController =
      TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  final supabase = Supabase.instance.client;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    retypePasswordController.dispose();
    super.dispose();
  }

  Future<void> registerUser() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);

    try {
      final response = await supabase.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        data: {
          'name': nameController.text.trim(),
          if (phoneController.text.trim().isNotEmpty)
            'phone': phoneController.text.trim(),
        },
        emailRedirectTo: 'app://redirect',
      );

      if (response.user != null && context.mounted) {
        // Trigger handles insertion into public.users
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VerifyEmailScreen(
              email: emailController.text,
            ),
          ),
        );
      }
    } on PostgrestException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Database error: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
        print('Postgrest error during signup: $e');
      }
    } on AuthException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
        print('Auth error during signup: ${e.message}');
      }
    } catch (e) {
      print('Unexpected error during signup: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                const CircleAvatar(
                  backgroundColor: Colors.transparent,
                  backgroundImage: AssetImage("assets/logo.jpg"),
                  radius: 60,
                ),
                const Text(
                  "Register",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 35,
                  ),
                ),
                const SizedBox(height: 9),
                const Text(
                  "Create your new account",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 40),
                _buildTextField(
                  controller: nameController,
                  label: "Display Name",
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter your display name' : null,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: emailController,
                  label: "Your Email",
                  validator: (value) {
                    if (value!.isEmpty) return 'Please enter your email';
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: phoneController,
                  label: "Phone Number",
                  validator: (value) {
                    if (value!.isEmpty) return null; // Phone is optional
                    if (!RegExp(r'^\d{10,15}$').hasMatch(value)) {
                      return 'Enter a valid phone number (10-15 digits)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                _buildPasswordField(
                  controller: passwordController,
                  label: "Password",
                  isObscured: isObscured,
                  onToggleVisibility: () =>
                      setState(() => isObscured = !isObscured),
                  validator: (value) {
                    if (value!.isEmpty) return 'Please enter your password';
                    if (value.length < 6)
                      return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                _buildPasswordField(
                  controller: retypePasswordController,
                  label: "Retype Password",
                  isObscured: retypeIsObscured,
                  onToggleVisibility: () =>
                      setState(() => retypeIsObscured = !retypeIsObscured),
                  validator: (value) {
                    if (value!.isEmpty) return 'Please retype your password';
                    if (value != passwordController.text)
                      return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 40),
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          if (_formKey.currentState!.validate()) {
                            registerUser();
                          }
                        },
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : _buildButtonContainer("Register Now"),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Center(
                    child: Text(
                      "Already have an account?",
                      style: TextStyle(
                          color: Colors.white24, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Center(
                  child: TextButton(
                    onPressed: () {
                      clearFormFields();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const LoginScreen()),
                      );
                    },
                    child: const Text(
                      "Login here",
                      style: TextStyle(
                          color: Colors.yellowAccent,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String? Function(String?) validator,
  }) {
    return SizedBox(
      width: double.infinity,
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Colors.white),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.white),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool isObscured,
    required VoidCallback onToggleVisibility,
    required String? Function(String?) validator,
  }) {
    return SizedBox(
      width: double.infinity,
      child: TextFormField(
        controller: controller,
        obscureText: isObscured,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white),
          suffixIcon: GestureDetector(
            onTap: onToggleVisibility,
            child: Icon(
              isObscured ? Icons.visibility : Icons.visibility_off,
              color: Colors.white,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Colors.white),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.white),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildButtonContainer(String text) {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: Colors.yellow.shade600,
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void clearFormFields() {
    nameController.clear();
    emailController.clear();
    phoneController.clear();
    passwordController.clear();
    retypePasswordController.clear();
    _formKey.currentState?.reset();
  }
}

class VerifyEmailScreen extends StatefulWidget {
  final String email;

  const VerifyEmailScreen({super.key, required this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _otpController = TextEditingController();
  bool isLoading = false;
  final supabase = Supabase.instance.client;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> verifyEmail() async {
    if (_otpController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a 6-digit code'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await supabase.auth.verifyOTP(
        email: widget.email,
        token: _otpController.text.trim(),
        type: OtpType.email,
      );

      if (response.session != null && context.mounted) {
        await supabase
            .from('users')
            .update({'email_verified': true}).eq('email', widget.email);

        if (context.mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email verified successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } on PostgrestException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Database error: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
        print('Postgrest error during verification: $e');
      }
    } on AuthException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
        print('Auth error during verification: ${e.message}');
      }
    } catch (e) {
      print('Unexpected error during verification: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> resendVerification() async {
    setState(() => isLoading = true);
    try {
      await supabase.auth.resend(
        type: OtpType.signup,
        email: widget.email,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email resent!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on AuthException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
        print('Auth error during resend: ${e.message}');
      }
    } catch (e) {
      print('Unexpected error during resend: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to resend verification'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
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
              "Verify Your Email",
              style: TextStyle(
                  fontSize: 24,
                  color: Colors.white,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              widget.email,
              style: const TextStyle(fontSize: 16, color: Colors.white54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const Text(
              "Check your email inbox for a 6-digit verification code.",
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
                  labelText: "Enter 6-digit code",
                  labelStyle: const TextStyle(color: Colors.white),
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: isLoading ? null : verifyEmail,
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
                          "Verify",
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
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Back to Signup',
                style: TextStyle(color: Colors.yellowAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
