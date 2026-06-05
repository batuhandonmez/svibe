import 'dart:async';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

class MotionTrigger {
  MotionTrigger({
    required this.onTrigger,
    this.threshold = 18,
    this.cooldown = const Duration(milliseconds: 1200),
  });

  final MotionCallback onTrigger;
  final double threshold;
  final Duration cooldown;

  StreamSubscription<UserAccelerometerEvent>? _subscription;
  DateTime _lastTrigger = DateTime.fromMillisecondsSinceEpoch(0);

  void start() {
    _subscription ??= userAccelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 80),
    ).listen(_handle, onError: (_) {});
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _handle(UserAccelerometerEvent event) {
    final force = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    final now = DateTime.now();
    if (force < threshold || now.difference(_lastTrigger) < cooldown) {
      return;
    }
    _lastTrigger = now;
    onTrigger();
  }
}

typedef MotionCallback = void Function();
