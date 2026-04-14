import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class TerminalLine {
  final String text;
  final TerminalLineType type;
  TerminalLine(this.text, this.type);
}

enum TerminalLineType { input, output, error, info, success, system }

class TerminalProvider with ChangeNotifier {
  final List<TerminalLine> _lines = [];
  String _prompt = r'$ ~ > ';
  bool _running = false;
  final List<String> _history = [];
  int _historyIndex = -1;

  List<TerminalLine> get lines => _lines;
  String get prompt => _prompt;
  bool get running => _running;

  TerminalProvider() {
    _lines.add(TerminalLine('═══════════════════════════════', TerminalLineType.info));
    _lines.add(TerminalLine('  File Manager Pro Terminal v3.0', TerminalLineType.success));
    _lines.add(TerminalLine('  Type "help" for commands', TerminalLineType.info));
    _lines.add(TerminalLine('═══════════════════════════════', TerminalLineType.info));
    _lines.add(TerminalLine('', TerminalLineType.output));
    _fetchPrompt();
  }

  Future<void> _fetchPrompt() async {
    try {
      final data = await ApiService.getTerminalCwd();
      _prompt = data['prompt'] ?? r'$ ~ > ';
      notifyListeners();
    } catch (_) {}
  }

  Future<void> executeCommand(String command) async {
    if (command.trim().isEmpty) return;

    _history.add(command);
    _historyIndex = _history.length;

    _lines.add(TerminalLine('$_prompt$command', TerminalLineType.input));
    _running = true;
    notifyListeners();

    try {
      final result = await ApiService.executeCommand(command);
      final output = result['output'] ?? '';
      _prompt = result['prompt'] ?? _prompt;

      if (output == '__CLEAR__') {
        _lines.clear();
      } else if (output == '__EXIT__') {
        _lines.add(TerminalLine('Session ended.', TerminalLineType.system));
      } else if (output.isNotEmpty) {
        for (final line in output.split('\n')) {
          _lines.add(TerminalLine(line, _classifyLine(line)));
        }
      }
    } catch (e) {
      _lines.add(TerminalLine('Connection error: $e', TerminalLineType.error));
    }

    _running = false;

    // Trim old lines
    if (_lines.length > 1000) {
      _lines.removeRange(0, _lines.length - 500);
    }

    notifyListeners();
  }

  Future<void> killProcess() async {
    try {
      await ApiService.killProcess();
      _lines.add(TerminalLine('^C Process killed', TerminalLineType.error));
      _running = false;
      notifyListeners();
    } catch (e) {
      _lines.add(TerminalLine('Kill failed: $e', TerminalLineType.error));
      notifyListeners();
    }
  }

  Future<List<String>> autocomplete(String partial) async {
    try {
      return await ApiService.getAutocomplete(partial);
    } catch (_) {
      return [];
    }
  }

  String? historyUp() {
    if (_history.isEmpty || _historyIndex <= 0) return null;
    _historyIndex--;
    return _history[_historyIndex];
  }

  String? historyDown() {
    if (_historyIndex >= _history.length - 1) {
      _historyIndex = _history.length;
      return '';
    }
    _historyIndex++;
    return _history[_historyIndex];
  }

  void clear() {
    _lines.clear();
    notifyListeners();
  }

  TerminalLineType _classifyLine(String line) {
    final l = line.toLowerCase();
    if (l.contains('error') || l.contains('failed') || l.contains('traceback')) {
      return TerminalLineType.error;
    }
    if (l.contains('warning') || l.contains('deprecated')) {
      return TerminalLineType.info;
    }
    if (l.contains('success') || l.contains('done') || l.contains('installed')) {
      return TerminalLineType.success;
    }
    if (line.startsWith('http://') || line.startsWith('https://')) {
      return TerminalLineType.system;
    }
    return TerminalLineType.output;
  }
}
