import 'dart:math';
import '../data/providers.dart' show HeadReference;
import 'vision_models.dart';

// ---- thresholds (apne phone/models par test karke badalna) ----
const int kMaxGapMs = 250; // isse bada gap = tracking toota, run band
const int kMinBlinkMs = 80, kMaxBlinkMs = 600; // isse lamba = intentional closure
const int kMinBlinkValidMs = 5000; // blink rate ke liye kam se kam 30 sec valid data
const int kMinGazeSamples = 20; // ~5 sec
const double kSaccadeVelocity = 1.0; // gaze units / sec
const int kMinFixationMs = 100;
const double kSlightDeg = 8, kDeviatedDeg = 12;
const double kGazeSpreadForZero = 0.4; // itna spread = 0% stability

class SessionMeasurements {
  final double trackingQuality; // 0..1
  final double faceVisibleFraction; // 0..1

  // blink (eyes-open only)
  final int? blinkCount;
  final double? blinkRate; // per minute
  final int? avgBlinkMs;

  // gaze (eyes-open only)
  final double? gazeStability; // 0..1
  final int? fixationCount, avgFixationMs, saccadeCount;

  // head posture
  final int? alignedSec, slightSec, deviatedSec;
  final bool headUsedSessionMedian; // true = reference set nahi tha

  const SessionMeasurements({
    required this.trackingQuality,
    required this.faceVisibleFraction,
    this.blinkCount,
    this.blinkRate,
    this.avgBlinkMs,
    this.gazeStability,
    this.fixationCount,
    this.avgFixationMs,
    this.saccadeCount,
    this.alignedSec,
    this.slightSec,
    this.deviatedSec,
    this.headUsedSessionMedian = false,
  });

  static const empty =
      SessionMeasurements(trackingQuality: 0, faceVisibleFraction: 0);
}

double _median(List<double> v) {
  final s = [...v]..sort();
  final m = s.length ~/ 2;
  return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2;
}

SessionMeasurements computeMeasurements(
  List<FrameReading> r, {
  required bool eyesClosedMode,
  HeadReference? headRef,
}) {
  if (r.length < 2) return SessionMeasurements.empty;

  int dt(int i) => r[i].tMs - r[i - 1].tMs;

  final quality =
      r.map((e) => e.trackingQuality).reduce((a, b) => a + b) / r.length;
  final visible = r.where((e) => e.faceVisible).length / r.length;

  // ================= BLINKS =================
  int? blinkCount, avgBlinkMs;
  double? blinkRate;
  if (!eyesClosedMode) {
    var blinks = 0, blinkMsTotal = 0, validMs = 0;
    int? closedStart;
    var prevTrusted = false;
    for (var i = 0; i < r.length; i++) {
      final e = r[i];
      final trusted = e.faceVisible &&
          e.eyeState != EyeState.uncertain &&
          e.eyeConfidence >= 0.6;
      final gap = i > 0 && dt(i) > kMaxGapMs;
      if (gap) closedStart = null;
      if (i > 0 && trusted && prevTrusted && !gap) validMs += dt(i);
      prevTrusted = trusted;
      if (!trusted) {
        closedStart = null; // tracking toota, ye run blink nahi gina jayega
        continue;
      }
      if (e.eyeState == EyeState.closed) {
        closedStart ??= e.tMs;
      } else if (closedStart != null) {
        final d = e.tMs - closedStart;
        if (d >= kMinBlinkMs && d <= kMaxBlinkMs) {
          blinks++;
          blinkMsTotal += d;
        }
        closedStart = null;
      }
    }
    if (validMs > 0) blinkCount = blinks;
    if (validMs >= kMinBlinkValidMs) {
      blinkRate = blinks / (validMs / 60000);
    }
    if (blinks > 0) avgBlinkMs = (blinkMsTotal / blinks).round();
  }

  // ================= GAZE, FIXATIONS, SACCADES =================
  double? gazeStability;
  int? fixCount, avgFixMs, sacCount;
  if (!eyesClosedMode) {
    bool validGaze(int i) {
      final e = r[i];
      return e.faceVisible &&
          e.eyeState == EyeState.open &&
          e.gazeX != null &&
          e.gazeY != null;
    }

    final xs = <double>[], ys = <double>[];
    for (var i = 0; i < r.length; i++) {
      if (validGaze(i)) {
        xs.add(r[i].gazeX!);
        ys.add(r[i].gazeY!);
      }
    }

    if (xs.length >= kMinGazeSamples) {
      double variance(List<double> v) {
        final m = v.reduce((a, b) => a + b) / v.length;
        return v.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) /
            v.length;
      }

      final spread = sqrt(variance(xs) + variance(ys));
      gazeStability = (1 - spread / kGazeSpreadForZero).clamp(0.0, 1.0);

      // velocity threshold: tez gaze = saccade, dheema = fixation
      var fix = 0, sac = 0, fixMsTotal = 0;
      int? runStart;
      var runIsSac = false;
      var lastT = 0;

      void closeRun() {
        if (runStart == null) return;
        final d = lastT - runStart!;
        if (runIsSac) {
          sac++;
        } else if (d >= kMinFixationMs) {
          fix++;
          fixMsTotal += d;
        }
        runStart = null;
      }

      for (var i = 0; i < r.length; i++) {
        if (!validGaze(i)) {
          closeRun();
          continue;
        }
        if (i > 0 && validGaze(i - 1) && dt(i) <= kMaxGapMs && dt(i) > 0) {
          final dx = r[i].gazeX! - r[i - 1].gazeX!;
          final dy = r[i].gazeY! - r[i - 1].gazeY!;
          final v = sqrt(dx * dx + dy * dy) / (dt(i) / 1000);
          final isSac = v > kSaccadeVelocity;
          if (runStart == null) {
            runStart = r[i - 1].tMs;
            runIsSac = isSac;
          } else if (isSac != runIsSac) {
            closeRun();
            runStart = r[i - 1].tMs;
            runIsSac = isSac;
          }
          lastT = r[i].tMs;
        } else {
          closeRun();
        }
      }
      closeRun();

      fixCount = fix;
      sacCount = sac;
      if (fix > 0) avgFixMs = (fixMsTotal / fix).round();
    }
  }

  // ================= HEAD POSTURE =================
  int? aligned, slight, deviated;
  var usedMedian = false;
  bool validHead(int i) =>
      r[i].faceVisible &&
      r[i].yaw != null &&
      r[i].pitch != null &&
      r[i].roll != null;

  final ys = <double>[], ps = <double>[], rs = <double>[];
  for (var i = 0; i < r.length; i++) {
    if (validHead(i)) {
      ys.add(r[i].yaw!);
      ps.add(r[i].pitch!);
      rs.add(r[i].roll!);
    }
  }
  if (ys.length >= 50) {
    final refYaw = headRef?.yaw ?? _median(ys);
    final refPitch = headRef?.pitch ?? _median(ps);
    final refRoll = headRef?.roll ?? _median(rs);
    usedMedian = headRef == null;

    var a = 0, s = 0, d = 0; // milliseconds
    for (var i = 1; i < r.length; i++) {
      if (!validHead(i)) continue;
      final ms = min(dt(i), kMaxGapMs);
      final dev = max(
        (r[i].yaw! - refYaw).abs(),
        max((r[i].pitch! - refPitch).abs(), (r[i].roll! - refRoll).abs()),
      );
      if (dev >= kDeviatedDeg) {
        d += ms;
      } else if (dev >= kSlightDeg) {
        s += ms;
      } else {
        a += ms;
      }
    }
    aligned = (a / 1000).round();
    slight = (s / 1000).round();
    deviated = (d / 1000).round();
  }

  return SessionMeasurements(
    trackingQuality: quality,
    faceVisibleFraction: visible,
    blinkCount: blinkCount,
    blinkRate: blinkRate,
    avgBlinkMs: avgBlinkMs,
    gazeStability: gazeStability,
    fixationCount: fixCount,
    avgFixationMs: avgFixMs,
    saccadeCount: sacCount,
    alignedSec: aligned,
    slightSec: slight,
    deviatedSec: deviated,
    headUsedSessionMedian: usedMedian,
  );
}