import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:atlocator/core/routing/route_names.dart';
import 'package:atlocator/features/auth/session/auth_session.dart';
import 'package:atlocator/features/trip/session/trip_session.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _openLogin();
  }

  Future<void> _openLogin() async {
    await Future.delayed(const Duration(milliseconds: 1800));
    await AuthSession.load();
    await TripSession.load();

    if (!mounted) return;
    context.go(AuthSession.isLoggedIn ? RouteNames.home : RouteNames.login);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xff102A43), Color(0xff006D77), Color(0xffE8F7F5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -70,
              child: _GlowCircle(
                size: 230,
                color: Colors.white.withOpacity(.13),
              ),
            ),
            Positioned(
              left: -60,
              bottom: 90,
              child: _GlowCircle(
                size: 180,
                color: const Color(0xffF6C85F).withOpacity(.16),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 170,
                color: const Color(0xffF6C85F).withOpacity(.12),
              ),
            ),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 116,
                        width: 116,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.18),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(.42),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xff06182E).withOpacity(.28),
                              blurRadius: 34,
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.near_me_rounded,
                          size: 58,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 26),
                      Text(
                        'AT Locator',
                        textAlign: TextAlign.center,
                        style: textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'GPS trip sharing',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(.82),
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 38),
                      const SizedBox(
                        height: 28,
                        width: 28,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.8,
                        ),
                      ),
                    ],
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

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
