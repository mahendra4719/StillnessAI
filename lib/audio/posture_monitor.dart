import '../data/providers.dart' show HeadReference;
import '../vision/measurements.dart' show kDeviatedDeg;
import '../vision/vision_models.dart';

const int kSustainedMs = 10000; // itni der lagatar deviation = reminder
const int kCooldownMs = 120000; // do reminders ke beech kam se kam 2 min
const int kAutoRefSamples = 100; // reference na ho to shuru ke ~10 sec

class PostureMonitor {
  PostureMonitor({this.reference});

  final HeadReference? reference;
  HeadReference? _auto;
  final List<FrameReading> _calib = [];
  int? _devStart, _lastReminderT;
  int count = 0;

  /// true = abhi reminder dena chahiye.
  bool update(FrameReading r) {
    final valid = r.faceVisible &&
        r.trackingQuality >= 0.5 &&
        r.yaw != null &&
        r.pitch != null &&
        r.roll != null;
    if (!valid) {
      _devStart = null; // tracking toota, ise posture kharab nahi maante
      return false;
    }

    final ref = reference ?? _auto;
    if (ref == null) {
      // Setup me reference nahi set tha: shuru ke kuch sec ka average lo
      _calib.add(r);
      if (_calib.length >= kAutoRefSamples) {
        double avg(double Function(FrameReading f) g) =>
            _calib.map(g).reduce((a, b) => a + b) / _calib.length;
        _auto = HeadReference(
            avg((f) => f.yaw!), avg((f) => f.pitch!), avg((f) => f.roll!));
      }
      return false;
    }

    final dev = [
      (r.yaw! - ref.yaw).abs(),
      (r.pitch! - ref.pitch).abs(),
      (r.roll! - ref.roll).abs(),
    ].reduce((a, b) => a > b ? a : b);

    if (dev < kDeviatedDeg) {
      _devStart = null;
      return false;
    }
    _devStart ??= r.tMs;
    final sustained = r.tMs - _devStart! >= kSustainedMs;
    final cooled =
        _lastReminderT == null || r.tMs - _lastReminderT! >= kCooldownMs;
    return sustained && cooled;
  }

  /// Reminder asli me bola gaya tabhi call karo.
  void markReminded(int tMs) {
    count++;
    _lastReminderT = tMs;
  }

  /// Pause ke baad dobara naye sire se gino.
  void resetRun() => _devStart = null;
}