"""Auto-updater that checks GitHub Releases for new versions on launch."""

import json
import os
import sys
import subprocess
import tempfile
import shutil
import urllib.request
import urllib.error

GITHUB_OWNER = "skyeatsbrad"
GITHUB_REPO = "Boatry-McBoaterson"
CURRENT_VERSION = "1.0.0"
VERSION_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "version.txt")
API_URL = f"https://api.github.com/repos/{GITHUB_OWNER}/{GITHUB_REPO}/releases/latest"


def get_current_version():
    try:
        with open(VERSION_FILE, "r") as f:
            return f.read().strip()
    except Exception:
        return CURRENT_VERSION


def save_version(version):
    try:
        with open(VERSION_FILE, "w") as f:
            f.write(version)
    except Exception:
        pass


def check_for_update():
    """Returns (new_version, download_url) if update available, else (None, None)."""
    try:
        req = urllib.request.Request(API_URL, headers={"User-Agent": "Survivor-Game"})
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read().decode())
        latest = data.get("tag_name", "").lstrip("v")
        current = get_current_version().lstrip("v")
        if latest and latest != current:
            for asset in data.get("assets", []):
                if asset["name"].endswith(".zip"):
                    return latest, asset["browser_download_url"]
        return None, None
    except Exception:
        return None, None


def download_and_apply_update(version, url):
    """Downloads the zip and extracts it to replace the current installation."""
    try:
        tmp_dir = tempfile.mkdtemp()
        zip_path = os.path.join(tmp_dir, "update.zip")

        req = urllib.request.Request(url, headers={"User-Agent": "Survivor-Game"})
        with urllib.request.urlopen(req, timeout=60) as resp:
            with open(zip_path, "wb") as f:
                f.write(resp.read())

        import zipfile
        extract_dir = os.path.join(tmp_dir, "extracted")
        with zipfile.ZipFile(zip_path, "r") as zf:
            zf.extractall(extract_dir)

        # Find the Survivor.exe in extracted files
        app_dir = os.path.dirname(os.path.abspath(__file__))
        for root, dirs, files in os.walk(extract_dir):
            for fname in files:
                src = os.path.join(root, fname)
                # Compute relative path from extract root
                rel = os.path.relpath(src, extract_dir)
                # Strip top-level folder if present (e.g., "Survivor/Survivor.exe")
                parts = rel.split(os.sep)
                if len(parts) > 1:
                    rel = os.path.join(*parts[1:])
                dst = os.path.join(app_dir, rel)
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                # Skip overwriting ourselves while running
                if os.path.basename(dst).lower() == os.path.basename(sys.executable).lower():
                    pending = dst + ".update"
                    shutil.copy2(src, pending)
                else:
                    shutil.copy2(src, dst)

        save_version(version)
        shutil.rmtree(tmp_dir, ignore_errors=True)
        return True
    except Exception as e:
        print(f"Update failed: {e}")
        return False
