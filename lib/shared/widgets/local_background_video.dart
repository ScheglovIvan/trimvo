import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:trimvo/core/theme/app_colors.dart';

class LocalBackgroundVideo extends StatefulWidget {
  const LocalBackgroundVideo({
    super.key,
    this.assetPath = 'assets/videos/welcome.mp4',
  });

  final String assetPath;

  @override
  State<LocalBackgroundVideo> createState() => _LocalBackgroundVideoState();
}

class _LocalBackgroundVideoState extends State<LocalBackgroundVideo>
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
      if (_ready) _ctrl?.play();
    }
  }

  Future<void> _initVideo() async {
    try {
      final ctrl = VideoPlayerController.asset(
        widget.assetPath,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.setVolume(0);
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
  void deactivate() {
    _ctrl?.pause();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    if (_ready) _ctrl?.play();
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
    if (!_ready || _ctrl == null) {
      return const ColoredBox(color: AppColors.backgroundPrimary);
    }
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _ctrl!.value.size.width,
          height: _ctrl!.value.size.height,
          child: VideoPlayer(_ctrl!),
        ),
      ),
    );
  }
}
