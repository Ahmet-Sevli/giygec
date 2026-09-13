import 'package:flutter/material.dart';
import '../core/theme.dart';

class NfcScanAnimation extends StatefulWidget {
  final bool isScanning;
  final VoidCallback onTap;

  const NfcScanAnimation({
    super.key,
    required this.isScanning,
    required this.onTap,
  });

  @override
  State<NfcScanAnimation> createState() => _NfcScanAnimationState();
}

class _NfcScanAnimationState extends State<NfcScanAnimation>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseAnimation, _rotateController]),
        builder: (context, child) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glow ring
                  Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            DepoTheme.primaryColor.withOpacity(
                              widget.isScanning ? 0.3 : 0.1,
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Rotating border
                  Transform.rotate(
                    angle: _rotateController.value * 6.28,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [
                            DepoTheme.primaryColor.withOpacity(0.0),
                            DepoTheme.primaryColor.withOpacity(0.5),
                            DepoTheme.primaryLight.withOpacity(0.8),
                            DepoTheme.primaryColor.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Inner circle
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: DepoTheme.cardBg,
                      boxShadow: [
                        BoxShadow(
                          color: DepoTheme.primaryColor.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.isScanning ? Icons.contactless : Icons.nfc,
                      size: 52,
                      color: widget.isScanning
                          ? DepoTheme.primaryLight
                          : DepoTheme.textSecondary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Status text
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  widget.isScanning
                      ? 'NFC etiketini okutun...'
                      : 'Taramayı başlatmak için dokunun',
                  key: ValueKey(widget.isScanning),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: widget.isScanning
                        ? DepoTheme.primaryLight
                        : DepoTheme.textSecondary,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
