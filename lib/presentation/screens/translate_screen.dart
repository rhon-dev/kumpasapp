import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:kumpas/data/signs_catalog.dart';
import 'package:kumpas/presentation/providers/camera_provider.dart';
import 'package:kumpas/presentation/widgets/camera_feedback_overlay.dart';
import 'package:kumpas/presentation/widgets/sign_video_sheet.dart';
import 'package:kumpas/presentation/screens/gesture_recognition_screen.dart';
import 'package:kumpas/theme/app_theme.dart';
import 'package:kumpas/utils/fuzzy_search.dart';

class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen>
    with WidgetsBindingObserver {
  bool _isTranslating = false;
  String _translatedText = '';

  bool get _isCameraSupported {
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
        if (_isTranslating && cameraProvider.isInitialized) {
          cameraProvider.startCameraPreview();
        }
        break;
      case AppLifecycleState.paused:
        if (_isTranslating) {
          cameraProvider.stopCameraPreview();
        }
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CameraProvider>(
      builder: (context, cameraProvider, _) {
        if (!_isTranslating) {
          return _buildSelectionMode(context, cameraProvider);
        }

        if (!cameraProvider.isInitialized ||
            cameraProvider.cameraController == null) {
          return Container(
            color: Colors.black,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return _buildTranslateMode(context, cameraProvider);
      },
    );
  }

  Widget _buildSelectionMode(
    BuildContext context,
    CameraProvider cameraProvider,
  ) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Translate'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Translate Filipino Sign Language',
                style: AppTypography.headlineMedium(context),
              ),
              const SizedBox(height: 8),
              Text(
                'Convert sign language to text or text to sign in real-time',
                style: AppTypography.bodyMedium(context).copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),

              // Mode Selection Cards
              _buildTranslationModeCard(
                context: context,
                title: 'Gesture Recognition',
                description:
                    'Real-time hand gesture recognition with AI feedback',
                icon: Icons.pan_tool_outlined,
                color: const Color(0xFF9C27B0),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const GestureRecognitionScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildTranslationModeCard(
                context: context,
                title: 'Text to Sign',
                description: 'Type text and see how to sign it',
                icon: Icons.keyboard_outlined,
                color: AppColors.secondary,
                onTap: () {
                  _showTextToSignSheet(context);
                },
              ),
              const SizedBox(height: 32),

              // Quick Phrases
              Text(
                'Quick Phrases',
                style: AppTypography.titleMedium(context),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  'Hello',
                  'Thank You',
                  'Good Morning',
                  'How Are You',
                  'Yes',
                  'No',
                ]
                    .map(
                      (phrase) => ActionChip(
                        onPressed: () {
                          final sign = bestSignMatch(phrase);
                          if (sign != null) {
                            SignVideoSheet.show(context, sign);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('No sign for $phrase')),
                            );
                          }
                        },
                        label: Text(phrase),
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        labelStyle: AppTypography.labelMedium(context).copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTranslationModeCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.titleMedium(context),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: AppTypography.bodySmall(context).copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: color, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _initializeAndStartTranslate(
      CameraProvider cameraProvider) async {
    if (!_isCameraSupported) {
      debugPrint('Camera translation is not supported on this platform.');
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        final frontCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );

        if (mounted) {
          await cameraProvider.initializeCamera(frontCamera);
          setState(() {
            _isTranslating = true;
            _translatedText = '';
          });
          await cameraProvider.startCameraPreview();
        }
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Widget _buildTranslateMode(
    BuildContext context,
    CameraProvider cameraProvider,
  ) {
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

        // AI Overlay
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

        // Top Bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      onPressed: () async {
                        await cameraProvider.stopCameraPreview();
                        if (mounted) {
                          setState(() => _isTranslating = false);
                        }
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
                      'LIVE TRANSLATION',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
          ),
        ),

        // Translation Result Overlay
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Container(
              color: Colors.black.withValues(alpha: 0.6),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detected Sign',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.5),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _translatedText.isEmpty
                          ? 'Waiting for sign...'
                          : _translatedText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showTextToSignSheet(BuildContext context, {String? initialQuery}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TextToSignSheet(initialQuery: initialQuery ?? ''),
    );
  }
}

class _TextToSignSheet extends StatefulWidget {
  final String initialQuery;
  const _TextToSignSheet({required this.initialQuery});

  @override
  State<_TextToSignSheet> createState() => _TextToSignSheetState();
}

class _TextToSignSheetState extends State<_TextToSignSheet> {
  late final TextEditingController _controller;
  late List<SignScore> _results;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _results = searchSigns(widget.initialQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() => _results = searchSigns(value));
  }

  void _openSign(Sign sign) {
    Navigator.of(context).pop();
    SignVideoSheet.show(context, sign);
  }

  void _onSubmit(String value) {
    final best = bestSignMatch(value);
    if (best != null) {
      _openSign(best);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No sign found for "$value"')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Padding(
          padding: EdgeInsets.only(bottom: viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Text to Sign',
                          style: AppTypography.titleLarge(context)),
                      const SizedBox(height: 4),
                      Text(
                        'Type a word — spelling and capitalization don\'t matter.',
                        style: AppTypography.bodySmall(context).copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _controller,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        textCapitalization: TextCapitalization.none,
                        onChanged: _onChanged,
                        onSubmitted: _onSubmit,
                        decoration: InputDecoration(
                          hintText: 'e.g. salamat, helo, mngdng umaga',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _controller.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _controller.clear();
                                    _onChanged('');
                                  },
                                ),
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppColors.borderLight,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppColors.borderLight,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _buildResults(scrollController),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResults(ScrollController scrollController) {
    if (_controller.text.trim().isEmpty) {
      return ListView(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Text('Browse all signs',
              style: AppTypography.labelMedium(context).copyWith(
                color: AppColors.textSecondary,
              )),
          const SizedBox(height: 8),
          ...kSignCatalog.map((s) => _resultTile(s, null)),
        ],
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off, size: 48, color: AppColors.disabled),
              const SizedBox(height: 12),
              Text('No close match found',
                  style: AppTypography.bodyMedium(context).copyWith(
                    color: AppColors.textSecondary,
                  )),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _results.length,
      itemBuilder: (_, i) {
        final r = _results[i];
        return _resultTile(r.sign, r.score, isTop: i == 0);
      },
    );
  }

  Widget _resultTile(Sign sign, double? score, {bool isTop = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _openSign(sign),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isTop
                ? AppColors.primary.withValues(alpha: 0.08)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isTop
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : AppColors.borderLight,
              width: isTop ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.play_arrow,
                    color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(sign.word,
                              style: AppTypography.titleMedium(context)),
                        ),
                        if (isTop && score != null && score < 0.99)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Did you mean?',
                              style: AppTypography.labelSmall(context).copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      '${sign.pronunciation}  •  ${sign.category}',
                      style: AppTypography.labelSmall(context).copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
