import 'package:flutter/material.dart';
import '../services/calculation_service.dart';
import '../utils/constants.dart';

/// 分數變化動畫 widget
/// 當 score 改變時，數字會從舊值平滑過渡到新值，並閃爍背景色
class AnimatedScoreText extends StatefulWidget {
  final int score;
  final TextStyle? style;

  const AnimatedScoreText({
    super.key,
    required this.score,
    this.style,
  });

  @override
  State<AnimatedScoreText> createState() => _AnimatedScoreTextState();
}

class _AnimatedScoreTextState extends State<AnimatedScoreText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _scoreAnimation;
  late Animation<double> _flashAnimation;
  int _previousScore = 0;
  int _scoreDirection = 0; // 1 = gain, -1 = loss, 0 = no change

  @override
  void initState() {
    super.initState();
    _previousScore = widget.score;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scoreAnimation = AlwaysStoppedAnimation(widget.score);
    _flashAnimation = AlwaysStoppedAnimation(0.0);
  }

  @override
  void didUpdateWidget(AnimatedScoreText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      _previousScore = oldWidget.score;
      _scoreDirection = widget.score > _previousScore ? 1 : -1;

      _scoreAnimation = IntTween(
        begin: _previousScore,
        end: widget.score,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ));

      _flashAnimation = TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.3), weight: 30),
        TweenSequenceItem(tween: Tween(begin: 0.3, end: 0.0), weight: 70),
      ]).animate(_controller);

      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final displayScore = _scoreAnimation.value;
        final flashOpacity = _flashAnimation.value;

        Color? flashColor;
        if (flashOpacity > 0 && _scoreDirection != 0) {
          flashColor = (_scoreDirection > 0
                  ? AppConstants.winColor
                  : AppConstants.loseColor)
              .withValues(alpha: flashOpacity);
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: flashColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              CalculationService.formatScore(displayScore),
              style: widget.style,
              maxLines: 1,
            ),
          ),
        );
      },
    );
  }
}

/// 按下縮放回饋 wrapper
class TapScaleWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;
  final Duration duration;

  const TapScaleWrapper({
    super.key,
    required this.child,
    this.onTap,
    this.scaleDown = 0.95,
    this.duration = const Duration(milliseconds: 100),
  });

  @override
  State<TapScaleWrapper> createState() => _TapScaleWrapperState();
}

class _TapScaleWrapperState extends State<TapScaleWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleDown,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

/// 頁面切換動畫 - fade + 輕微上滑
class FadeSlidePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  FadeSlidePageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.05),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );
}
