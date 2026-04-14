import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/file_provider.dart';
import '../services/api_service.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FileProvider>().loadDirectory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FileProvider>(
      builder: (context, fp, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('File Manager Pro'),
            leading: fp.canGoBack
                ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: fp.goBack)
                : IconButton(icon: const Icon(Icons.home), onPressed: fp.goHome),
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'hidden') fp.toggleHidden();
                  else if (v == 'refresh') fp.loadDirectory(fp.currentPath);
                  else if (v == 'new_folder') _showCreateDialog(context, fp, true);
                  else if (v == 'new_file') _showCreateDialog(context, fp, false);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'new_folder', child: Text('New Folder')),
                  const PopupMenuItem(value: 'new_file', child: Text('New File')),
                  const PopupMenuItem(value: 'refresh', child: Text('Refresh')),
                  PopupMenuItem(value: 'hidden', child: Text(fp.showHidden ? 'Hide Hidden' : 'Show Hidden')),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              // Path bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFF12121A),
                child: Row(
                  children: [
                    const Icon(Icons.folder_open, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fp.currentPath,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Action bar
              Container(
                height: 44,
                color: const Color(0xFF14141E),
                child: Row(
                  children: [
                    _actionBtn(Icons.arrow_upward, () => fp.goBack()),
                    _actionBtn(Icons.create_new_folder, () => _showCreateDialog(context, fp, true)),
                    _actionBtn(Icons.note_add, () => _showCreateDialog(context, fp, false)),
                    if (fp.hasClipboard) _actionBtn(Icons.content_paste, () => _paste(context, fp)),
                    const Spacer(),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.sort, size: 20, color: Colors.grey),
                      onSelected: fp.setSortBy,
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'name', child: Text('Name')),
                        const PopupMenuItem(value: 'size', child: Text('Size')),
                        const PopupMenuItem(value: 'date', child: Text('Date')),
                        const PopupMenuItem(value: 'type', child: Text('Type')),
                      ],
                    ),
                    _actionBtn(Icons.refresh, () => fp.loadDirectory(fp.currentPath)),
                  ],
                ),
              ),

              // File list
              Expanded(
                child: fp.loading
                    ? const Center(child: CircularProgressIndicator())
                    : fp.error.isNotEmpty
                        ? Center(child: Text(fp.error, style: const TextStyle(color: Colors.red)))
                        : fp.items.isEmpty
                            ? const Center(child: Text('Empty folder', style: TextStyle(color: Colors.grey)))
                            : ListView.builder(
                                itemCount: fp.items.length,
                                itemBuilder: (ctx, i) => _buildFileItem(ctx, fp, fp.items[i]),
                              ),
              ),

              // Status bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                color: const Color(0xFF0A0A10),
                child: Text(
                  '${fp.folderCount} folders, ${fp.fileCount} files',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _actionBtn(IconData icon, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, size: 20, color: Colors.grey),
      onPressed: onTap,
      splashRadius: 20,
    );
  }

  Widget _buildFileItem(BuildContext ctx, FileProvider fp, FileItem item) {
    final color = item.isDir
        ? Colors.blue
        : _getFileColor(item.extension);
    final icon = item.isDir ? Icons.folder : _getFileIcon(item.extension);

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        item.isDir ? 'Folder • ${item.modifiedStr}' : '${item.sizeStr} • ${item.modifiedStr}',
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.more_vert, size: 20),
        onPressed: () => _showContextMenu(ctx, fp, item),
      ),
      onTap: () {
        if (item.isDir) {
          fp.navigateTo(item.path);
        } else {
          _openFile(ctx, item);
        }
      },
    );
  }

  void _showContextMenu(BuildContext ctx, FileProvider fp, FileItem item) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: const Color(0xFF1A1A24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
            Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _ctxTile(Icons.copy, 'Copy', () { fp.copyItem(item.path); Navigator.pop(ctx); _snack(ctx, 'Copied'); }),
            _ctxTile(Icons.cut, 'Cut', () { fp.cutItem(item.path); Navigator.pop(ctx); _snack(ctx, 'Cut'); }),
            _ctxTile(Icons.drive_file_rename_outline, 'Rename', () { Navigator.pop(ctx); _showRenameDialog(ctx, fp, item); }),
            _ctxTile(Icons.info_outline, 'Info', () { Navigator.pop(ctx); _showInfo(ctx, item.path); }),
            _ctxTile(Icons.delete_outline, 'Delete', () { Navigator.pop(ctx); _confirmDelete(ctx, fp, item); },
              color: Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _ctxTile(IconData icon, String text, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.white70),
      title: Text(text, style: TextStyle(color: color ?? Colors.white)),
      onTap: onTap,
    );
  }

  void _showCreateDialog(BuildContext ctx, FileProvider fp, bool isFolder) {
    final controller = TextEditingController();
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A24),
        title: Text(isFolder ? 'New Folder' : 'New File'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: isFolder ? 'Folder name' : 'filename.ext',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              final result = isFolder ? await fp.createFolder(name) : await fp.createFile(name);
              if (ctx.mounted) _snack(ctx, result['message'] ?? 'Done');
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext ctx, FileProvider fp, FileItem item) {
    final controller = TextEditingController(text: item.name);
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A24),
        title: const Text('Rename'),
        content: TextField(controller: controller, autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final result = await fp.renameItem(item.path, controller.text.trim());
              if (ctx.mounted) _snack(ctx, result['message'] ?? 'Done');
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext ctx, FileProvider fp, FileItem item) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A24),
        title: const Text('Delete?'),
        content: Text('Delete "${item.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final result = await fp.deleteItem(item.path);
              if (ctx.mounted) _snack(ctx, result['message'] ?? 'Done');
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _paste(BuildContext ctx, FileProvider fp) async {
    final result = await fp.pasteItem();
    if (ctx.mounted) _snack(ctx, result['message'] ?? 'Done');
  }

  Future<void> _openFile(BuildContext ctx, FileItem item) async {
    try {
      final data = await ApiService.readFile(item.path);
      if (data['success'] == true && ctx.mounted) {
        Navigator.push(ctx, MaterialPageRoute(
          builder: (_) => _FileViewerScreen(name: item.name, content: data['content'] ?? '', path: item.path),
        ));
      } else {
        if (ctx.mounted) _snack(ctx, data['message'] ?? 'Cannot open file');
      }
    } catch (e) {
      if (ctx.mounted) _snack(ctx, 'Error: $e');
    }
  }

  Future<void> _showInfo(BuildContext ctx, String path) async {
    try {
      final info = await ApiService.getFileInfo(path);
      if (ctx.mounted) {
        showDialog(
          context: ctx,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A24),
            title: const Text('File Info'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow('Name', info['name'] ?? ''),
                _infoRow('Size', info['size_str'] ?? ''),
                _infoRow('Type', info['is_dir'] == true ? 'Directory' : (info['extension'] ?? 'File')),
                _infoRow('Modified', info['modified'] ?? ''),
                _infoRow('Permissions', info['permissions'] ?? ''),
                _infoRow('MIME', info['mime_type'] ?? ''),
              ],
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
          ),
        );
      }
    } catch (e) {
      if (ctx.mounted) _snack(ctx, 'Error: $e');
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text('$label:', style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  void _snack(BuildContext ctx, String msg) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Color _getFileColor(String ext) {
    const codeExts = {'.py', '.js', '.ts', '.html', '.css', '.java', '.dart', '.json', '.xml', '.md', '.sh'};
    const imgExts = {'.jpg', '.jpeg', '.png', '.gif', '.svg', '.webp'};
    const audioExts = {'.mp3', '.wav', '.flac', '.aac', '.ogg'};
    const videoExts = {'.mp4', '.avi', '.mkv', '.mov', '.webm'};
    const archExts = {'.zip', '.rar', '.tar', '.gz', '.7z'};

    if (codeExts.contains(ext)) return Colors.green;
    if (imgExts.contains(ext)) return Colors.orange;
    if (audioExts.contains(ext)) return Colors.purple;
    if (videoExts.contains(ext)) return Colors.red;
    if (archExts.contains(ext)) return Colors.yellow;
    return Colors.grey;
  }

  IconData _getFileIcon(String ext) {
    const codeExts = {'.py', '.js', '.ts', '.html', '.css', '.java', '.dart', '.json', '.xml', '.md', '.sh'};
    const imgExts = {'.jpg', '.jpeg', '.png', '.gif', '.svg', '.webp'};
    const audioExts = {'.mp3', '.wav', '.flac', '.aac', '.ogg'};
    const videoExts = {'.mp4', '.avi', '.mkv', '.mov', '.webm'};
    const archExts = {'.zip', '.rar', '.tar', '.gz', '.7z'};

    if (codeExts.contains(ext)) return Icons.code;
    if (imgExts.contains(ext)) return Icons.image;
    if (audioExts.contains(ext)) return Icons.music_note;
    if (videoExts.contains(ext)) return Icons.video_file;
    if (archExts.contains(ext)) return Icons.archive;
    if (ext == '.pdf') return Icons.picture_as_pdf;
    if (ext == '.apk') return Icons.android;
    return Icons.insert_drive_file;
  }
}

class _FileViewerScreen extends StatefulWidget {
  final String name;
  final String content;
  final String path;

  const _FileViewerScreen({required this.name, required this.content, required this.path});

  @override
  State<_FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends State<_FileViewerScreen> {
  late TextEditingController _controller;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.content);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name, style: const TextStyle(fontSize: 16)),
        actions: [
          if (_editing)
            IconButton(
              icon: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                           : const Icon(Icons.save),
              onPressed: _save,
            ),
          IconButton(
            icon: Icon(_editing ? Icons.visibility : Icons.edit),
            onPressed: () => setState(() => _editing = !_editing),
          ),
        ],
      ),
      body: _editing
          ? TextField(
              controller: _controller,
              maxLines: null,
              expands: true,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                _controller.text,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final result = await ApiService.writeFile(widget.path, _controller.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
    setState(() { _saving = false; _editing = false; });
  }
}
