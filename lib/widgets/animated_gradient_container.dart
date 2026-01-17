import 'package:flutter/material.dart';

class AnimatedGradientContainer extends StatefulWidget {
  final Widget child;
  final List<Color> colors;
  final Duration duration;
  final double height;
  final double width;
  final BorderRadius? borderRadius;

  const AnimatedGradientContainer({
    Key? key,
    required this.child,
    this.colors = const [
      Color(0xFF4285F4), // Google Blue
      Color(0xFF34A853), // Google Green
      Color(0xFFEA4335), // Google Red
      Color(0xFFFBBC05), // Google Yellow
      Color(0xFF4285F4), // Back to blue for seamless loop
    ],
    this.duration = const Duration(seconds: 8),
    this.height = double.infinity,
    this.width = double.infinity,
    this.borderRadius,
  }) : super(key: key);

  @override
  _AnimatedGradientContainerState createState() =>
      _AnimatedGradientContainerState();
}

class _AnimatedGradientContainerState extends State<AnimatedGradientContainer>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
    );
    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                (_animation.value - 0.3).clamp(0.0, 1.0),
                (_animation.value - 0.2).clamp(0.0, 1.0),
                (_animation.value - 0.1).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.1).clamp(0.0, 1.0),
                (_animation.value + 0.2).clamp(0.0, 1.0),
                (_animation.value + 0.3).clamp(0.0, 1.0),
              ],
              colors: [
                widget.colors[0],
                widget.colors[1],
                widget.colors[2],
                widget.colors[3],
                widget.colors[2],
                widget.colors[1],
                widget.colors[0],
              ],
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}

class ProfessionalAnimatedGradient extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double height;
  final double width;
  final BorderRadius? borderRadius;

  const ProfessionalAnimatedGradient({
    Key? key,
    required this.child,
    this.duration = const Duration(seconds: 10),
    this.height = double.infinity,
    this.width = double.infinity,
    this.borderRadius,
  }) : super(key: key);

  @override
  _ProfessionalAnimatedGradientState createState() =>
      _ProfessionalAnimatedGradientState();
}

class _ProfessionalAnimatedGradientState
    extends State<ProfessionalAnimatedGradient> with TickerProviderStateMixin {
  late AnimationController _controller1;
  late AnimationController _controller2;
  late AnimationController _controller3;
  late Animation<double> _animation1;
  late Animation<double> _animation2;
  late Animation<double> _animation3;

  @override
  void initState() {
    super.initState();

    // Multiple controllers for floating shapes effect like Shiftly
    _controller1 = AnimationController(
      duration: const Duration(seconds: 20), // Slow like Shiftly
      vsync: this,
    );
    _controller2 = AnimationController(
      duration:
          const Duration(seconds: 15), // Different speeds for organic feel
      vsync: this,
    );
    _controller3 = AnimationController(
      duration: const Duration(seconds: 25), // Even slower
      vsync: this,
    );

    _animation1 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller1, curve: Curves.easeInOut),
    );
    _animation2 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller2, curve: Curves.easeInOut),
    );
    _animation3 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller3, curve: Curves.easeInOut),
    );

    // Start animations with delays for more organic movement
    _controller1.repeat(reverse: true);
    _controller2.repeat(reverse: true);
    _controller3.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller1.dispose();
    _controller2.dispose();
    _controller3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_animation1, _animation2, _animation3]),
      builder: (context, child) {
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            // Base subtle gradient - very light
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFDAE2F0), // Soft blue-grey
                const Color(0xFFE5E9F0), // Light grey-blue
                const Color(0xFFD4DDE9), // Subtle blue tint
                const Color(0xFFE0E5ED), // Light blue-grey
              ],
              stops: const [0.0, 0.3, 0.7, 1.0],
            ),
          ),
          child: Stack(
            children: [
              // First floating shape - soft vibrant purple
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.lerp(
                        const Alignment(-0.6, 0.6),
                        const Alignment(-0.4, 0.8),
                        _animation1.value,
                      )!,
                      radius: 1.2 + (_animation1.value * 0.3),
                      colors: [
                        const Color(0xFFD5C4F7)
                            .withOpacity(0.35), // Vibrant light purple
                        const Color(0xFFE3D5FF).withOpacity(0.20),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),

              // Second floating shape - soft vibrant blue
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.lerp(
                        const Alignment(0.6, -0.6),
                        const Alignment(0.4, -0.8),
                        _animation2.value,
                      )!,
                      radius: 1.0 + (_animation2.value * 0.4),
                      colors: [
                        const Color(0xFFB8D4F7)
                            .withOpacity(0.40), // Vibrant light blue
                        const Color(0xFFCFE2FF).withOpacity(0.22),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),

              // Third floating shape - soft vibrant pink
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.lerp(
                        const Alignment(-0.2, -0.2),
                        const Alignment(0.2, 0.2),
                        _animation3.value,
                      )!,
                      radius: 0.8 + (_animation3.value * 0.5),
                      colors: [
                        const Color(0xFFF7C4D8)
                            .withOpacity(0.30), // Vibrant light pink
                        const Color(0xFFFFD5E8).withOpacity(0.18),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),

              // Base gradient background - very subtle
              Container(
                decoration: BoxDecoration(
                  borderRadius: widget.borderRadius,
                  gradient: LinearGradient(
                    begin: Alignment.lerp(
                      Alignment.topLeft,
                      Alignment.centerLeft,
                      _animation1.value * 0.2, // Even more subtle movement
                    )!,
                    end: Alignment.lerp(
                      Alignment.bottomRight,
                      Alignment.centerRight,
                      _animation1.value * 0.2,
                    )!,
                    colors: [
                      Colors.white.withOpacity(0.95),
                      const Color(0xFFF8F9FA).withOpacity(0.9), // Light gray
                      const Color(0xFFE3F2FD).withOpacity(0.85), // Light blue
                      Colors.white.withOpacity(0.9),
                    ],
                    stops: const [0.0, 0.3, 0.7, 1.0],
                  ),
                ),
              ),

              // Content
              widget.child,
            ],
          ),
        );
      },
    );
  }
}
