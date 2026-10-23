import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const HabitFlowApp());

const ink = Color(0xFF101827);
const panel = Color(0xFF192438);
const lime = Color(0xFFC7F36B);
const mint = Color(0xFF71E0C2);
const muted = Color(0xFF8D9AB0);

class HabitFlowApp extends StatelessWidget {
  const HabitFlowApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'HabitFlow',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: ink,
          colorScheme: ColorScheme.fromSeed(
            seedColor: lime,
            brightness: Brightness.dark,
            surface: panel,
          ),
          fontFamily: 'Roboto',
        ),
        home: const HabitDashboard(),
      );
}

class HabitItem {
  HabitItem({
    required this.id,
    required this.title,
    required this.category,
    required this.icon,
    required this.description,
    required this.targetDays,
    this.done = const {},
  });

  final String id;
  final String title;
  final String category;
  final IconData icon;
  final String description;
  final List<int> targetDays; // DateTime weekday: Monday = 1
  Map<String, bool> done;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'icon': icon.codePoint,
        'description': description,
        'targetDays': targetDays,
        'done': done,
      };

  factory HabitItem.fromJson(Map<String, dynamic> json) => HabitItem(
        id: json['id'] as String,
        title: json['title'] as String,
        category: json['category'] as String? ?? 'Daily',
        icon: IconData(
          json['icon'] as int? ?? Icons.check_circle_outline.codePoint,
          fontFamily: 'MaterialIcons',
        ),
        description: json['description'] as String? ?? '',
        targetDays: (json['targetDays'] as List<dynamic>? ?? [1, 2, 3, 4, 5, 6, 7])
            .map((e) => (e as num).toInt())
            .toList(),
        done: Map<String, bool>.from(json['done'] as Map? ?? {}),
      );
}

String dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

DateTime startOfWeek(DateTime date) =>
    DateTime(date.year, date.month, date.day).subtract(Duration(days: date.weekday - 1));

String shortDate(DateTime date) => '${date.day}/${date.month}';

List<HabitItem> defaultHabits() => [
      HabitItem(id: 'walk', title: 'Brisk walk', category: 'Movement', icon: Icons.directions_walk_rounded, description: '20–30 min; start gently', targetDays: [1, 2, 3, 4, 5, 6, 7]),
      HabitItem(id: 'strength', title: 'Strength workout', category: 'Workout', icon: Icons.fitness_center_rounded, description: 'Beginner bodyweight routine', targetDays: [1, 3, 5]),
      HabitItem(id: 'mobility', title: 'Stretch & mobility', category: 'Movement', icon: Icons.self_improvement_rounded, description: '5–10 min, pain-free range', targetDays: [1, 2, 3, 4, 5, 6, 7]),
      HabitItem(id: 'breaks', title: 'Movement breaks', category: 'Daily', icon: Icons.timer_outlined, description: 'Stand or walk every 30–60 min', targetDays: [1, 2, 3, 4, 5, 6, 7]),
      HabitItem(id: 'water', title: 'Drink water regularly', category: 'Nutrition', icon: Icons.water_drop_outlined, description: 'Drink across the day; do not force excess', targetDays: [1, 2, 3, 4, 5, 6, 7]),
      HabitItem(id: 'protein', title: 'Balanced meals', category: 'Nutrition', icon: Icons.restaurant_outlined, description: 'Protein + vegetables/fruit + usual staple', targetDays: [1, 2, 3, 4, 5, 6, 7]),
      HabitItem(id: 'sugary', title: 'Skip sugary drinks', category: 'Nutrition', icon: Icons.no_drinks_outlined, description: 'Choose water most of the time', targetDays: [1, 2, 3, 4, 5, 6, 7]),
      HabitItem(id: 'sleep', title: 'Sleep routine', category: 'Recovery', icon: Icons.bedtime_outlined, description: 'Aim for 7–9 hours; keep a steady schedule', targetDays: [1, 2, 3, 4, 5, 6, 7]),
    ];

class HabitDashboard extends StatefulWidget {
  const HabitDashboard({super.key});
  @override
  State<HabitDashboard> createState() => _HabitDashboardState();
}

class _HabitDashboardState extends State<HabitDashboard> {
  List<HabitItem> habits = [];
  bool loading = true;
  int tab = 0;
  DateTime selectedDate = DateTime.now();
  final List<String> weekdays = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('habitflow_data_v1');
    if (raw != null) {
      try {
        habits = (jsonDecode(raw) as List<dynamic>)
            .map((item) => HabitItem.fromJson(Map<String, dynamic>.from(item as Map))
            ).toList();
      } catch (_) {
        habits = defaultHabits();
      }
    } else {
      habits = defaultHabits();
    }
    if (mounted) setState(() => loading = false);
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('habitflow_data_v1', jsonEncode(habits.map((h) => h.toJson()).toList()));
  }

  bool _isScheduled(HabitItem habit, DateTime date) => habit.targetDays.contains(date.weekday);
  bool _isDone(HabitItem habit, DateTime date) => habit.done[dateKey(date)] ?? false;

  void _toggle(HabitItem habit, DateTime date, bool value) {
    setState(() => habit.done[dateKey(date)] = value);
    _save();
  }

  double _weeklyRate(HabitItem habit) {
    final monday = startOfWeek(DateTime.now());
    final due = List.generate(7, (i) => monday.add(Duration(days: i)))
        .where((day) => _isScheduled(habit, day))
        .toList();
    if (due.isEmpty) return 0;
    final completed = due.where((day) => _isDone(habit, day)).length;
    return completed / due.length;
  }

  int get _todayDone => habits.where((h) => _isScheduled(h, selectedDate) && _isDone(h, selectedDate)).length;
  int get _todayDue => habits.where((h) => _isScheduled(h, selectedDate)).length;
  double get _todayRate => _todayDue == 0 ? 0 : _todayDone / _todayDue;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: lime)));
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1D2B3D), ink, Color(0xFF101D28)]),
        ),
        child: SafeArea(
          child: IndexedStack(
            index: tab,
            children: [_dashboard(), _weeklyPlan(), _guide()],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF141F2E),
        indicatorColor: lime.withOpacity(.16),
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_view_rounded), selectedIcon: Icon(Icons.grid_view_rounded, color: lime), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.calendar_month_rounded), selectedIcon: Icon(Icons.calendar_month_rounded, color: lime), label: 'This week'),
          NavigationDestination(icon: Icon(Icons.menu_book_rounded), selectedIcon: Icon(Icons.menu_book_rounded, color: lime), label: 'Guide'),
        ],
      ),
    );
  }

  Widget _dashboard() {
    final due = habits.where((h) => _isScheduled(h, selectedDate)).toList();
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 44, height: 44, decoration: BoxDecoration(color: lime, borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.bolt_rounded, color: ink, size: 28)),
                const SizedBox(width: 12),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('HABITFLOW', style: TextStyle(color: lime, letterSpacing: 2.5, fontSize: 11, fontWeight: FontWeight.w800)),
                  Text('Small steps. Real progress.', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ])),
                IconButton(onPressed: _addHabit, icon: const Icon(Icons.add_circle_outline_rounded, color: lime, size: 29), tooltip: 'Add habit'),
              ]),
              const SizedBox(height: 24),
              Text(_greeting(), style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: -.5)),
              const SizedBox(height: 5),
              Text('${_monthName(selectedDate.month)} ${selectedDate.day} • Your daily reset', style: const TextStyle(color: muted)),
              const SizedBox(height: 19),
              _heroCard(),
              const SizedBox(height: 20),
              _dateStrip(),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Today’s habits', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                Text('${due.where((h) => _isDone(h, selectedDate)).length}/${due.length} done', style: const TextStyle(color: lime, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 5),
              const Text('Tap a circle to mark a task complete.', style: TextStyle(color: muted, fontSize: 12)),
              const SizedBox(height: 12),
            ]),
          ),
        ),
        if (due.isEmpty)
          const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(28), child: Text('No scheduled tasks for this day.', textAlign: TextAlign.center, style: TextStyle(color: muted))))
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            sliver: SliverList(delegate: SliverChildBuilderDelegate(
              (context, index) => _habitCard(due[index]),
              childCount: due.length,
            )),
          ),
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), child: _bottomTip())),
      ],
    );
  }

  Widget _heroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(27),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFBFEF66), Color(0xFF8BDCB8)]),
        boxShadow: [BoxShadow(color: lime.withOpacity(.12), blurRadius: 28, offset: const Offset(0, 12))],
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('DAILY SCORE', style: TextStyle(color: Color(0xFF34442A), fontSize: 11, letterSpacing: 1.8, fontWeight: FontWeight.w900)),
          const SizedBox(height: 7),
          Text('${(_todayRate * 100).round()}%', style: const TextStyle(color: ink, fontSize: 43, fontWeight: FontWeight.w900, height: 1)),
          const SizedBox(height: 9),
          Text('$_todayDone of $_todayDue tasks completed', style: const TextStyle(color: Color(0xFF34442A), fontWeight: FontWeight.w600)),
          const SizedBox(height: 13),
          Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7), decoration: BoxDecoration(color: Colors.white.withOpacity(.45), borderRadius: BorderRadius.circular(20)), child: Text(_todayRate == 1 && _todayDue > 0 ? 'All done — nice work!' : 'Keep your pace steady', style: const TextStyle(color: ink, fontSize: 11, fontWeight: FontWeight.w800))),
        ])),
        SizedBox(
          width: 105,
          height: 105,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(width: 100, height: 100, child: CircularProgressIndicator(value: _todayRate, strokeWidth: 9, backgroundColor: ink.withOpacity(.1), valueColor: const AlwaysStoppedAnimation<Color>(ink), strokeCap: StrokeCap.round)),
            const Icon(Icons.bolt_rounded, size: 40, color: ink),
          ]),
        ),
      ]),
    );
  }

  Widget _dateStrip() {
    final monday = startOfWeek(DateTime.now());
    return Row(children: List.generate(7, (index) {
      final day = monday.add(Duration(days: index));
      final selected = dateKey(selectedDate) == dateKey(day);
      final dueCount = habits.where((h) => _isScheduled(h, day)).length;
      final doneCount = habits.where((h) => _isScheduled(h, day) && _isDone(h, day)).length;
      return Expanded(child: Padding(padding: EdgeInsets.only(right: index == 6 ? 0 : 7), child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => selectedDate = day),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(color: selected ? lime : panel.withOpacity(.9), borderRadius: BorderRadius.circular(16), border: Border.all(color: selected ? lime : Colors.white.withOpacity(.06))),
          child: Column(children: [
            Text(weekdays[index], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: selected ? ink : muted)),
            const SizedBox(height: 8),
            Text('${day.day}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: selected ? ink : Colors.white)),
            const SizedBox(height: 7),
            Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: dueCount > 0 && doneCount == dueCount ? (selected ? ink : lime) : (selected ? ink.withOpacity(.22) : Colors.white24))),
          ]),
        ),
      )));
    }));
  }

  Widget _habitCard(HabitItem habit) {
    final complete = _isDone(habit, selectedDate);
    final rate = _weeklyRate(habit);
    final monday = startOfWeek(DateTime.now());
    final dueCount = habit.targetDays.length;
    final doneCount = List.generate(7, (i) => monday.add(Duration(days: i)))
        .where((date) => _isScheduled(habit, date) && _isDone(habit, date)).length;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: panel.withOpacity(.91), borderRadius: BorderRadius.circular(22), border: Border.all(color: complete ? lime.withOpacity(.36) : Colors.white.withOpacity(.06))),
      child: Column(children: [
        Row(children: [
          Container(width: 47, height: 47, decoration: BoxDecoration(color: (complete ? lime : mint).withOpacity(.13), borderRadius: BorderRadius.circular(15)), child: Icon(habit.icon, color: complete ? lime : mint, size: 24)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(habit.title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, decoration: complete ? TextDecoration.lineThrough : null, color: complete ? muted : Colors.white)),
            const SizedBox(height: 4),
            Text(habit.description, style: const TextStyle(color: muted, fontSize: 11)),
          ])),
          const SizedBox(width: 8),
          InkWell(onTap: () => _toggle(habit, selectedDate, !complete), borderRadius: BorderRadius.circular(50), child: AnimatedContainer(duration: const Duration(milliseconds: 160), width: 34, height: 34, decoration: BoxDecoration(shape: BoxShape.circle, color: complete ? lime : Colors.transparent, border: Border.all(color: complete ? lime : muted, width: 1.5)), child: complete ? const Icon(Icons.check_rounded, color: ink, size: 22) : null)),
        ]),
        const SizedBox(height: 15),
        Row(children: [
          const Text('WEEKLY PROGRESS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.3, color: muted)),
          const Spacer(),
          Text('$doneCount/$dueCount days', style: const TextStyle(color: lime, fontSize: 11, fontWeight: FontWeight.w800)),
          const SizedBox(width: 7),
          Text('${(rate * 100).round()}%', style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: rate, minHeight: 6, backgroundColor: Colors.white.withOpacity(.07), valueColor: const AlwaysStoppedAnimation<Color>(lime))),
        const SizedBox(height: 10),
        Row(children: List.generate(7, (i) {
          final day = monday.add(Duration(days: i));
          final scheduled = _isScheduled(habit, day);
          final done = _isDone(habit, day);
          return Expanded(child: Center(child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(shape: BoxShape.circle, color: done ? lime : scheduled ? Colors.white.withOpacity(.06) : Colors.transparent, border: Border.all(color: done ? lime : scheduled ? Colors.white12 : Colors.transparent)),
            child: Center(child: Text(weekdays[i][0], style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: done ? ink : scheduled ? muted : Colors.white12))),
          )));
        })),
      ]),
    );
  }

  Widget _bottomTip() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF202D38), borderRadius: BorderRadius.circular(20)),
        child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.lightbulb_outline_rounded, color: lime),
          SizedBox(width: 11),
          Expanded(child: Text('Consistency beats intensity. Start with a comfortable pace and build gradually. You do not need a crash diet or extreme workouts.', style: TextStyle(color: Colors.white70, height: 1.45, fontSize: 12))),
        ]),
      );

  Widget _weeklyPlan() {
    final monday = startOfWeek(DateTime.now());
    const plan = [
      ('Monday', 'Walk + strength', '20–30 min walk • 2 sets each: chair squats, wall push-ups, glute bridges, plank'),
      ('Tuesday', 'Walk + mobility', '20–30 min walk • 5–10 min gentle stretching'),
      ('Wednesday', 'Strength day', '20–30 min walk • repeat the beginner strength routine'),
      ('Thursday', 'Active recovery', 'Easy walk • gentle mobility; no hard workout required'),
      ('Friday', 'Strength day', '20–30 min walk • strength routine if recovered'),
      ('Saturday', 'Enjoyable movement', 'Walk, cycle, or play a sport at a comfortable pace'),
      ('Sunday', 'Recovery & review', 'Easy movement or rest • review your weekly progress'),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        const Text('YOUR WEEK', style: TextStyle(color: lime, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2)),
        const SizedBox(height: 7),
        const Text('A balanced movement plan', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text('Start gently. Rest if sore, and do not exercise through pain.', style: TextStyle(color: muted, height: 1.4)),
        const SizedBox(height: 20),
        ...List.generate(7, (i) {
          final day = monday.add(Duration(days: i));
          final entry = plan[i];
          final todaysHabits = habits.where((h) => _isScheduled(h, day)).toList();
          final completed = todaysHabits.where((h) => _isDone(h, day)).length;
          final rate = todaysHabits.isEmpty ? 0.0 : completed / todaysHabits.length;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(21), border: Border.all(color: dateKey(day) == dateKey(DateTime.now()) ? lime.withOpacity(.5) : Colors.white.withOpacity(.06))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 43, height: 43, decoration: BoxDecoration(color: lime.withOpacity(.12), borderRadius: BorderRadius.circular(14)), child: Center(child: Text('${day.day}', style: const TextStyle(color: lime, fontWeight: FontWeight.w900, fontSize: 17)))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(entry.$1, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  Text(entry.$2, style: const TextStyle(color: lime, fontSize: 12, fontWeight: FontWeight.w700)),
                ])),
                Text('$completed/${todaysHabits.length}', style: const TextStyle(color: muted, fontSize: 12)),
              ]),
              const SizedBox(height: 12),
              Text(entry.$3, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.5)),
              const SizedBox(height: 12),
              ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: rate, minHeight: 5, backgroundColor: Colors.white10, valueColor: const AlwaysStoppedAnimation<Color>(lime))),
            ]),
          );
        }),
        _sectionNote(Icons.fitness_center_rounded, 'Beginner strength circuit', 'Chair/bodyweight squat: 2 × 8–10 • Wall push-up: 2 × 8–10 • Glute bridge: 2 × 10 • Plank: 2 × 10–20 seconds. Rest between sets; stop for sharp pain, dizziness or unusual shortness of breath.'),
        const SizedBox(height: 10),
        _sectionNote(Icons.trending_up_rounded, 'Progress gradually', 'Start at a level that feels comfortable. Add a few minutes of walking or a repetition only when the current routine feels easy. The long-term adult target is 150 minutes of moderate activity per week plus strength training at least twice weekly.'),
      ],
    );
  }

  Widget _guide() => ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          const Text('THE PLAYBOOK', style: TextStyle(color: lime, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 7),
          const Text('Habits that help', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('Your BMI is in the usual adult healthy range. Focus on fitness, strength and consistency—not rapid weight loss.', style: TextStyle(color: muted, height: 1.5)),
          const SizedBox(height: 20),
          _guideCard(Icons.check_circle_outline_rounded, lime, 'DO MORE OF', [
            'Walk most days and break up long sitting periods.',
            'Eat regular balanced meals; include protein, vegetables and fruit.',
            'Drink water regularly and use thirst as a guide.',
            'Keep a consistent sleep routine; adults usually need 7–9 hours.',
            'Track waist and energy trends weekly, not several times each day.',
            'Take rest days and adapt exercise to how you feel.',
          ]),
          const SizedBox(height: 13),
          _guideCard(Icons.block_rounded, const Color(0xFFFF9D88), 'AVOID', [
            'Crash diets, skipping meals or trying to lose weight rapidly.',
            'Expecting sit-ups or face exercises to remove fat from one place.',
            'Sugary drinks as your main source of hydration.',
            'Pushing through sharp pain, dizziness or unusual breathlessness.',
            'Comparing your face or body to edited social-media images.',
          ]),
          const SizedBox(height: 13),
          _guideCard(Icons.restaurant_menu_rounded, mint, 'SIMPLE PLATE GUIDE', [
            'Keep your regular rice/roti portion; no need to ban carbohydrates.',
            'Include dal, fish, eggs, chicken, tofu or another protein source.',
            'Add vegetables and fruit most days.',
            'Reduce frequent sugary drinks and ultra-processed snacks without strict bans.',
          ]),
          const SizedBox(height: 13),
          _guideCard(Icons.health_and_safety_outlined, const Color(0xFFFFCE78), 'SAFETY NOTES', [
            'Stop and seek medical advice if exercise causes chest pain, faintness or unusual breathlessness.',
            'Sudden facial swelling, especially with lip/tongue swelling or breathing trouble, needs urgent care.',
            'Habit tracking is not a diagnosis. If tiredness or unexplained swelling persists, speak to a clinician.',
          ]),
          const SizedBox(height: 18),
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: lime.withOpacity(.09), borderRadius: BorderRadius.circular(20), border: Border.all(color: lime.withOpacity(.2))), child: const Text('Your goal: show up consistently, build strength, and feel better. Missing a day is a reset—not a failure.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, height: 1.5))),
        ],
      );

  Widget _guideCard(IconData icon, Color color, String title, List<String> lines) => Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(21), border: Border.all(color: Colors.white.withOpacity(.06))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, color: color), const SizedBox(width: 9), Text(title, style: TextStyle(color: color, letterSpacing: 1.3, fontSize: 11, fontWeight: FontWeight.w900))]),
          const SizedBox(height: 12),
          ...lines.map((line) => Padding(padding: const EdgeInsets.only(bottom: 9), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.circle, color: color.withOpacity(.8), size: 6), const SizedBox(width: 10), Expanded(child: Text(line, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.45)))]))),
        ]),
      );

  Widget _sectionNote(IconData icon, String title, String description) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF202D38), borderRadius: BorderRadius.circular(20)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: lime),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(description, style: const TextStyle(color: Colors.white70, height: 1.5, fontSize: 12)),
          ])),
        ]),
      );

  Future<void> _addHabit() async {
    final title = TextEditingController();
    final description = TextEditingController();
    String category = 'Daily';
    final days = <int>{1, 2, 3, 4, 5, 6, 7};
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: panel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (context) => StatefulBuilder(builder: (context, setModal) => Padding(
        padding: EdgeInsets.fromLTRB(20, 22, 20, MediaQuery.of(context).viewInsets.bottom + 24),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Create a habit', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          TextField(controller: title, autofocus: true, decoration: const InputDecoration(labelText: 'Habit name', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: description, decoration: const InputDecoration(labelText: 'Small action / reminder', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: category, decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()), items: const ['Daily', 'Movement', 'Workout', 'Nutrition', 'Recovery', 'Study'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (value) => setModal(() => category = value ?? 'Daily')),
          const SizedBox(height: 14),
          const Text('Repeat on', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, children: List.generate(7, (i) => FilterChip(label: Text(weekdays[i]), selected: days.contains(i + 1), onSelected: (on) => setModal(() { on ? days.add(i + 1) : days.remove(i + 1); })))),
          const SizedBox(height: 18),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: () { if (title.text.trim().isEmpty || days.isEmpty) return; Navigator.pop(context, true); }, child: const Text('Save habit'))),
        ])),
      )),
    );
    if (result == true && title.text.trim().isNotEmpty && days.isNotEmpty) {
      setState(() => habits.add(HabitItem(id: DateTime.now().microsecondsSinceEpoch.toString(), title: title.text.trim(), category: category, icon: Icons.flag_outlined, description: description.text.trim().isEmpty ? 'Your custom habit' : description.text.trim(), targetDays: days.toList()..sort())));
      await _save();
    }
    title.dispose();
    description.dispose();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning.';
    if (hour < 17) return 'Good afternoon.';
    return 'Good evening.';
  }

  String _monthName(int month) => const ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][month - 1];
}
