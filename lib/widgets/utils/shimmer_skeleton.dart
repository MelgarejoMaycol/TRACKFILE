import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Widget que simula un loading con efecto Shimmer
class ShimmerSkeleton extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final EdgeInsets margin;

  const ShimmerSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 8,
    this.margin = const EdgeInsets.all(0),
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.white.withValues(alpha: 0.1),
      highlightColor: Colors.white.withValues(alpha: 0.2),
      child: Container(
        margin: margin,
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Skeleton para un chip de resumen
class ShimmerSummaryChip extends StatelessWidget {
  const ShimmerSummaryChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShimmerSkeleton(width: 20, height: 20, borderRadius: 4),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerSkeleton(width: 60, height: 16, borderRadius: 4),
              const SizedBox(height: 4),
              ShimmerSkeleton(width: 80, height: 12, borderRadius: 4),
            ],
          ),
        ],
      ),
    );
  }
}

/// Skeleton para tarjeta de documento
class ShimmerDocumentCard extends StatelessWidget {
  const ShimmerDocumentCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ShimmerSkeleton(width: 100, height: 100, borderRadius: 8),
        const SizedBox(height: 8),
        ShimmerSkeleton(width: 80, height: 14, borderRadius: 4),
        const SizedBox(height: 4),
        ShimmerSkeleton(width: 100, height: 12, borderRadius: 4),
      ],
    );
  }
}

/// Skeleton para tarjeta de vehículo
class ShimmerVehicleCard extends StatelessWidget {
  const ShimmerVehicleCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          ShimmerSkeleton(width: 44, height: 44, borderRadius: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerSkeleton(width: 120, height: 16, borderRadius: 4),
                const SizedBox(height: 8),
                ShimmerSkeleton(width: 150, height: 12, borderRadius: 4),
                const SizedBox(height: 6),
                ShimmerSkeleton(width: 130, height: 12, borderRadius: 4),
                const SizedBox(height: 6),
                ShimmerSkeleton(width: 100, height: 12, borderRadius: 4),
              ],
            ),
          ),
          ShimmerSkeleton(width: 24, height: 24, borderRadius: 4),
        ],
      ),
    );
  }
}

/// Skeleton para el perfil de usuario
class ShimmerUserProfile extends StatelessWidget {
  const ShimmerUserProfile({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24, width: 1.4),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerSkeleton(width: 60, height: 60, borderRadius: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerSkeleton(width: 150, height: 18, borderRadius: 4),
                    const SizedBox(height: 8),
                    ShimmerSkeleton(width: 180, height: 14, borderRadius: 4),
                  ],
                ),
              ),
              ShimmerSkeleton(width: 40, height: 40, borderRadius: 20),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, thickness: 0.8, height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ShimmerSkeleton(
                  width: double.infinity,
                  height: 50,
                  borderRadius: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ShimmerSkeleton(
                  width: double.infinity,
                  height: 50,
                  borderRadius: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Skeleton completo para la pantalla de perfil
class ShimmerPerfilPage extends StatelessWidget {
  const ShimmerPerfilPage({super.key});

  static const Color _surfaceColor = Color(0xFF131760);
  static const Color _cardColor = Color(0xFF20206B);
  static const Color _panelColor = Color(0xFF171968);
  static const Color _softBorderColor = Color(0xFF3E3BB8);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _surfaceColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isCompact = constraints.maxWidth < 920;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              isCompact ? 16 : 24,
              24,
              isCompact ? 16 : 24,
              isCompact ? 120 : 80,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ShimmerSkeleton(
                      width: 260,
                      height: 28,
                      borderRadius: 8,
                    ),
                    const SizedBox(height: 10),
                    const ShimmerSkeleton(
                      width: 520,
                      height: 14,
                      borderRadius: 8,
                    ),
                    const SizedBox(height: 14),
                    const ShimmerSkeleton(
                      width: 190,
                      height: 38,
                      borderRadius: 12,
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 18,
                      runSpacing: 18,
                      children: [
                        _profileCard(isCompact),
                        _detailsCard(isCompact),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _actionsCard(isCompact),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static Widget _profileCard(bool isCompact) {
    return Container(
      width: isCompact ? double.infinity : 360,
      padding: const EdgeInsets.all(22),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              ShimmerSkeleton(width: 72, height: 72, borderRadius: 36),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerSkeleton(width: 170, height: 18, borderRadius: 6),
                    SizedBox(height: 10),
                    ShimmerSkeleton(width: 210, height: 13, borderRadius: 6),
                    SizedBox(height: 8),
                    ShimmerSkeleton(width: 130, height: 13, borderRadius: 6),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.45,
            children: List.generate(
              4,
              (_) => Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _panelColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _softBorderColor.withValues(alpha: 0.45),
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ShimmerSkeleton(width: 80, height: 15, borderRadius: 6),
                    SizedBox(height: 8),
                    ShimmerSkeleton(width: 60, height: 11, borderRadius: 6),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _detailsCard(bool isCompact) {
    return Container(
      width: isCompact ? double.infinity : 640,
      padding: const EdgeInsets.all(22),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerSkeleton(width: 220, height: 20, borderRadius: 6),
          const SizedBox(height: 18),
          Wrap(
            spacing: 18,
            runSpacing: 16,
            children: List.generate(
              6,
              (_) => SizedBox(
                width: isCompact ? double.infinity : 280,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: _panelColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _softBorderColor.withValues(alpha: 0.45),
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerSkeleton(width: 90, height: 12, borderRadius: 6),
                      SizedBox(height: 8),
                      ShimmerSkeleton(width: 170, height: 15, borderRadius: 6),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _actionsCard(bool isCompact) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 18 : 22),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerSkeleton(width: 210, height: 20, borderRadius: 6),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: List.generate(
              3,
              (_) => SizedBox(
                width: isCompact ? double.infinity : 260,
                child: const ShimmerSkeleton(height: 50, borderRadius: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: _cardColor,
      border: Border.all(color: _softBorderColor.withValues(alpha: 0.45)),
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}
