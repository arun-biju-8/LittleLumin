import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_state.dart';

class DeviceFrameContainer extends StatelessWidget {
  final DeviceFrameType frameType;
  final Widget child;

  const DeviceFrameContainer({
    super.key,
    required this.frameType,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (frameType == DeviceFrameType.fullscreen) {
      return Container(
        width: 860,
        height: 720,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(24.0),
          border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 30,
              offset: Offset(0, 15),
            )
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
    }

    final isIphone = frameType == DeviceFrameType.iphone;
    final width = isIphone ? 375.0 : 380.0;
    final height = isIphone ? 760.0 : 770.0;
    final borderRadius = isIphone ? 48.0 : 42.0;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: const Color(0xFF1E293B), width: 10.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x88000000),
            blurRadius: 32,
            offset: Offset(0, 16),
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Internal Screen Content
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(top: 24.0, bottom: 16.0),
              child: child,
            ),
          ),

          // Top Status Bar (Time, Signal, Wifi, Battery)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 28,
            child: IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "9:41",
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: const [
                        Icon(Icons.signal_cellular_4_bar,
                            size: 11, color: Colors.white),
                        SizedBox(width: 4),
                        Icon(Icons.wifi, size: 11, color: Colors.white),
                        SizedBox(width: 4),
                        Icon(Icons.battery_full,
                            size: 12, color: Colors.white),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // iPhone Notch / Dynamic Island Cutout
          if (isIphone)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    width: 110,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF1E293B)),
                          ),
                        ),
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF1E293B)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Pixel Punchhole Camera Cutout
          if (!isIphone)
            Positioned(
              top: 6,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF0F172A),
                          spreadRadius: 2,
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Bottom Home Indicator Bar
          Positioned(
            bottom: 4,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  width: 120,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
