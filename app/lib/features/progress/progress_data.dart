/// Data for the "My progress" page. Shaped after what the server already
/// stores (sessions, steps, unaided-check results) so `GET /progress` can be
/// mapped onto it later. Until then [ProgressData.sample] seeds the demo.
library;

enum CheckStatus { passed, needsPractice, notTaken }

class LessonRecord {
  const LessonRecord({
    required this.title,
    required this.stepsDone,
    required this.stepsTotal,
    required this.check,
    this.attempts = 0,
  });

  final String title;
  final int stepsDone;
  final int stepsTotal;

  /// Result of the unaided check (no hints, no tutor blanks filled in).
  final CheckStatus check;
  final int attempts;
}

class TopicRecord {
  const TopicRecord({required this.name, required this.lessons});
  final String name;
  final List<LessonRecord> lessons;
}

class SubjectRecord {
  const SubjectRecord({required this.name, required this.topics});
  final String name;
  final List<TopicRecord> topics;
}

class DayActivity {
  const DayActivity({required this.date, required this.minutes});
  final DateTime date;
  final int minutes;
  bool get active => minutes > 0;
}

/// Strength by branch of a topic. Shown only with enough evidence.
class BranchStrength {
  const BranchStrength({required this.label, required this.percent, required this.attempts});
  final String label;
  final int percent;
  final int attempts;

  static const minAttempts = 3;
  bool get hasEvidence => attempts >= minAttempts;
}

class ProgressData {
  const ProgressData({
    required this.studentName,
    required this.today,
    required this.week,
    required this.subjects,
    required this.strengths,
    this.isSample = true,
  });

  final String studentName;
  final DateTime today;

  /// Last 7 days, oldest first, ending today.
  final List<DayActivity> week;
  final List<SubjectRecord> subjects;
  final List<BranchStrength> strengths;

  /// True while strengths and records are seeded demo data.
  final bool isSample;

  int get activeDays => week.where((d) => d.active).length;

  int get streak => currentStreak(week.where((d) => d.active).map((d) => d.date), today);

  /// Seeded demo data. Demo names only, no real student records.
  factory ProgressData.sample({DateTime? today}) {
    final t = _day(today ?? DateTime.now());
    // Oldest first. A gap four days ago shows that a miss resets the streak.
    const minutes = [18, 0, 12, 25, 9, 20, 14];
    final week = [
      for (var i = 0; i < 7; i++) DayActivity(date: t.subtract(Duration(days: 6 - i)), minutes: minutes[i]),
    ];
    return ProgressData(
      studentName: 'Ada',
      today: t,
      week: week,
      subjects: const [
        SubjectRecord(name: 'Mathematics', topics: [
          TopicRecord(name: 'Quadratic equations', lessons: [
            LessonRecord(
                title: 'Factorising x² + 5x + 6',
                stepsDone: 5,
                stepsTotal: 5,
                check: CheckStatus.passed,
                attempts: 2),
            LessonRecord(
                title: 'Finding the roots',
                stepsDone: 3,
                stepsTotal: 4,
                check: CheckStatus.needsPractice,
                attempts: 3),
            LessonRecord(
                title: 'Reading the graph',
                stepsDone: 0,
                stepsTotal: 3,
                check: CheckStatus.notTaken),
          ]),
        ]),
        SubjectRecord(name: 'Physics', topics: [
          TopicRecord(name: 'Friction', lessons: [
            LessonRecord(
                title: 'Pushing a crate',
                stepsDone: 4,
                stepsTotal: 4,
                check: CheckStatus.passed,
                attempts: 1),
            LessonRecord(
                title: 'Changing the surface',
                stepsDone: 1,
                stepsTotal: 4,
                check: CheckStatus.notTaken),
          ]),
        ]),
      ],
      strengths: const [
        BranchStrength(label: 'Factorising', percent: 85, attempts: 6),
        BranchStrength(label: 'Finding roots', percent: 55, attempts: 4),
        BranchStrength(label: 'Reading the graph', percent: 0, attempts: 1),
      ],
    );
  }
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// A normal streak: consecutive days with learning, ending today. If today has
/// no activity yet but yesterday did, the streak is still alive (the day is not
/// over). One missed full day resets it to zero.
int currentStreak(Iterable<DateTime> activeDays, DateTime today) {
  final set = activeDays.map(_day).toSet();
  var cursor = _day(today);
  if (!set.contains(cursor)) cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  var n = 0;
  while (set.contains(cursor)) {
    n++;
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  return n;
}
