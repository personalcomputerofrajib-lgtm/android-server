import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/terminal_provider.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final TextEditingController _cmdController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _cmdController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TerminalProvider>(
      builder: (context, tp, _) {
        _scrollToBottom();
        return Scaffold(
          backgroundColor: const Color(0xFF0A0A0E),
          appBar: AppBar(
            title: const Text('Terminal'),
            backgroundColor: const Color(0xFF0E0E14),
            actions: [
              IconButton(icon: const Icon(Icons.stop, color: Colors.red), onPressed: tp.killProcess,
                tooltip: 'Kill Process'),
              IconButton(icon: const Icon(Icons.copy, size: 20), onPressed: () => _copyOutput(context, tp),
                tooltip: 'Copy Output'),
              IconButton(icon: const Icon(Icons.delete_sweep, size: 20), onPressed: tp.clear,
                tooltip: 'Clear'),
            ],
          ),
          body: Column(
            children: [
              // Output
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8),
                  itemCount: tp.lines.length,
                  itemBuilder: (_, i) {
                    final line = tp.lines[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 0.5),
                      child: SelectableText(
                        line.text,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: _lineColor(line.type),
                          height: 1.4,
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Divider
              Container(height: 1, color: Colors.grey[800]),

              // Input area
              Container(
                color: const Color(0xFF0E0E14),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    Text(tp.prompt, style: const TextStyle(color: Colors.blue, fontSize: 12, fontFamily: 'monospace')),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextField(
                        controller: _cmdController,
                        style: const TextStyle(color: Colors.green, fontFamily: 'monospace', fontSize: 14),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Enter command...',
                          hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                        onSubmitted: (_) => _run(tp),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.blue, size: 22),
                      onPressed: () => _run(tp),
                    ),
                  ],
                ),
              ),

              // Quick buttons
              Container(
                height: 42,
                color: const Color(0xFF08080C),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  children: [
                    _quickBtn('Tab', () => _tabComplete(tp)),
                    _quickBtn('↑', () { final c = tp.historyUp(); if (c != null) _cmdController.text = c; }),
                    _quickBtn('↓', () { final c = tp.historyDown(); if (c != null) _cmdController.text = c; }),
                    const SizedBox(width: 8),
                    _quickBtn('ls -la', () => _quickRun(tp, 'ls -la')),
                    _quickBtn('pwd', () => _quickRun(tp, 'pwd')),
                    _quickBtn('python3 -V', () => _quickRun(tp, 'python3 --version')),
                    _quickBtn('pip3 list', () => _quickRun(tp, 'pip3 list')),
                    _quickBtn('git status', () => _quickRun(tp, 'git status')),
                    _quickBtn('clear', () => _quickRun(tp, 'clear')),
                    _quickBtn('help', () => _quickRun(tp, 'help')),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _run(TerminalProvider tp) {
    final cmd = _cmdController.text.trim();
    if (cmd.isEmpty) return;
    _cmdController.clear();
    tp.executeCommand(cmd);
  }

  void _quickRun(TerminalProvider tp, String cmd) {
    _cmdController.text = cmd;
    _run(tp);
  }

  Future<void> _tabComplete(TerminalProvider tp) async {
    final text = _cmdController.text;
    if (text.isEmpty) return;
    final suggestions = await tp.autocomplete(text);
    if (suggestions.length == 1) {
      final parts = text.split(' ');
      parts[parts.length - 1] = suggestions[0];
      _cmdController.text = parts.join(' ');
      _cmdController.selection = TextSelection.collapsed(offset: _cmdController.text.length);
    } else if (suggestions.isNotEmpty) {
      tp.executeCommand('echo ${suggestions.take(10).join("  ")}');
    }
  }

  void _copyOutput(BuildContext ctx, TerminalProvider tp) {
    final text = tp.lines.map((l) => l.text).join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(ctx).showSnackBar(
      const SnackBar(content: Text('Output copied')),
    );
  }

  Widget _quickBtn(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        onPressed: onTap,
        backgroundColor: const Color(0xFF1A1A24),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  Color _lineColor(TerminalLineType type) {
    switch (type) {
      case TerminalLineType.input:
        return Colors.white;
      case TerminalLineType.error:
        return const Color(0xFFFF4444);
      case TerminalLineType.success:
        return const Color(0xFF44FF44);
      case TerminalLineType.info:
        return const Color(0xFFFFCC00);
      case TerminalLineType.system:
        return const Color(0xFF4DB8FF);
      case TerminalLineType.output:
        return const Color(0xFF00FF00);
    }
  }
}
