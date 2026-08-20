import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import 'equipment_browse_screen.dart';
import 'equipment_detail_screen.dart';

const _viewfinderHero =
    'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?auto=format&fit=crop&w=1200&q=80';

/// Full-bleed network image with a graceful gradient fallback so a dead
/// link never breaks the layout — the same defensive pattern used across
/// onboarding, profile setup, and the workout module.
Widget _networkHero(String url, {BoxFit fit = BoxFit.cover}) {
  return Image.network(
    url,
    fit: fit,
    loadingBuilder: (context, child, progress) =>
        progress == null ? child : Container(color: AppColors.ink),
    errorBuilder: (context, error, stack) =>
        const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.heroGradient)),
  );
}

/// UC-2.6 — Scan Gym Equipment. No real camera or on-device model is
/// wired up yet — there's no backend to match against — so this
/// simulates the recognition flow end to end: a viewfinder over a static
/// "camera feed" image, an animated scan line, a brief scanning state,
/// then a match against `MockData.gymEquipment` — including the honest
/// case where nothing matches, roughly every fourth scan.
///
/// Swapping in a real camera preview and an on-device classifier later
/// only touches `_runScan` below: everything downstream already expects
/// a real `GymEquipment` and doesn't know or care how it was found.
class EquipmentScannerScreen extends StatefulWidget {
  const EquipmentScannerScreen({super.key});

  @override
  State<EquipmentScannerScreen> createState() => _EquipmentScannerScreenState();
}

class _EquipmentScannerScreenState extends State<EquipmentScannerScreen>
    with TickerProviderStateMixin {
  late final AnimationController _scanLine;
  bool _scanning = false;
  bool _noMatch = false;
  int _scanCount = 0;

  static const _boxSize = 260.0;

  @override
  void initState() {
    super.initState();
    _scanLine = AnimationController(vsync: this, duration: const Duration(milliseconds: 1700))..repeat();
  }

  @override
  void dispose() {
    _scanLine.dispose();
    super.dispose();
  }

  Future<void> _runScan() async {
    if (_scanning) return;
    setState(() {
      _scanning = true;
      _noMatch = false;
    });
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;

    _scanCount++;
    final isNoMatch = _scanCount % 4 == 0;
    setState(() => _scanning = false);

    if (isNoMatch) {
      setState(() => _noMatch = true);
      return;
    }

    final active = MockData.gymEquipment.where((e) => e.isActive).toList();
    if (active.isEmpty) {
      if (!mounted) return;
      setState(() => _noMatch = true);
      return;
    }
    final equipment = active[(_scanCount - 1) % active.length];
    if (!mounted) return;
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => EquipmentDetailScreen(equipment: equipment)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _networkHero(_viewfinderHero),
          DecoratedBox(decoration: BoxDecoration(color: AppColors.ink.withValues(alpha: 0.55))),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text('Scan equipment',
                            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.grid_view_rounded, color: Colors.white),
                        tooltip: 'Browse all equipment',
                        onPressed: () => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => const EquipmentBrowseScreen())),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: _boxSize,
                      height: _boxSize,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRect(
                            child: AnimatedBuilder(
                              animation: _scanLine,
                              builder: (context, _) => Positioned(
                                top: _scanLine.value * (_boxSize - 3),
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: AppColors.overlay,
                                    boxShadow: [
                                      BoxShadow(color: AppColors.overlay.withValues(alpha: 0.7), blurRadius: 10),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          ..._corners(),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 12),
                  child: Text(
                    _scanning ? 'Scanning…' : 'Point your camera at gym equipment',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w600),
                  ),
                ),
                if (_noMatch)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.search_off_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Couldn't recognise this equipment",
                                    style:
                                        TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5)),
                                const SizedBox(height: 3),
                                const Text('Try moving closer, or browse the catalogue instead.',
                                    style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                                const SizedBox(height: 8),
                                TextButton(
                                  style: TextButton.styleFrom(
                                      foregroundColor: AppColors.overlay, padding: EdgeInsets.zero),
                                  onPressed: () => Navigator.push(context,
                                      MaterialPageRoute(builder: (_) => const EquipmentBrowseScreen())),
                                  child: const Text('Browse all equipment'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 36),
                  child: GestureDetector(
                    onTap: _runScan,
                    child: Container(
                      width: 74,
                      height: 74,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.fromBorderSide(BorderSide(color: Colors.white54, width: 4)),
                      ),
                      child: _scanning
                          ? const Padding(
                              padding: EdgeInsets.all(22),
                              child: CircularProgressIndicator(strokeWidth: 2.6, color: AppColors.primary),
                            )
                          : const Icon(Icons.camera_alt_rounded, color: AppColors.primary, size: 30),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _corners() {
    const size = 28.0;
    const thickness = 3.0;

    Widget bracket({required bool top, required bool left}) {
      return Positioned(
        top: top ? 0 : null,
        bottom: top ? null : 0,
        left: left ? 0 : null,
        right: left ? null : 0,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            border: Border(
              top: top ? const BorderSide(color: Colors.white, width: thickness) : BorderSide.none,
              bottom: !top ? const BorderSide(color: Colors.white, width: thickness) : BorderSide.none,
              left: left ? const BorderSide(color: Colors.white, width: thickness) : BorderSide.none,
              right: !left ? const BorderSide(color: Colors.white, width: thickness) : BorderSide.none,
            ),
          ),
        ),
      );
    }

    return [
      bracket(top: true, left: true),
      bracket(top: true, left: false),
      bracket(top: false, left: true),
      bracket(top: false, left: false),
    ];
  }
}
