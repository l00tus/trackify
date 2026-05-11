import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import '../../data/expense_api_service.dart';
import '../../logic/expense_bloc.dart';
import '../../data/auth_storage.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _isLoading = false;

  void _handleLogin() async {
  setState(() => _isLoading = true);
  try {
    final api = context.read<ExpenseApiService>();
    await api.login(_userController.text, _passController.text);
    // userId and token are now stored on the api service instance

    // Save to storage
    if (api.token != null && api.userId != null) {
      await AuthStorage.save(token: api.token!, userId: api.userId!);
    }

    if (mounted) {
      context.read<ExpenseBloc>().add(LoadExpenses());
      Navigator.pushReplacementNamed(context, '/home');
    }
  } catch (e) {
    String errorMessage = "Authentication failed.";
    if (e is DioException && e.response != null) {
      final statusCode = e.response!.statusCode;
      if (statusCode == 422) {
        errorMessage = "Invalid email format. Please enter a valid email address.";
      } else if (statusCode == 401) {
        errorMessage = "Invalid email or password.";
      } else if (statusCode == 400) {
        errorMessage = "Email already registered or bad request.";
      } else {
        errorMessage = e.response!.data?['detail'] ?? "Authentication failed.";
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: const Color(0xFFA64D32),
        ),
      );
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  @override
  Widget build(BuildContext context) {
    const vintageBg = Color(0xFFF4EBD9);
    const vintageInk = Color(0xFF2B2118);
    const vintageTitle = TextStyle(
      fontFamily: 'Georgia',
      fontSize: 24,
      fontWeight: FontWeight.bold,
      letterSpacing: 3,
      color: vintageInk,
    );

    return Scaffold(
      backgroundColor: vintageBg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            children: [
              const Icon(Icons.auto_stories, size: 80, color: Color(0xFF8D7B68)),
              const SizedBox(height: 10),
              const Text("TRACKIFY LEDGER", style: vintageTitle),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                decoration: BoxDecoration(
                    color: const Color(0xFFEAD8B1),
                    border: Border.all(color: const Color(0xFF8D7B68), width: 3),
                    boxShadow: const [BoxShadow(color: Colors.black26, offset: Offset(5, 5))]
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: Text("AUTHENTICATION", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    const SizedBox(height: 10),
                    const Divider(color: Color(0xFF8D7B68), thickness: 1.5),
                    const SizedBox(height: 10),
                    TextField(
                        controller: _userController,
                        decoration: const InputDecoration(
                            labelText: "Email Address",
                            labelStyle: TextStyle(color: Color(0xFF5E503F)),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF8D7B68)))
                        )
                    ),
                    const SizedBox(height: 15),
                    TextField(
                        controller: _passController,
                        obscureText: true,
                        decoration: const InputDecoration(
                            labelText: "Passphrase",
                            labelStyle: TextStyle(color: Color(0xFF5E503F)),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF8D7B68)))
                        )
                    ),
                    const SizedBox(height: 30),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator(color: vintageInk))
                    else
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: vintageInk,
                          foregroundColor: vintageBg,
                          elevation: 5,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                        ),
                        onPressed: _handleLogin,
                        child: const Text(
                          "ACCESS LEDGER SESSION",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/register'),
                        child: const Text("NEW SIGNATORY? REGISTER HERE", style: TextStyle(color: vintageInk, fontSize: 10))
                    ),
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