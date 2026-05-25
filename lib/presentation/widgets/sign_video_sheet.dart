import 'package:flutter/material.dart';
import 'package:kumpas/data/signs_catalog.dart';
import 'package:kumpas/theme/app_theme.dart';
import 'package:video_player/video_player.dart';

class SignVideoSheet extends StatefulWidget {
  final Sign sign;
  const SignVideoSheet({super.key, required this.sign});

  static Future<void> show(BuildContext context, Sign sign) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SignVideoSheet(sign: sign),
    );
  }

  @override
  State<SignVideoSheet> createState() => _SignVideoSheetState();
}

class _SignVideoSheetState extends State<SignVideoSheet> {
  late VideoPlayerController _controller;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.sign.videoAsset);
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      _controller.setLooping(true);
      _controller.play();
    }).catchError((e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.borderLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(widget.sign.word,
                      style: AppTypography.titleLarge(context)),
                  const SizedBox(height: 4),
                  Text(
                    widget.sign.pronunciation,
                    style: AppTypography.bodyMedium(context).copyWith(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio:
                          _ready ? _controller.value.aspectRatio : 9 / 16,
                      child: _error != null
                          ? Container(
                              color: Colors.black,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'Could not load video.\n${_error!}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white),
                              ),
                            )
                          : _ready
                              ? Stack(
                                  alignment: Alignment.bottomCenter,
                                  children: [
                                    VideoPlayer(_controller),
                                    VideoProgressIndicator(
                                      _controller,
                                      allowScrubbing: true,
                                      colors: VideoProgressColors(
                                        playedColor: AppColors.primary,
                                        bufferedColor: AppColors.primary
                                            .withValues(alpha: 0.3),
                                        backgroundColor: Colors.black54,
                                      ),
                                    ),
                                  ],
                                )
                              : Container(
                                  color: Colors.black,
                                  alignment: Alignment.center,
                                  child: const CircularProgressIndicator(),
                                ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_ready)
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _controller.value.isPlaying
                                  ? _controller.pause()
                                  : _controller.play();
                            });
                          },
                          icon: Icon(
                            _controller.value.isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_fill,
                            color: AppColors.primary,
                            size: 40,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            _controller.seekTo(Duration.zero);
                            _controller.play();
                          },
                          icon: const Icon(
                            Icons.replay_circle_filled,
                            color: AppColors.primary,
                            size: 36,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
