import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _storageKey = 'mini_todo_flutter_items_v1';

void main() {
  runApp(const MiniTodoFlutterApp());
}

class MiniTodoFlutterApp extends StatelessWidget {
  const MiniTodoFlutterApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFFEF6C42);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '오늘의 할 일',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5EFE4),
        fontFamily: 'Apple SD Gothic Neo',
      ),
      home: const TodoHomePage(),
    );
  }
}

class TodoItem {
  const TodoItem({
    required this.id,
    required this.text,
    required this.completed,
  });

  final String id;
  final String text;
  final bool completed;

  TodoItem copyWith({String? id, String? text, bool? completed}) {
    return TodoItem(
      id: id ?? this.id,
      text: text ?? this.text,
      completed: completed ?? this.completed,
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'text': text, 'completed': completed};
  }

  factory TodoItem.fromMap(Map<String, dynamic> map) {
    return TodoItem(
      id:
          map['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      text: map['text']?.toString() ?? '',
      completed: map['completed'] == true,
    );
  }
}

class TodoHomePage extends StatefulWidget {
  const TodoHomePage({super.key});

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();

  List<TodoItem> _todos = const [];
  bool _loading = true;
  String? _editingId;
  String _message = '가볍게 하나부터 시작해요.';

  int get _completedCount => _todos.where((todo) => todo.completed).length;
  int get _remainingCount => _todos.length - _completedCount;

  String get _focusMessage {
    if (_remainingCount == 0 && _todos.isNotEmpty) {
      return '오늘 할 일을 모두 마쳤어요. 멋져요!';
    }
    if (_remainingCount > 0) {
      return '지금 $_remainingCount개 남았어요. 하나씩 끝내봐요.';
    }
    return '가볍게 하나부터 시작해요.';
  }

  bool get _isEditing => _editingId != null;

  @override
  void initState() {
    super.initState();
    _loadTodos();
  }

  @override
  void dispose() {
    _controller.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw == null || raw.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final items = decoded
            .whereType<Map>()
            .map((entry) => TodoItem.fromMap(Map<String, dynamic>.from(entry)))
            .where((item) => item.text.trim().isNotEmpty)
            .toList();

        if (!mounted) return;
        setState(() {
          _todos = items;
          _loading = false;
        });
        return;
      }
    } catch (_) {
      // Ignore and fall through to reset.
    }

    if (!mounted) return;
    setState(() {
      _todos = const [];
      _loading = false;
      _message = '저장된 데이터를 읽지 못해 목록을 초기화했어요.';
    });
  }

  Future<void> _persistTodos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_todos.map((todo) => todo.toMap()).toList()),
    );
  }

  Future<void> _submitTodo() async {
    final value = _controller.text.trim();

    if (value.isEmpty) {
      setState(() {
        _message = '할 일을 입력한 뒤 저장해 주세요.';
      });
      _inputFocusNode.requestFocus();
      return;
    }

    setState(() {
      if (_editingId != null) {
        _todos = _todos
            .map(
              (todo) =>
                  todo.id == _editingId ? todo.copyWith(text: value) : todo,
            )
            .toList();
        _message = '할 일을 수정했어요.';
      } else {
        _todos = [
          TodoItem(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            text: value,
            completed: false,
          ),
          ..._todos,
        ];
        _message = '할 일이 추가됐어요.';
      }

      _controller.clear();
      _editingId = null;
    });

    await _persistTodos();
    if (!mounted) return;
    _inputFocusNode.requestFocus();
  }

  void _startEdit(TodoItem todo) {
    setState(() {
      _editingId = todo.id;
      _controller.text = todo.text;
      _message = '수정 내용을 저장하거나 취소할 수 있어요.';
    });

    _inputFocusNode.requestFocus();
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
  }

  void _cancelEdit() {
    setState(() {
      _editingId = null;
      _controller.clear();
      _message = '수정을 취소했어요.';
    });

    _inputFocusNode.requestFocus();
  }

  Future<void> _toggleTodo(String id, bool? checked) async {
    final isCompleted = checked ?? false;

    setState(() {
      _todos = _todos
          .map(
            (todo) =>
                todo.id == id ? todo.copyWith(completed: isCompleted) : todo,
          )
          .toList();
      _message = isCompleted ? '완료 처리했어요.' : '다시 진행 중으로 바꿨어요.';
    });

    await _persistTodos();
  }

  Future<void> _deleteTodo(String id) async {
    if (!_todos.any((todo) => todo.id == id)) return;

    final wasEditing = _editingId == id;

    setState(() {
      _todos = _todos.where((todo) => todo.id != id).toList();
      _message = '할 일을 삭제했어요.';

      if (wasEditing) {
        _editingId = null;
        _controller.clear();
      }
    });

    await _persistTodos();
  }

  String _todayLabel() {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final now = DateTime.now();
    final weekday = weekdays[now.weekday - 1];
    return '${now.month}월 ${now.day}일 · $weekday요일';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 920;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 11,
                              child: _HeroPanel(
                                remainingCount: _remainingCount,
                                completedCount: _completedCount,
                                focusMessage: _focusMessage,
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 10,
                              child: _TodoPanel(
                                theme: theme,
                                todayLabel: _todayLabel(),
                                loading: _loading,
                                isEditing: _isEditing,
                                editingId: _editingId,
                                controller: _controller,
                                focusNode: _inputFocusNode,
                                message: _message,
                                todos: _todos,
                                onSubmit: _submitTodo,
                                onCancelEdit: _cancelEdit,
                                onToggleTodo: _toggleTodo,
                                onDeleteTodo: _deleteTodo,
                                onStartEdit: _startEdit,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _HeroPanel(
                              remainingCount: _remainingCount,
                              completedCount: _completedCount,
                              focusMessage: _focusMessage,
                            ),
                            const SizedBox(height: 20),
                            _TodoPanel(
                              theme: theme,
                              todayLabel: _todayLabel(),
                              loading: _loading,
                              isEditing: _isEditing,
                              editingId: _editingId,
                              controller: _controller,
                              focusNode: _inputFocusNode,
                              message: _message,
                              todos: _todos,
                              onSubmit: _submitTodo,
                              onCancelEdit: _cancelEdit,
                              onToggleTodo: _toggleTodo,
                              onDeleteTodo: _deleteTodo,
                              onStartEdit: _startEdit,
                            ),
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.remainingCount,
    required this.completedCount,
    required this.focusMessage,
  });

  final int remainingCount;
  final int completedCount;
  final String focusMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF7EC), Color(0xFFF5E9D8), Color(0xFFF0DFC8)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x223C2911),
            blurRadius: 40,
            offset: Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MONDAY MODE',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xFFEF6C42),
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '오늘의 할 일',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: const Color(0xFF1D1A17),
              fontWeight: FontWeight.w900,
              height: 0.98,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '지금 떠오른 일을 바로 적고, 끝난 일은 가볍게 체크하세요.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF6D655D),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _StatCard(label: '남은 일', value: '$remainingCount'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(label: '완료한 일', value: '$completedCount'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _StatCard(label: '오늘의 메시지', value: focusMessage, accent: true),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    this.accent = false,
  });

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: accent
            ? const LinearGradient(
                colors: [Color(0x33EF6C42), Color(0xCCFFFDF7)],
              )
            : const LinearGradient(
                colors: [Color(0xCCFFFDF7), Color(0xB3FFFFFF)],
              ),
        border: Border.all(color: const Color(0x1F1D1A17)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xFF6D655D),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: const Color(0xFF1D1A17),
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _TodoPanel extends StatelessWidget {
  const _TodoPanel({
    required this.theme,
    required this.todayLabel,
    required this.loading,
    required this.isEditing,
    required this.editingId,
    required this.controller,
    required this.focusNode,
    required this.message,
    required this.todos,
    required this.onSubmit,
    required this.onCancelEdit,
    required this.onToggleTodo,
    required this.onDeleteTodo,
    required this.onStartEdit,
  });

  final ThemeData theme;
  final String todayLabel;
  final bool loading;
  final bool isEditing;
  final String? editingId;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String message;
  final List<TodoItem> todos;
  final VoidCallback onSubmit;
  final VoidCallback onCancelEdit;
  final ValueChanged<TodoItem> onStartEdit;
  final ValueChanged<String> onDeleteTodo;
  final void Function(String id, bool? checked) onToggleTodo;

  @override
  Widget build(BuildContext context) {
    final sortedTodos = [
      ...todos.where((todo) => !todo.completed),
      ...todos.where((todo) => todo.completed),
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xCCFFFDF7),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xB3FFFFFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x223C2911),
            blurRadius: 40,
            offset: Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TODAY LIST',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: const Color(0xFFEF6C42),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '오늘의 체크리스트',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF1D1A17),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0x1F1D1A17)),
                ),
                child: Text(
                  todayLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF6D655D),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 420;

              if (stacked) {
                return Column(
                  children: [
                    _TodoInputField(
                      controller: controller,
                      focusNode: focusNode,
                      isEditing: isEditing,
                      onSubmitted: onSubmit,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: onSubmit,
                            child: Text(isEditing ? '저장' : '추가'),
                          ),
                        ),
                        if (isEditing) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: onCancelEdit,
                              child: const Text('취소'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _TodoInputField(
                      controller: controller,
                      focusNode: focusNode,
                      isEditing: isEditing,
                      onSubmitted: onSubmit,
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: onSubmit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(100, 56),
                    ),
                    child: Text(isEditing ? '저장' : '추가'),
                  ),
                  if (isEditing) ...[
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: onCancelEdit,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(100, 56),
                      ),
                      child: const Text('취소'),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFFEF6C42),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (sortedTodos.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0x141D1A17)),
              ),
              child: Column(
                children: [
                  Text(
                    '아직 등록된 할 일이 없어요.',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF1D1A17),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '가장 먼저 끝낼 작은 일을 하나 적어보세요.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF6D655D),
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sortedTodos.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final todo = sortedTodos[index];
                final isEditingThis = todo.id == editingId;

                return AnimatedContainer(
                  key: ValueKey('todo-item-${todo.id}'),
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: todo.completed
                        ? const Color(0x1F4F7D73)
                        : Colors.white.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isEditingThis
                          ? const Color(0x66EF6C42)
                          : const Color(0x141D1A17),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: todo.completed,
                        onChanged: (value) => onToggleTodo(todo.id, value),
                        activeColor: const Color(0xFF4F7D73),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                todo.text,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: const Color(0xFF1D1A17),
                                  height: 1.45,
                                  decoration: todo.completed
                                      ? TextDecoration.lineThrough
                                      : null,
                                  decorationThickness: 2,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilledButton.tonalIcon(
                                    onPressed: () => onStartEdit(todo),
                                    icon: const Icon(
                                      Icons.edit_rounded,
                                      size: 18,
                                    ),
                                    label: Text(
                                      isEditingThis ? '수정 중' : '수정하기',
                                    ),
                                    style: FilledButton.styleFrom(
                                      foregroundColor: const Color(0xFF1D1A17),
                                      backgroundColor: isEditingThis
                                          ? const Color(0x33EF6C42)
                                          : const Color(0x141D1A17),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      minimumSize: const Size(0, 42),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => onDeleteTodo(todo.id),
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('삭제'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF9C3D2B),
                                      side: const BorderSide(
                                        color: Color(0x559C3D2B),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      minimumSize: const Size(0, 42),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _TodoInputField extends StatelessWidget {
  const _TodoInputField({
    required this.controller,
    required this.focusNode,
    required this.isEditing,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isEditing;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      maxLength: 80,
      decoration: InputDecoration(
        counterText: '',
        hintText: isEditing ? '수정할 할 일을 입력하세요' : '예: 기획서 검토하기',
        filled: true,
        fillColor: const Color(0xFFFDFBF6),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: isEditing ? const Color(0x70EF6C42) : Colors.transparent,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xAAEF6C42), width: 1.4),
        ),
      ),
      onSubmitted: (_) => onSubmitted(),
    );
  }
}
