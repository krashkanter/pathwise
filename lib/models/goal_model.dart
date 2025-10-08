import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'goal_model.g.dart';

@HiveType(typeId: 1)
class Goal extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  List<GoalStep> steps;

  @HiveField(3)
  DateTime? reminder;

  @HiveField(4)
  String recurrence; // 'none', 'daily', 'weekly'

  Goal({
    required this.id,
    required this.title,
    this.steps = const [],
    this.reminder,
    this.recurrence = 'none',
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'title': title,
      'steps': steps.map((step) => step.toFirestore()).toList(),
      'reminder': reminder != null ? Timestamp.fromDate(reminder!) : null,
      'recurrence': recurrence,
    };
  }

  factory Goal.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data()!;
    return Goal(
      id: data['id'],
      title: data['title'],
      steps: (data['steps'] as List<dynamic>)
          .map((stepData) => GoalStep.fromFirestore(stepData))
          .toList(),
      reminder:
      data['reminder'] != null ? (data['reminder'] as Timestamp).toDate() : null,
      recurrence: data['recurrence'] ?? 'none',
    );
  }
}

@HiveType(typeId: 2)
class GoalStep extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1)
  bool isCompleted;

  GoalStep({required this.title, this.isCompleted = false});

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'isCompleted': isCompleted,
    };
  }

  factory GoalStep.fromFirestore(Map<String, dynamic> data) {
    return GoalStep(
      title: data['title'],
      isCompleted: data['isCompleted'],
    );
  }
}

