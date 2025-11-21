import 'package:biblioteca/paginas/home_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  await Supabase.initialize(
    url: 'https://inywpjvhwhspmswqujsl.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlueXdwanZod2hzcG1zd3F1anNsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM3MDcyNTIsImV4cCI6MjA3OTI4MzI1Mn0.trwhl_UQrqe1ix_SDY4nQwnNQrrIQfTBiIsVJydh4QA',
  );

  runApp(MyApp());
}

// Get a reference your Supabase client
final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      home: LivrosApiScreen(),
    );
  }
}
