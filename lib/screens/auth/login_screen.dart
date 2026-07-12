import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/route_names.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));

    setState(() => _loading = false);

    if (!mounted) return;
    context.go(RouteNames.home);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xff102A43),
              Color(0xff006D77),
              Color(0xffE8F7F5),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 210,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(.16),
                      Colors.white.withOpacity(.02),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 160,
                color: const Color(0xffF6C85F).withOpacity(.13),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.94),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withOpacity(.55),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xff06182E).withOpacity(.28),
                            blurRadius: 38,
                            offset: const Offset(0, 22),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.fromLTRB(
                                  30,
                                  32,
                                  30,
                                  28,
                                ),
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xff102A43),
                                      Color(0xff006D77),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      height: 92,
                                      width: 92,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(.18),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white.withOpacity(.42),
                                          width: 1.4,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.near_me_rounded,
                                        size: 46,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 22),
                                    const Text(
                                      "AT Locator",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 31,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "Create trips, share live GPS, and keep your group in sync",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(.82),
                                        fontSize: 14,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  30,
                                  30,
                                  30,
                                  24,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      "Welcome back",
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            color: const Color(0xff12263F),
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      "Enter your credentials to open your dashboard.",
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: Colors.blueGrey.shade600,
                                            height: 1.35,
                                          ),
                                    ),
                                    const SizedBox(height: 26),
                                    _LoginTextField(
                                      controller: _usernameController,
                                      label: "Username",
                                      icon: Icons.person_outline_rounded,
                                      validatorMessage: "Enter username",
                                    ),
                                    const SizedBox(height: 18),
                                    _LoginTextField(
                                      controller: _passwordController,
                                      label: "Password",
                                      icon: Icons.lock_outline_rounded,
                                      obscureText: _obscurePassword,
                                      validatorMessage: "Enter password",
                                      suffixIcon: IconButton(
                                        tooltip: _obscurePassword
                                            ? "Show password"
                                            : "Hide password",
                                        onPressed: () {
                                          setState(() {
                                            _obscurePassword =
                                                !_obscurePassword;
                                          });
                                        },
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                          color: Colors.blueGrey.shade500,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 28),
                                    SizedBox(
                                      height: 56,
                                      child: ElevatedButton(
                                        onPressed: _loading ? null : _login,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xff006D77),
                                          foregroundColor: Colors.white,
                                          disabledBackgroundColor:
                                              Colors.blueGrey.shade200,
                                          elevation: 0,
                                          shadowColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(18),
                                          ),
                                        ),
                                        child: _loading
                                            ? const SizedBox(
                                                width: 24,
                                                height: 24,
                                                child:
                                                    CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2.5,
                                                ),
                                              )
                                            : const Text(
                                                "Sign In",
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.verified_user_outlined,
                                          size: 16,
                                          color: Colors.blueGrey.shade400,
                                        ),
                                        const SizedBox(width: 7),
                                        Text(
                                          "Version 1.0.0",
                                          style: TextStyle(
                                            color: Colors.blueGrey.shade400,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginTextField extends StatelessWidget {
  const _LoginTextField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.validatorMessage,
    this.obscureText = false,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String validatorMessage;
  final bool obscureText;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(
        color: Color(0xff12263F),
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.blueGrey.shade500),
        prefixIcon: Icon(icon, color: const Color(0xff006D77)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xffF5F8FB),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.blueGrey.shade100),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xff006D77),
            width: 1.8,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.red.shade300),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.8),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return validatorMessage;
        return null;
      },
    );
  }
}
