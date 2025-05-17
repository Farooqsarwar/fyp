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

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController retypePasswordController = TextEditingController();
  final supabase = Supabase.instance.client;

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
                    if (!value.contains("@"))
                      return 'Enter a valid email with "@"';
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
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      registerNewUser(context);
                    }
                  },
                  child: _buildButtonContainer("Register Now"),
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
    passwordController.clear();
    retypePasswordController.clear();
    _formKey.currentState?.reset();
  }

  Future<void> registerNewUser(BuildContext context) async {
    try {
      final response = await supabase.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        data: {'name': nameController.text.trim()},
      );

      if (response.user != null) {
        // Check email verification status
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Registration successful! Please check your email to verify your account.'),
            backgroundColor: Colors.green,
          ),
        );

        // Insert user into the database
        await supabase.from('users').insert({
          'id': response.user!.id,
          'name': nameController.text.trim(),
          'email': emailController.text.trim(),
        });
        clearFormFields();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('An unexpected error occurred. Please try again later.'),
            backgroundColor: Colors.red),
      );
      print('Registration error: $error');
    }
  }
}

