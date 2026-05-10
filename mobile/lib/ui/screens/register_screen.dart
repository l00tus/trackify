import 'package:flutter/material.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    const vintageBg = Color(0xFFF4EBD9);
    const vintageInk = Color(0xFF2B2118);
    return Scaffold(
      backgroundColor: vintageBg,
      appBar: AppBar(title: const Text("NEW REGISTRATION"), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFFEAD8B1), border: Border.all(color: const Color(0xFF8D7B68), width: 3), boxShadow: const [BoxShadow(color: Colors.black26, offset: Offset(5, 5))]),
            child: Column(
              children: [
                const Center(child: Text("MEMBERSHIP APPLICATION", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                const Divider(color: Color(0xFF8D7B68), thickness: 1.5),
                TextField(controller: _userController, decoration: const InputDecoration(labelText: "Desired Identifier", enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF8D7B68))))),
                const SizedBox(height: 15),
                TextField(controller: _emailController, decoration: const InputDecoration(labelText: "Email Address", enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF8D7B68))))),
                const SizedBox(height: 15),
                TextField(controller: _passController, obscureText: true, decoration: const InputDecoration(labelText: "Security Passphrase", enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF8D7B68))))),
                const SizedBox(height: 30),
                ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: vintageInk, foregroundColor: vintageBg, padding: const EdgeInsets.symmetric(vertical: 15), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)), onPressed: () => Navigator.pop(context), child: const Text("SUBMIT APPLICATION")),
              ],
            ),
          ),
        ),
      ),
    );
  }
}