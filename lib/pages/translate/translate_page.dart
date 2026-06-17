import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants.dart';
import 'translate_controller.dart';
import 'widgets/scanning_dots.dart';

class TranslatePage extends StatefulWidget {
  const TranslatePage({super.key});

  @override
  State<TranslatePage> createState() => _TranslatePageState();
}

class _TranslatePageState extends State<TranslatePage> {
  final _controller = TranslateController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
    _controller.init();
  }

  @override
  void dispose() {
    _controller.removeListener(() {
      if (mounted) setState(() {});
    });
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: C.primary, body: _buildBody());
  }

  Widget _buildBody() {
    if (!_controller.hasPermission) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt,
              size: 64,
              color: C.onPrimary.withValues(alpha: 0.54),
            ),
            const SizedBox(height: 16),
            Text(
              'Izin kamera diperlukan',
              style: TextStyle(color: C.onPrimary, fontSize: 18),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _controller.requestCameraPermission,
              child: const Text('Izinkan Kamera'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 3 / 4,
          child: Stack(
            children: [
              AndroidView(
                viewType: 'temanisyarat/hand_landmarker',
                creationParamsCodec: const StandardMessageCodec(),
                onPlatformViewCreated: _controller.onPlatformViewCreated,
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
                          icon: const Icon(
                            Icons.arrow_back,
                            color: C.onPrimary,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Text(
                          'Terjemahkan Isyarat',
                          style: TextStyle(
                            color: C.onPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(
                            Icons.flip_camera_android,
                            color: C.onPrimary,
                          ),
                          onPressed: _controller.switchCamera,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // if (_controller.bufferReady)
              //   Positioned(
              //     bottom: 16,
              //     left: 16,
              //     right: 16,
              //     child: _buildSubtitleOverlay(),
              //   ),
            ],
          ),
        ),
        Expanded(child: _buildResultPanel()),
      ],
    );
  }

  Widget _buildSubtitleOverlay() {
    if (_controller.currentPrediction != null) {
      final displayWords = [
        _controller.currentPrediction!,
        ..._controller.history.reversed.take(3),
      ];
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              displayWords[0].toUpperCase(),
              style: const TextStyle(
                color: C.onPrimary,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (displayWords.length > 1) ...[
              const SizedBox(height: 4),
              Text(
                displayWords.skip(1).join(' · '),
                style: TextStyle(
                  color: C.onPrimary.withValues(alpha: 0.5),
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: C.onPrimary,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Memindai...',
            style: TextStyle(
              color: C.onPrimary.withValues(alpha: 0.54),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: C.primary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_controller.modelError)
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
          else if (!_controller.modelLoaded)
            Column(
              children: [
                const CircularProgressIndicator(color: C.onPrimary),
                const SizedBox(height: 12),
                Text(
                  'Memuat model...',
                  style: TextStyle(color: C.onPrimary.withValues(alpha: 0.7)),
                ),
              ],
            )
          else if (!_controller.hasLandmarks)
            Column(
              children: [
                Icon(
                  Icons.pan_tool,
                  color: C.onPrimary.withValues(alpha: 0.54),
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tidak ada tangan terdeteksi',
                  style: TextStyle(
                    color: C.onPrimary.withValues(alpha: 0.54),
                    fontSize: 14,
                  ),
                ),
              ],
            )
          else if (!_controller.bufferReady)
            Column(
              children: [
                LinearProgressIndicator(
                  value: _controller.bufferCount / 30,
                  color: C.onPrimary,
                  backgroundColor: C.onPrimary.withValues(alpha: 0.2),
                ),
                const SizedBox(height: 12),
                Text(
                  'Mengumpulkan frame... ${_controller.bufferCount}/30',
                  style: TextStyle(color: C.onPrimary.withValues(alpha: 0.7)),
                ),
              ],
            )
          else if (_controller.currentPrediction != null)
            Column(
              children: [
                Text(
                  _controller.currentPrediction!.toUpperCase(),
                  style: const TextStyle(
                    color: C.onPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            )
          else
            _buildScanningIndicator(),
          _buildBufferBar(),
        ],
      ),
    );
  }

  Widget _buildBufferBar() {
    final fillRatio = (_controller.bufferCount / 110.0).clamp(0.0, 1.0);
    final offsetRatio = _controller.bufferCount >= 110
        ? (_controller.writeOffset / 110.0).clamp(0.0, 1.0)
        : fillRatio;
    final wrapped = _controller.bufferCount >= 110;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 6,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final totalWidth = constraints.maxWidth;
                return Stack(
                  children: [
                    Container(
                      width: totalWidth,
                      decoration: BoxDecoration(
                        color: C.onPrimary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    Container(
                      width: totalWidth * fillRatio,
                      decoration: BoxDecoration(
                        color: C.onPrimary,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    if (wrapped)
                      Positioned(
                        left: totalWidth * offsetRatio - 1,
                        child: Container(
                          width: 2,
                          height: 6,
                          color: C.onPrimary,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_controller.inferencePulse)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
              Text(
                'Frame ${_controller.totalFrames}  ›  Offset ${_controller.writeOffset}  ›  Buffer ${_controller.bufferCount}/110',
                style: TextStyle(
                  color: C.onPrimary.withValues(alpha: 0.54),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScanningIndicator() {
    return Column(
      children: [
        const ScanningDots(),
        const SizedBox(height: 8),
        Text(
          'Pindai gerakan...',
          style: TextStyle(
            color: C.onPrimary.withValues(alpha: 0.7),
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
