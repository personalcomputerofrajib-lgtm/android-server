"""
File Operations Engine — Backend
Complete file/folder CRUD with async dir size
"""

import os
import shutil
import stat
import time
import threading
import mimetypes

mimetypes.init()


class FileOperations:
    """All file system operations"""

    def __init__(self):
        self.clipboard = None
        self._dir_size_cache = {}

    @staticmethod
    def get_storage_root():
        """Platform-aware storage root"""
        home = os.path.expanduser("~")
        # Android
        if os.path.exists("/sdcard"):
            return "/sdcard"
        return home

    @staticmethod
    def list_directory(path, show_hidden=False, sort_by="name"):
        """List directory contents with full metadata"""
        items = []
        try:
            entries = os.listdir(path)
        except PermissionError:
            return {"error": "Permission denied", "path": path}
        except FileNotFoundError:
            return {"error": "Directory not found", "path": path}
        except OSError as e:
            return {"error": str(e), "path": path}

        for entry in entries:
            if not show_hidden and entry.startswith("."):
                continue
            full_path = os.path.join(path, entry)
            try:
                st = os.stat(full_path)
                is_dir = os.path.isdir(full_path)
                items.append({
                    "name": entry,
                    "path": full_path,
                    "is_dir": is_dir,
                    "size": st.st_size if not is_dir else 0,
                    "modified": st.st_mtime,
                    "modified_str": time.strftime("%Y-%m-%d %H:%M", time.localtime(st.st_mtime)),
                    "extension": os.path.splitext(entry)[1].lower() if not is_dir else "",
                    "permissions": stat.filemode(st.st_mode),
                    "is_symlink": os.path.islink(full_path),
                })
            except (PermissionError, OSError):
                items.append({
                    "name": entry, "path": full_path, "is_dir": False,
                    "size": 0, "modified": 0, "modified_str": "Unknown",
                    "extension": "", "permissions": "----------",
                    "is_symlink": False, "error": "Cannot read",
                })

        sort_keys = {
            "name": lambda x: (not x["is_dir"], x["name"].lower()),
            "size": lambda x: (not x["is_dir"], x["size"]),
            "date": lambda x: (not x["is_dir"], -x["modified"]),
            "type": lambda x: (not x["is_dir"], x["extension"], x["name"].lower()),
        }
        items.sort(key=sort_keys.get(sort_by, sort_keys["name"]))
        return items

    @staticmethod
    def create_folder(path, name):
        new_path = os.path.join(path, name)
        try:
            os.makedirs(new_path, exist_ok=False)
            return {"success": True, "message": f"Folder '{name}' created", "path": new_path}
        except FileExistsError:
            return {"success": False, "message": f"'{name}' already exists"}
        except PermissionError:
            return {"success": False, "message": "Permission denied"}
        except Exception as e:
            return {"success": False, "message": str(e)}

    @staticmethod
    def create_file(path, name, content=""):
        new_path = os.path.join(path, name)
        try:
            if os.path.exists(new_path):
                return {"success": False, "message": f"'{name}' already exists"}
            with open(new_path, "w") as f:
                f.write(content)
            return {"success": True, "message": f"File '{name}' created", "path": new_path}
        except PermissionError:
            return {"success": False, "message": "Permission denied"}
        except Exception as e:
            return {"success": False, "message": str(e)}

    @staticmethod
    def delete_item(path):
        try:
            if os.path.isdir(path):
                shutil.rmtree(path)
            else:
                os.remove(path)
            return {"success": True, "message": "Deleted"}
        except PermissionError:
            return {"success": False, "message": "Permission denied"}
        except Exception as e:
            return {"success": False, "message": str(e)}

    @staticmethod
    def rename_item(old_path, new_name):
        directory = os.path.dirname(old_path)
        new_path = os.path.join(directory, new_name)
        try:
            if os.path.exists(new_path):
                return {"success": False, "message": f"'{new_name}' already exists"}
            os.rename(old_path, new_path)
            return {"success": True, "message": f"Renamed to '{new_name}'", "path": new_path}
        except PermissionError:
            return {"success": False, "message": "Permission denied"}
        except Exception as e:
            return {"success": False, "message": str(e)}

    def copy_item(self, path):
        self.clipboard = {"path": path, "operation": "copy"}
        return {"success": True, "message": f"Copied: {os.path.basename(path)}"}

    def cut_item(self, path):
        self.clipboard = {"path": path, "operation": "cut"}
        return {"success": True, "message": f"Cut: {os.path.basename(path)}"}

    def paste_item(self, destination):
        if not self.clipboard:
            return {"success": False, "message": "Nothing to paste"}
        src = self.clipboard["path"]
        name = os.path.basename(src)
        dest = os.path.join(destination, name)
        try:
            if os.path.exists(dest):
                base, ext = os.path.splitext(name)
                counter = 1
                while os.path.exists(dest):
                    dest = os.path.join(destination, f"{base}_copy{counter}{ext}")
                    counter += 1
            if os.path.isdir(src):
                shutil.copytree(src, dest)
            else:
                shutil.copy2(src, dest)
            if self.clipboard["operation"] == "cut":
                self.delete_item(src)
                self.clipboard = None
            return {"success": True, "message": f"Pasted '{name}'"}
        except Exception as e:
            return {"success": False, "message": str(e)}

    @staticmethod
    def get_file_info(path):
        try:
            st = os.stat(path)
            return {
                "name": os.path.basename(path),
                "path": path,
                "parent": os.path.dirname(path),
                "is_dir": os.path.isdir(path),
                "size": st.st_size,
                "size_str": FileOperations.format_size(st.st_size),
                "created": time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(st.st_ctime)),
                "modified": time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(st.st_mtime)),
                "permissions": stat.filemode(st.st_mode),
                "extension": os.path.splitext(path)[1],
                "mime_type": mimetypes.guess_type(path)[0] or "unknown",
            }
        except Exception as e:
            return {"error": str(e)}

    @staticmethod
    def read_file(path, max_bytes=50000):
        """Read text file content"""
        try:
            with open(path, "r", errors="replace") as f:
                return {"success": True, "content": f.read(max_bytes), "path": path}
        except Exception as e:
            return {"success": False, "message": str(e)}

    @staticmethod
    def write_file(path, content):
        """Write content to file"""
        try:
            with open(path, "w") as f:
                f.write(content)
            return {"success": True, "message": "File saved"}
        except Exception as e:
            return {"success": False, "message": str(e)}

    @staticmethod
    def search_files(root_path, query, max_results=100):
        results = []
        query_lower = query.lower()
        try:
            for dirpath, dirnames, filenames in os.walk(root_path):
                dirnames[:] = [d for d in dirnames if not d.startswith(".")]
                for name in dirnames + filenames:
                    if query_lower in name.lower():
                        full_path = os.path.join(dirpath, name)
                        results.append({
                            "name": name,
                            "path": full_path,
                            "is_dir": os.path.isdir(full_path),
                        })
                        if len(results) >= max_results:
                            return results
        except (PermissionError, OSError):
            pass
        return results

    @staticmethod
    def get_storage_info(path=None):
        if not path:
            path = FileOperations.get_storage_root()
        try:
            u = shutil.disk_usage(path)
            return {
                "path": path,
                "total": u.total,
                "used": u.used,
                "free": u.free,
                "total_str": FileOperations.format_size(u.total),
                "used_str": FileOperations.format_size(u.used),
                "free_str": FileOperations.format_size(u.free),
                "percent": round((u.used / u.total) * 100, 1),
            }
        except Exception as e:
            return {"error": str(e)}

    @staticmethod
    def format_size(size_bytes):
        if size_bytes == 0:
            return "0 B"
        units = ["B", "KB", "MB", "GB", "TB"]
        idx = 0
        size = float(size_bytes)
        while size >= 1024 and idx < len(units) - 1:
            size /= 1024
            idx += 1
        return f"{size:.1f} {units[idx]}"
