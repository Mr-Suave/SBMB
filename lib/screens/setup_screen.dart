import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'activity_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  _SetupScreenState createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController babyNameController = TextEditingController();
  final TextEditingController parentNameController = TextEditingController();

  void saveAndProceed() async {
    if (_formKey.currentState!.validate()) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('babyName', babyNameController.text);
      await prefs.setString('parentName', parentNameController.text);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ActivityScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Center(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('👶 Welcome, Parent!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                SizedBox(height: 12),
                Text('Let’s get started with a few quick details 👇', style: TextStyle(fontSize: 16)),
                SizedBox(height: 32),
                TextFormField(
                  controller: babyNameController,
                  decoration: InputDecoration(labelText: 'Baby\'s Name'),
                  validator: (value) => value!.isEmpty ? 'Enter baby\'s name' : null,
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: parentNameController,
                  decoration: InputDecoration(labelText: 'Parent\'s Name'),
                  validator: (value) => value!.isEmpty ? 'Enter your name' : null,
                ),
                SizedBox(height: 32),
                ElevatedButton(
                  onPressed: saveAndProceed,
                  child: Text('🚀 Let’s Go!', style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
