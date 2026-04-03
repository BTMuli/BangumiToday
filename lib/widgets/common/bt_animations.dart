import 'package:fluent_ui/fluent_ui.dart';

import '../../core/theme/bt_theme.dart';

class BTFadeIn extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Curve curve;

  const BTFadeIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.delay = Duration.zero,
    this.curve = Curves.easeOut,
  });

  @override
  State<BTFadeIn> createState() => _BTFadeInState();
}

class _BTFadeInState extends State<BTFadeIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _animation, child: widget.child);
  }
}

class BTSlideIn extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Offset offset;
  final Curve curve;

  const BTSlideIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.delay = Duration.zero,
    this.offset = const Offset(0.1, 0),
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<BTSlideIn> createState() => _BTSlideInState();
}

class _BTSlideInState extends State<BTSlideIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(position: _animation, child: widget.child);
  }
}

class BTScaleIn extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final double beginScale;
  final Curve curve;

  const BTScaleIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.delay = Duration.zero,
    this.beginScale = 0.9,
    this.curve = Curves.easeOutBack,
  });

  @override
  State<BTScaleIn> createState() => _BTScaleInState();
}

class _BTScaleInState extends State<BTScaleIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = Tween<double>(
      begin: widget.beginScale,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _animation, child: widget.child);
  }
}

class BTFadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Offset offset;
  final Curve curve;

  const BTFadeSlideIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 350),
    this.delay = Duration.zero,
    this.offset = const Offset(0, 0.05),
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<BTFadeSlideIn> createState() => _BTFadeSlideInState();
}

class _BTFadeSlideInState extends State<BTFadeSlideIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: widget.curve);
    _slideAnimation = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(position: _slideAnimation, child: widget.child),
    );
  }
}

class BTStaggeredList extends StatefulWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Duration itemDuration;
  final Duration staggerDelay;
  final Offset slideOffset;

  const BTStaggeredList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.itemDuration = const Duration(milliseconds: 300),
    this.staggerDelay = const Duration(milliseconds: 50),
    this.slideOffset = const Offset(0, 0.03),
  });

  @override
  State<BTStaggeredList> createState() => _BTStaggeredListState();
}

class _BTStaggeredListState extends State<BTStaggeredList> {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: widget.itemCount,
      itemBuilder: (context, index) {
        return BTFadeSlideIn(
          duration: widget.itemDuration,
          delay: widget.staggerDelay * index,
          offset: widget.slideOffset,
          child: widget.itemBuilder(context, index),
        );
      },
    );
  }
}

class BTPulseAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double minScale;
  final double maxScale;
  final bool repeat;

  const BTPulseAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1000),
    this.minScale = 0.97,
    this.maxScale = 1.0,
    this.repeat = true,
  });

  @override
  State<BTPulseAnimation> createState() => _BTPulseAnimationState();
}

class _BTPulseAnimationState extends State<BTPulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = Tween<double>(
      begin: widget.minScale,
      end: widget.maxScale,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (widget.repeat) {
      _controller.repeat(reverse: true);
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _animation, child: widget.child);
  }
}

class BTShakeAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double offset;
  final VoidCallback? onComplete;

  const BTShakeAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.offset = 10,
    this.onComplete,
  });

  @override
  State<BTShakeAnimation> createState() => _BTShakeAnimationState();
}

class _BTShakeAnimationState extends State<BTShakeAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: widget.offset), weight: 1),
      TweenSequenceItem(
        tween: Tween(begin: widget.offset, end: -widget.offset),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -widget.offset, end: widget.offset),
        weight: 2,
      ),
      TweenSequenceItem(tween: Tween(begin: widget.offset, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_animation.value, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class BTHoverScale extends StatefulWidget {
  final Widget child;
  final double hoverScale;
  final Duration duration;
  final Curve curve;

  const BTHoverScale({
    super.key,
    required this.child,
    this.hoverScale = 1.02,
    this.duration = const Duration(milliseconds: 150),
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<BTHoverScale> createState() => _BTHoverScaleState();
}

class _BTHoverScaleState extends State<BTHoverScale>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = Tween<double>(
      begin: 1.0,
      end: widget.hoverScale,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        _controller.forward();
      },
      onExit: (_) {
        _controller.reverse();
      },
      child: ScaleTransition(scale: _animation, child: widget.child),
    );
  }
}

class BTAnimatedNumber extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final Duration duration;

  const BTAnimatedNumber({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 500),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Text(value.toString(), style: style);
      },
    );
  }
}

class BTPageTransition extends PageRouteBuilder {
  final Widget page;
  final BTTransitionType type;

  BTPageTransition({
    required this.page,
    this.type = BTTransitionType.fadeSlide,
    super.settings,
  }) : super(
         pageBuilder: (context, animation, secondaryAnimation) => page,
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           switch (type) {
             case BTTransitionType.fade:
               return FadeTransition(opacity: animation, child: child);
             case BTTransitionType.slide:
               return SlideTransition(
                 position:
                     Tween<Offset>(
                       begin: const Offset(0.1, 0),
                       end: Offset.zero,
                     ).animate(
                       CurvedAnimation(
                         parent: animation,
                         curve: Curves.easeOutCubic,
                       ),
                     ),
                 child: child,
               );
             case BTTransitionType.fadeSlide:
               return FadeTransition(
                 opacity: CurvedAnimation(
                   parent: animation,
                   curve: Curves.easeOut,
                 ),
                 child: SlideTransition(
                   position:
                       Tween<Offset>(
                         begin: const Offset(0.05, 0),
                         end: Offset.zero,
                       ).animate(
                         CurvedAnimation(
                           parent: animation,
                           curve: Curves.easeOutCubic,
                         ),
                       ),
                   child: child,
                 ),
               );
             case BTTransitionType.scale:
               return ScaleTransition(
                 scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                   CurvedAnimation(
                     parent: animation,
                     curve: Curves.easeOutCubic,
                   ),
                 ),
                 child: FadeTransition(opacity: animation, child: child),
               );
           }
         },
         transitionDuration: BTTheme.animationDurationNormal,
         reverseTransitionDuration: BTTheme.animationDurationFast,
       );
}

enum BTTransitionType { fade, slide, fadeSlide, scale }
