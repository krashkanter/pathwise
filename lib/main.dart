import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sharing_intent/flutter_sharing_intent.dart';
import 'package:flutter_sharing_intent/model/sharing_file.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pathwise/models/goal_model.dart';
import 'package:pathwise/screens/auth_page.dart';
import 'package:pathwise/screens/home_page.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Hive for local storage
  await Hive.initFlutter();
  // Registering the adapter
  Hive.registerAdapter(GoalAdapter());
  Hive.registerAdapter(GoalStepAdapter());
  // Opening the box
  await Hive.openBox<Goal>('goalsBox');

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late StreamSubscription _intentDataStreamSubscription;
  List<SharedFile>? list;

  @override
  void initState() {
    super.initState();
    _intentDataStreamSubscription =
        FlutterSharingIntent.instance.getMediaStream().listen(
              (List<SharedFile> value) {
            setState(() {
              list = value;
            });
          },
          onError: (_) {},
        );

    FlutterSharingIntent.instance.getInitialSharing().then((
        List<SharedFile> value,
        ) {
      setState(() {
        list = value;
      });
    });
  }

  @override
  void dispose() {
    _intentDataStreamSubscription.cancel();
    // It's good practice to close Hive boxes when the app is disposed.
    Hive.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (list != null && list!.isNotEmpty) {
      return MaterialApp(
        home: Scaffold(
          body: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Center(child: Text(list!.map((f) => f.value).join(","))),
            ],
          ),
        ),
      );
    }

    return MaterialApp(
      theme: ThemeData(
        fontFamily: GoogleFonts.comme().fontFamily,
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          centerTitle: true,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Colors.blueAccent,
        ),
        cardTheme: CardThemeData(color: Colors.blue.shade50),
      ),
      debugShowCheckedModeBanner: false,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          } else if (snapshot.hasData) {
            return const HomePage();
          } else {
            return const AuthPage();
          }
        },
      ),
    );
  }
}
