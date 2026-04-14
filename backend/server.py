"""
=============================================================
FILE MANAGER PRO — REST API SERVER v3.1
=============================================================
Run:  python server.py
API:  http://127.0.0.1:8000

Features:
  - API Key authentication (X-API-Key header)
  - CORS enabled for Flutter app
  - Auto-start prints connection info for real devices
=============================================================
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
from functools import wraps
import os
import shutil
import secrets

from core.file_operations import FileOperations
from core.terminal_engine import TerminalEngine
from core.server_manager import ServerManager

app = Flask(__name__)
CORS(app)

# Engine instances
file_ops = FileOperations()
terminal = TerminalEngine()
server_mgr = ServerManager()

# ==================== AUTHENTICATION ====================

# API Key — must match the key in Flutter's ApiService
API_KEY = os.environ.get("FMPRO_API_KEY", "fmpro_2024_secure_key")

# Public routes that don't need auth (health check only)
PUBLIC_ROUTES = {"/", "/api/health"}


@app.before_request
def check_api_key():
    """Validate API key on every request except public routes"""
    if request.path in PUBLIC_ROUTES:
        return None
    
    provided_key = request.headers.get("X-API-Key", "")
    if provided_key != API_KEY:
        return jsonify({
            "error": "Unauthorized",
            "message": "Invalid or missing API key. Add X-API-Key header."
        }), 401


# ==================== HEALTH ====================

@app.route("/", methods=["GET"])
def index():
    return jsonify({
        "app": "File Manager Pro API",
        "version": "3.1",
        "status": "running",
        "auth": "API key required (X-API-Key header)",
        "endpoints": {
            "files": "/api/files",
            "terminal": "/api/terminal",
            "servers": "/api/servers",
            "storage": "/api/storage",
            "search": "/api/search",
        }
    })


@app.route("/api/health", methods=["GET"])
def health():
    return jsonify({"status": "ok"})


# ==================== FILES ====================

@app.route("/api/files", methods=["GET"])
def list_files():
    """List directory contents"""
    path = request.args.get("path", file_ops.get_storage_root())
    show_hidden = request.args.get("hidden", "false").lower() == "true"
    sort_by = request.args.get("sort", "name")
    result = file_ops.list_directory(path, show_hidden=show_hidden, sort_by=sort_by)
    if isinstance(result, dict) and "error" in result:
        return jsonify(result), 400
    return jsonify({"path": path, "items": result, "count": len(result)})


@app.route("/api/files/info", methods=["GET"])
def file_info():
    """Get file/folder info"""
    path = request.args.get("path", "")
    if not path:
        return jsonify({"error": "path required"}), 400
    return jsonify(file_ops.get_file_info(path))


@app.route("/api/files/read", methods=["GET"])
def read_file():
    """Read text file content"""
    path = request.args.get("path", "")
    if not path:
        return jsonify({"error": "path required"}), 400
    return jsonify(file_ops.read_file(path))


@app.route("/api/files/write", methods=["POST"])
def write_file():
    """Write content to file"""
    data = request.get_json()
    path = data.get("path", "")
    content = data.get("content", "")
    if not path:
        return jsonify({"error": "path required"}), 400
    return jsonify(file_ops.write_file(path, content))


@app.route("/api/files/create-folder", methods=["POST"])
def create_folder():
    """Create new folder"""
    data = request.get_json()
    path = data.get("path", "")
    name = data.get("name", "")
    if not path or not name:
        return jsonify({"error": "path and name required"}), 400
    return jsonify(file_ops.create_folder(path, name))


@app.route("/api/files/create-file", methods=["POST"])
def create_file():
    """Create new file"""
    data = request.get_json()
    path = data.get("path", "")
    name = data.get("name", "")
    content = data.get("content", "")
    if not path or not name:
        return jsonify({"error": "path and name required"}), 400
    return jsonify(file_ops.create_file(path, name, content))


@app.route("/api/files/delete", methods=["POST"])
def delete_item():
    """Delete file/folder"""
    data = request.get_json()
    path = data.get("path", "")
    if not path:
        return jsonify({"error": "path required"}), 400
    return jsonify(file_ops.delete_item(path))


@app.route("/api/files/rename", methods=["POST"])
def rename_item():
    """Rename file/folder"""
    data = request.get_json()
    path = data.get("path", "")
    new_name = data.get("new_name", "")
    if not path or not new_name:
        return jsonify({"error": "path and new_name required"}), 400
    return jsonify(file_ops.rename_item(path, new_name))


@app.route("/api/files/copy", methods=["POST"])
def copy_item():
    data = request.get_json()
    path = data.get("path", "")
    return jsonify(file_ops.copy_item(path))


@app.route("/api/files/cut", methods=["POST"])
def cut_item():
    data = request.get_json()
    path = data.get("path", "")
    return jsonify(file_ops.cut_item(path))


@app.route("/api/files/paste", methods=["POST"])
def paste_item():
    data = request.get_json()
    destination = data.get("destination", "")
    return jsonify(file_ops.paste_item(destination))


# ==================== SEARCH ====================

@app.route("/api/search", methods=["GET"])
def search_files():
    """Search files by name"""
    query = request.args.get("q", "")
    root = request.args.get("root", file_ops.get_storage_root())
    max_results = int(request.args.get("max", "100"))
    if not query:
        return jsonify({"error": "q parameter required"}), 400
    results = file_ops.search_files(root, query, max_results)
    return jsonify({"query": query, "results": results, "count": len(results)})


# ==================== STORAGE ====================

@app.route("/api/storage", methods=["GET"])
def storage_info():
    """Get storage/disk info"""
    path = request.args.get("path", None)
    return jsonify(file_ops.get_storage_info(path))


# ==================== TERMINAL ====================

@app.route("/api/terminal/execute", methods=["POST"])
def terminal_execute():
    """Execute a terminal command"""
    data = request.get_json()
    command = data.get("command", "")
    if not command:
        return jsonify({"error": "command required"}), 400
    result = terminal.execute(command)
    return jsonify(result)


@app.route("/api/terminal/kill", methods=["POST"])
def terminal_kill():
    """Kill running process"""
    return jsonify(terminal.kill_process())


@app.route("/api/terminal/autocomplete", methods=["GET"])
def terminal_autocomplete():
    """Get autocomplete suggestions"""
    partial = request.args.get("q", "")
    return jsonify({"suggestions": terminal.autocomplete(partial)})


@app.route("/api/terminal/history", methods=["GET"])
def terminal_history():
    """Get command history"""
    return jsonify({"history": terminal.get_history()})


@app.route("/api/terminal/cwd", methods=["GET"])
def terminal_cwd():
    """Get current working directory"""
    return jsonify({"cwd": terminal.current_dir, "prompt": terminal.get_prompt()})


# ==================== SERVERS ====================

@app.route("/api/servers", methods=["GET"])
def list_servers():
    """List all server instances"""
    return jsonify({
        "servers": server_mgr.get_all(),
        "local_ip": server_mgr.get_local_ip(),
    })


@app.route("/api/servers/start", methods=["POST"])
def start_server():
    """Start a new server"""
    data = request.get_json()
    stype = data.get("type", "custom")
    directory = data.get("directory", file_ops.get_storage_root())
    port = int(data.get("port", 8000))

    if stype == "python_http":
        result = server_mgr.start_python_http(directory, port)
    elif stype == "npm":
        script = data.get("script", "start")
        result = server_mgr.start_npm(directory, script, port)
    else:
        command = data.get("command", "")
        name = data.get("name", "Custom Server")
        if not command:
            return jsonify({"error": "command required for custom server"}), 400
        result = server_mgr.start_server(name, command, directory, port)

    return jsonify(result)


@app.route("/api/servers/<sid>/stop", methods=["POST"])
def stop_server(sid):
    return jsonify(server_mgr.stop_server(sid))


@app.route("/api/servers/<sid>/restart", methods=["POST"])
def restart_server(sid):
    return jsonify(server_mgr.restart_server(sid))


@app.route("/api/servers/<sid>/remove", methods=["POST"])
def remove_server(sid):
    return jsonify(server_mgr.remove_server(sid))


@app.route("/api/servers/<sid>/logs", methods=["GET"])
def server_logs(sid):
    last_n = int(request.args.get("n", "50"))
    return jsonify({"logs": server_mgr.get_logs(sid, last_n)})


@app.route("/api/servers/<sid>/status", methods=["GET"])
def server_status(sid):
    return jsonify(server_mgr.get_status(sid))


@app.route("/api/servers/stop-all", methods=["POST"])
def stop_all_servers():
    return jsonify(server_mgr.stop_all())


# ==================== RUN ====================

if __name__ == "__main__":
    ip = server_mgr.get_local_ip()
    port = int(os.environ.get("PORT", 8000))

    print()
    print("=" * 55)
    print("  FILE MANAGER PRO - API SERVER v3.1")
    print("=" * 55)
    print(f"  Local:     http://127.0.0.1:{port}")
    print(f"  Network:   http://{ip}:{port}")
    print(f"  Auth:      API Key required (X-API-Key header)")
    print("-" * 55)
    print("  CONNECT FROM REAL PHONE:")
    print(f"    Set Flutter baseUrl to: http://{ip}:{port}")
    print("    Both devices must be on same WiFi network")
    print("=" * 55)
    print()

    app.run(host="0.0.0.0", port=port, debug=False)
