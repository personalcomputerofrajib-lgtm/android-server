"""
Terminal Engine — Backend
Command execution, history, autocomplete
"""

import os
import subprocess
import threading
import queue
import time
import shutil


class TerminalEngine:
    """Terminal/Shell engine"""

    def __init__(self):
        self.current_dir = self._default_dir()
        self.process = None
        self.output_queue = queue.Queue()
        self.is_running = False
        self.command_history = []
        self.history_index = -1
        self.env = os.environ.copy()
        self.env["TERM"] = "xterm-256color"
        self.env["LANG"] = "en_US.UTF-8"

    @staticmethod
    def _default_dir():
        if os.path.exists("/sdcard"):
            return "/sdcard"
        return os.path.expanduser("~")

    def execute(self, command):
        """Execute command and return full output (blocking)"""
        if not command.strip():
            return {"output": "", "cwd": self.current_dir}

        self.command_history.append(command)
        self.history_index = len(self.command_history)

        # Builtins
        result = self._builtin(command)
        if result is not None:
            return {"output": result, "cwd": self.current_dir, "prompt": self.get_prompt()}

        # External command
        return self._external(command)

    def _builtin(self, command):
        parts = command.strip().split()
        cmd = parts[0].lower()

        if cmd == "cd":
            target = parts[1] if len(parts) > 1 else "~"
            return self._cd(target)
        elif cmd == "pwd":
            return self.current_dir
        elif cmd == "clear" or cmd == "cls":
            return "__CLEAR__"
        elif cmd == "history":
            if len(self.command_history) <= 1:
                return "No history"
            return "\n".join(f"  {i+1}  {c}" for i, c in enumerate(self.command_history[:-1]))
        elif cmd == "echo":
            text = " ".join(parts[1:])
            for k, v in self.env.items():
                text = text.replace(f"${k}", v).replace(f"${{{k}}}", v)
            return text
        elif cmd == "which" or cmd == "where":
            if len(parts) >= 2:
                found = shutil.which(parts[1])
                return found or f"{parts[1]}: not found"
            return "Usage: which <command>"
        elif cmd == "whoami":
            return os.environ.get("USER", os.environ.get("USERNAME", "unknown"))
        elif cmd == "date":
            return time.strftime("%Y-%m-%d %H:%M:%S")
        elif cmd == "export" or cmd == "set":
            if len(parts) >= 2 and "=" in parts[1]:
                k, v = parts[1].split("=", 1)
                self.env[k] = v
                return f"Set {k}={v}"
            return "\n".join(f"{k}={v}" for k, v in sorted(self.env.items())[:30])
        elif cmd == "help":
            return self._help()
        elif cmd == "exit" or cmd == "quit":
            return "__EXIT__"
        return None

    def _cd(self, path):
        if path == "~":
            path = self._default_dir()
        elif path == "..":
            path = os.path.dirname(self.current_dir)
        elif not os.path.isabs(path):
            path = os.path.join(self.current_dir, path)
        path = os.path.normpath(os.path.abspath(path))
        if os.path.isdir(path):
            self.current_dir = path
            return f"cd: {path}"
        return f"cd: no such directory: {path}"

    def _external(self, command):
        """Run external command, return output"""
        self.is_running = True
        output_lines = []
        return_code = -1

        try:
            if os.name == "nt":
                shell_cmd = ["cmd", "/c", command]
            else:
                shell_cmd = ["/bin/sh", "-c", command]

            proc = subprocess.Popen(
                shell_cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                stdin=subprocess.PIPE, cwd=self.current_dir, env=self.env,
                bufsize=1, universal_newlines=True,
            )
            self.process = proc

            for line in iter(proc.stdout.readline, ""):
                if line:
                    output_lines.append(line.rstrip())

            proc.wait()
            return_code = proc.returncode

            if return_code != 0 and not output_lines:
                output_lines.append(f"Process exited with code {return_code}")

        except FileNotFoundError:
            output_lines.append(f"Command not found: {command.split()[0]}")
        except Exception as e:
            output_lines.append(f"Error: {str(e)}")
        finally:
            self.is_running = False
            self.process = None

        return {
            "output": "\n".join(output_lines),
            "return_code": return_code,
            "cwd": self.current_dir,
            "prompt": self.get_prompt(),
        }

    def kill_process(self):
        """Kill running process"""
        if self.process:
            try:
                self.process.terminate()
                time.sleep(0.3)
                if self.process.poll() is None:
                    self.process.kill()
                return {"success": True, "message": "Process killed"}
            except Exception as e:
                return {"success": False, "message": str(e)}
            finally:
                self.is_running = False
        return {"success": False, "message": "No running process"}

    def autocomplete(self, partial):
        """Tab completion"""
        completions = []
        parts = partial.strip().split()

        if len(parts) <= 1:
            search = parts[0] if parts else ""
            builtins = ["cd", "pwd", "clear", "history", "export", "echo", "help", "which", "whoami", "date"]
            for b in builtins:
                if b.startswith(search.lower()):
                    completions.append(b)
            for path_dir in self.env.get("PATH", "").split(os.pathsep):
                if os.path.isdir(path_dir):
                    try:
                        for item in os.listdir(path_dir):
                            if item.lower().startswith(search.lower()):
                                completions.append(item)
                    except (PermissionError, OSError):
                        pass
        else:
            search = parts[-1]
            search_dir = self.current_dir
            search_base = search
            if os.sep in search:
                search_dir = os.path.join(self.current_dir, os.path.dirname(search))
                search_base = os.path.basename(search)
            if os.path.isdir(search_dir):
                try:
                    for item in os.listdir(search_dir):
                        if item.lower().startswith(search_base.lower()):
                            suffix = "/" if os.path.isdir(os.path.join(search_dir, item)) else ""
                            completions.append(item + suffix)
                except (PermissionError, OSError):
                    pass

        return sorted(set(completions))[:20]

    def get_prompt(self):
        home = self._default_dir()
        display = self.current_dir.replace(home, "~")
        return f"$ {display} > "

    def get_history(self):
        return self.command_history

    @staticmethod
    def _help():
        return """
========================================
         TERMINAL HELP
========================================
BUILT-IN: cd, pwd, clear, history, export,
          echo, which, whoami, date, help, exit

COMMON:   ls, cat, mkdir, rm, cp, mv, grep,
          find, chmod, python3, pip3, node, npm,
          git

Tab = Autocomplete | Up/Down = History
========================================
"""
