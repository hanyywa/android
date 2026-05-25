import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class TranslatePage extends StatefulWidget {
  const TranslatePage({super.key});

  @override
  State<TranslatePage> createState() => _TranslatePageState();
}

class _TranslatePageState extends State<TranslatePage> {
  MethodChannel? _methodChannel;
  bool _hasPermission = false;
  bool _modelLoaded = false;
  bool _modelError = false;
  bool _bufferReady = false;
  int _bufferCount = 0;
  String? _currentPrediction;
  final List<String> _history = [];
  File? _historyFile;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final status = await Permission.camera.request();
    if (mounted) {
      setState(() {
        _hasPermission = status.isGranted;
      });
    }

    final dir = await getApplicationDocumentsDirectory();
    _historyFile = File('${dir.path}/history.txt');
    if (await _historyFile!.exists()) {
      final existing = await _historyFile!.readAsString();
      _history.addAll(
        existing.split('\n').where((l) => l.trim().isNotEmpty).take(10),
      );
    }
  }

  void _onPlatformViewCreated(int id) {
    _methodChannel = MethodChannel('temanisyarat/hand_landmarker_$id');
    _methodChannel?.setMethodCallHandler(_handleMethodCall);
    _startCamera();
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onLandmarks':
        _handleLandmarks(call.arguments as Map);
        break;
      case 'onModelReady':
        final args = call.arguments as Map;
        if (mounted) {
          setState(() {
            _modelLoaded = args['loaded'] as bool? ?? false;
            _modelError = !_modelLoaded;
          });
        }
        break;
      case 'onError':
        final args = call.arguments as Map;
        debugPrint('Landmarker error: ${args['message']}');
        break;
    }
  }

  void _handleLandmarks(Map args) {
    final prediction = args['prediction'] as String?;
    final bufferCount = args['bufferCount'] as int? ?? 0;
    final bufferReady = args['bufferReady'] as bool? ?? false;
    final modelLoaded = args['modelLoaded'] as bool?;

    if (mounted) {
      setState(() {
        _bufferCount = bufferCount;
        _bufferReady = bufferReady;
        if (modelLoaded != null) _modelLoaded = modelLoaded;
      });
    }

    if (prediction != null && prediction != _currentPrediction) {
      setState(() {
        _currentPrediction = prediction;
        _history.add(prediction);
        if (_history.length > 10) _history.removeAt(0);
      });
      unawaited(_writeHistory(prediction));
    }
  }

  Future<void> _writeHistory(String word) async {
    final file = _historyFile;
    if (file == null) return;
    final timestamp = DateTime.now().toIso8601String().split('T').first;
    await file.writeAsString('$timestamp $word\n', mode: FileMode.append);
  }

  Future<void> _startCamera() async {
    if (!_hasPermission) return;
    try {
      await _methodChannel?.invokeMethod('startCamera');
    } catch (e) {
      debugPrint('Failed to start camera: $e');
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.black, body: _buildBody());
  }

  Widget _buildBody() {
    if (!_hasPermission) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Izin kamera diperlukan',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final status = await Permission.camera.request();
                if (mounted) {
                  setState(() => _hasPermission = status.isGranted);
                }
              },
              child: const Text('Izinkan Kamera'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        AndroidView(
          viewType: 'temanisyarat/hand_landmarker',
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated,
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Terjemahkan Isyarat',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(bottom: 0, left: 0, right: 0, child: _buildResultPanel()),
        if (_bufferReady)
          Positioned(
            bottom: 160,
            left: 16,
            right: 16,
            child: _buildSubtitleOverlay(),
          ),
      ],
    );
  }

  Widget _buildSubtitleOverlay() {
    if (_currentPrediction != null) {
      final displayWords = [_currentPrediction!, ..._history.reversed.take(3)];
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayWords[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (displayWords.length > 1) ...[
              const SizedBox(height: 4),
              Text(
                displayWords.skip(1).join(' · '),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white54,
            ),
          ),
          SizedBox(width: 10),
          Text(
            'Memindai...',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildResultPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_modelError)
            const Column(
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 32),
                SizedBox(height: 8),
                Text(
                  'Gagal memuat model',
                  style: TextStyle(color: Colors.red, fontSize: 14),
                ),
              ],
            )
          else if (!_modelLoaded)
            const Column(
              children: [
                CircularProgressIndicator(color: Colors.blue),
                SizedBox(height: 12),
                Text(
                  'Memuat model...',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            )
          else if (!_bufferReady)
            Column(
              children: [
                LinearProgressIndicator(
                  value: _bufferCount / 125,
                  color: Colors.blue,
                  backgroundColor: Colors.grey.shade800,
                ),
                const SizedBox(height: 12),
                Text(
                  'Mengumpulkan frame... $_bufferCount/125',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            )
          else if (_currentPrediction != null)
            Column(
              children: [
                Text(
                  _currentPrediction!.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 4,
                  width: 200,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            )
          else
            _buildScanningIndicator(),
        ],
      ),
    );
  }

  Widget _buildScanningIndicator() {
    return Column(
      children: [
        _ScanningDots(),
        const SizedBox(height: 8),
        const Text(
          'Pindai gerakan...',
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
      ],
    );
  }
}

class _ScanningDots extends StatefulWidget {
  @override
  State<_ScanningDots> createState() => _ScanningDotsState();
}

class _ScanningDotsState extends State<_ScanningDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final value = ((_controller.value - delay) % 1.0).clamp(0.0, 1.0);
            final opacity =
                0.3 + (0.7 * (1 - (value - 0.5).abs() * 2).clamp(0.0, 1.0));
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
