// lib/widgets/app_loading.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 심플한 흰 화면 + 파란색 로딩 스피너
class AppLoading extends StatefulWidget {
  const AppLoading({Key? key}) : super(key: key);

  @override
  State<AppLoading> createState() => _AppLoadingState();
}

class _AppLoadingState extends State<AppLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const ticks = 12; // 막대 개수
    const tickLength = 14.0;
    const tickThickness = 4.0;
    const size = 60.0;

    return Container(
      color: Colors.white, // 전체 흰 배경
      alignment: Alignment.center,
      child: SizedBox(
        width: size,
        height: size,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            return Transform.rotate(
              angle: _ctrl.value * 2 * math.pi,
              child: Stack(
                alignment: Alignment.center,
                children: List.generate(ticks, (i) {
                  final angle = (2 * math.pi / ticks) * i;
                  final alpha = (255 / ticks * (i + 1)).toInt();
                  final color = Colors.blue.withAlpha(alpha);
                  return Transform.rotate(
                    angle: angle,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        width: tickThickness,
                        height: tickLength,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(tickThickness),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          },
        ),
      ),
    );
  }
}
