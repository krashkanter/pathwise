import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pathwise/models/goal_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pathwise/screens/goal_detail_page.dart';
import 'package:pathwise/screens/share_goals_page.dart';
import 'dart:async';
import 'package:home_widget/home_widget.dart';
import 'dart:convert';

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  final Box<Goal> _goalsBox = Hive.box<Goal>('goalsBox');
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _syncGoalsFromFirestore();
  }

  CollectionReference<Goal> get _goalsCollection => FirebaseFirestore.instance
      .collection('users')
      .doc(_currentUser!.uid)
      .collection('goals')
      .withConverter<Goal>(
    fromFirestore: (snapshots, _) => Goal.fromFirestore(snapshots),
    toFirestore: (goal, _) => goal.toFirestore(),
  );

  Future<void> _syncGoalsFromFirestore() async {
    if (_currentUser == null) return;
    try {
      final snapshot = await _goalsCollection.get();
      final goalsFromFirestore =
      snapshot.docs.map((doc) => doc.data()).toList();
      await _goalsBox.clear();
      for (var goal in goalsFromFirestore) {
        await _goalsBox.put(goal.id, goal);
      }
    } catch (e) {
      // Handle error
    }
  }

  void _navigateToDetail(Goal? goal) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => GoalDetailPage(goal: goal)))
        .then((_) => setState(() {}));
  }

  // Updated function to check and refresh the widget
  void _toggleStepCompletion(Goal goal, int originalStepIndex) async {
    // Update state locally first for instant UI feedback
    setState(() {
      goal.steps[originalStepIndex].isCompleted =
      !goal.steps[originalStepIndex].isCompleted;
    });

    // Save changes to local and cloud storage
    await _goalsBox.put(goal.id, goal);
    if (_currentUser != null) {
      await _goalsCollection.doc(goal.id).set(goal);
    }

    // Check if the modified goal is the one on the widget
    final widgetGoalData = await HomeWidget.getWidgetData<String>('goal_data');
    if (widgetGoalData != null) {
      final decodedData = jsonDecode(widgetGoalData);
      final widgetGoalId = decodedData['id'];
      // If it is, update the widget with the new data
      if (widgetGoalId == goal.id) {
        await _updateWidgetData(goal);
      }
    }
  }

  // Reusable function to send data to the widget
  Future<void> _updateWidgetData(Goal goal) async {
    try {
      final goalData = {
        'id': goal.id,
        'title': goal.title,
        'steps': goal.steps.map((s) => s.toFirestore()).toList(),
      };
      await HomeWidget.saveWidgetData<String>('goal_data', jsonEncode(goalData));
      await HomeWidget.updateWidget(name: 'HomeWidgetProvider', iOSName: 'HomeWidget');
    } on PlatformException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Failed to update widget. Is it set up correctly? Error: ${e.message}')));
    }
  }

  Future<void> _setWidgetGoal(Goal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Home Widget'),
        content: Text('Display "${goal.title}" on your home screen?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Set')),
        ],
      ),
    );

    if (confirmed == true) {
      await _updateWidgetData(goal);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Goal widget updated!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder<Box<Goal>>(
        valueListenable: _goalsBox.listenable(),
        builder: (context, box, _) {
          final goals = box.values.toList().cast<Goal>();
          if (goals.isEmpty) {
            return const Center(
              child: Text(
                'No goals yet. Tap + to add one!',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8.0).copyWith(bottom: 80),
            itemCount: goals.length,
            itemBuilder: (context, index) {
              final goal = goals[index];
              final completedSteps =
                  goal.steps.where((s) => s.isCompleted).length;
              final progress =
              goal.steps.isEmpty ? 0.0 : completedSteps / goal.steps.length;

              final sortedSteps = List<GoalStep>.from(goal.steps);
              sortedSteps.sort((a, b) {
                if (a.isCompleted == b.isCompleted) return 0;
                return a.isCompleted ? 1 : -1;
              });

              return GestureDetector(
                onLongPress: () => _setWidgetGoal(goal),
                child: Dismissible(
                  key: Key(goal.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                      color: Colors.blue,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('Share',
                              style:
                              TextStyle(color: Colors.white, fontSize: 16)),
                          SizedBox(width: 8),
                          Icon(Icons.share, color: Colors.white),
                        ],
                      )),
                  confirmDismiss: (direction) async {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => ShareGoalPage(goal: goal),
                    ));
                    return false;
                  },
                  child: Card(
                    elevation: 4,
                    margin:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  goal.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_note,
                                    color: Colors.grey),
                                onPressed: () => _navigateToDetail(goal),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          goal.steps.isEmpty
                              ? const Text('No steps added yet.',
                              style: TextStyle(color: Colors.grey))
                              : SizedBox(
                            height: 50,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: sortedSteps.length,
                              itemBuilder: (context, stepIndex) {
                                final step = sortedSteps[stepIndex];
                                return GestureDetector(
                                  onTap: () {
                                    final originalIndex =
                                    goal.steps.indexOf(step);
                                    _toggleStepCompletion(
                                        goal, originalIndex);
                                  },
                                  child: Card(
                                    color: step.isCompleted
                                        ? Colors.green.shade50
                                        : Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(8),
                                        side: BorderSide(
                                          color: step.isCompleted
                                              ? Colors.green
                                              : Colors.grey.shade300,
                                        )),
                                    child: Padding(
                                      padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 8.0),
                                      child: Row(
                                        children: [
                                          Checkbox(
                                            value: step.isCompleted,
                                            onChanged: (value) {
                                              final originalIndex =
                                              goal.steps.indexOf(
                                                  step);
                                              _toggleStepCompletion(
                                                  goal, originalIndex);
                                            },
                                            activeColor: Colors.green,
                                          ),
                                          Text(step.title),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.grey.shade200,
                            color: Colors.green,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToDetail(null),
        child: const Icon(Icons.add),
      ),
    );
  }
}

