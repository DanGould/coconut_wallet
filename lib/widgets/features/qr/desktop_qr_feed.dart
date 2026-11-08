import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/material.dart';

/// Camera stand-in for Linux desktop builds, which have no camera plugin.
///
/// A helper outside the app decodes the QR codes another window shows and
/// appends each payload as a line to `$HOME/qr-feed.txt`, and writes its
/// latest screen grab to `$HOME/qr-preview.png`. This widget tails the feed
/// and hands every new line to [onScanData], the same entry point a camera
/// frame takes, and shows the preview as its viewfinder.
class DesktopQrFeed extends StatefulWidget {
  final void Function(String scanData) onScanData;

  const DesktopQrFeed({super.key, required this.onScanData});

  /// Whether the scanner should read the feed instead of a camera: on the
  /// Linux desktop app, but not under `flutter test`, which also runs on
  /// Linux and drives the camera path with fakes.
  static bool get isAvailable => Platform.isLinux && !Platform.environment.containsKey('FLUTTER_TEST');

  @override
  State<DesktopQrFeed> createState() => _DesktopQrFeedState();
}

class _DesktopQrFeedState extends State<DesktopQrFeed> {
  static const _pollInterval = Duration(milliseconds: 100);

  late final File _feed;
  late final File _previewFile;
  Timer? _timer;
  int _offset = 0;
  String _pendingLine = '';
  DateTime? _previewModified;
  Uint8List? _preview;

  @override
  void initState() {
    super.initState();
    final home = Platform.environment['HOME'] ?? '.';
    _feed = File('$home/qr-feed.txt');
    _previewFile = File('$home/qr-preview.png');
    // Lines already in the feed belong to an earlier scan.
    _offset = _feed.existsSync() ? _feed.lengthSync() : 0;
    _timer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _poll() {
    _readFeed();
    _readPreview();
  }

  void _readFeed() {
    if (!_feed.existsSync()) return;
    final length = _feed.lengthSync();
    if (length < _offset) {
      // The helper truncates the feed when it restarts.
      _offset = 0;
      _pendingLine = '';
    }
    if (length == _offset) return;

    final file = _feed.openSync();
    try {
      file.setPositionSync(_offset);
      final chunk = utf8.decode(file.readSync(length - _offset), allowMalformed: true);
      _offset = length;
      final lines = (_pendingLine + chunk).split('\n');
      _pendingLine = lines.removeLast();
      for (final line in lines) {
        final scanData = line.trim();
        if (scanData.isNotEmpty && mounted) widget.onScanData(scanData);
      }
    } finally {
      file.closeSync();
    }
  }

  void _readPreview() {
    if (!_previewFile.existsSync()) return;
    try {
      final modified = _previewFile.lastModifiedSync();
      if (modified == _previewModified) return;
      final bytes = _previewFile.readAsBytesSync();
      _previewModified = modified;
      if (mounted) setState(() => _preview = bytes);
    } on FileSystemException {
      // The helper replaces the file while we read it; the next poll retries.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: CoconutColors.black,
      alignment: Alignment.center,
      child: _preview == null ? null : Image.memory(_preview!, gaplessPlayback: true, fit: BoxFit.contain),
    );
  }
}
