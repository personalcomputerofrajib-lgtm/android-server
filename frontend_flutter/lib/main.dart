import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/api_service.dart';
import 'providers/file_provider.dart';
import 'providers/terminal_provider.dart';
import 'providers/server_provider.dart';
import 'screens/home_screen.dart';
import 'screens/terminal_screen.dart';
import 'screens/server_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/search_screen.dart';

void main() {
  runApp(const FileManagerApp());
}

class FileManagerApp extends StatelessWidget {
  const FileManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FileProvider()),
        ChangeNotifierProvider(create: (_) => TerminalProvider()),
        ChangeNotifierProvider(create: (_) => ServerProvider()),
      ],
      child: MaterialApp(
        title: 'File Manager Pro',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0D0D12),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF2196F3),
            secondary: Color(0xFF64B5F6),
            surface: Color(0xFF1A1A24),
            error: Color(0xFFE53935),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF12121A),
            elevation: 0,
          ),
          cardTheme: const CardThemeData(
            color: Color(0xFF1A1A24),
            elevation: 2,
          ),
          textTheme: GoogleFonts.interTextTheme(
            ThemeData.dark().textTheme,
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: const Color(0xFF12121A),
            indicatorColor: const Color(0xFF2196F3).withOpacity(0.3),
            labelTextStyle: WidgetStateProperty.all(
              const TextStyle(fontSize: 12),
            ),
          ),
        ),
        home: const MainShell(),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const TerminalScreen(),
    const ServerScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        height: 65,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder), label: 'Files'),
          NavigationDestination(icon: Icon(Icons.terminal_outlined), selectedIcon: Icon(Icons.terminal), label: 'Terminal'),
          NavigationDestination(icon: Icon(Icons.dns_outlined), selectedIcon: Icon(Icons.dns), label: 'Servers'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
