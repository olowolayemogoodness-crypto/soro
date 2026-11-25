import 'package:flutter/material.dart';

import '../../theme/soro_theme.dart';
import 'progress_data.dart';
import 'progress_strings.dart';

/// Route path for the "My progress" page. Register it in the app router.
const String progressRoutePath = '/progress';

// Colours and fonts come from the app theme tokens.
class _T {
  static const crimson = SoroTokens.crimson;
  static const crimsonDeep = SoroTokens.crimsonDeep;
  static const blue = SoroTokens.studentBlue;
  static const orange = SoroTokens.orange;
  static const ink = SoroTokens.ink;
  static const ink2 = SoroTokens.ink2;
  static const cream = SoroTokens.cream;
  static const sand = SoroTokens.sand;
  static const line = SoroTokens.line;
  static const paper = SoroTokens.paper;
  static const success = SoroTokens.success;
  static const mint = SoroTokens.mint;
  static const peach = SoroTokens.peach;
  static const sticky = SoroTokens.sticky;
  static const lilac = SoroTokens.lilac;

  static const serif = SoroTokens.fontSerif;
  static const sans = SoroTokens.fontSans;
}

enum ProgressView { student, parent }

/// "My progress": a read-only page with the learning record. Opens with one tap
/// from home. Student view by default; the Parent view switch changes the
/// wording and shows a consent note.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({
    super.key,
    this.data,
    this.initialLang = ProgressLang.en,
    this.initialView = ProgressView.student,
    this.onBack,
    this.onLangChanged,
  });

  /// Defaults to seeded sample data until `GET /progress` is wired in.
  final ProgressData? data;
  final ProgressLang initialLang;
  final ProgressView initialView;
  final VoidCallback? onBack;

  /// Lets the app keep its language in step with the selector on this page.
  final ValueChanged<ProgressLang>? onLangChanged;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  late final ProgressData _data = widget.data ?? ProgressData.sample();
  late ProgressLang _lang = widget.initialLang;
  late ProgressView _view = widget.initialView;

  bool get _parent => _view == ProgressView.parent;
  String _t(String key, [Map<String, Object> args = const {}]) =>
      progressText(_lang, key, {'name': _data.studentName, ...args});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(fontFamily: _T.sans, bodyColor: _T.ink, displayColor: _T.ink),
      ),
      child: Scaffold(
        key: const Key('progress-screen'),
        backgroundColor: _T.cream,
        body: SoroDottedPaperBackground(
          child: SafeArea(
          child: LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth >= 860;
            final pad = c.maxWidth < 500 ? 16.0 : 28.0;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(pad, 12, pad, 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(c.maxWidth < 560),
                      const SizedBox(height: 20),
                      if (_parent) ...[_consentNote(), const SizedBox(height: 16)],
                      _hero(wide),
                      const SizedBox(height: 16),
                      if (wide)
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(flex: 3, child: _leftColumn()),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: _rightColumn()),
                        ])
                      else ...[
                        _leftColumn(),
                        const SizedBox(height: 16),
                        _rightColumn(),
                      ],
                      if (_lang == ProgressLang.yo) ...[
                        const SizedBox(height: 20),
                        Text(_t('yoNeedsCheck'),
                            style: const TextStyle(fontSize: 13, color: _T.ink2, fontStyle: FontStyle.italic)),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
          ),
        ),
      ),
    );
  }

  // ---------- header ----------

  Widget _header(bool narrow) {
    final back = IconButton(
      key: const Key('progress-back-button'),
      tooltip: _t('back'),
      onPressed: widget.onBack ?? () => Navigator.maybePop(context),
      style: IconButton.styleFrom(minimumSize: const Size(48, 48), backgroundColor: _T.paper, side: const BorderSide(color: _T.line)),
      icon: const Icon(Icons.arrow_back_rounded, color: _T.ink),
    );
    final title = Text(_t('title'),
        style: const TextStyle(fontFamily: _T.serif, fontSize: 26, fontWeight: FontWeight.w600, color: _T.ink));
    final viewSwitch = Semantics(
      label: _t('viewSwitchLabel'),
      child: _Segmented<ProgressView>(
        value: _view,
        onChanged: (v) => setState(() => _view = v),
        items: [
          (ProgressView.student, _t('viewStudent'), Icons.person_outline_rounded),
          (ProgressView.parent, _t('viewParent'), Icons.family_restroom_rounded),
        ],
        activeColor: _T.crimson,
        compact: narrow,
      ),
    );
    final lang = _LangMenu(lang: _lang, label: _t('language'), onChanged: (l) {
      setState(() => _lang = l);
      widget.onLangChanged?.call(l);
    });

    if (narrow) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [back, const SizedBox(width: 12), Expanded(child: title), lang]),
        const SizedBox(height: 12),
        viewSwitch,
      ]);
    }
    return Row(children: [
      back,
      const SizedBox(width: 14),
      Expanded(child: title),
      viewSwitch,
      const SizedBox(width: 12),
      lang,
    ]);
  }

  Widget _consentNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _T.lilac, borderRadius: BorderRadius.circular(16)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.lock_outline_rounded, size: 22, color: _T.ink),
        const SizedBox(width: 12),
        Expanded(
          child: Text('${_t('consentParent')} ${_t('consentLaw')}',
              style: const TextStyle(fontSize: 14, height: 1.4, color: _T.ink)),
        ),
      ]),
    );
  }

  // ---------- hero + streak ----------

  Widget _hero(bool wide) {
    final streak = _data.streak;
    final headline = Text(_t(_parent ? 'heroParent' : 'heroStudent'),
        style: const TextStyle(fontFamily: _T.serif, fontSize: 28, height: 1.2, fontWeight: FontWeight.w600, color: _T.ink));
    final sub = Text(_t(_parent ? 'heroSubParent' : 'heroSubStudent'),
        style: const TextStyle(fontSize: 15, height: 1.4, color: _T.ink2));
    final text = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [headline, const SizedBox(height: 6), sub]);
    final badge = _StreakBadge(
      days: streak,
      label: _t('streak'),
      caption: streak == 0 ? _t('streakNone') : (streak == 1 ? _t('streakOne') : _t('streakNote')),
    );
    return _Card(
      color: _T.peach,
      child: wide
          ? Row(children: [Expanded(child: text), const SizedBox(width: 24), SizedBox(width: 300, child: badge)])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [text, const SizedBox(height: 16), badge]),
    );
  }

  // ---------- columns ----------

  Widget _leftColumn() => Column(children: [_activityCard(), const SizedBox(height: 16), _subjectsCard()]);

  Widget _rightColumn() => Column(children: [
        _strengthsCard(),
        if (_nextLesson() != null) ...[const SizedBox(height: 16), _nextUpCard(_nextLesson()!)],
        if (_parent) ...[const SizedBox(height: 16), _emailCard()],
      ]);

  // ---------- activity by day ----------

  static const _daysEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  // Needs native check.
  static const _daysYo = ['Ajé', 'Ìṣẹ́', 'Ọjọ́rú', 'Ọjọ́bọ', 'Ẹtì', 'Àbá', 'Àìkú'];

  Widget _activityCard() {
    final maxMin = _data.week.map((d) => d.minutes).fold<int>(1, (a, b) => b > a ? b : a);
    final names = _lang == ProgressLang.en ? _daysEn : _daysYo;
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SectionTitle(_t('week')),
        const SizedBox(height: 4),
        Text(_t(_parent ? 'weekSubParent' : 'weekSubStudent', {'n': _data.activeDays}),
            style: const TextStyle(fontSize: 14, color: _T.ink2)),
        const SizedBox(height: 16),
        SizedBox(
          height: 148,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final d in _data.week)
              Expanded(
                child: Semantics(
                  label: '${names[d.date.weekday - 1]}: ${d.active ? '${d.minutes} ${_t('minutes')}' : _t('noActivity')}',
                  excludeSemantics: true,
                  child: _DayBar(
                    name: DateUtils.isSameDay(d.date, _data.today) ? _t('today') : names[d.date.weekday - 1],
                    minutes: d.minutes,
                    fraction: d.minutes / maxMin,
                    isToday: DateUtils.isSameDay(d.date, _data.today),
                    unit: _t('minutes'),
                  ),
                ),
              ),
          ]),
        ),
      ]),
    );
  }

  // ---------- subjects ----------

  Widget _subjectsCard() {
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SectionTitle(_t('subjects')),
        const SizedBox(height: 12),
        for (var i = 0; i < _data.subjects.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _SubjectTile(
            key: ValueKey('subject-${_data.subjects[i].name}'),
            subject: _data.subjects[i],
            t: _t,
            initiallyOpen: i == 0,
            accent: i.isEven ? _T.blue : _T.orange,
          ),
        ],
      ]),
    );
  }

  // ---------- strengths ----------

  Widget _strengthsCard() {
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: _SectionTitle(_t('strengths'))),
          if (_data.isSample) _Chip(_t('sample'), color: _T.sticky),
        ]),
        const SizedBox(height: 4),
        Text(_t('strengthsSub'), style: const TextStyle(fontSize: 14, color: _T.ink2)),
        const SizedBox(height: 16),
        for (final s in _data.strengths) ...[
          _StrengthRow(s: s, notEnough: _t('notEnough'), basedOn: s.attempts == 1 ? _t('basedOnOne') : _t('basedOn', {'n': s.attempts})),
          const SizedBox(height: 14),
        ],
        if (_data.isSample)
          Text(_t('sampleNote'), style: const TextStyle(fontSize: 13, height: 1.4, color: _T.ink2, fontStyle: FontStyle.italic)),
      ]),
    );
  }

  LessonRecord? _nextLesson() {
    for (final s in _data.subjects) {
      for (final topic in s.topics) {
        for (final l in topic.lessons) {
          if (l.stepsDone > 0 && l.stepsDone < l.stepsTotal) return l;
        }
      }
    }
    return null;
  }

  Widget _nextUpCard(LessonRecord l) {
    final left = l.stepsTotal - l.stepsDone;
    return _Card(
      color: _T.sticky,
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(color: _T.paper, shape: BoxShape.circle),
          child: const Icon(Icons.arrow_forward_rounded, color: _T.crimson),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_t('nextUp'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _T.ink2)),
            const SizedBox(height: 2),
            Text(l.title, style: const TextStyle(fontFamily: _T.serif, fontSize: 18, fontWeight: FontWeight.w600, height: 1.25)),
            const SizedBox(height: 2),
            Text(left == 1 ? _t('stepsLeftOne') : _t('stepsLeft', {'n': left}),
                style: const TextStyle(fontSize: 13.5, color: _T.ink2)),
          ]),
        ),
      ]),
    );
  }

  Widget _emailCard() {
    return _Card(
      color: _T.mint,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.mail_outline_rounded, size: 22, color: _T.ink),
          const SizedBox(width: 10),
          Expanded(child: _SectionTitle(_t('emailTitle'))),
          _Chip(_t('emailSample'), color: _T.sticky),
        ]),
        const SizedBox(height: 12),
        Text(_t('emailBody', {'n': _data.activeDays}), style: const TextStyle(fontSize: 15, height: 1.5, color: _T.ink)),
      ]),
    );
  }
}

// =====================================================================
// Small private widgets
// =====================================================================

class _Card extends StatelessWidget {
  const _Card({required this.child, this.color = _T.paper});
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _T.ink.withValues(alpha: 0.06)),
          boxShadow: [BoxShadow(color: const Color(0xFF5C4A2A).withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: child,
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontFamily: _T.serif, fontSize: 20, height: 1.25, fontWeight: FontWeight.w600, color: _T.ink));
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, {required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _T.ink)),
      );
}

class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.activeColor,
    this.compact = false,
  });
  final T value;
  final List<(T, String, IconData)> items;
  final ValueChanged<T> onChanged;
  final Color activeColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: _T.sand, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min, children: [
        for (final (v, label, icon) in items)
          Flexible(
            fit: compact ? FlexFit.tight : FlexFit.loose,
            child: Semantics(
              button: true,
              selected: v == value,
              label: label,
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => onChanged(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: v == value ? activeColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon, size: 18, color: v == value ? Colors.white : _T.ink),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: v == value ? Colors.white : _T.ink)),
                    ),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
    return row;
  }
}

class _LangMenu extends StatelessWidget {
  const _LangMenu({required this.lang, required this.label, required this.onChanged});
  final ProgressLang lang;
  final String label;
  final ValueChanged<ProgressLang> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ProgressLang>(
      tooltip: label,
      initialValue: lang,
      onSelected: onChanged,
      color: _T.paper,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (_) => [
        for (final l in ProgressLang.values) PopupMenuItem(value: l, height: 48, child: Text(l.label)),
      ],
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: _T.paper, borderRadius: BorderRadius.circular(999), border: Border.all(color: _T.line)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.translate_rounded, size: 18, color: _T.ink),
          const SizedBox(width: 6),
          Text(lang.code, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const Icon(Icons.expand_more_rounded, size: 18, color: _T.ink),
        ]),
      ),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  const _StreakBadge({required this.days, required this.label, required this.caption});
  final int days;
  final String label;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$days $label',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _T.paper.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(color: _T.orange, shape: BoxShape.circle),
            child: const Icon(Icons.local_fire_department_rounded, size: 32, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text('$days',
                    style: const TextStyle(
                        fontFamily: _T.serif, fontSize: 34, height: 1, fontWeight: FontWeight.w700, color: _T.ink)),
                const SizedBox(width: 6),
                Flexible(child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
              ]),
              const SizedBox(height: 4),
              Text(caption, style: const TextStyle(fontSize: 13, height: 1.35, color: _T.ink2)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({required this.name, required this.minutes, required this.fraction, required this.isToday, required this.unit});
  final String name;
  final int minutes;
  final double fraction;
  final bool isToday;
  final String unit;

  @override
  Widget build(BuildContext context) {
    const maxBar = 88.0;
    final h = minutes == 0 ? 6.0 : 14 + (maxBar - 14) * fraction;
    return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
      Text(minutes == 0 ? '' : '$minutes',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _T.ink)),
      const SizedBox(height: 4),
      AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        width: 30,
        height: h,
        decoration: BoxDecoration(
          color: minutes == 0 ? _T.line : (isToday ? _T.crimson : _T.blue),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      const SizedBox(height: 8),
      Text(name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, fontWeight: isToday ? FontWeight.w700 : FontWeight.w500, color: isToday ? _T.crimsonDeep : _T.ink2)),
    ]);
  }
}

class _SubjectTile extends StatefulWidget {
  const _SubjectTile({super.key, required this.subject, required this.t, required this.initiallyOpen, required this.accent});
  final SubjectRecord subject;
  final String Function(String, [Map<String, Object>]) t;
  final bool initiallyOpen;
  final Color accent;

  @override
  State<_SubjectTile> createState() => _SubjectTileState();
}

class _SubjectTileState extends State<_SubjectTile> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final s = widget.subject;
    final t = widget.t;
    return Container(
      decoration: BoxDecoration(color: _T.cream, borderRadius: BorderRadius.circular(18)),
      child: Column(children: [
        Semantics(
          button: true,
          expanded: _open,
          label: '${s.name}. ${_open ? t('collapse') : t('expand')}',
          excludeSemantics: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Container(width: 10, height: 36, decoration: BoxDecoration(color: widget.accent, borderRadius: BorderRadius.circular(6))),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(s.name,
                        style: const TextStyle(fontFamily: _T.serif, fontSize: 18, fontWeight: FontWeight.w600))),
                AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.expand_more_rounded, size: 28)),
              ]),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (final topic in s.topics) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 22, bottom: 8, top: 2),
                        child: Text(topic.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _T.ink2)),
                      ),
                      for (final l in topic.lessons) _LessonRow(lesson: l, t: t),
                    ],
                  ]),
                )
              : const SizedBox(width: double.infinity),
        ),
      ]),
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({required this.lesson, required this.t});
  final LessonRecord lesson;
  final String Function(String, [Map<String, Object>]) t;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (lesson.check) {
      CheckStatus.passed => (t('passed'), _T.mint, Icons.check_circle_rounded),
      CheckStatus.needsPractice => (t('needsPractice'), _T.sticky, Icons.refresh_rounded),
      CheckStatus.notTaken => (t('notYet'), _T.sand, Icons.radio_button_unchecked_rounded),
    };
    final iconColor = lesson.check == CheckStatus.passed ? _T.success : _T.ink;
    final attempts = lesson.attempts == 0
        ? null
        : (lesson.attempts == 1 ? t('attemptOne') : t('attempts', {'n': lesson.attempts}));
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _T.paper, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(lesson.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.3)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: lesson.stepsTotal == 0 ? 0 : lesson.stepsDone / lesson.stepsTotal,
                minHeight: 6,
                backgroundColor: _T.sand,
                color: _T.blue,
              ),
            ),
            const SizedBox(height: 4),
            Text(t('steps', {'done': lesson.stepsDone, 'total': lesson.stepsTotal}),
                style: const TextStyle(fontSize: 13, color: _T.ink2)),
          ]),
        ),
        const SizedBox(width: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 176),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(t('unaided'), style: const TextStyle(fontSize: 13, color: _T.ink2)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: 5),
                Flexible(child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.2))),
              ]),
            ),
            if (attempts != null) ...[
              const SizedBox(height: 4),
              Text(attempts, style: const TextStyle(fontSize: 13, color: _T.ink2)),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _StrengthRow extends StatelessWidget {
  const _StrengthRow({required this.s, required this.notEnough, required this.basedOn});
  final BranchStrength s;
  final String notEnough;
  final String basedOn;

  @override
  Widget build(BuildContext context) {
    final strong = s.percent >= 70;
    final color = strong ? _T.success : (s.percent >= 40 ? _T.orange : _T.crimson);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(s.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
        if (s.hasEvidence)
          Text('${s.percent}%',
              style: TextStyle(fontFamily: _T.serif, fontSize: 18, fontWeight: FontWeight.w700, color: color)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          value: s.hasEvidence ? s.percent / 100 : 0,
          minHeight: 10,
          backgroundColor: _T.sand,
          color: color,
        ),
      ),
      const SizedBox(height: 4),
      Text(s.hasEvidence ? basedOn : '$notEnough · ${basedOn[0].toLowerCase()}${basedOn.substring(1)}',
          style: const TextStyle(fontSize: 13, color: _T.ink2)),
    ]);
  }
}
