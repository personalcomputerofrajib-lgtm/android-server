"""
Server Manager — Backend
Manages HTTP/Node/Custom servers with ring-buffer logs
"""

import os
import subprocess
import threading
import socket
import time
from collections import deque


class ServerInstance:
    """Single server instance"""
    def __init__(self, sid, name, stype, port, directory, command):
        self.id = sid
        self.name = name
        self.server_type = stype
        self.port = port
        self.directory = directory
        self.command = command
        self.process = None
        self.status = "stopped"
        self.pid = None
        self.start_time = 0
        self._logs = deque(maxlen=500)

    @property
    def logs(self):
        return list(self._logs)

    def add_log(self, msg):
        ts = time.strftime("%H:%M:%S")
        self._logs.append(f"[{ts}] {msg}")

    def to_dict(self):
        uptime = time.time() - self.start_time if self.status == "running" and self.start_time else 0
        return {
            "id": self.id,
            "name": self.name,
            "type": self.server_type,
            "port": self.port,
            "status": self.status,
            "pid": self.pid,
            "uptime": round(uptime),
            "uptime_str": self._fmt_uptime(uptime),
            "directory": self.directory,
            "command": self.command,
            "log_count": len(self._logs),
        }

    @staticmethod
    def _fmt_uptime(sec):
        if sec < 60:
            return f"{int(sec)}s"
        elif sec < 3600:
            return f"{int(sec//60)}m {int(sec%60)}s"
        return f"{int(sec//3600)}h {int((sec%3600)//60)}m"


class ServerManager:
    """Manages multiple server instances"""

    def __init__(self):
        self.servers = {}
        self._counter = 0

    def _next_id(self):
        self._counter += 1
        return f"srv_{self._counter}"

    @staticmethod
    def find_available_port(start=8000):
        port = start
        while port < 65535:
            try:
                s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                s.settimeout(1)
                s.bind(("", port))
                s.close()
                return port
            except OSError:
                port += 1
        raise RuntimeError("No available ports")

    @staticmethod
    def get_local_ip():
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            ip = s.getsockname()[0]
            s.close()
            return ip
        except Exception:
            return "127.0.0.1"

    def start_server(self, name, command, directory, port=8000, server_type="custom"):
        sid = self._next_id()
        try:
            actual_port = self.find_available_port(port)
        except RuntimeError as e:
            srv = ServerInstance(sid, name, server_type, port, directory, command)
            srv.status = "error"
            srv.add_log(str(e))
            self.servers[sid] = srv
            return srv.to_dict()

        # Replace port placeholder in command
        cmd = command.replace("{port}", str(actual_port)).replace("{PORT}", str(actual_port))

        srv = ServerInstance(sid, name, server_type, actual_port, directory, cmd)
        self.servers[sid] = srv
        self._run(srv)
        return srv.to_dict()

    def start_python_http(self, directory, port=8000):
        import shutil
        py = "python3" if shutil.which("python3") else "python"
        return self.start_server(
            f"Python HTTP :{port}", f"{py} -m http.server {{port}}",
            directory, port, "python_http"
        )

    def start_npm(self, directory, script="start", port=3000):
        return self.start_server(
            f"NPM {script} :{port}", f"npm run {script}" if script != "start" else "npm start",
            directory, port, "npm"
        )

    def _run(self, srv):
        def worker():
            try:
                if os.name == "nt":
                    shell_cmd = ["cmd", "/c", srv.command]
                else:
                    shell_cmd = ["/bin/sh", "-c", srv.command]

                env = os.environ.copy()
                env["PORT"] = str(srv.port)

                srv.process = subprocess.Popen(
                    shell_cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                    stdin=subprocess.PIPE, cwd=srv.directory, env=env,
                    bufsize=1, universal_newlines=True,
                )
                srv.pid = srv.process.pid
                srv.status = "running"
                srv.start_time = time.time()
                srv.add_log(f"Started (PID:{srv.pid})")

                try:
                    for line in iter(srv.process.stdout.readline, ""):
                        if line:
                            srv.add_log(line.rstrip())
                except (ValueError, OSError):
                    pass

                srv.process.wait()
                srv.status = "stopped"
                srv.add_log("Stopped")
            except Exception as e:
                srv.status = "error"
                srv.add_log(f"Error: {e}")

        threading.Thread(target=worker, daemon=True).start()

    def stop_server(self, sid):
        srv = self.servers.get(sid)
        if not srv or not srv.process:
            return {"success": False, "message": "Not found or not running"}
        try:
            srv.process.terminate()
            time.sleep(1)
            if srv.process.poll() is None:
                srv.process.kill()
            srv.status = "stopped"
            srv.add_log("Stopped by user")
            return {"success": True, "message": "Stopped"}
        except Exception as e:
            return {"success": False, "message": str(e)}

    def stop_all(self):
        for sid in list(self.servers.keys()):
            self.stop_server(sid)
        return {"success": True, "message": "All stopped"}

    def restart_server(self, sid):
        srv = self.servers.get(sid)
        if not srv:
            return {"success": False, "message": "Not found"}
        self.stop_server(sid)
        time.sleep(1)
        self._run(srv)
        return {"success": True, "message": "Restarting"}

    def remove_server(self, sid):
        self.stop_server(sid)
        self.servers.pop(sid, None)
        return {"success": True}

    def get_all(self):
        return [s.to_dict() for s in self.servers.values()]

    def get_logs(self, sid, last_n=50):
        srv = self.servers.get(sid)
        return srv.logs[-last_n:] if srv else []

    def get_status(self, sid):
        srv = self.servers.get(sid)
        return srv.to_dict() if srv else {"error": "Not found"}
