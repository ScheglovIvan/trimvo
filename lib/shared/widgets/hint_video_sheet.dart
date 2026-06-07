import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:trimvo/core/theme/app_colors.dart';

Future<void> showHintVideoSheet(BuildContext context, String assetPath) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _HintVideoSheet(assetPath: assetPath),
  );
}

class _HintVideoSheet extends StatefulWidget {
  const _HintVideoSheet({required this.assetPath});

  final String assetPath;

  @override
  State<_HintVideoSheet> createState() => _HintVideoSheetState();
}

class _HintVideoSheetState extends State<_HintVideoSheet>
    with WidgetsBindingObserver {
  VideoPlayerController? _ctrl;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initVideo();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _ctrl?.pause();
    } else if (state == AppLifecycleState.resumed) {
      _ctrl?.play();
    }
  }

  Future<void> _initVideo() async {
    try {
      final ctrl = VideoPlayerController.asset(widget.assetPath);
      await ctrl.initialize();
      if (!mounted) { ctrl.dispose(); return; }
      await ctrl.setLooping(true);
      await ctrl.play();
      if (mounted) {
        setState(() {
          _ctrl = ctrl;
          _ready = true;
        });
      } else {
        ctrl.pause();
        ctrl.dispose();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctrl?.pause();
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.of(context).size.height * 0.80;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SizedBox(
        height: sheetHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_ready && _ctrl != null)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _ctrl!.value.size.width,
                  height: _ctrl!.value.size.height,
                  child: VideoPlayer(_ctrl!),
                ),
              )
            else
              const ColoredBox(
                color: Colors.black,
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.accentPurpleLight,
                    strokeWidth: 2,
                  ),
                ),
              ),
            Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundPrimary.withOpacity(0.72),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: AppColors.textPrimary,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
