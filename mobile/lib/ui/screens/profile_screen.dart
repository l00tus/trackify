import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../logic/expense_bloc.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  final List<String> _supportedCurrencies = const [
    "USD", "EUR", "GBP", "RON", "CHF", "CNY", "JPY", "ILS", "RUB", "HUF", "PLN",
    "DEM", "GRD", "ITL", "FRF", "ESP", "ATS"
  ];
  @override
  Widget build(BuildContext context) {
    const vintageInk = Color(0xFF2B2118);
    const vintageBorder = BorderSide(color: Color(0xFF8D7B68), width: 1.5);
    return Scaffold(
      appBar: AppBar(title: const Text("OFFICIAL PROFILE")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Center(child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(border: Border.all(color: const Color(0xFF8D7B68), width: 2), shape: BoxShape.circle), child: const CircleAvatar(radius: 50, backgroundColor: Color(0xFFD6C5A0), child: Icon(Icons.person, size: 60, color: vintageInk)))),
            const SizedBox(height: 16),
            const Text("MEMBER #12345", style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: vintageInk)),
            const Text("ACTIVE SINCE MAY 2026", style: TextStyle(fontSize: 10, color: Color(0xFF5E503F))),
            const SizedBox(height: 30),
            Container(
              decoration: BoxDecoration(color: const Color(0xFFEAD8B1), border: Border.all(color: const Color(0xFF8D7B68), width: 3)),
              child: Column(
                children: [
                  _buildProfileItem(Icons.alternate_email, "IDENTIFIER", "user123@ledger.com", vintageBorder),
                  BlocBuilder<ExpenseBloc, ExpenseState>(
                    builder: (context, state) {
                      String currentDefault = (state is ExpenseLoaded) ? state.defaultCurrency : "RON";
                      return Container(
                        decoration: const BoxDecoration(border: Border(bottom: vintageBorder)),
                        child: ListTile(
                          leading: const Icon(Icons.payments, color: vintageInk),
                          title: const Text("DEFAULT TENDER", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF5E503F))),
                          subtitle: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: currentDefault, isDense: true, dropdownColor: const Color(0xFFF4EBD9),
                              style: const TextStyle(fontFamily: 'Georgia', fontSize: 16, color: vintageInk),
                              items: _supportedCurrencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  // This triggers the ChangeDefaultCurrency event in the Bloc,
                                  // which calls apiService.updateUserCurrency(val)
                                  context.read<ExpenseBloc>().add(ChangeDefaultCurrency(val));

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("Preferred tender updated to $val in the ledger."),
                                      backgroundColor: const Color(0xFF8D7B68),
                                    ),
                                  );
                                }
                              },                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  _buildProfileItem(Icons.security, "STATUS", "Verified Auditor", vintageBorder),
                  ListTile(leading: const Icon(Icons.logout, color: Color(0xFFA64D32)), title: const Text("CEASE SESSION", style: TextStyle(color: Color(0xFFA64D32), fontWeight: FontWeight.bold)), onTap: () => Navigator.pushReplacementNamed(context, '/login')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildProfileItem(IconData icon, String label, String value, BorderSide border) {
    return Container(decoration: BoxDecoration(border: Border(bottom: border)), child: ListTile(leading: Icon(icon, color: const Color(0xFF2B2118)), title: Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF5E503F))), subtitle: Text(value, style: const TextStyle(fontFamily: 'Georgia', fontSize: 16, color: Color(0xFF2B2118)))));
  }
}