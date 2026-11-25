import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../theme.dart';

class EphemeralAudioPlayer extends StatefulWidget {
  final String base64Audio;
  final bool isPermanent;
  final VoidCallback onBurn;

  const EphemeralAudioPlayer({
    Key? key,
    required this.base64Audio,
    this.isPermanent = false,
    required this.onBurn,
  }) : super(key: key);

  @override
  State<EphemeralAudioPlayer> createState() => _EphemeralAudioPlayerState();
}

class _EphemeralAudioPlayerState extends State<EphemeralAudioPlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _hasPlayed = false;
  String? _tempFilePath;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.completed) {
        if (!widget.isPermanent) {
          _burnAudio();
        } else {
          if (mounted) setState(() => _isPlaying = false);
        }
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    _cleanTempFile();
    super.dispose();
  }

  Future<void> _cleanTempFile() async {
    if (_tempFilePath != null) {
      final file = File(_tempFilePath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<void> _play() async {
    if (_hasPlayed && !widget.isPermanent) return;

    try {
      if (_tempFilePath == null) {
        final Uint8List bytes = base64Decode(widget.base64Audio);
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/zka_ram_${DateTime.now().millisecondsSinceEpoch}.m4a');
        await file.writeAsBytes(bytes);
        _tempFilePath = file.path;
      }

      await _player.play(DeviceFileSource(_tempFilePath!));
      if (mounted) setState(() => _isPlaying = true);
    } catch (e) {
      print("Error reproduciendo audio: $e");
    }
  }

  void _burnAudio() async {
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _hasPlayed = true;
      });
    }
    await _cleanTempFile();
    widget.onBurn();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isPermanent ? VinkiarColors.hackingGreen : VinkiarColors.vertigoGold;

    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.2),
        foregroundColor: color,
        side: BorderSide(color: color),
      ),
      icon: Icon(_isPlaying ? Icons.multitrack_audio : Icons.play_arrow, size: 18),
      label: Text(
        _isPlaying ? "REPRODUCIENDO..." : (widget.isPermanent ? "▶️ REPRODUCIR VOZ (FIJO)" : "▶️ ESCUCHAR VOZ (1 USO)"),
        style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold),
      ),
      onPressed: _isPlaying || (_hasPlayed && !widget.isPermanent) ? null : _play,
    );
  }
}