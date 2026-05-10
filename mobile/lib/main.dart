import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trackify/data/expense_api_service.dart';
import 'package:trackify/logic/expense_bloc.dart';
import 'package:trackify/ui/screens/dashboard_screen.dart';
import 'package:trackify/ui/screens/add_expense_screen.dart';
import 'package:trackify/ui/screens/login_screen.dart';
import 'package:trackify/ui/screens/profile_screen.dart';
import 'package:trackify/ui/screens/register_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (context) => ExpenseApiService()),
      ],
      child: BlocProvider(
        create: (context) => ExpenseBloc(
          context.read<ExpenseApiService>(),
        )..add(LoadExpenses()),
        child: MaterialApp(
          title: 'Trackify Ledger',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            scaffoldBackgroundColor: const Color(0xFFF4EBD9),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFD6C5A0),
              foregroundColor: Color(0xFF2B2118),
              elevation: 2,
              titleTextStyle: TextStyle(
                fontFamily: 'Georgia',
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
                fontSize: 18,
                color: Color(0xFF2B2118),
              ),
            ),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF8D7B68),
              primary: const Color(0xFF2B2118),
              secondary: const Color(0xFF5E503F),
            ),
            textTheme: const TextTheme(
              bodyLarge: TextStyle(fontFamily: 'Georgia', color: Color(0xFF2B2118)),
              bodyMedium: TextStyle(fontFamily: 'Georgia', color: Color(0xFF2B2118)),
            ),
          ),
          initialRoute: '/login',
          routes: {
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/home': (context) => const MainNavigation(),
          },
        ),
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const AddExpenseScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF8D7B68), width: 2)),
        ),
        child: NavigationBar(
          backgroundColor: const Color(0xFFD6C5A0),
          indicatorColor: const Color(0xFF8D7B68).withOpacity(0.3),
          selectedIndex: _selectedIndex,
          onDestinationSelected: (int index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.history_edu),
              label: 'Ledger',
            ),
            NavigationDestination(
              icon: Icon(Icons.add_box),
              label: 'New Entry',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_box),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}