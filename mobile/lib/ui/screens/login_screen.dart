import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  void _handleLogin() {
    if (_userController.text == "user123" && _passController.text == "user123") {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Credentials not recognized."), backgroundColor: Color(0xFFA64D32)));
    }
  }
  @override
  Widget build(BuildContext context) {
    const vintageBg = Color(0xFFF4EBD9);
    const vintageInk = Color(0xFF2B2118);
    return Scaffold(
      backgroundColor: vintageBg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            children: [
              const Icon(Icons.auto_stories, size: 80, color: Color(0xFF8D7B68)),
              const SizedBox(height: 10),
              const Text("TRACKIFY LEDGER", style: TextStyle(fontFamily: 'Georgia', fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 3, color: vintageInk)),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: const Color(0xFFEAD8B1), border: Border.all(color: const Color(0xFF8D7B68), width: 3), boxShadow: const [BoxShadow(color: Colors.black26, offset: Offset(5, 5))]),
                child: Column(
                  children: [
                    const Center(child: Text("AUTHENTICATION", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    const Divider(color: Color(0xFF8D7B68), thickness: 1.5),
                    TextField(controller: _userController, decoration: const InputDecoration(labelText: "Identifier", enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF8D7B68))))),
                    const SizedBox(height: 15),
                    TextField(controller: _passController, obscureText: true, decoration: const InputDecoration(labelText: "Passphrase", enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF8D7B68))))),
                    const SizedBox(height: 30),
                    ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: vintageInk, foregroundColor: vintageBg, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)), onPressed: _handleLogin, child: const Text("ACCESS LEDGER")),
                    const SizedBox(height: 10),
                    TextButton(onPressed: () => Navigator.pushNamed(context, '/register'), child: const Text("NEW SIGNATORY? REGISTER HERE", style: TextStyle(color: vintageInk, fontSize: 10))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}