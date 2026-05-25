import 'package:flutter/material.dart';

/// Model for a single hand joint
class HandJoint {
  final Offset position; // 0.0 - 1.0 normalized coordinates
  final String name;
  final double confidence; // 0.0 - 1.0

  HandJoint({
    required this.position,
    required this.name,
    this.confidence = 1.0,
  });
}

/// Model for hand skeleton structure
class HandSkeleton {
  final List<HandJoint> joints;

  HandSkeleton({required this.joints});

  /// Get connection lines between joints (finger structure)
  /// 20 joints total: 1 wrist + 4 fingers * 4 bones each
  static List<(int, int)> getConnections() => [
        // Thumb (0-4)
        (0, 1), (1, 2), (2, 3), (3, 4),
        // Index (0, 5-8)
        (0, 5), (5, 6), (6, 7), (7, 8),
        // Middle (0, 9-12)
        (0, 9), (9, 10), (10, 11), (11, 12),
        // Ring (0, 13-16)
        (0, 13), (13, 14), (14, 15), (15, 16),
        // Pinky (0, 17-20)
        (0, 17), (17, 18), (18, 19), (19, 20),
      ];
}

/// CustomPaint painter for drawing hand joints and skeleton
class HandJointPainter extends CustomPainter {
  final HandSkeleton? skeleton;
  final Color jointColor;
  final Color lineColor;
  final double jointRadius;
  final double lineWidth;
  final bool showLabels;

  HandJointPainter({
    this.skeleton,
    this.jointColor = Colors.blue,
    this.lineColor = Colors.white,
    this.jointRadius = 6.0,
    this.lineWidth = 2.0,
    this.showLabels = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (skeleton == null || skeleton!.joints.isEmpty) {
      return;
    }

    // Draw connection lines first (so they appear behind joints)
    _drawConnections(canvas, size);

    // Draw joints
    _drawJoints(canvas, size);

    // Draw labels if enabled
    if (showLabels) {
      _drawLabels(canvas, size);
    }
  }

  /// Draw connection lines between joints
  void _drawConnections(Canvas canvas, Size size) {
    final connections = HandSkeleton.getConnections();
    final joints = skeleton!.joints;

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final (startIdx, endIdx) in connections) {
      if (startIdx < joints.length && endIdx < joints.length) {
        final start = joints[startIdx];
        final end = joints[endIdx];

        // Convert normalized coordinates to canvas coordinates
        final startOffset = Offset(
          start.position.dx * size.width,
          start.position.dy * size.height,
        );
        final endOffset = Offset(
          end.position.dx * size.width,
          end.position.dy * size.height,
        );

        // Use confidence to adjust opacity
        final opacity =
            ((start.confidence + end.confidence) / 2.0).clamp(0.3, 1.0);
        linePaint.color = lineColor.withValues(alpha: opacity);

        canvas.drawLine(startOffset, endOffset, linePaint);
      }
    }
  }

  /// Draw individual joints as circles
  void _drawJoints(Canvas canvas, Size size) {
    final jointPaint = Paint()..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white;

    for (final joint in skeleton!.joints) {
      final offset = Offset(
        joint.position.dx * size.width,
        joint.position.dy * size.height,
      );

      // Use confidence to adjust joint appearance
      final opacity = joint.confidence.clamp(0.3, 1.0);
      jointPaint.color = jointColor.withValues(alpha: opacity);

      // Draw filled circle
      canvas.drawCircle(offset, jointRadius, jointPaint);

      // Draw border
      canvas.drawCircle(offset, jointRadius, borderPaint);
    }
  }

  /// Draw joint labels
  void _drawLabels(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    const textStyle = TextStyle(
      color: Colors.white,
      fontSize: 10,
      fontWeight: FontWeight.w500,
      backgroundColor: Color.fromARGB(200, 0, 0, 0),
    );

    for (final joint in skeleton!.joints) {
      final offset = Offset(
        joint.position.dx * size.width + jointRadius + 4,
        joint.position.dy * size.height - 8,
      );

      textPainter.text = TextSpan(
        text: joint.name,
        style: textStyle,
      );
      textPainter.layout();
      textPainter.paint(canvas, offset);
    }
  }

  @override
  bool shouldRepaint(HandJointPainter oldDelegate) {
    return oldDelegate.skeleton != skeleton ||
        oldDelegate.jointColor != jointColor ||
        oldDelegate.lineColor != lineColor;
  }
}

/// Widget for displaying hand joints overlay on camera feed
class HandJointOverlay extends StatelessWidget {
  final HandSkeleton? skeleton;
  final Color jointColor;
  final Color lineColor;
  final double jointRadius;
  final bool showLabels;

  const HandJointOverlay({
    super.key,
    required this.skeleton,
    this.jointColor = Colors.blue,
    this.lineColor = Colors.white,
    this.jointRadius = 6.0,
    this.showLabels = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: HandJointPainter(
        skeleton: skeleton,
        jointColor: jointColor,
        lineColor: lineColor,
        jointRadius: jointRadius,
        showLabels: showLabels,
      ),
      isComplex: true,
      willChange: true,
    );
  }
}
