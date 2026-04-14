import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/server_provider.dart';

class ServerScreen extends StatelessWidget {
  const ServerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ServerProvider>(
      builder: (context, sp, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Server Manager'),
            actions: [
              IconButton(icon: const Icon(Icons.refresh), onPressed: sp.refresh),
              if (sp.servers.isNotEmpty)
                IconButton(icon: const Icon(Icons.stop_circle, color: Colors.red), onPressed: sp.stopAll),
            ],
          ),
          body: Column(
            children: [
              // Info bar
              Container(
                padding: const EdgeInsets.all(12),
                color: const Color(0xFF12121A),
                child: Row(
                  children: [
                    const Icon(Icons.wifi, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text('IP: ${sp.localIp}', style: const TextStyle(color: Colors.blue, fontSize: 13)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: sp.runningCount > 0 ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${sp.runningCount} running',
                        style: TextStyle(fontSize: 12, color: sp.runningCount > 0 ? Colors.green : Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),

              // Start buttons
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _startBtn('Python HTTP', Colors.blue, () => _startPython(context, sp)),
                    _startBtn('npm start', Colors.green, () => _startNpm(context, sp, 'start')),
                    _startBtn('npm dev', Colors.green, () => _startNpm(context, sp, 'dev')),
                    _startBtn('Custom', Colors.purple, () => _showCustomDialog(context, sp)),
                  ],
                ),
              ),

              // Server list
              Expanded(
                child: sp.servers.isEmpty
                    ? const Center(child: Text('No servers running', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: sp.servers.length,
                        itemBuilder: (_, i) => _serverTile(context, sp, sp.servers[i]),
                      ),
              ),

              // Logs
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                color: const Color(0xFF0A0A10),
                child: Row(
                  children: [
                    const Text('Logs', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const Spacer(),
                    Text('${sp.logs.length} lines', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                height: 150,
                color: const Color(0xFF08080C),
                child: sp.logs.isEmpty
                    ? const Center(child: Text('Select a server', style: TextStyle(color: Colors.grey, fontSize: 12)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: sp.logs.length,
                        itemBuilder: (_, i) => Text(
                          sp.logs[i],
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.green),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _startBtn(String label, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: color.withOpacity(0.8)),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontSize: 13)),
      ),
    );
  }

  Widget _serverTile(BuildContext ctx, ServerProvider sp, ServerInfo srv) {
    final isRunning = srv.isRunning;
    final color = isRunning ? Colors.green : (srv.isError ? Colors.red : Colors.grey);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Icon(isRunning ? Icons.dns : Icons.dns_outlined, color: color),
        title: Text(srv.name),
        subtitle: Text(
          '${srv.status.toUpperCase()} • Port:${srv.port} • ${srv.uptimeStr}',
          style: TextStyle(fontSize: 12, color: color),
        ),
        trailing: isRunning
            ? IconButton(icon: const Icon(Icons.stop_circle, color: Colors.red), onPressed: () => sp.stopServer(srv.id))
            : IconButton(icon: const Icon(Icons.play_circle, color: Colors.green), onPressed: () => sp.restartServer(srv.id)),
        onTap: () => sp.selectServer(srv.id),
      ),
    );
  }

  void _startPython(BuildContext ctx, ServerProvider sp) {
    _showPortDialog(ctx, 8000, (port) => sp.startPythonHttp(_getDir(), port));
  }

  void _startNpm(BuildContext ctx, ServerProvider sp, String script) {
    _showPortDialog(ctx, 3000, (port) => sp.startNpm(_getDir(), script, port));
  }

  void _showPortDialog(BuildContext ctx, int defaultPort, Function(int) onStart) {
    final controller = TextEditingController(text: defaultPort.toString());
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A24),
        title: const Text('Port'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Port'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onStart(int.tryParse(controller.text) ?? defaultPort);
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }

  void _showCustomDialog(BuildContext ctx, ServerProvider sp) {
    final cmdCtl = TextEditingController();
    final nameCtl = TextEditingController(text: 'Custom Server');
    final portCtl = TextEditingController(text: '8080');
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A24),
        title: const Text('Custom Server'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtl, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: cmdCtl, decoration: const InputDecoration(labelText: 'Command', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: portCtl, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Port', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              sp.startCustom(_getDir(), cmdCtl.text, nameCtl.text, int.tryParse(portCtl.text) ?? 8080);
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }

  String _getDir() {
    if (Directory('/sdcard').existsSync()) return '/sdcard';
    return Platform.environment['HOME'] ?? '/tmp';
  }
}
