import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

// ── Sleep-stage palette ────────────────────────────────────────────────────────
const _kBg         = Color(0xFF0C1B2A);
const _kAwake      = Color(0xFFE8355E);
const _kRem        = Color(0xFF62BFEE);
const _kLight      = Color(0xFF4A82BE);
const _kDeep       = Color(0xFF1D3F62);
const _kTotalLabel = Color(0xFF62BFEE);
const _kSubtext    = Color(0xFF6A8A9E);

class SleepDetailPage extends StatefulWidget {
  const SleepDetailPage({
    super.key,
    required this.date,
    this.sleepScore,
  });

  /// Date-only string (e.g. "2025-01-15"). Logs whose `date` field starts
  /// with this value are fetched from Firestore.
  final String date;
  final int?   sleepScore;

  @override
  State<SleepDetailPage> createState() => _SleepDetailPageState();
}

class _SleepDetailPageState extends State<SleepDetailPage> {
  bool    _loading = true;
  String? _error;

  int _totalMinutes = 0;
  int _awakeMinutes = 0;
  int _remMinutes   = 0;
  int _lightMinutes = 0;
  int _deepMinutes  = 0;

  // Sorted list of {date, sleepTime, temp*} for the stages chart.
  List<Map<String, dynamic>> _sleepPoints = [];

  // Pointer position (mouse hover or touch drag) in canvas-local coordinates.
  Offset? _pointerPos;

  // ── lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _fetchSleepLogs();
  }

  // ── Firestore fetch ───────────────────────────────────────────────────────────

  Future<void> _fetchSleepLogs() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() { _loading = false; _error = 'Not signed in'; });
        return;
      }

      debugPrint("widget date is ${widget.date} -----------------------");
      final dayString = widget.date.split('T')[0];

      final snap = await FirebaseFirestore.instance
          .collection('daily_sleep')
          .where('userId', isEqualTo: user.uid)
          .where('date', isEqualTo: dayString)
          .get();

      final sleepLogSnap = await FirebaseFirestore.instance
          .collection('sleep_logs')
          .where('userId', isEqualTo: user.uid)
          .where('sleepDay', isEqualTo: dayString)
          .get();
      debugPrint("sleep data ${snap} ----------------");

      if(snap.docs.isEmpty) return;

      int total = 0, awake = 0, rem = 0, light = 0, deep = 0;

      Map<String, dynamic> dailySleepData = snap.docs.first.data() as Map<String, dynamic>;
      final points = <Map<String, dynamic>>[];
     
      for (final doc in sleepLogSnap.docs) {
        final data    = doc.data();
        final rawTime = data['sleepTime'];
        final rawDate = data['date'] as String? ?? '';

        if (rawDate.isNotEmpty) {
          points.add({
            'date':              rawDate,
            'sleepTime':         rawTime.toDouble(),
            'deepSleepTime':  (data['deepSleepTime']  as num?)?.toDouble() ?? 0.0,
            'lightSleepTime': (data['lightSleepTime'] as num?)?.toDouble() ?? 0.0,
            'awakeTime':      (data['awakeTime']      as num?)?.toDouble() ?? 0.0,
            'remSleepTime':   (data['remSleepTime']   as num?)?.toDouble() ?? 0.0,
          });
        }
      }

      points.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

      setState(() {
        _totalMinutes = dailySleepData['sleepTime']?.toInt() ?? 0;
        _awakeMinutes = dailySleepData['awakeTime']?.toInt() ?? 0;
        _remMinutes   = dailySleepData['remSleepTime']?.toInt() ?? 0;
        _lightMinutes = dailySleepData['lightSleepTime']?.toInt() ?? 0;
        _deepMinutes  = dailySleepData['deepSleepTime']?.toInt() ?? 0;
        
        _sleepPoints  = points;
        _loading      = false;
      });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  // ── helpers ──────────────────────────────────────────────────────────────────

  String _fmt(int minutes) {
    if (minutes <= 0) return '0 min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m min';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  String _pct(int part) {
    if (_totalMinutes <= 0) return '';
    return '${(part / _totalMinutes * 100).round()}%';
  }

  // ── build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(date: widget.date),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _kTotalLabel),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not load sleep data\n$_error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _kSubtext),
          ),
        ),
      );
    }
    if (_totalMinutes == 0) {
      return const Center(
        child: Text(
          'No sleep data for this date',
          style: TextStyle(color: _kSubtext),
        ),
      );
    }

    final stages = _stages();
    final maxMins = stages.fold(0, (acc, s) => acc > s.minutes ? acc : s.minutes);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          ...stages.map((s) => _StageRow(
                stage:   s,
                maxMins: maxMins,
                fmt:     _fmt,
                pct:     _pct,
              )),
          const SizedBox(height: 32),
          _TotalRow(label: 'Total duration', value: _fmt(_totalMinutes)),
          if (widget.sleepScore != null && widget.sleepScore! > 0) ...[
            const SizedBox(height: 10),
            _TotalRow(label: 'Sleep score', value: '${widget.sleepScore}'),
          ],
          _chart(),
        ],
      ),
    );
  }

  List<_Stage> _stages() => [
        _Stage(label: 'Awake', minutes: _awakeMinutes, color: _kAwake, showPct: false),
        _Stage(label: 'REM',   minutes: _remMinutes,   color: _kRem,   showPct: true),
        _Stage(label: 'Light', minutes: _lightMinutes, color: _kLight, showPct: true),
        _Stage(label: 'Deep',  minutes: _deepMinutes,  color: _kDeep,  showPct: true),
      ];

  Widget _chart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        const Text(
          'Sleep Stages',
          style: TextStyle(
            color: _kTotalLabel,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        // Legend
        Wrap(
          spacing: 16,
          children: const [
            _LegendDot(color: Color(0xFFE8355E), label: 'Awake'),
            _LegendDot(color: Color(0xFF62BFEE), label: 'REM'),
            _LegendDot(color: Color(0xFF4A82BE), label: 'Light'),
            _LegendDot(color: Color(0xFF2B5EA0), label: 'Deep'),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          width: double.infinity,
          child: MouseRegion(
            onHover: (e) => setState(() => _pointerPos = e.localPosition),
            onExit:  (_)  => setState(() => _pointerPos = null),
            child: GestureDetector(
              onPanUpdate: (d) => setState(() => _pointerPos = d.localPosition),
              onPanEnd:    (_)  => setState(() => _pointerPos = null),
              onTapDown:   (d)  => setState(() => _pointerPos = d.localPosition),
              onTapUp:     (_)  => setState(() => _pointerPos = null),
              child: CustomPaint(
                painter: _SleepLinePainter(_sleepPoints, pointerPos: _pointerPos),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Data carrier ──────────────────────────────────────────────────────────────

class _Stage {
  const _Stage({
    required this.label,
    required this.minutes,
    required this.color,
    required this.showPct,
  });
  final String label;
  final int    minutes;
  final Color  color;
  final bool   showPct;
}

// ── Header with back arrow ────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.date});
  final String date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sleep',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (date.isNotEmpty)
                Text(
                  date,
                  style: const TextStyle(color: _kSubtext, fontSize: 12),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── One stage row ─────────────────────────────────────────────────────────────

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.stage,
    required this.maxMins,
    required this.fmt,
    required this.pct,
  });

  final _Stage   stage;
  final int      maxMins;
  final String Function(int) fmt;
  final String Function(int) pct;

  @override
  Widget build(BuildContext context) {
    final fraction = maxMins > 0 ? (stage.minutes / maxMins) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: stage.color,
              borderRadius: BorderRadius.circular(5),
              border: stage.color == _kDeep
                  ? Border.all(color: const Color(0xFF2D5A8A), width: 1)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 44,
            child: Text(
              stage.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 22,
                child: Stack(
                  children: [
                    Container(color: const Color(0xFF132030)),
                    FractionallySizedBox(
                      widthFactor: fraction.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: stage.color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 82,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    fmt(stage.minutes),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (stage.showPct && stage.minutes > 0)
                  Text(
                    pct(stage.minutes),
                    style: const TextStyle(color: _kSubtext, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Legend dot ────────────────────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color  color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10, height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: _kSubtext, fontSize: 11)),
    ],
  );
}

// ── Sleep stages step-line CustomPainter ─────────────────────────────────────
//
// Single continuous stepped line: Awake / REM / Light / Deep bands on Y axis,
// real time on X axis. Horizontal span = segment duration; vertical jump on
// stage change. Fill below the line in each segment's band color.

class _SleepLinePainter extends CustomPainter {
  _SleepLinePainter(this.points, {this.pointerPos});
  final List<Map<String, dynamic>> points;
  final Offset? pointerPos;

  // Y band order (0 = top): Awake, REM, Light, Deep
  static const _bandLabels = ['Awake', 'REM', 'Light', 'Deep'];
  static const _bandColors = <Color>[
    Color(0xFFE8355E), // Awake
    Color(0xFF62BFEE), // REM
    Color(0xFF4A82BE), // Light
    Color(0xFF2B5EA0), // Deep
  ];

  static const _lPad = 46.0;
  static const _rPad = 12.0;
  static const _tPad = 8.0;
  static const _bPad = 28.0;

  // Expands one log into sub-segments (Awake→REM→Light→Deep), skipping zeros.
  // The chart always starts at Awake regardless — see paint() for how the
  // zero-duration Awake anchor is prepended to the very first segment only.
  static List<({DateTime start, DateTime end, int band})> _expandLog(
      Map<String, dynamic> p) {
    final dateStr = p['date'] as String? ?? '';
    if (dateStr.isEmpty) return [];
    late DateTime cursor;
    try { cursor = DateTime.parse(dateStr); } catch (_) { return []; }
    const keys = ['awakeTime', 'remSleepTime', 'lightSleepTime', 'deepSleepTime'];
    final out = <({DateTime start, DateTime end, int band})>[];
    for (int b = 0; b < keys.length; b++) {
      final mins = (p[keys[b]] as num?)?.toDouble() ?? 0.0;
      if (mins <= 0) continue;
      final end = cursor.add(Duration(seconds: (mins * 60).round()));
      out.add((start: cursor, end: end, band: b));
      cursor = end;
    }
    return out;
  }

  void _text(Canvas canvas, String s, Offset o, TextStyle style,
      {double maxW = 200, bool center = false}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: maxW);
    final dx = center ? (o.dx - tp.width / 2) : o.dx;
    tp.paint(canvas, Offset(dx.clamp(0.0, double.infinity), o.dy));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cL = _lPad;
    final cT = _tPad;
    final cR = size.width - _rPad;
    final cB = size.height - _bPad;
    final cW = cR - cL;
    final cH = cB - cT;
    final bH = cH / 4;

    double yBand(int b) => cT + (b + 0.5) * bH;

    // ── Y-axis band labels ─────────────────────────────────────────────
    for (int b = 0; b < 4; b++) {
      _text(
        canvas,
        _bandLabels[b],
        Offset(2, yBand(b) - 6),
        TextStyle(color: _bandColors[b], fontSize: 10, fontWeight: FontWeight.w600),
        maxW: _lPad - 4,
      );
    }

    // ── Horizontal band dividers ───────────────────────────────────────
    final divPaint = Paint()
      ..color = const Color(0xFF1A2E40)
      ..strokeWidth = 0.5;
    for (int i = 0; i <= 4; i++) {
      canvas.drawLine(Offset(cL, cT + i * bH), Offset(cR, cT + i * bH), divPaint);
    }

    // ── Parse: each sleep log expands into segments ──────────────────────
    final sorted = [...points]
      ..sort((a, b) => ((a['date'] as String?) ?? '').compareTo(
                        (b['date'] as String?) ?? ''));
    final logSegs = <List<({DateTime start, DateTime end, int band})>>[];
    for (final p in sorted) {
      final s = _expandLog(p);
      if (s.isNotEmpty) logSegs.add(s);
    }

    // ── No-data fallback ───────────────────────────────────────────────
    if (logSegs.isEmpty) {
      _text(
        canvas, 'No data',
        Offset(cL + cW / 2, cT + cH / 2 - 6),
        const TextStyle(color: _kSubtext, fontSize: 13),
        maxW: 80, center: true,
      );
      return;
    }

    // ── Merge consecutive logs whose gap is ≤ 20 minutes into one line ───
    // Each group is a list of logs that will be drawn as a single connected
    // step-line; groups with a larger gap are drawn as separate lines.
    const _mergeThreshold = Duration(minutes: 20);
    final groups = <List<List<({DateTime start, DateTime end, int band})>>>[];
    for (final segs in logSegs) {
      if (groups.isEmpty) {
        groups.add([segs]);
      } else {
        final lastEnd   = groups.last.last.last.end;
        final nextStart = segs.first.start;
        if (nextStart.difference(lastEnd) <= _mergeThreshold) {
          groups.last.add(segs);
        } else {
          groups.add([segs]);
        }
      }
    }

    // ── Total ms across all groups for proportional width allocation ──────
    double totalMs = 0;
    for (final group in groups) {
      for (final segs in group) {
        for (final seg in segs) {
          totalMs += seg.end.difference(seg.start).inMilliseconds.toDouble();
        }
      }
    }
    totalMs = totalMs.clamp(1.0, double.infinity);

    // Fixed pixel gap between separate groups
    const gapPx = 10.0;
    final availW = (cW - gapPx * (groups.length - 1)).clamp(1.0, double.infinity);

    const double hW = 6.0;
    const double vW = 1.5;

    final hPaint = Paint()
      ..strokeWidth = hW
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round;

    final vPaint = Paint()
      ..strokeWidth = vW
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round;

    const labelStyle = TextStyle(color: _kSubtext, fontSize: 9);

    _layout.clear();

    double groupLeft = cL;
    for (int gi = 0; gi < groups.length; gi++) {
      final group = groups[gi];
      // Flatten all logs in this group into one renderSegs list.
      // Prepend the zero-duration Awake anchor only for the first log of the
      // group; subsequent logs connect directly to whatever band preceded them.
      final renderSegs = <({DateTime start, DateTime end, int band})>[];
      for (int li = 0; li < group.length; li++) {
        final segs = group[li];
        if (li == 0 && segs.first.band != 0) {
          final t = segs.first.start;
          renderSegs.add((start: t, end: t, band: 0));
        }
        renderSegs.addAll(segs);
      }

      // This group's total duration for proportional width
      double groupMs = 0;
      for (final seg in renderSegs) {
        groupMs += seg.end.difference(seg.start).inMilliseconds.toDouble();
      }
      groupMs = groupMs.clamp(1.0, double.infinity);
      final groupW = availW * groupMs / totalMs;

      // Cumulative x positions within this group
      final x1s = <double>[];
      final x2s = <double>[];
      double cum = 0;
      for (final seg in renderSegs) {
        final dur = seg.end.difference(seg.start).inMilliseconds.toDouble();
        x1s.add(groupLeft + cum / groupMs * groupW);
        x2s.add(groupLeft + (cum + dur) / groupMs * groupW);
        cum += dur;
      }

      // Pass 1 — thin vertical connectors
      for (int i = 0; i < renderSegs.length - 1; i++) {
        if (renderSegs[i].band == renderSegs[i + 1].band) continue;
        vPaint.color = _bandColors[renderSegs[i].band];
        canvas.drawLine(
          Offset(x2s[i], yBand(renderSegs[i].band)),
          Offset(x2s[i], yBand(renderSegs[i + 1].band)),
          vPaint,
        );
      }

      // Pass 2 — thick horizontal segments
      for (int i = 0; i < renderSegs.length; i++) {
        hPaint.color = _bandColors[renderSegs[i].band];
        canvas.drawLine(
          Offset(x1s[i], yBand(renderSegs[i].band)),
          Offset(x2s[i], yBand(renderSegs[i].band)),
          hPaint,
        );
      }

      // Start label at the left edge of every group; end label only for
      // the last group so adjacent labels never overlap.
      _text(canvas, DateFormat('h:mm a').format(group.first.first.start),
          Offset(groupLeft, cB + 6), labelStyle, maxW: 60, center: true);
      if (gi == groups.length - 1) {
        _text(canvas, DateFormat('h:mm a').format(group.last.last.end),
            Offset(groupLeft + groupW, cB + 6), labelStyle, maxW: 60, center: true);
      }

      // Collect every rendered segment position for tooltip hit-testing.
      for (int i = 0; i < renderSegs.length; i++) {
        _layout.add((
          x1: x1s[i], x2: x2s[i],
          band: renderSegs[i].band,
          segStart: renderSegs[i].start,
          segEnd:   renderSegs[i].end,
        ));
      }

      // Awake connector between this group and the next: vertical up to the
      // Awake band, then horizontal across the gap.
      if (gi < groups.length - 1) {
        final lastBand = renderSegs.last.band;
        final x1 = groupLeft + groupW;
        final x2 = x1 + gapPx;
        if (lastBand != 0) {
          canvas.drawLine(
            Offset(x1, yBand(lastBand)),
            Offset(x1, yBand(0)),
            Paint()
              ..color       = _kAwake
              ..strokeWidth = vW
              ..strokeCap   = StrokeCap.round,
          );
        }
        canvas.drawLine(
          Offset(x1, yBand(0)),
          Offset(x2, yBand(0)),
          Paint()
            ..color       = _kAwake
            ..strokeWidth = hW
            ..strokeCap   = StrokeCap.round,
        );
      }

      groupLeft += groupW + gapPx;
    }

    // ── Tooltip ──────────────────────────────────────────────────────────
    final px = pointerPos?.dx;
    if (px != null && px >= cL && px <= cR) {
      // Find the segment the pointer falls in (first match wins).
      for (final seg in _layout) {
        if (px < seg.x1 || px > seg.x2) continue;
        // Interpolate time within the segment.
        final frac = (seg.x2 > seg.x1)
            ? (px - seg.x1) / (seg.x2 - seg.x1)
            : 0.0;
        final msRange = seg.segEnd.difference(seg.segStart).inMilliseconds;
        final t = seg.segStart.add(Duration(milliseconds: (frac * msRange).round()));

        // Vertical hair line
        canvas.drawLine(
          Offset(px, cT),
          Offset(px, cB),
          Paint()
            ..color       = Colors.white.withOpacity(0.25)
            ..strokeWidth = 1.0,
        );

        // Tooltip box
        final bandColor = _bandColors[seg.band];
        final stageName = _bandLabels[seg.band];
        final timeStr   = DateFormat('h:mm a').format(t);
        const bw = 76.0, bh = 38.0;
        double bx = (px - bw / 2).clamp(cL, cR - bw);
        final by = cT + 4.0;
        final rr = RRect.fromRectAndRadius(
          Rect.fromLTWH(bx, by, bw, bh),
          const Radius.circular(6),
        );
        canvas.drawRRect(rr, Paint()..color = const Color(0xF00C1B2A));
        canvas.drawRRect(rr,
          Paint()
            ..color      = bandColor.withOpacity(0.7)
            ..style      = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
        _text(canvas, stageName, Offset(bx + 8, by + 5),
            TextStyle(color: bandColor, fontSize: 10, fontWeight: FontWeight.w700),
            maxW: bw - 16);
        _text(canvas, timeStr, Offset(bx + 8, by + 20),
            const TextStyle(color: Color(0xCCFFFFFF), fontSize: 10),
            maxW: bw - 16);
        break;
      }
    }
  }

  // Segment layout built during paint for tooltip hit-testing.
  final _layout = <({double x1, double x2, int band, DateTime segStart, DateTime segEnd})>[];

  @override
  bool shouldRepaint(_SleepLinePainter old) =>
      old.points != points || old.pointerPos != pointerPos;
}

// ── Total / score row ─────────────────────────────────────────────────────────

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        children: [
          TextSpan(
            text: '$label  ',
            style: const TextStyle(color: _kTotalLabel),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
