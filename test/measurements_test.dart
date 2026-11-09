import 'package:flutter_test/flutter_test.dart';
import 'package:drishti/vision/measurements.dart';
import 'package:drishti/vision/vision_models.dart';

/// 10 readings/sec. closedRanges = [(start, end)] ms jab aankh band ho.
List<FrameReading> make({
  int seconds = 60,
  List<(int, int)> closedRanges = const [],
  bool faceVisible = true,
  bool allClosed = false,
}) {
  final out = <FrameReading>[];
  for (var t = 0; t < seconds * 1000; t += 100) {
    final closed =
        allClosed || closedRanges.any((r) => t >= r.$1 && t <= r.$2);
    out.add(FrameReading(
      tMs: t,
      faceVisible: faceVisible,
      trackingQuality: faceVisible ? 0.9 : 0.1,
      eyeState: !faceVisible
          ? EyeState.uncertain
          : closed
              ? EyeState.closed
              : EyeState.open,
      eyeConfidence: 0.9,
      gazeX: (faceVisible && !closed) ? 0.0 : null,
      gazeY: (faceVisible && !closed) ? 0.0 : null,
      yaw: faceVisible ? 0.0 : null,
      pitch: faceVisible ? 0.0 : null,
      roll: faceVisible ? 0.0 : null,
    ));
  }
  return out;
}

void main() {
  test('3 normal blinks are counted', () {
    final m = computeMeasurements(
      make(closedRanges: [(5000, 5200), (20000, 20200), (40000, 40200)]),
      eyesClosedMode: false,
    );
    expect(m.blinkCount, 3);
    expect(m.blinkRate, closeTo(3, 0.5));
  });

  test('long eye closure is not counted as a blink', () {
    final m = computeMeasurements(
      make(closedRanges: [(10000, 12000)]),
      eyesClosedMode: false,
    );
    expect(m.blinkCount, 0);
  });

  test('eyes-closed mode: eye measurements null, head still available', () {
    final m = computeMeasurements(
      make(allClosed: true),
      eyesClosedMode: true,
    );
    expect(m.blinkCount, isNull);
    expect(m.gazeStability, isNull);
    expect(m.alignedSec, isNotNull);
  });

  test('no face: measurements are null, not zero', () {
    final m = computeMeasurements(
      make(faceVisible: false),
      eyesClosedMode: false,
    );
    expect(m.blinkCount, isNull);
    expect(m.gazeStability, isNull);
    expect(m.alignedSec, isNull);
  });
}