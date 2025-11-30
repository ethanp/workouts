#!/usr/bin/env python3
"""
Workouts - iPhone Deployment Script

A lean, reliable installer for deploying the app to a real iPhone.
Focuses on:
- Single responsibility: discover device(s) and install
- Clear, minimal flow with small helpers
- Inline deployment base functionality
"""

import hashlib
import json
import os
import subprocess
import time
from typing import Dict, List, Optional, Tuple


class Colors:
    """ANSI color codes for terminal output"""
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'


class IPhoneDeployment:
    """iPhone deployment with minimal branching and clear steps."""

    def __init__(self):
        self.script_name = "iPhone"
        self.build_type = "release"
        self.hash_file = '.build_hash_iphone'

    def print_header(self, text: str):
        """Print a formatted header"""
        print(f"{Colors.HEADER}{Colors.BOLD}{text}{Colors.ENDC}")
        print("=" * len(text))

    def print_success(self, text: str):
        """Print success message"""
        print(f"{Colors.OKGREEN}✅ {text}{Colors.ENDC}")

    def print_warning(self, text: str):
        """Print warning message"""
        print(f"{Colors.WARNING}⚠️  {text}{Colors.ENDC}")

    def print_error(self, text: str):
        """Print error message"""
        print(f"{Colors.FAIL}❌ {text}{Colors.ENDC}")

    def print_info(self, text: str):
        """Print info message"""
        print(f"{Colors.OKBLUE}📱 {text}{Colors.ENDC}")

    def run_command(self, command: List[str], capture_output: bool = True, check: bool = False) -> \
    Tuple[int, str, str]:
        """Run a command and return exit code, stdout, and stderr"""
        try:
            result = subprocess.run(
                command,
                capture_output=capture_output,
                text=True,
                check=check
            )
            return result.returncode, result.stdout, result.stderr
        except subprocess.CalledProcessError as e:
            return e.returncode, e.stdout, e.stderr

    def run_command_streaming(self, command: List[str], check: bool = False) -> int:
        """Run a command with real-time output streaming"""
        try:
            result = subprocess.run(
                command,
                check=check
            )
            return result.returncode
        except subprocess.CalledProcessError as e:
            return e.returncode

    def check_flutter_available(self) -> bool:
        """Check if Flutter is available"""
        returncode, _, _ = self.run_command(["flutter", "--version"], check=False)
        return returncode == 0

    def check_project_directory(self) -> bool:
        """Check if we're in the right directory"""
        return os.path.exists("pubspec.yaml")

    def get_file_hash(self, file_path: str) -> str:
        """Get MD5 hash of a file"""
        try:
            with open(file_path, 'rb') as f:
                return hashlib.md5(f.read()).hexdigest()
        except (IOError, OSError):
            return ""

    def get_directory_hash(self, directory: str, extensions: List[str] = None) -> str:
        """Get a hash representing the state of files in a directory"""
        if extensions is None:
            extensions = ['.dart', '.yaml', '.yml', '.json', '.png', '.jpg', '.jpeg', '.svg',
                          '.ttf', '.otf']

        hashes = []
        try:
            for root, dirs, files in os.walk(directory):
                dirs[:] = [d for d in dirs if
                           d not in ['build', '.dart_tool', 'ios/build', 'ios/Pods']]

                for file in files:
                    if any(file.endswith(ext) for ext in extensions):
                        file_path = os.path.join(root, file)
                        file_hash = self.get_file_hash(file_path)
                        if file_hash:
                            hashes.append(f"{file_path}:{file_hash}")
        except (IOError, OSError):
            pass

        hashes.sort()
        return hashlib.md5('\n'.join(hashes).encode()).hexdigest()

    def check_if_deployment_needed(self) -> None:
        """Check if deployment is needed based on file changes since last deployment."""
        self.print_info("Checking if deployment is needed...")

        directories_to_check = [
            'lib',
            'assets',
            'ios/Runner',
            'ios/Runner/Assets.xcassets'
        ]

        files_to_check = [
            'pubspec.yaml',
            'pubspec.lock',
            'ios/Runner/Info.plist'
        ]

        current_hashes = {}

        for directory in directories_to_check:
            if os.path.exists(directory):
                current_hashes[directory] = self.get_directory_hash(directory)

        for file_path in files_to_check:
            if os.path.exists(file_path):
                current_hashes[file_path] = self.get_file_hash(file_path)

        if os.path.exists(self.hash_file):
            try:
                with open(self.hash_file, 'r') as f:
                    stored_data = json.load(f)

                stored_hashes = stored_data.get('hashes', {})
                last_deploy_time = stored_data.get('last_deploy_time')

                if current_hashes == stored_hashes:
                    if last_deploy_time:
                        self.print_success(
                            "No changes detected since last deployment - skipping deployment")
                        print(f"Last deployment: {last_deploy_time}")
                        raise SystemExit(0)
                    else:
                        self.print_info(
                            "No changes detected, but no deployment timestamp found - proceeding with deployment")
                else:
                    self.print_info("Changes detected since last deployment - deployment needed")
            except (IOError, json.JSONDecodeError):
                self.print_info(
                    "Could not read previous deployment data - proceeding with deployment")
        else:
            self.print_info("No previous deployment data found - proceeding with deployment")

    def check_if_rebuild_needed(self) -> bool:
        """Check if a rebuild is needed based on file changes"""
        self.print_info("Checking for file changes...")

        directories_to_check = [
            'lib',
            'assets',
            'ios/Runner',
            'ios/Runner/Assets.xcassets'
        ]

        files_to_check = [
            'pubspec.yaml',
            'pubspec.lock',
            'ios/Runner/Info.plist'
        ]

        current_hashes = {}

        for directory in directories_to_check:
            if os.path.exists(directory):
                current_hashes[directory] = self.get_directory_hash(directory)

        for file_path in files_to_check:
            if os.path.exists(file_path):
                current_hashes[file_path] = self.get_file_hash(file_path)

        if os.path.exists(self.hash_file):
            try:
                with open(self.hash_file, 'r') as f:
                    stored_data = json.load(f)

                stored_hashes = stored_data.get('hashes', {})

                if current_hashes == stored_hashes:
                    self.print_success("No changes detected - skipping clean and rebuild")
                    return False
                else:
                    self.print_info("Changes detected - rebuild needed")
            except (IOError, json.JSONDecodeError):
                self.print_info("Could not read previous build hash - rebuilding")
        else:
            self.print_info("No previous build hash found - rebuilding")

        try:
            with open(self.hash_file, 'w') as f:
                json.dump(current_hashes, f, indent=2)
        except IOError:
            self.print_warning("Could not save build hash")

        return True

    def build_app(self) -> None:
        """Build the Flutter app."""
        rebuild_needed = self.check_if_rebuild_needed()

        if rebuild_needed:
            self.print_info("🧹 Cleaning previous build...")
            returncode = self.run_command_streaming(["flutter", "clean"], check=False)
            if returncode != 0:
                raise RuntimeError("Failed to clean previous build artifacts.")

            self.print_info("📦 Getting dependencies...")
            returncode = self.run_command_streaming(["flutter", "pub", "get"], check=False)
            if returncode != 0:
                raise RuntimeError("Failed to fetch Flutter dependencies.")

            self.print_info("🔨 Generating code...")
            returncode = self.run_command_streaming([
                "flutter", "packages", "pub", "run", "build_runner", "build",
                "--delete-conflicting-outputs"
            ], check=False)
            if returncode != 0:
                raise RuntimeError("Failed to run build_runner code generation.")

            self.print_info(f"🏗️  Building iOS {self.build_type} version...")
            returncode = self.run_command_streaming([
                "flutter", "build", "ios", f"--{self.build_type}", "--no-tree-shake-icons"
            ], check=False)
            if returncode != 0:
                raise RuntimeError("Failed to build the iOS target.")
        else:
            self.print_info("📦 Getting dependencies (no rebuild needed)...")
            returncode = self.run_command_streaming(["flutter", "pub", "get"], check=False)
            if returncode != 0:
                raise RuntimeError("Failed to fetch Flutter dependencies.")

    def record_deployment_timestamp(self):
        """Record the current deployment timestamp"""
        try:
            if os.path.exists(self.hash_file):
                with open(self.hash_file, 'r') as f:
                    stored_data = json.load(f)

                hashes = stored_data.get('hashes', {})
            else:
                hashes = {}

            deployment_data = {
                'hashes': hashes,
                'last_deploy_time': time.strftime('%Y-%m-%d %H:%M:%S')
            }

            with open(self.hash_file, 'w') as f:
                json.dump(deployment_data, f, indent=2)

        except IOError:
            self.print_warning("Could not save deployment timestamp")

    def check_prerequisites(self) -> None:
        """Check if all prerequisites are met."""
        if not self.check_flutter_available():
            raise RuntimeError("Flutter is not installed or not in PATH.")

        if not self.check_project_directory():
            raise RuntimeError("pubspec.yaml not found. Please run this script from the project "
                               "root directory.")

    # ----- Device Discovery -----
    def _read_command(self, command: List[str]) -> Optional[str]:
        """Run a command and return stdout when successful."""
        code, stdout, _ = self.run_command(command, check=False)
        return stdout or "" if code == 0 else None

    def _list_ios_devices(self) -> List[Dict[str, str]]:
        """Return a list of PHYSICAL iOS devices from `flutter devices` output.

        Output example line:
        "Ethan's iPhone • 00008030-... • ios • iOS 17.5"
        """
        code, stdout, stderr = self.run_command(["flutter", "devices"], check=False)
        if code != 0:
            raise RuntimeError(f"Failed to list devices: {stderr.strip() or stdout.strip()}")

        devices: List[Dict[str, str]] = []
        for line in stdout.splitlines():
            if "•" not in line:
                continue
            parts = [p.strip() for p in line.split("•")]
            if len(parts) < 3:
                continue
            name, device_id, platform = parts[0], parts[1], parts[2]
            lower_line = line.lower()
            lower_platform = platform.lower()

            # Skip simulators explicitly
            if "simulator" in lower_line or "com.apple.coresimulator" in lower_platform:
                continue

            # Keep only physical iOS devices (USB or wireless)
            if "ios" in lower_platform or "mobile" in lower_platform:
                devices.append({"name": name, "id": device_id})
        return devices

    # ----- Installation -----
    def _install_to_device(self, device_id: str) -> None:
        self.print_info(f"Installing to iPhone: -d {device_id}")
        code = self.run_command_streaming(["flutter", "install", "--release", "-d", device_id],
                                          check=False)

        if code != 0:
            raise RuntimeError("Installation failed. See flutter install output above for details.")

        self.print_success("Deployment complete! 🎉")

    # ----- Orchestration -----
    def deploy(self) -> None:
        """Discover devices and install with the simplest possible logic."""
        self.print_warning("VPN detection does not work. Disable any active VPN to prevent "
                           "deployment from stalling indefinitely after the build completes.")
        self.print_info("Checking for iOS devices...")
        devices = self._list_ios_devices()

        if len(devices) != 1:
            if not devices:
                raise RuntimeError(
                    "No physical iPhone detected. Unlock and connect via USB or Wi-Fi and retry."
                )

            device_list = "\n".join(f"  • {device['name']} ({device['id']})" for device in devices)
            raise RuntimeError(
                "Multiple physical iPhones detected. Disconnect extra devices before deploying.\n"
                f"Detected devices:\n{device_list}"
            )

        self._install_to_device(devices[0]["id"])

    def main(self):
        """Main deployment function."""
        self.print_header(f"Workouts - {self.script_name} Deployment Script")

        self.check_prerequisites()
        self.check_if_deployment_needed()
        self.build_app()
        self.deploy()

        self.record_deployment_timestamp()


if __name__ == "__main__":
    IPhoneDeployment().main()

