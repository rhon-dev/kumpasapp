import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:kumpas/models/learning_models.dart';
import 'package:kumpas/presentation/providers/app_state_provider.dart';
import 'package:kumpas/presentation/providers/camera_provider.dart';
import 'package:kumpas/presentation/widgets/camera_feedback_overlay.dart';
import 'package:kumpas/theme/app_theme.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> with WidgetsBindingObserver {
  bool get _isCameraSupported {
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_isCameraSupported) {
      _initializeCamera();
    } else {
      debugPrint('Camera is not supported on this platform.');
    }
  }

  void _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        final frontCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );

        if (mounted) {
          await context.read<CameraProvider>().initializeCamera(frontCamera);
        }
      }
    } catch (e) {
      debugPrint('Error getting cameras: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;

    final cameraProvider = context.read<CameraProvider>();

    switch (state) {
      case AppLifecycleState.resumed:
        if (cameraProvider.isInitialized) {
          cameraProvider.startCameraPreview();
        }
        break;
      case AppLifecycleState.paused:
        cameraProvider.stopCameraPreview();
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AppStateProvider, CameraProvider>(
      builder: (context, appState, cameraProvider, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              // Mode Selector / Content
              if (appState.cameraMode == CameraMode.instruction)
                _buildInstructionMode(context, appState)
              else
                _buildPracticeMode(context, cameraProvider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInstructionMode(
      BuildContext context, AppStateProvider appState) {
    final lessons = appState.currentLessons;
    final selectedLesson = lessons.isNotEmpty ? lessons.first : null;

    if (selectedLesson == null) {
      return const Center(
        child: Text('No lessons available.'),
      );
    }

    return CustomScrollView(
      slivers: [
        // App bar
        SliverAppBar(
          pinned: true,
          title: Text(
            selectedLesson.title,
            style: AppTypography.titleMedium(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {},
            ),
          ],
        ),

        // Content
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Video placeholder
                Container(
                  width: double.infinity,
                  height: 250,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.videocam_outlined,
                        size: 64,
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                      FloatingActionButton(
                        onPressed: () {},
                        backgroundColor: AppColors.primary,
                        child: const Icon(Icons.play_arrow),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Lesson details
                Text(
                  'About This Lesson',
                  style: AppTypography.titleMedium(context),
                ),
                const SizedBox(height: 8),
                Text(
                  selectedLesson.description,
                  style: AppTypography.bodyMedium(context).copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),

                // Keywords
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: selectedLesson.keywords.map((keyword) {
                    return Chip(
                      label: Text(
                        keyword,
                        style: AppTypography.labelSmall(context).copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Start Practice Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (!_isCameraSupported) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Camera practice mode is not supported on macOS.',
                            ),
                          ),
                        );
                        return;
                      }
                      appState.setCameraMode(CameraMode.practice);
                      context.read<CameraProvider>().startCameraPreview();
                    },
                    icon: const Icon(Icons.videocam),
                    label: const Text('Start Practice'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPracticeMode(
      BuildContext context, CameraProvider cameraProvider) {
    if (!cameraProvider.isInitialized ||
        cameraProvider.cameraController == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final controller = cameraProvider.cameraController!;
    final screenSize = MediaQuery.of(context).size;
    final cameraAspectRatio = controller.value.aspectRatio;

    return Stack(
      children: [
        // Camera preview
        Container(
          color: Colors.black,
          child: Center(
            child: Transform.scale(
              scale: screenSize.width / (screenSize.height * cameraAspectRatio),
              child: CameraPreview(controller),
            ),
          ),
        ),

        // AI Feedback Overlay
        IgnorePointer(
          child: SizedBox(
            width: screenSize.width,
            height: screenSize.height,
            child: CameraFeedbackOverlay(
              frameSize: Size(screenSize.width, screenSize.height),
              showLandmarks: true,
              showFeedback: true,
            ),
          ),
        ),

        // Top Controls and Info
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      onPressed: () {
                        context.read<CameraProvider>().stopCameraPreview();
                        context
                            .read<AppStateProvider>()
                            .setCameraMode(CameraMode.instruction);
                      },
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'PRACTICE MODE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.settings_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Bottom Controls
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Container(
              color: Colors.black.withValues(alpha: 0.3),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Confidence meter
                  Container(
                    width: double.infinity,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: LinearProgressIndicator(
                      value: 0.65,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildActionIcon(
                        icon: Icons.redo,
                        label: 'Redo',
                        onTap: () {},
                      ),
                      _buildActionIcon(
                        icon: Icons.pause_circle_outline,
                        label: 'Pause',
                        onTap: () {},
                      ),
                      _buildActionIcon(
                        icon: Icons.check_circle_outline,
                        label: 'Done',
                        onTap: () {
                          _showCompletionDialog(context);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionIcon({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showCompletionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Great job!'),
        content: const Text('You\'ve completed this practice session.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<CameraProvider>().stopCameraPreview();
              context
                  .read<AppStateProvider>()
                  .setCameraMode(CameraMode.instruction);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
