import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/task.dart';

const Color kPrimary = Color(0xFF6750A4);
const Color kBackground = Color(0xFFF7F5FC);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TaskFlowApp());
}

class TaskFlowApp extends StatelessWidget {
  const TaskFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: kPrimary,
      brightness: Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'مهامي',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: kBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: kBackground,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE9E5F1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: kPrimary, width: 1.5),
          ),
        ),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: HomeScreen(),
      ),
    );
  }
}

enum TaskFilter { all, pending, completed }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _storageKey = 'taskflow_tasks_v1';

  List<Task> _tasks = [];
  TaskFilter _filter = TaskFilter.all;
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _tasks = decoded
            .map((item) => Task.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ))
            .toList();
      }
    } catch (_) {
      _tasks = [];
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_tasks.map((task) => task.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  List<Task> get _visibleTasks {
    return _tasks.where((task) {
      final matchesFilter = switch (_filter) {
        TaskFilter.all => true,
        TaskFilter.pending => !task.isCompleted,
        TaskFilter.completed => task.isCompleted,
      };

      final query = _searchQuery.trim().toLowerCase();
      final matchesSearch = query.isEmpty ||
          task.title.toLowerCase().contains(query) ||
          task.description.toLowerCase().contains(query);

      return matchesFilter && matchesSearch;
    }).toList()
      ..sort((a, b) {
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        return b.createdAt.compareTo(a.createdAt);
      });
  }

  int get _completedCount => _tasks.where((task) => task.isCompleted).length;
  int get _pendingCount => _tasks.length - _completedCount;

  Future<void> _openTaskForm({Task? task}) async {
    final result = await showModalBottomSheet<Task>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TaskFormSheet(task: task),
    );

    if (result == null) return;

    setState(() {
      final index = _tasks.indexWhere((item) => item.id == result.id);
      if (index == -1) {
        _tasks.insert(0, result);
      } else {
        _tasks[index] = result;
      }
    });

    await _saveTasks();
    if (!mounted) return;
    _showMessage(task == null ? 'تمت إضافة المهمة' : 'تم تحديث المهمة');
  }

  Future<void> _toggleTask(Task task, bool value) async {
    setState(() {
      final index = _tasks.indexWhere((item) => item.id == task.id);
      if (index != -1) {
        _tasks[index] = _tasks[index].copyWith(isCompleted: value);
      }
    });
    await _saveTasks();
  }

  Future<void> _deleteTask(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف المهمة؟'),
        content: Text('هل تريد حذف «${task.title}» نهائياً؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB3261E),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _tasks.removeWhere((item) => item.id == task.id));
    await _saveTasks();
    if (mounted) _showMessage('تم حذف المهمة');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _tasks.isEmpty ? 0.0 : _completedCount / _tasks.length;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'مساحة إنجازك',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            SizedBox(height: 2),
            Text(
              'مهامي',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsetsDirectional.only(end: 16),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEDE7F6),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.checklist_rounded, color: kPrimary),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTaskForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('مهمة جديدة'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
                      children: [
                        _buildWelcomeCard(progress),
                        const SizedBox(height: 22),
                        _buildSectionHeader(),
                        const SizedBox(height: 12),
                        _buildSearchField(),
                        const SizedBox(height: 14),
                        _buildFilters(),
                        const SizedBox(height: 14),
                        if (_visibleTasks.isEmpty)
                          _buildEmptyState()
                        else
                          ..._visibleTasks.map(
                            (task) => Padding(
                              padding: const EdgeInsets.only(bottom: 11),
                              child: TaskCard(
                                task: task,
                                onChanged: (value) =>
                                    _toggleTask(task, value),
                                onEdit: () => _openTaskForm(task: task),
                                onDelete: () => _deleteTask(task),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildWelcomeCard(double progress) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7056B3), Color(0xFF493581)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withOpacity(.20),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'خطوة صغيرة كل يوم تصنع فرقاً كبيراً ✨',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _tasks.isEmpty
                ? 'أضف أول مهمة وابدأ يومك بإنجاز.'
                : 'واصل التقدم، أنت تقوم بعمل رائع!',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _statItem('كل المهام', _tasks.length.toString()),
              const SizedBox(width: 25),
              _statItem('قيد التنفيذ', _pendingCount.toString()),
              const SizedBox(width: 25),
              _statItem('مكتملة', _completedCount.toString()),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFFFD98A),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '${(progress * 100).round()}% من المهام مكتملة',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 23,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _buildSectionHeader() {
    return const Row(
      children: [
        Text(
          'قائمة المهام',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
        Spacer(),
        Icon(Icons.tune_rounded, color: kPrimary, size: 20),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      textDirection: TextDirection.rtl,
      onChanged: (value) => setState(() => _searchQuery = value),
      decoration: const InputDecoration(
        hintText: 'ابحث عن مهمة...',
        prefixIcon: Icon(Icons.search_rounded),
        contentPadding: EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }

  Widget _buildFilters() {
    final filters = [
      (TaskFilter.all, 'الكل', _tasks.length),
      (TaskFilter.pending, 'غير مكتملة', _pendingCount),
      (TaskFilter.completed, 'مكتملة', _completedCount),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((item) {
          final selected = _filter == item.$1;
          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: ChoiceChip(
              selected: selected,
              showCheckmark: false,
              label: Text('${item.$2} (${item.$3})'),
              onSelected: (_) => setState(() => _filter = item.$1),
              selectedColor: kPrimary,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: selected ? Colors.white : const Color(0xFF625D6B),
                fontWeight: FontWeight.w600,
              ),
              side: BorderSide(
                color: selected ? kPrimary : const Color(0xFFE9E5F1),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasSearch = _searchQuery.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(
            hasSearch ? Icons.search_off_rounded : Icons.task_alt_rounded,
            size: 52,
            color: const Color(0xFFB8ACD5),
          ),
          const SizedBox(height: 12),
          Text(
            hasSearch ? 'لا توجد نتائج' : 'لا توجد مهام هنا بعد',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            hasSearch
                ? 'جرّب كلمة بحث أخرى.'
                : 'أضف مهمة جديدة لتنظيم يومك.',
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class TaskCard extends StatelessWidget {
  final Task task;
  final ValueChanged<bool> onChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const TaskCard({
    super.key,
    required this.task,
    required this.onChanged,
    required this.onEdit,
    required this.onDelete,
  });

  Color get priorityColor {
    switch (task.priority) {
      case TaskPriority.low:
        return const Color(0xFF23865A);
      case TaskPriority.medium:
        return const Color(0xFFB7791F);
      case TaskPriority.high:
        return const Color(0xFFC04444);
    }
  }

  String get priorityLabel {
    switch (task.priority) {
      case TaskPriority.low:
        return 'منخفضة';
      case TaskPriority.medium:
        return 'متوسطة';
      case TaskPriority.high:
        return 'عالية';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: task.isCompleted
              ? const Color(0xFFE6E3EA)
              : const Color(0xFFF0EDF5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.025),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: task.isCompleted,
              onChanged: (value) => onChanged(value ?? false),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        color: task.isCompleted
                            ? Colors.black45
                            : const Color(0xFF292531),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      task.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF77727F),
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 7,
                      runSpacing: 5,
                      children: [
                        _smallTag(
                          task.isCompleted ? 'مكتملة' : 'قيد التنفيذ',
                          task.isCompleted
                              ? const Color(0xFFE4F3EA)
                              : const Color(0xFFEDE7F6),
                          task.isCompleted
                              ? const Color(0xFF23865A)
                              : kPrimary,
                        ),
                        _smallTag(
                          'أولوية $priorityLabel',
                          priorityColor.withOpacity(.11),
                          priorityColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'خيارات المهمة',
              icon: const Icon(Icons.more_vert_rounded, color: Colors.black54),
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 19),
                      SizedBox(width: 9),
                      Text('تعديل'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red, size: 19),
                      SizedBox(width: 9),
                      Text('حذف'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallTag(String text, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class TaskFormSheet extends StatefulWidget {
  final Task? task;

  const TaskFormSheet({super.key, this.task});

  @override
  State<TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends State<TaskFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late TaskPriority _priority;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.task?.description ?? '');
    _priority = widget.task?.priority ?? TaskPriority.medium;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final oldTask = widget.task;
    final result = Task(
      id: oldTask?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      priority: _priority,
      isCompleted: oldTask?.isCompleted ?? false,
      createdAt: oldTask?.createdAt ?? DateTime.now(),
    );

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: kBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  widget.task == null ? 'إضافة مهمة جديدة' : 'تعديل المهمة',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'أدخل تفاصيل المهمة وحدد مستوى أولويتها.',
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _titleController,
                  autofocus: true,
                  maxLength: 60,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'عنوان المهمة',
                    hintText: 'مثال: مراجعة درس Flutter',
                    prefixIcon: Icon(Icons.title_rounded),
                    counterText: '',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'يرجى إدخال عنوان المهمة';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 13),
                TextFormField(
                  controller: _descriptionController,
                  maxLength: 250,
                  minLines: 3,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'وصف المهمة',
                    hintText: 'اكتب وصفاً مختصراً للمهمة...',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'يرجى إدخال وصف المهمة';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 13),
                DropdownButtonFormField<TaskPriority>(
                  value: _priority,
                  decoration: const InputDecoration(
                    labelText: 'الأولوية',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: TaskPriority.low,
                      child: Text('منخفضة'),
                    ),
                    DropdownMenuItem(
                      value: TaskPriority.medium,
                      child: Text('متوسطة'),
                    ),
                    DropdownMenuItem(
                      value: TaskPriority.high,
                      child: Text('عالية'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _priority = value);
                  },
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(widget.task == null ? 'إضافة المهمة' : 'حفظ التعديلات'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
