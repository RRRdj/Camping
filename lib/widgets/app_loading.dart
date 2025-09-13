// lib/widgets/app_loading.dart
import 'package:flutter/material.dart';

/// 라이트/다크에 따라 자동으로 색이 변하는
/// "실루엣(스켈레톤) + 쉬머" 로딩 위젯.
/// 기존 스피너 대신 전체 화면 플레이스홀더를 보여준다.
class AppLoading extends StatelessWidget {
  const AppLoading({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surface;
    return ColoredBox(
      color: bg,
      child: const _MyInfoSkeleton(), // 프로필+목록 형태의 실루엣
    );
  }
}

/* ─────────────────────────────
 * Shimmer + Skeleton Utilities
 * ────────────────────────────*/

class _Shimmer extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;
  final Duration period;

  const _Shimmer({
    required this.child,
    required this.baseColor,
    required this.highlightColor,
    this.period = const Duration(milliseconds: 1400),
  });

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        // -1.0 ~ 2.0 사이로 이동하는 수평 그라디언트
        final double dx = -1.0 + 3.0 * _controller.value;

        return ShaderMask(
          shaderCallback: (Rect bounds) {
            return LinearGradient(
              begin: const Alignment(-1.0, 0.0),
              end: const Alignment(1.0, 0.0),
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: const [0.25, 0.5, 0.75],
              transform: _SlidingGradientTransform(slidePercent: dx),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: widget.child,
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const _SkeletonBox({
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final hi = isDark ? Colors.grey.shade700 : Colors.grey.shade100;

    return _Shimmer(
      baseColor: base,
      highlightColor: hi,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: base, borderRadius: borderRadius),
      ),
    );
  }
}

class _SkeletonCircle extends StatelessWidget {
  final double size;
  const _SkeletonCircle({this.size = 100});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final hi = isDark ? Colors.grey.shade700 : Colors.grey.shade100;

    return _Shimmer(
      baseColor: base,
      highlightColor: hi,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: base, shape: BoxShape.circle),
      ),
    );
  }
}

/* ─────────────────────────────
 * MyInfo 전용 실루엣 레이아웃
 * (프로필 + 메뉴 리스트)
 * ────────────────────────────*/

class _MyInfoSkeleton extends StatelessWidget {
  const _MyInfoSkeleton();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 프로필 헤더
            Center(
              child: Column(
                children: [
                  const _SkeletonCircle(size: 100),
                  const SizedBox(height: 12),
                  _SkeletonBox(width: width * 0.4, height: 20), // 이름
                  const SizedBox(height: 6),
                  _SkeletonBox(width: width * 0.5, height: 14), // 닉네임
                  const SizedBox(height: 6),
                  _SkeletonBox(width: width * 0.6, height: 14), // 이메일
                  const SizedBox(height: 6),
                  _SkeletonBox(width: width * 0.3, height: 12), // 로그인 방식
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // 메뉴 리스트 실루엣
            ...List.generate(
              6,
              (i) => const _SkeletonListTile(),
            ).expand((w) => [w, const SizedBox(height: 12)]),
          ],
        ),
      ),
    );
  }
}

class _SkeletonListTile extends StatelessWidget {
  const _SkeletonListTile();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Row(
      children: [
        const _SkeletonCircle(size: 36),
        const SizedBox(width: 12),
        Expanded(child: _SkeletonBox(width: width, height: 18)),
        const SizedBox(width: 12),
        _SkeletonBox(
          width: 16,
          height: 16,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}
