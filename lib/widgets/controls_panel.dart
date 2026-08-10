import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_state.dart';

class ControlsPanelWidget extends StatelessWidget {
  final AppState state;

  const ControlsPanelWidget({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    const paletteColors = [
      {'name': 'Primary Blue', 'hex': '#4A90D9', 'color': Color(0xFF4A90D9)},
      {'name': 'Soft Purple', 'hex': '#9B59B6', 'color': Color(0xFF9B59B6)},
      {'name': 'Warm Yellow', 'hex': '#F1C40F', 'color': Color(0xFFF1C40F)},
      {'name': 'White', 'hex': '#FFFFFF', 'color': Colors.white},
    ];

    return Container(
      width: double.infinity,
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF1E293B), width: 1.0),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Row Controls
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.start,
            spacing: 12.0,
            runSpacing: 10.0,
            children: [
              // Brand Title
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1C40F),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x66F1C40F),
                          blurRadius: 4,
                          spreadRadius: 1,
                        )
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "LittleLumin Splash Studio",
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              // View Toggle
              Container(
                padding: const EdgeInsets.all(2.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildModeBtn(
                      label: "Splash View",
                      icon: Icons.visibility,
                      isActive: !state.showAppPreview,
                      activeColor: const Color(0xFF4A90D9),
                      onTap: () => state.setShowAppPreview(false),
                    ),
                    _buildModeBtn(
                      label: "App Preview",
                      icon: Icons.smartphone,
                      isActive: state.showAppPreview,
                      activeColor: const Color(0xFF9B59B6),
                      onTap: () => state.setShowAppPreview(true),
                    ),
                  ],
                ),
              ),

              // Device Frame Selectors
              Container(
                padding: const EdgeInsets.all(2.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFrameBtn(
                      label: "iPhone",
                      icon: Icons.phone_iphone,
                      isActive: state.deviceFrame == DeviceFrameType.iphone,
                      onTap: () => state.setDeviceFrame(DeviceFrameType.iphone),
                    ),
                    _buildFrameBtn(
                      label: "Pixel",
                      icon: Icons.phone_android,
                      isActive: state.deviceFrame == DeviceFrameType.pixel,
                      onTap: () => state.setDeviceFrame(DeviceFrameType.pixel),
                    ),
                    _buildFrameBtn(
                      label: "Full Screen",
                      icon: Icons.monitor,
                      isActive: state.deviceFrame == DeviceFrameType.fullscreen,
                      onTap: () => state.setDeviceFrame(DeviceFrameType.fullscreen),
                    ),
                  ],
                ),
              ),

              // Playback & Progress Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: state.replaySplash,
                    icon: const Icon(Icons.replay, size: 14, color: Color(0xFF0F172A)),
                    label: Text(
                      "Replay Splash",
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF1C40F),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => state.setIsAutoPlay(!state.isAutoPlay),
                    icon: Icon(
                      state.isAutoPlay ? Icons.pause : Icons.play_arrow,
                      size: 14,
                      color: Colors.white,
                    ),
                    label: Text(
                      state.isAutoPlay ? "Auto Playing" : "Paused",
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: state.isAutoPlay
                          ? const Color(0xFF059669)
                          : const Color(0xFF1E293B),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          const Divider(color: Color(0xFF1E293B), height: 1),
          const SizedBox(height: 8),

          // Bottom Palette & Density Row
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.start,
            spacing: 12.0,
            runSpacing: 8.0,
            children: [
              // Palette
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.palette_outlined,
                      size: 14, color: Color(0xFFF1C40F)),
                  const SizedBox(width: 4),
                  Text(
                    "Palette:",
                    style: GoogleFonts.inter(
                      color: const Color(0xFFCBD5E1),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  ...paletteColors.map((c) {
                    return Container(
                      margin: const EdgeInsets.only(right: 6.0),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6.0, vertical: 2.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(4.0),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: c['color'] as Color,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            c['hex'] as String,
                            style: GoogleFonts.firaCode(
                              color: const Color(0xFFE2E8F0),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),

              // Shape Density Selector
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.layers_outlined,
                      size: 14, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                  Text(
                    "Shapes:",
                    style: GoogleFonts.inter(
                      color: const Color(0xFF94A3B8),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 6),
                  ...ShapeDensity.values.map((d) {
                    final isActive = state.shapeDensity == d;
                    return Padding(
                      padding: const EdgeInsets.only(right: 4.0),
                      child: InkWell(
                        onTap: () => state.setShapeDensity(d),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8.0, vertical: 3.0),
                          decoration: BoxDecoration(
                            color: isActive
                                ? const Color(0xFF4A90D9)
                                : const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                          child: Text(
                            d.name,
                            style: GoogleFonts.inter(
                              color: isActive ? Colors.white : const Color(0xFF94A3B8),
                              fontSize: 10,
                              fontWeight:
                                  isActive ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeBtn({
    required String label,
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13,
                color: isActive ? Colors.white : const Color(0xFF94A3B8)),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? Colors.white : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrameBtn({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF334155) : Colors.transparent,
          borderRadius: BorderRadius.circular(6.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13,
                color: isActive ? Colors.white : const Color(0xFF94A3B8)),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? Colors.white : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
