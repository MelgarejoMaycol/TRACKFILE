import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  static const route = '/onboarding';
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  Timer? _timer;
  int _currentPage = 0;
  int _pageDirection = 1; // 1 = forward (from right), -1 = backward
  Offset _incomingOffset = const Offset(0.3, 0);

  @override
  void initState() {
    super.initState();
    // Auto-advance the page every 4 seconds
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_controller.hasClients) return;
      final current = (_controller.page?.round() ?? _controller.initialPage);
      final next = (current + 1) % _slides.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  final _slides = const [
    _SlideData(
      title: 'Welcome!',
      description:
          'Gestión documental y mantenimientos de tu flota en un solo lugar.',
      imagePath: 'assets/slide1.webp',
    ),
    _SlideData(
      title: 'Alertas inteligentes',
      description:
          'Recibe recordatorios de vencimientos y mantenimientos a tiempo.',
      imagePath: 'assets/slide2.webp',
    ),
    _SlideData(
      title: 'Todo centralizado',
      description:
          'Documentos de vehículos y conductores ordenados y seguros.',
      imagePath: 'assets/slide3.webp',
    ),
  ];

  @override
  Widget build(BuildContext context) {
  final size = MediaQuery.of(context).size;
  // clamp image heights to avoid overflow on small screens
  final outerImageHeight = math.min(size.height * 0.605, 520.0);
  final innerImageHeight = math.min(size.height * 0.528, 480.0);

    return Scaffold(
      backgroundColor: const Color(0xFF0C1C58),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
              // Header con logo (alineado a la izquierda)
              Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Image.asset('assets/logo.png', height: 64),
                  const SizedBox(width: 10),
                  const Text(
                    'TRACKFILE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Imagen corrediza (solo la imagen dentro del PageView)
              SizedBox(
                // aumentamos la altura de la caja de imagenes un 10% (con tope)
                height: outerImageHeight,
                child: Center(
                  child: Container(
                    width: size.width * 0.62,
                    // la altura interna también se incrementa un 10% (con tope)
                    height: innerImageHeight,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: _slides.length,
                        onPageChanged: (i) {
                          // determina la dirección y actualiza el índice
                          setState(() {
                            _pageDirection = i > _currentPage ? 1 : -1;
                            _incomingOffset = Offset(_pageDirection * 0.3, 0);
                            _currentPage = i;
                          });
                        },
                        itemBuilder: (_, i) {
                          final s = _slides[i];
                          return Image.asset(s.imagePath, fit: BoxFit.cover);
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Texto fuera de la imagen: título + descripción con animación
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, animation) {
                    final offsetAnim = Tween<Offset>(
                      begin: _incomingOffset,
                      end: Offset.zero,
                    ).animate(animation);
                    return SlideTransition(
                      position: offsetAnim,
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: Column(
                    key: ValueKey<int>(_currentPage),
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        _slides[_currentPage].title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _slides[_currentPage].description,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Indicador de páginas al final
              SmoothPageIndicator(
                controller: _controller,
                count: _slides.length,
                effect: const ExpandingDotsEffect(
                  dotHeight: 8,
                  dotWidth: 8,
                  spacing: 8,
                  activeDotColor: Color(0xFF14C6A4),
                  dotColor: Colors.white24,
                ),
              ),
              const SizedBox(height: 8),

              // Botón "ÚNETE" (alineado al centro con ancho del contenedor de imagen)
              SizedBox(
                width: size.width * 0.62,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed(LoginScreen.route);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                  ).merge(
                    ButtonStyle(
                      // degradado manual con Ink
                        foregroundColor:
                          WidgetStateProperty.all<Color>(Colors.white),
                        overlayColor: WidgetStateProperty.all<Color>(
                          Colors.white.withValues(alpha: 0.08)),
                    ),
                  ),
                  child: Ink(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF14C6A4), Color(0xFF2E50E5)],
                      ),
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      constraints: const BoxConstraints(minHeight: 48),
                      child: const Text(
                        'ÚNETE',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
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
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

}

class _SlideData {
  final String title;
  final String description;
  final String imagePath;
  const _SlideData({
    required this.title,
    required this.description,
    required this.imagePath,
  });
}
