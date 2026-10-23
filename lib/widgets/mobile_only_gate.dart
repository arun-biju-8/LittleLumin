// lib/widgets/mobile_only_gate.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import '../screens/parent/desktop_parent_companion.dart';

class MobileOnlyGate extends StatelessWidget {
  final Widget child;
  final String userType; // parent | llg | admin

  const MobileOnlyGate({super.key, required this.child, required this.userType});

  bool get _isParent => userType == 'parent';
  bool get _isMobile => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Widget build(BuildContext context) {
    // LLG and Admin: full web/desktop access allowed
    if (userType == 'llg' || userType == 'admin') return child;

    // Parent on mobile: full mobile app allowed
    if (_isMobile) return child;

    // Parent on web/desktop: professional, responsive, read-focused companion
    if (_isParent) {
      return const DesktopParentCompanionScreen();
    }

    return child;
  }
}
