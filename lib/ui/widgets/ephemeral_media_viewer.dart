import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import '../theme.dart';

class EphemeralMediaViewer extends StatefulWidget {
  final Uint8List mediaBytes;
  final int durationSeconds;
  final bool isVideo;
  final VoidCallback onBurn;

  const EphemeralMediaViewer({
    Key? key,
    required this.mediaBytes,
    required this.durationSeconds,
    this.isVideo = false,
    required this.onBurn,
  }) : super(key: key);

  @override
  State<EphemeralMediaViewer> createState() => _EphemeralMediaViewerState();
}

class _EphemeralMediaViewerState extends State<EphemeralMediaViewer> {
  late int _remainingSeconds;
  Timer? _countdownTimer;
  VideoPlayerController? _videoController;
  String? _tempVideoPath;
  bool _isBurning = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.durationSeconds;
    
    if (widget.isVideo) {
      _initVideo();
    } else {
      _startCountdown();
    }
  }

  Future<void> _initVideo() async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/zka_ram_${DateTime.now().millisecondsSinceEpoch}.mp4');
    await file.writeAsBytes(widget.mediaBytes);
    _tempVideoPath = file.path;

    _videoController = VideoPlayerController.file(file)
      ..initialize().then((_) {
        if (mounted) setState(() {});
        _videoController!.play();
        _videoController!.addListener(() {
          if (_videoController!.value.isInitialized &&
              !_videoController!.value.isPlaying &&
              _videoController!.value.position >= _videoController!.value.duration) {
            
            if (widget.durationSeconds != 0) {
              _burnAndClose();
            }
          }
        });
      });
  }

  void _startCountdown() {
    if (_remainingSeconds <= 0) return;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _remainingSeconds--;
      });

      if (_remainingSeconds <= 0) {
        timer.cancel();
        _burnAndClose();
      }
    });
  }

  void _burnAndClose() async {
    if (_isBurning) return;
    _isBurning = true;

    widget.onBurn();
    if (_tempVideoPath != null) {
      final file = File(_tempVideoPath!);
      if (await file.exists()) await file.delete();
    }
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _videoController?.dispose();
    if (!_isBurning && widget.durationSeconds != 0) {
      _burnAndClose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.isVideo)
              _videoController != null && _videoController!.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: VideoPlayer(_videoController!),
                    )
                  : const CircularProgressIndicator(color: VinkiarColors.vertigoGold)
            else
              Image.memory(
                widget.mediaBytes,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
              ),
            
            if (!widget.isVideo && widget.durationSeconds > 0)
              Positioned(
                top: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: VinkiarColors.panicRed.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: VinkiarColors.vertigoGold),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_fire_department, color: VinkiarColors.vertigoGold, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "$_remainingSeconds s",
                        style: GoogleFonts.jetBrainsMono(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}