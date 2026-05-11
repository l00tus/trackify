import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/expense_api_service.dart';
import '../../logic/expense_bloc.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  final List<String> _supportedCurrencies = const [
    "USD", "EUR", "GBP", "RON", "CHF", "CNY", "JPY", "ILS", "RUB", "HUF", "PLN",
    "DEM", "GRD", "ITL", "FRF", "ESP", "ATS"
  ];

  String _generateRandomCardNumber() {
    final random = Random();
    String card = "";
    for (int i = 0; i < 4; i++) {
      card += (1000 + random.nextInt(9000)).toString();
      if (i < 3) card += " ";
    }
    return card;
  }

  @override
  Widget build(BuildContext context) {
    const vintageInk = Color(0xFF2B2118);
    const goldLeaf = Color(0xFFD4AF37);

    final apiService = context.read<ExpenseApiService>();
    final String userEmail = apiService.userEmail ?? "AUDITOR@LEDGER.COM";
    final String cardNumber = _generateRandomCardNumber();

    return Scaffold(
      appBar: AppBar(title: const Text("CREDENTIALS")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: AspectRatio(
                aspectRatio: 1.586,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAD8B1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: const Color(0xFF8D7B68), width: 3),
                    boxShadow: const [
                      BoxShadow(color: Colors.black38, offset: Offset(6, 6), blurRadius: 4),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // New Top-Left Currency Preference Module
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("TENDER PREF", style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, letterSpacing: 1)),
                              const SizedBox(height: 4),
                              Container(
                                width: 75,
                                height: 45,
                                decoration: BoxDecoration(
                                  color: goldLeaf.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: vintageInk.withOpacity(0.3)),
                                ),
                                child: BlocBuilder<ExpenseBloc, ExpenseState>(
                                  builder: (context, state) {
                                    String currentDefault = (state is ExpenseLoaded) ? state.defaultCurrency : "RON";
                                    return DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: currentDefault,
                                        alignment: Alignment.center,
                                        dropdownColor: const Color(0xFFF4EBD9),
                                        icon: const SizedBox.shrink(), // Hide icon for cleaner "chip" look
                                        style: const TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: vintageInk),
                                        items: _supportedCurrencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            context.read<ExpenseBloc>().add(ChangeDefaultCurrency(val));
                                          }
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          Text(
                            "LEDGER CARD",
                            style: TextStyle(
                              fontFamily: 'Georgia',
                              fontWeight: FontWeight.bold,
                              color: vintageInk.withOpacity(0.7),
                              letterSpacing: 2,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        cardNumber,
                        style: const TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: vintageInk,
                          shadows: [Shadow(color: Colors.black26, offset: Offset(1, 1))],
                        ),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("ACCOUNT HOLDER", style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold)),
                                Text(
                                  userEmail.toUpperCase(),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              apiService.userId = null;
                              apiService.userEmail = null;
                              apiService.token = null;
                              Navigator.pushReplacementNamed(context, '/login');
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text("EXPIRY / LOGOUT", style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold)),
                                const Text("09 / 26", style: TextStyle(fontFamily: 'Courier', fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFA64D32))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}