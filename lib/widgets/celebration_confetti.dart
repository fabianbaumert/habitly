import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

class CelebrationConfetti extends StatefulWidget {
  final bool show;
  final VoidCallback? onCompleted;
  const CelebrationConfetti({Key? key, required this.show, this.onCompleted}) : super(key: key);

  @override
  State<CelebrationConfetti> createState() => _CelebrationConfettiState();
}

class _CelebrationConfettiState extends State<CelebrationConfetti> {
  late ConfettiController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ConfettiController(duration: const Duration(seconds: 2));
    if (widget.show) {
      _controller.play();
    }
  }

  @override
  void didUpdateWidget(covariant CelebrationConfetti oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.show && !oldWidget.show) {
      _controller.play();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.show) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.topCenter,
      child: ConfettiWidget(
        confettiController: _controller,
        blastDirectionality: BlastDirectionality.explosive,
        shouldLoop: false,
        numberOfParticles: 10, // Reduced number of particles
        maxBlastForce: 15,  // Slightly reduced force
        minBlastForce: 8,
        emissionFrequency: 0.08,
        gravity: 0.3,
        colors: const [
          Colors.green,
          Colors.blue,
          Colors.pink,
          Colors.orange,
          Colors.purple,
          Colors.yellow,
        ],
      ),
    );
  }
}
