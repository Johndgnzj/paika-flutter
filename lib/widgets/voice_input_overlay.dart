import 'package:flutter/material.dart';

/// 語音輸入時的全螢幕視覺反饋
class VoiceInputOverlay extends StatefulWidget {
  final String recognizedText;
  final bool isListening;
  final VoidCallback onCancel;

  const VoiceInputOverlay({
    super.key,
    required this.recognizedText,
    required this.isListening,
    required this.onCancel,
  });

  @override
  State<VoiceInputOverlay> createState() => _VoiceInputOverlayState();
}

class _VoiceInputOverlayState extends State<VoiceInputOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.75),
      child: SafeArea(
        child: Stack(
          children: [
            // 中央麥克風動畫
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 脈動圓圈 + 麥克風 icon
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final scale = 1.0 + (_pulseController.value * 0.3);
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // 外圈波紋
                          Container(
                            width: 180 * scale,
                            height: 180 * scale,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red.withValues(alpha: 0.2 * (1 - _pulseController.value)),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.4),
                                width: 2,
                              ),
                            ),
                          ),
                          // 內圈
                          Container(
                            width: 140,
                            height: 140,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.redAccent,
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.mic,
                              size: 70,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 40),

                  // 提示文字
                  Text(
                    widget.isListening ? '正在聆聽...' : '語音辨識中...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 辨識文字顯示
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    constraints: const BoxConstraints(minHeight: 80),
                    child: Center(
                      child: Text(
                        widget.recognizedText.isEmpty
                            ? '等待語音輸入...'
                            : widget.recognizedText,
                        style: TextStyle(
                          color: widget.recognizedText.isEmpty
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // 使用範例
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '💡 語音範例：',
                          style: TextStyle(
                            color: Colors.lightBlueAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '• 「小明胡阿華5台」\n• 「莊家自摸3台」\n• 「東家胡南家8台」',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 取消按鈕（右上角）
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: widget.onCancel,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.3),
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
