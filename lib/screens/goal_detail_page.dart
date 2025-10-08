import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:pathwise/models/goal_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pathwise/secrets.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';

class GoalDetailPage extends StatefulWidget {
  final Goal? goal;

  const GoalDetailPage({super.key, this.goal});

  @override
  State<GoalDetailPage> createState() => _GoalDetailPageState();
}

class _GoalDetailPageState extends State<GoalDetailPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  List<TextEditingController> _stepControllers = [];
  DateTime? _selectedDate;
  String _selectedRecurrence = 'none';
  bool _isLoadingAiSteps = false;

  // IMPORTANT: Replace with your actual Gemini API Key
  static final String _apiKey = geminiApiKey();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.goal?.title ?? '');
    if (widget.goal != null) {
      _stepControllers = widget.goal!.steps
          .map((step) => TextEditingController(text: step.title))
          .toList();
      _selectedDate = widget.goal!.reminder;
      _selectedRecurrence = widget.goal!.recurrence;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (var controller in _stepControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _generateAiSteps() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a goal title first.')),
      );
      return;
    }
    if (_apiKey == 'YOUR_GEMINI_API_KEY') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please add your Gemini API key to the code.')),
      );
      return;
    }

    setState(() => _isLoadingAiSteps = true);

    try {
      final model = GenerativeModel(model: 'gemini-2.0-flash', apiKey: _apiKey);
      final prompt =
          'Generate a concise list of 5-7 actionable steps for the given goal. You are setting steps in a goal planning app, so optimize the steps: "${_titleController.text}". Respond with only a JSON array of strings. For example: ["Step 1", "Step 2"]';
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      if (response.text != null) {
        // Clean the response to ensure it's valid JSON
        final cleanedJson =
        response.text!.replaceAll('```json', '').replaceAll('```', '').trim();
        final List<dynamic> stepsJson = jsonDecode(cleanedJson);
        final steps = stepsJson.map((step) => step.toString()).toList();

        setState(() {
          _stepControllers =
              steps.map((title) => TextEditingController(text: title)).toList();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate AI steps: $e')),
      );
    } finally {
      setState(() => _isLoadingAiSteps = false);
    }
  }

  void _addStep() {
    setState(() {
      _stepControllers.add(TextEditingController());
    });
  }

  void _removeStep(int index) {
    setState(() {
      _stepControllers.removeAt(index).dispose();
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _saveGoal() async {
    if (_formKey.currentState!.validate()) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final goalId = widget.goal?.id ?? const Uuid().v4();
      final steps = _stepControllers
          .where((c) => c.text.isNotEmpty)
          .map((c) => GoalStep(title: c.text, isCompleted: false))
          .toList();

      final newGoal = Goal(
        id: goalId,
        title: _titleController.text,
        steps: steps,
        reminder: _selectedDate,
        recurrence: _selectedRecurrence,
      );

      final goalsBox = Hive.box<Goal>('goalsBox');
      await goalsBox.put(newGoal.id, newGoal);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('goals')
          .doc(newGoal.id)
          .set(newGoal.toFirestore());

      Navigator.pop(context);
    }
  }

  void _deleteGoal() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Goal?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && widget.goal != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await Hive.box<Goal>('goalsBox').delete(widget.goal!.id);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('goals')
          .doc(widget.goal!.id)
          .delete();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.goal == null ? 'New Goal' : 'Edit Goal'),
        actions: [
          if (widget.goal != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteGoal,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Goal Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                value!.isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 16),
              const Text('Steps',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ..._stepControllers.asMap().entries.map((entry) {
                int idx = entry.key;
                TextEditingController ctrl = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: ctrl,
                          decoration: InputDecoration(
                            labelText: 'Step ${idx + 1}',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => _removeStep(idx),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: _addStep,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Step'),
                  ),
                  _isLoadingAiSteps
                      ? const CircularProgressIndicator()
                      : ElevatedButton.icon(
                    onPressed: _generateAiSteps,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Generate with AI'),
                  ),
                ],
              ),
              const Divider(height: 32),
              const Text('Reminders & Recurrence',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(_selectedDate == null
                    ? 'Set a reminder'
                    : 'Reminder on: ${DateFormat.yMd().format(_selectedDate!)}'),
                onTap: _selectDate,
              ),
              ListTile(
                leading: const Icon(Icons.repeat),
                title: const Text('Recurrence'),
                trailing: DropdownButton<String>(
                  value: _selectedRecurrence,
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedRecurrence = newValue!;
                    });
                  },
                  items: <String>['none', 'daily', 'weekly']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value[0].toUpperCase() + value.substring(1)),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveGoal,
        icon: const Icon(Icons.save),
        label: const Text('Save Goal'),
      ),
    );
  }
}

