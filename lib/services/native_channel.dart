import 'dart:async';
import 'package:flutter/services.dart';

class NativeChannel {
  static final _ch = const MethodChannel('com.example.safelink/intent');
  static final _streamCtrl = StreamController<String>.broadcast();

  /// Listen here for every incoming URL
  static Stream<String> get urlStream => _streamCtrl.stream;

  /// Call once at app start
  static Future<void> init() async {
    // 1️⃣ initial launch
    final initial = await _ch.invokeMethod<String>('getInitialUrl');
    if (initial != null) _streamCtrl.add(initial);

    // 2️⃣ subsequent launches while app is alive
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'incomingUrl') {
        final url = call.arguments as String?;
        if (url != null) _streamCtrl.add(url);
      }
    });
  }
}