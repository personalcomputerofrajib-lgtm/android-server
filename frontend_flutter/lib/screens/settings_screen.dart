import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/server_provider.dart';
import '../providers/terminal_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('General'),
          ListTile(
            leading: const Icon(Icons.health_and_safety),
            title: const Text('Check Backend Connection'),
            subtitle: const Text('Test API connection'),
            onTap: () => _checkHealth(context),
          ),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Storage Info'),
            subtitle: const Text('View disk usage'),
            onTap: () => _showStorage(context),
          ),

          const _SectionHeader('Terminal'),
          ListTile(
            leading: const Icon(Icons.delete_sweep),
            title: const Text('Clear Terminal'),
            onTap: () {
              context.read<TerminalProvider>().clear();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Terminal cleared')),
              );
            },
          ),

          const _SectionHeader('Servers'),
          ListTile(
            leading: const Icon(Icons.stop_circle, color: Colors.red),
            title: const Text('Stop All Servers'),
            onTap: () {
              context.read<ServerProvider>().stopAll();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All servers stopped')),
              );
            },
          ),

          const _SectionHeader('About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('File Manager Pro'),
            subtitle: const Text('Version 3.0\nFlutter + Python Backend'),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'File Manager Pro',
              applicationVersion: '3.0',
              children: [
                const Text('\nFeatures:\n• File Browser with CRUD\n• Integrated Terminal\n• Server Manager\n• Search\n\nBuilt with Flutter + Python Flask'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkHealth(BuildContext ctx) async {
    final ok = await ApiService.checkHealth();
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(ok ? '✅ Backend connected!' : '❌ Backend not reachable'),
          backgroundColor: ok ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _showStorage(BuildContext ctx) async {
    try {
      final info = await ApiService.getStorageInfo();
      if (ctx.mounted) {
        showDialog(
          context: ctx,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A24),
            title: const Text('Storage Info'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row('Path', info['path'] ?? ''),
                _row('Total', info['total_str'] ?? ''),
                _row('Used', '${info["used_str"] ?? ""} (${info["percent"] ?? 0}%)'),
                _row('Free', info['free_str'] ?? ''),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: (info['percent'] ?? 0) / 100,
                  backgroundColor: Colors.grey[800],
                  color: (info['percent'] ?? 0) > 90 ? Colors.red : Colors.blue,
                ),
              ],
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
          ),
        );
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  static Widget _row(String l, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      SizedBox(width: 60, child: Text('$l:', style: const TextStyle(color: Colors.grey, fontSize: 13))),
      Expanded(child: Text(v, style: const TextStyle(fontSize: 13))),
    ]),
  );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(title, style: TextStyle(color: Colors.blue[300], fontSize: 13, fontWeight: FontWeight.bold)),
    );
  }
}
