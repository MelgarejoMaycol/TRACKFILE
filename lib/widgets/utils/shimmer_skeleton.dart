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
                child: ShimmerSkeleton(width: double.infinity, height: 50, borderRadius: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ShimmerSkeleton(width: double.infinity, height: 50, borderRadius: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
