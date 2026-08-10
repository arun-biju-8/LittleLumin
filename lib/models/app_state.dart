// lib/models/app_state.dart
import 'package:flutter/foundation.dart';

enum DeviceFrameType {
  iphone,
  pixel,
  fullscreen,
}

// ✅ Change to uppercase S
enum ShapeDensity {
  sparse,
  normal,
  rich,
}

enum AgeGroup {
  age3('3'),
  age4('4'),
  age5('5'),
  age6('6');

  final String label;
  const AgeGroup(this.label);
}

class AppState extends ChangeNotifier {
  DeviceFrameType _deviceFrame = DeviceFrameType.iphone;
  ShapeDensity _shapeDensity = ShapeDensity.normal;  // ✅ Updated
  AgeGroup _selectedAge = AgeGroup.age4;
  double _progress = 0.0;
  bool _isAutoPlay = true;
  bool _showAppPreview = false;
  int _keyCounter = 0;

  DeviceFrameType get deviceFrame => _deviceFrame;
  ShapeDensity get shapeDensity => _shapeDensity;  // ✅ Updated
  AgeGroup get selectedAge => _selectedAge;
  double get progress => _progress;
  bool get isAutoPlay => _isAutoPlay;
  bool get showAppPreview => _showAppPreview;
  int get keyCounter => _keyCounter;

  void setDeviceFrame(DeviceFrameType frame) {
    _deviceFrame = frame;
    notifyListeners();
  }

  void setShapeDensity(ShapeDensity density) {  // ✅ Updated
    _shapeDensity = density;
    notifyListeners();
  }

  void setSelectedAge(AgeGroup age) {
    _selectedAge = age;
    notifyListeners();
  }

  void setProgress(double value) {
    _progress = value.clamp(0.0, 100.0);
    notifyListeners();
  }

  void setIsAutoPlay(bool value) {
    _isAutoPlay = value;
    notifyListeners();
  }

  void setShowAppPreview(bool value) {
    _showAppPreview = value;
    notifyListeners();
  }

  void replaySplash() {
    _progress = 0.0;
    _showAppPreview = false;
    _isAutoPlay = true;
    _keyCounter++;
    notifyListeners();
  }

  void incrementProgress(double delta) {
    if (_progress < 100.0) {
      _progress = (_progress + delta).clamp(0.0, 100.0);
      notifyListeners();
    }
  }
}