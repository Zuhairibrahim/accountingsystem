import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// نافذة مسح الباركود بالكاميرا الأمامية مع إدخال يدوي كبديل
/// تعيد قيمة الباركود أو null عند الإلغاء
Future<String?> scanBarcode(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (context) => const _BarcodeScanDialog(),
  );
}

class _BarcodeScanDialog extends StatefulWidget {
  const _BarcodeScanDialog();

  @override
  State<_BarcodeScanDialog> createState() => _BarcodeScanDialogState();
}

class _BarcodeScanDialogState extends State<_BarcodeScanDialog> {
  MobileScannerController _controller =
      MobileScannerController(facing: CameraFacing.front);
  int _attempt = 0;
  final TextEditingController _manualCtrl = TextEditingController();
  bool _detected = false;

  @override
  void dispose() {
    _manualCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _submit(String code) {
    if (code.trim().isEmpty) return;
    if (_detected) return;
    _detected = true;
    Navigator.pop(context, code.trim());
  }

  void _restartScanner() {
    _controller.dispose();
    setState(() {
      _attempt++;
      _controller = MobileScannerController(facing: CameraFacing.front);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.qr_code_scanner, color: Color(0xFF2563EB)),
          const SizedBox(width: 8),
          const Text(
            'مسح الباركود',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 240,
                width: double.infinity,
                child: MobileScanner(
                  key: ValueKey(_attempt),
                  controller: _controller,
                  onDetect: (capture) {
                    if (_detected) return;
                    for (final b in capture.barcodes) {
                      final raw = b.rawValue;
                      if (raw != null && raw.isNotEmpty) {
                        _submit(raw);
                        return;
                      }
                    }
                  },
                  placeholderBuilder: (context) => const ColoredBox(
                    color: Color(0xFF0F172A),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white54),
                          SizedBox(height: 10),
                          Text(
                            'جارٍ تشغيل الكاميرا...',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                  errorBuilder: (context, error) => ColoredBox(
                    color: const Color(0xFFFEF2F2),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.videocam_off_outlined,
                              color: Color(0xFFDC2626),
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'تعذّر تشغيل الكاميرا',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF991B1B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'تأكد من السماح باستخدام الكاميرا، وأنها غير مستخدمة في تطبيق آخر.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _restartScanner,
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('إعادة المحاولة'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  overlayBuilder: (context, constraints) {
                    final rect = Rect.fromCenter(
                      center: constraints.biggest.center(Offset.zero),
                      width: constraints.biggest.width * 0.7,
                      height: constraints.biggest.height * 0.5,
                    );
                    return Stack(
                      children: [
                        Positioned.fromRect(
                          rect: rect,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.greenAccent,
                                width: 2.5,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualCtrl,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'أدخل الرقم يدوياً',
                    ),
                    onSubmitted: _submit,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _controller.switchCamera(),
                  tooltip: 'تبديل الكاميرا',
                  icon: const Icon(Icons.cameraswitch_outlined),
                ),
                const SizedBox(width: 4),
                ElevatedButton(
                  onPressed: () => _submit(_manualCtrl.text),
                  child: const Text('استخدام'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'ضع الباركود أمام الكاميرا الأمامية',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
      ],
    );
  }
}