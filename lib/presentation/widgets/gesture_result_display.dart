import 'package:flutter/material.dart';
import 'package:kumpas/theme/app_theme.dart';

class GestureResult {
  final String sign;
  final double confidence; // always 0–1 scale
  final Map<String, double> probabilities;
  final String? warning;
  final DateTime timestamp;

  GestureResult({
    required this.sign,
    required this.confidence,
    required this.probabilities,
    this.warning,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  double get confidencePercent => (confidence.clamp(0.0, 1.0)) * 100;

  bool get isHighConfidence => confidencePercent >= 70;

  Color getConfidenceColor() {
    if (confidencePercent >= 70) return AppColors.confidenceHigh;
    if (confidencePercent >= 40) return AppColors.confidenceMedium;
    return AppColors.confidenceLow;
  }

  String getConfidenceLabel() {
    if (confidencePercent >= 70) return 'High confidence';
    if (confidencePercent >= 40) return 'Medium confidence';
    return 'Low confidence — try again';
  }
}

class GestureResultDisplay extends StatefulWidget {
  final GestureResult? result;
  final bool isProcessing;
  final String? errorMessage;
  final VoidCallback onDismiss;

  const GestureResultDisplay({
    super.key,
    this.result,
    this.isProcessing = false,
    this.errorMessage,
    required this.onDismiss,
  });

  @override
  State<GestureResultDisplay> createState() => _GestureResultDisplayState();
}

class _GestureResultDisplayState extends State<GestureResultDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  @override
  void didUpdateWidget(GestureResultDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result != widget.result && widget.result != null) {
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.errorMessage != null) return _buildErrorDisplay();
    if (widget.isProcessing) return _buildProcessingDisplay();
    if (widget.result == null) return _buildEmptyDisplay();
    return _buildResultDisplay();
  }

  Widget _buildErrorDisplay() {
    return _StateCard(
      color: AppColors.errorLight,
      borderColor: AppColors.error.withValues(alpha: 0.3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.wifi_off_rounded,
                color: AppColors.error, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Could not reach AI model',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Make sure the backend server is running and try again.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppColors.error.withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: widget.onDismiss,
            child: const Icon(Icons.close, color: AppColors.error, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingDisplay() {
    return _StateCard(
      color: AppColors.secondaryLight,
      borderColor: AppColors.secondary.withValues(alpha: 0.2),
      child: const Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
            ),
          ),
          SizedBox(width: 12),
          Text(
            'Analyzing gesture…',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDisplay() {
    return const _StateCard(
      color: AppColors.surface,
      borderColor: AppColors.borderLight,
      child: Column(
        children: [
          Icon(Icons.back_hand_outlined, size: 32, color: AppColors.textHint),
          SizedBox(height: 10),
          Text(
            'Show your hand to the camera',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Hold a sign clearly in frame and tap Capture',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: AppColors.textHint,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultDisplay() {
    final result = widget.result!;
    final confidenceColor = result.getConfidenceColor();
    final confidenceLabel = result.getConfidenceLabel();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'RECOGNIZED SIGN',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: widget.onDismiss,
                    child: const Icon(Icons.close,
                        color: AppColors.textHint, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Sign name — large and prominent
              Text(
                result.sign.toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Confidence bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    confidenceLabel,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: confidenceColor,
                    ),
                  ),
                  Text(
                    '${result.confidencePercent.toStringAsFixed(0)}%',
                    style: AppTypography.monoMedium.copyWith(
                      color: confidenceColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  // FIX: was result.confidence / 100 — now uses normalized getter
                  value: result.confidence.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: AppColors.borderLight,
                  valueColor: AlwaysStoppedAnimation<Color>(confidenceColor),
                ),
              ),

              if (result.warning != null) ...[
                const SizedBox(height: 12),
                _WarningChip(message: result.warning!),
              ],

              if (result.probabilities.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Other possibilities',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                ..._buildProbabilityBars(result.probabilities),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildProbabilityBars(Map<String, double> probabilities) {
    final sorted = probabilities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(4);

    return top.map((entry) {
      final probability = entry.value.clamp(0.0, 1.0);
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(
                entry.key,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: probability,
                  minHeight: 6,
                  backgroundColor: AppColors.borderLight,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color.lerp(
                      AppColors.confidenceLow,
                      AppColors.confidenceHigh,
                      probability,
                    )!,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 36,
              child: Text(
                '${(probability * 100).toStringAsFixed(0)}%',
                textAlign: TextAlign.right,
                style: AppTypography.monoMedium.copyWith(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

class _StateCard extends StatelessWidget {
  final Color color;
  final Color borderColor;
  final Widget child;

  const _StateCard({
    required this.color,
    required this.borderColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

class _WarningChip extends StatelessWidget {
  final String message;
  const _WarningChip({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 15, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: AppColors.warning,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
