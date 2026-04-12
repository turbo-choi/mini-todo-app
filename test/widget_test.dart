import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_todo_flutter_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _storageKey = 'mini_todo_flutter_items_v1';

void main() {
  testWidgets('renders todo app shell', (WidgetTester tester) async {
    await _pumpApp(tester);

    expect(find.text('오늘의 할 일'), findsWidgets);
    expect(find.text('오늘의 체크리스트'), findsOneWidget);
    expect(find.text('아직 등록된 할 일이 없어요.'), findsOneWidget);
  });

  testWidgets('adds a todo and persists it', (WidgetTester tester) async {
    await _pumpApp(tester);

    await tester.enterText(find.byType(TextField), '기획서 검토하기');
    final addButton = find.widgetWithText(FilledButton, '추가');
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(find.text('기획서 검토하기'), findsOneWidget);
    expect(find.text('할 일이 추가됐어요.'), findsOneWidget);

    final storedTodos = await _readStoredTodos();
    expect(storedTodos, hasLength(1));
    expect(storedTodos.single['text'], '기획서 검토하기');
    expect(storedTodos.single['completed'], isFalse);
  });

  testWidgets('edits only the selected todo', (WidgetTester tester) async {
    await _pumpApp(
      tester,
      storedTodos: _encodeTodos([
        {'id': 'todo-1', 'text': '기획서 검토하기', 'completed': false},
        {'id': 'todo-2', 'text': '운동하기', 'completed': false},
      ]),
    );

    final firstEditButton = find.widgetWithText(FilledButton, '수정하기').first;
    await tester.ensureVisible(firstEditButton);
    await tester.tap(firstEditButton);
    await tester.pumpAndSettle();

    expect(find.text('수정 중'), findsOneWidget);
    expect(find.text('수정하기'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '기획서 다시 보기');
    final saveButton = find.widgetWithText(FilledButton, '저장');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('기획서 검토하기'), findsNothing);
    expect(find.text('기획서 다시 보기'), findsOneWidget);
    expect(find.text('운동하기'), findsOneWidget);

    final storedTodos = await _readStoredTodos();
    expect(storedTodos.first['text'], '기획서 다시 보기');
    expect(storedTodos.last['text'], '운동하기');
  });

  testWidgets('toggles completion and persists it', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      storedTodos: _encodeTodos([
        {'id': 'todo-1', 'text': '기획서 검토하기', 'completed': false},
      ]),
    );

    final firstCheckbox = find.byType(Checkbox).first;
    await tester.ensureVisible(firstCheckbox);
    await tester.tap(firstCheckbox);
    await tester.pumpAndSettle();

    expect(find.text('완료 처리했어요.'), findsOneWidget);

    final storedTodos = await _readStoredTodos();
    expect(storedTodos.single['completed'], isTrue);
  });

  testWidgets('shows remaining todos above completed todos', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      storedTodos: _encodeTodos([
        {'id': 'todo-1', 'text': '운동하기', 'completed': false},
        {'id': 'todo-2', 'text': '기획서 검토하기', 'completed': false},
      ]),
    );

    final firstCheckbox = find.byType(Checkbox).first;
    await tester.ensureVisible(firstCheckbox);
    await tester.tap(firstCheckbox);
    await tester.pumpAndSettle();

    final activeTodo = find.byKey(const ValueKey('todo-item-todo-2'));
    final completedTodo = find.byKey(const ValueKey('todo-item-todo-1'));

    await tester.ensureVisible(activeTodo);

    expect(
      tester.getTopLeft(activeTodo).dy,
      lessThan(tester.getTopLeft(completedTodo).dy),
    );
  });

  testWidgets('deletes a todo and persists the remaining list', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      storedTodos: _encodeTodos([
        {'id': 'todo-1', 'text': '기획서 검토하기', 'completed': false},
        {'id': 'todo-2', 'text': '운동하기', 'completed': true},
      ]),
    );

    final firstDeleteButton = find.widgetWithText(OutlinedButton, '삭제').first;
    await tester.ensureVisible(firstDeleteButton);
    await tester.tap(firstDeleteButton);
    await tester.pumpAndSettle();

    expect(find.text('기획서 검토하기'), findsNothing);
    expect(find.text('운동하기'), findsOneWidget);
    expect(find.text('할 일을 삭제했어요.'), findsOneWidget);

    final storedTodos = await _readStoredTodos();
    expect(storedTodos, hasLength(1));
    expect(storedTodos.single['id'], 'todo-2');
  });
}

Future<void> _pumpApp(WidgetTester tester, {String? storedTodos}) async {
  final initialValues = <String, Object>{};
  if (storedTodos != null) {
    initialValues[_storageKey] = storedTodos;
  }

  SharedPreferences.setMockInitialValues(initialValues);

  await tester.pumpWidget(const MiniTodoFlutterApp());
  await tester.pumpAndSettle();
}

String _encodeTodos(List<Map<String, Object>> todos) {
  return jsonEncode(todos);
}

Future<List<Map<String, dynamic>>> _readStoredTodos() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_storageKey);
  expect(raw, isNotNull);

  final decoded = jsonDecode(raw!) as List<dynamic>;
  return decoded
      .map((entry) => Map<String, dynamic>.from(entry as Map<dynamic, dynamic>))
      .toList();
}
