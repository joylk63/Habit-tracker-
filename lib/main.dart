import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const AdvancedHabitTrackerApp());
}

class AdvancedHabitTrackerApp extends StatelessWidget {
  const AdvancedHabitTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Emerald Habit Tracker',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF07130E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF10B981),
          surface: Color(0xFF0F261C),
          onSurface: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: const MainHomeScreen(),
    );
  }
}

// ------------------- MODELS -------------------

enum HabitType { yesNo, target }

class Habit {
  final String id;
  final String title;
  final String category;
  final HabitType type;
  final double targetGoal;
  final String unit;
  final Map<String, double> progressRecords;

  Habit({
    required this.id,
    required this.title,
    required this.category,
    required this.type,
    this.targetGoal = 1.0,
    this.unit = '',
    required this.progressRecords,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'type': type.index,
      'targetGoal': targetGoal,
      'unit': unit,
      'progressRecords': progressRecords,
    };
  }

  factory Habit.fromMap(Map<String, dynamic> map) {
    return Habit(
      id: map['id'],
      title: map['title'],
      category: map['category'] ?? 'General',
      type: HabitType.values[map['type'] ?? 0],
      targetGoal: (map['targetGoal'] as num?)?.toDouble() ?? 1.0,
      unit: map['unit'] ?? '',
      progressRecords: Map<String, double>.from(map['progressRecords'] ?? {}),
    );
  }

  int get currentStreak {
    int streak = 0;
    DateTime checkDate = DateTime.now();
    String todayStr = _formatDate(checkDate);

    if ((progressRecords[todayStr] ?? 0) < targetGoal) {
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    while (true) {
      String dateStr = _formatDate(checkDate);
      double val = progressRecords[dateStr] ?? 0;
      if (val >= targetGoal) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  int get bestStreak {
    if (progressRecords.isEmpty) return 0;
    List<String> sortedDates = progressRecords.keys.toList()..sort();
    int maxStreak = 0;
    int current = 0;
    DateTime? prevDate;

    for (String dStr in sortedDates) {
      if ((progressRecords[dStr] ?? 0) >= targetGoal) {
        DateTime date = DateTime.parse(dStr);
        if (prevDate != null && date.difference(prevDate).inDays == 1) {
          current++;
        } else {
          current = 1;
        }
        prevDate = date;
        if (current > maxStreak) maxStreak = current;
      }
    }
    return maxStreak;
  }

  static String _formatDate(DateTime dt) => dt.toIso8601String().split('T')[0];
}

// ------------------- UI COMPONENTS (GLASSMORPHISM) -------------------

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? borderColor;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 20.0,
    this.padding,
    this.margin,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF132F23).withOpacity(0.65),
                  const Color(0xFF091711).withOpacity(0.45),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: borderColor ?? Colors.emerald.withOpacity(0.25),
                width: 1.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class GlassButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;
  final Color color;
  final double borderRadius;

  const GlassButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.color = const Color(0xFF10B981),
    this.borderRadius = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(borderRadius),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                gradient: LinearGradient(
                  colors: [
                    color.withOpacity(0.4),
                    color.withOpacity(0.15),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: color.withOpacity(0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 12,
                    spreadRadius: 1,
                  )
                ],
              ),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
// ------------------- MAIN SCREEN -------------------

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  List<Habit> _habits = [];
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Health',
    'Study',
    'Fitness',
    'Mindfulness',
    'Finance'
  ];

  @override
  void initState() {
    super.initState();
    _loadHabits();
  }

  String get _todayStr => DateTime.now().toIso8601String().split('T')[0];

  Future<void> _loadHabits() async {
    final prefs = await SharedPreferences.getInstance();
    final String? rawData = prefs.getString('advanced_habits_v2');
    if (rawData != null) {
      final List<dynamic> decoded = jsonDecode(rawData);
      setState(() {
        _habits = decoded.map((e) => Habit.fromMap(e)).toList();
      });
    }
  }

  Future<void> _saveHabits() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_habits.map((h) => h.toMap()).toList());
    await prefs.setString('advanced_habits_v2', encoded);
  }

  void _updateHabitProgress(String id, double value) {
    setState(() {
      final habit = _habits.firstWhere((h) => h.id == id);
      habit.progressRecords[_todayStr] = value;
    });
    _saveHabits();
  }

  void _deleteHabit(String id) {
    setState(() {
      _habits.removeWhere((h) => h.id == id);
    });
    _saveHabits();
  }

  double get _overallCompletionRate {
    if (_habits.isEmpty) return 0.0;
    int completed = 0;
    for (var h in _habits) {
      if ((h.progressRecords[_todayStr] ?? 0) >= h.targetGoal) {
        completed++;
      }
    }
    return completed / _habits.length;
  }

  @override
  Widget build(BuildContext context) {
    final filteredHabits = _selectedCategory == 'All'
        ? _habits
        : _habits.where((h) => h.category == _selectedCategory).toList();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.8, -0.6),
            radius: 1.2,
            colors: [
              Color(0xFF133E2B),
              Color(0xFF07130E),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DAILY TRACKER',
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 2.0,
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Dashboard',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    GlassButton(
                      borderRadius: 30,
                      onPressed: () => _showAddHabitModal(context),
                      child: const Row(
                        children: [
                          Icon(Icons.add, color: Colors.white, size: 20),
                          SizedBox(width: 4),
                          Text(
                            'New Habit',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: GlassContainer(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Today's Overall Progress",
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          Text(
                            '${(_overallCompletionRate * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: _overallCompletionRate,
                          minHeight: 10,
                          backgroundColor: Colors.black45,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        selectedColor: const Color(0xFF10B981).withOpacity(0.3),
                        backgroundColor: const Color(0xFF0F261C).withOpacity(0.5),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.emeraldAccent : Colors.white60,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? const Color(0xFF10B981)
                              : Colors.white12,
                        ),
                        onSelected: (_) => setState(() => _selectedCategory = cat),
                      ),
                    );
                  },
                ),
              ),

              Expanded(
                child: filteredHabits.isEmpty
                    ? const Center(
                        child: Text(
                          'No habits created yet!\nClick the button above to add one.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white38, fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        itemCount: filteredHabits.length,
                        itemBuilder: (context, index) {
                                                    final habit = filteredHabits[index];
                          final currentVal = habit.progressRecords[_todayStr] ?? 0.0;
                          final isDone = currentVal >= habit.targetGoal;

                          return GlassContainer(
                            margin: const EdgeInsets.only(bottom: 12),
                            borderColor: isDone
                                ? const Color(0xFF10B981).withOpacity(0.5)
                                : Colors.white10,
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            habit.title,
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              decoration: isDone
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                              color: isDone
                                                  ? Colors.white54
                                                  : Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.white10,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  habit.category,
                                                  style: const TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.emeraldAccent),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                '🔥 Streak: ${habit.currentStreak}d  |  🏆 Best: ${habit.bestStreak}d',
                                                style: const TextStyle(
                                                    fontSize: 12, color: Colors.white54),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.analytics_outlined,
                                          color: Colors.white60),
                                      onPressed: () => _showAnalyticsModal(context, habit),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.redAccent),
                                      onPressed: () => _deleteHabit(habit.id),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (habit.type == HabitType.yesNo)
                                  GlassButton(
                                    color: isDone ? Colors.green : const Color(0xFF10B981),
                                    onPressed: () {
                                      _updateHabitProgress(
                                          habit.id, isDone ? 0.0 : 1.0);
                                    },
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          isDone
                                              ? Icons.check_circle
                                              : Icons.circle_outlined,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          isDone ? 'Completed' : 'Mark as Done',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline,
                                            color: Colors.emeraldAccent),
                                        onPressed: currentVal > 0
                                            ? () => _updateHabitProgress(
                                                habit.id, currentVal - 1)
                                            : null,
                                      ),
                                      Expanded(
                                        child: Column(
                                          children: [
                                            Text(
                                              '${currentVal.toInt()} / ${habit.targetGoal.toInt()} ${habit.unit}',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white),
                                            ),
                                            const SizedBox(height: 4),
                                            LinearProgressIndicator(
                                              value: (currentVal / habit.targetGoal)
                                                  .clamp(0.0, 1.0),
                                              color: const Color(0xFF10B981),
                                              backgroundColor: Colors.black38,
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline,
                                            color: Colors.emeraldAccent),
                                        onPressed: () => _updateHabitProgress(
                                            habit.id, currentVal + 1),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddHabitModal(BuildContext context) {
    final titleController = TextEditingController();
    final targetController = TextEditingController(text: '1');
    final unitController = TextEditingController(text: 'times');
    String category = 'Health';
    HabitType type = HabitType.yesNo;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => GlassContainer(
          borderRadius: 30,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 10,
            right: 10,
            top: 50,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add New Habit',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.emeraldAccent)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Habit Title (e.g., Drink Water)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: category,
                          items: _categories
                              .where((c) => c != 'All')
                              .map((c) =>
                                  DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) => setModalState(() => category = v!),
                          decoration:
                              const InputDecoration(labelText: 'Category'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<HabitType>(
                          value: type,
                          items: const [
                            DropdownMenuItem(
                                value: HabitType.yesNo, child: Text('Yes / No')),
                            DropdownMenuItem(
                                value: HabitType.target, child: Text('Target Goal')),
                          ],
                          onChanged: (v) => setModalState(() => type = v!),
                          decoration:
                              const InputDecoration(labelText: 'Type'),
                        ),
                      ),
                    ],
                  ),
                  if (type == HabitType.target) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: targetController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Target Goal'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: unitController,
                            decoration:
                                const InputDecoration(labelText: 'Unit (e.g., ml, pages)'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  GlassButton(
                    onPressed: () {
                      if (titleController.text.trim().isEmpty) return;
                      final habit = Habit(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        title: titleController.text.trim(),
                        category: category,
                        type: type,
                        targetGoal:
                            double.tryParse(targetController.text) ?? 1.0,
                        unit: unitController.text.trim(),
                        progressRecords: {},
                      );
                      setState(() => _habits.add(habit));
                      _saveHabits();
                      Navigator.pop(context);
                    },
                    child: const Text('Create Habit',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAnalyticsModal(BuildContext context, Habit habit) {
    final last14Days = List.generate(
      14,
      (i) => DateTime.now().subtract(Duration(days: 13 - i)),
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassContainer(
        borderRadius: 30,
        margin: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${habit.title} Analytics',
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.emeraldAccent)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatBox('Current Streak', '${habit.currentStreak} Days'),
                _buildStatBox('Best Streak', '${habit.bestStreak} Days'),
                _buildStatBox('Total Done', '${habit.progressRecords.length} Days'),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Last 14 Days Tracking History',
                style: TextStyle(fontSize: 14, color: Colors.white70)),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: last14Days.map((d) {
                  String dStr = d.toIso8601String().split('T')[0];
                  bool isDone = (habit.progressRecords[dStr] ?? 0) >= habit.targetGoal;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: isDone ? const Color(0xFF10B981) : Colors.white10,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: isDone
                              ? const Icon(Icons.check, size: 14, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(height: 4),
                        Text('${d.day}/${d.month}',
                            style: const TextStyle(fontSize: 10, color: Colors.white38)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 10, color: Colors.white54)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.emeraldAccent)),
        ],
      ),
    );
  }
}
