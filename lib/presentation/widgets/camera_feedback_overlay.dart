import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kumpas/models/learning_models.dart';
import 'package:kumpas/presentation/providers/camera_provider.dart';
import 'package:kumpas/theme/app_theme.dart';

/// Overlay widget for MediaPipe landmarks and AI feedback visualization
class CameraFeedbackOverlay extends StatelessWidget {
  final Size frameSize;
  final bool showLandmarks;
  final bool showFeedback;

  const CameraFeedbackOverlay({
    super.key,
    required this.frameSize,
    this.showLandmarks = true,
    this.showFeedback = true,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<CameraProvider>(
      builder: (context, cameraProvider, _) {
        return Stack(
          children: [
            // Custom Paint for MediaPipe landmarks
            if (showLandmarks && cameraProvider.currentLandmarks.isNotEmpty)
              CustomPaint(
                painter: LandmarksPainter(
                  landmarks: cameraProvider.currentLandmarks,
                  frameSize: frameSize,
                ),
                size: frameSize,
              ),

            // Feedback overlay - top of screen
            if (showFeedback && cameraProvider.activeFeedbacks.isNotEmpty)
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Column(
                  children: cameraProvider.activeFeedbacks.map((feedback) {
                    return FeedbackBanner(feedback: feedback);
                  }).toList(),
                ),
              ),

            // Recording indicator
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Recording',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Corner guides
            Positioned(
              top: 0,
              left: 0,
              child: _buildCornerGuide(),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Transform.rotate(
                angle: 1.57, // 90 degrees
                child: _buildCornerGuide(),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              child: Transform.rotate(
                angle: -1.57, // -90 degrees
                child: _buildCornerGuide(),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Transform.rotate(
                angle: 3.14, // 180 degrees
                child: _buildCornerGuide(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCornerGuide() {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.7),
            width: 3,
          ),
          left: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.7),
            width: 3,
          ),
        ),
      ),
    );
  }
}

/// Custom painter for drawing MediaPipe landmarks
class LandmarksPainter extends CustomPainter {
  final List<PoseLandmark> landmarks;
  final Size frameSize;

  LandmarksPainter({
    required this.landmarks,
    required this.frameSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw landmark circles
    for (final landmark in landmarks) {
      final x = landmark.x * size.width;
      final y = landmark.y * size.height;
      final visibility = landmark.visibility ?? 0.8;

      if (visibility > 0.5) {
        // Draw circle for joint
        canvas.drawCircle(
          Offset(x, y),
          8,
          Paint()
            ..color = AppColors.primary.withValues(alpha: visibility)
            ..style = PaintingStyle.fill,
        );

        // Draw border
        canvas.drawCircle(
          Offset(x, y),
          8,
          Paint()
            ..color = Colors.white.withValues(alpha: visibility)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }

    // Draw connections between landmarks (skeleton)
    _drawSkeletonConnections(canvas, size);
  }

  void _drawSkeletonConnections(Canvas canvas, Size size) {
    const connections = [
      ('left_shoulder', 'left_elbow'),
      ('left_elbow', 'left_wrist'),
      ('right_shoulder', 'right_elbow'),
      ('right_elbow', 'right_wrist'),
      ('left_shoulder', 'right_shoulder'),
    ];

    for (final connection in connections) {
      final from = landmarks.firstWhere(
        (l) => l.name == connection.$1,
        orElse: () => const PoseLandmark(
          name: 'none',
          x: 0,
          y: 0,
          visibility: 0,
        ),
      );

      final to = landmarks.firstWhere(
        (l) => l.name == connection.$2,
        orElse: () => const PoseLandmark(
          name: 'none',
          x: 0,
          y: 0,
          visibility: 0,
        ),
      );

      if (from.name != 'none' && to.name != 'none') {
        final fromVisibility = from.visibility ?? 0;
        final toVisibility = to.visibility ?? 0;

        if (fromVisibility > 0.5 && toVisibility > 0.5) {
          canvas.drawLine(
            Offset(from.x * size.width, from.y * size.height),
            Offset(to.x * size.width, to.y * size.height),
            Paint()
              ..color = AppColors.primary.withValues(alpha: 0.6)
              ..strokeWidth = 3,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(LandmarksPainter oldDelegate) {
    return oldDelegate.landmarks != landmarks;
  }
}

/// Feedback banner widget
class FeedbackBanner extends StatefulWidget {
  final AIFeedback feedback;

  const FeedbackBanner({
    super.key,
    required this.feedback,
  });

  @override
  State<FeedbackBanner> createState() => _FeedbackBannerState();
}

class _FeedbackBannerState extends State<FeedbackBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _getFeedbackColor(widget.feedback.type);
    final icon = _getFeedbackIcon(widget.feedback.type);

    return ScaleTransition(
      scale: _animation,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: backgroundColor.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: backgroundColor,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: backgroundColor.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.feedback.message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(widget.feedback.confidence * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getFeedbackColor(String type) {
    switch (type) {
      case 'correction':
        return AppColors.warning;
      case 'encouragement':
        return AppColors.success;
      case 'tip':
        return AppColors.primary;
      default:
        return AppColors.secondary;
    }
  }

  IconData _getFeedbackIcon(String type) {
    switch (type) {
      case 'correction':
        return Icons.info_outline;
      case 'encouragement':
        return Icons.thumb_up;
      case 'tip':
        return Icons.lightbulb_outline;
      default:
        return Icons.campaign_outlined;
    }
  }
}
