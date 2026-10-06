#!/bin/bash

# Advanced USB-C Scanner + Diagnostic Tool
# Copy & paste this entire script into Termux

set -e

echo -e "\033[1;36m╔═════════════════════════════════════════════╗\033[0m"
echo -e "\033[1;36m║  USB-C SCANNER ADVANCED INSTALLER - TERMUX  ║\033[0m"
echo -e "\033[1;36m╚═════════════════════════════════════════════╝\033[0m"
echo ""

echo -e "\033[1;33m[1/6]\033[0m Updating Termux packages..."
pkg update -y >/dev/null 2>&1 || true
pkg install -y python git >/dev/null 2>&1 || true

echo -e "\033[1;33m[2/6]\033[0m Creating scanner directory..."
mkdir -p ~/usb-scanner
cd ~/usb-scanner

echo -e "\033[1;33m[3/6]\033[0m Installing Python dependencies..."
pip install --upgrade pip >/dev/null 2>&1 || true
pip install rich >/dev/null 2>&1 || true

echo -e "\033[1;33m[4/6]\033[0m Downloading scanner script..."
cat > usb_scanner.py << 'SCANNER'
#!/usr/bin/env python3
"""Advanced USB-C scanner for Termux with Rich UI and instant detection."""

from __future__ import annotations

import argparse
import glob
import os
import random
import subprocess
import sys
import time
from typing import Dict, List

from rich.align import Align
from rich.console import Console, Group
from rich.live import Live
from rich.panel import Panel
from rich.table import Table
from rich.text import Text

ASCII_MATRIX = "01ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz░▒▓█@#$%&*+=-:;,.?"
SCAN_FRAMES = ["[=---]", "[==--]", "[===-]", "[====]", "[===-]", "[==--]", "[=---]", "[----]"]

def safe_read(path: str) -> str:
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            return f.read().strip()
    except Exception:
        return ""

def detect_usb_devices_sysfs() -> List[Dict[str, str]]:
    """Detect from /sys/bus/usb/devices"""
    devices = []
    try:
        for sys_path in sorted(glob.glob("/sys/bus/usb/devices/*")):
            name = os.path.basename(sys_path)
            if name.startswith("usb") or ":" in name:
                continue
            
            vendor = safe_read(f"{sys_path}/idVendor")
            product = safe_read(f"{sys_path}/idProduct")
            manufacturer = safe_read(f"{sys_path}/manufacturer")
            product_name = safe_read(f"{sys_path}/product")
            bus = safe_read(f"{sys_path}/busnum") or "?\"\n            dev = safe_read(f"{sys_path}/devnum") or "?"\n            serial = safe_read(f"{sys_path}/serial")\n            \n            if not any([vendor, product, manufacturer, product_name, serial]):\n                continue\n            \n            label = " ".join(part for part in [manufacturer, product_name] if part)\n            if not label:\n                label = name\n            if vendor and product:\n                label = f"{label} [{vendor}:{product}]"\n            \n            devices.append({\n                "name": label,\n                "vendor": vendor,\n                "product": product,\n                "bus": bus,\n                "dev": dev,\n                "serial": serial,\n                "path": sys_path,\n                "source": "sysfs"\n            })\n    except Exception:\n        pass\n    return devices\n\ndef detect_usb_devices_lsusb() -> List[Dict[str, str]]:\n    """Detect from lsusb command\"\"\"\n    devices = []\n    try:\n        result = subprocess.run(["lsusb"], capture_output=True, text=True, timeout=2, check=False)\n        if result.returncode == 0 and result.stdout.strip():\n            for line in result.stdout.strip().splitlines():\n                if line.strip():\n                    devices.append({\n                        "name": line.strip(),\n                        "vendor": "",\n                        "product": "",\n                        "bus": "",\n                        "dev": "",\n                        "serial": "",\n                        "path": "",\n                        "source": "lsusb"\n                    })\n    except Exception:\n        pass\n    return devices\n\ndef detect_usb_devices_dev() -> List[Dict[str, str]]:\n    """Detect from /dev/bus/usb\"\"\"\n    devices = []\n    try:\n        for dev_path in glob.glob("/dev/bus/usb/*/*"):\n            devices.append({\n                "name": f"USB Device: {dev_path}\",\n                "vendor": "",\n                "product": "",\n                "bus": "",\n                "dev": "",\n                "serial": "",\n                "path": dev_path,\n                "source": "/dev"\n            })\n    except Exception:\n        pass\n    return devices\n\ndef detect_usb_devices() -> List[Dict[str, str]]:\n    """Try all detection methods and merge results\"\"\"\n    all_devices = []\n    all_devices.extend(detect_usb_devices_sysfs())\n    all_devices.extend(detect_usb_devices_lsusb())\n    all_devices.extend(detect_usb_devices_dev())\n    \n    # Remove duplicates\n    seen = set()\n    unique = []\n    for device in all_devices:\n        key = device.get("name", "")\n        if key not in seen:\n            seen.add(key)\n            unique.append(device)\n    \n    return unique\n\ndef matrix_text(rows: int = 12, cols: int = 56) -> Text:\n    text = Text()\n    for row in range(rows):\n        for col in range(cols):\n            if random.random() < 0.25:\n                char = random.choice(ASCII_MATRIX)\n                style = "green" if random.random() > 0.4 else "bright_green"\n                text.append(char, style=style)\n            else:\n                text.append(" ")\n        if row < rows - 1:\n            text.append("\\n")\n    return text\n\ndef build_header(step: int) -> Panel:\n    frame = SCAN_FRAMES[step % len(SCAN_FRAMES)]\n    title = Text("USB-C SCANNER", style="bold bright_cyan")\n    subtitle = Text(f"scanning {frame}", style="bold bright_green")\n    return Panel(Group(title, subtitle), border_style="bright_blue", padding=(0, 2))\n\ndef build_status_panel(connected: bool) -> Panel:\n    if connected:\n        label = "✓ USB CONNECTED"\n        color = "green"\n    else:\n        label = "✗ NO USB DETECTED"\n        color = "red"\n    \n    return Panel(\n        Align.center(Text(label, style=f"bold {color}")),\n        border_style=color,\n        padding=(1, 3),\n        title="[bold]STATUS[/bold]",\n        title_align="left",\n    )\n\ndef build_device_table(devices: List[Dict[str, str]]) -> Table:\n    table = Table(show_header=True, header_style="bold bright_green", box=None, pad_edge=False)\n    table.add_column("Device Name", style="cyan", min_width=30)\n    table.add_column("Vendor", style="magenta", min_width=10)\n    table.add_column("Product", style="yellow", min_width=10)\n    table.add_column("Source", style="blue", min_width=10)\n    \n    if not devices:\n        table.add_row("Waiting for USB...", "-", "-", "-")\n        return table\n    \n    for device in devices[:5]:\n        table.add_row(\n            device.get("name", "Unknown")[:30],\n            device.get("vendor", "-"),\n            device.get("product", "-"),\n            device.get("source", "unknown")\n        )\n    \n    if len(devices) > 5:\n        table.add_row(f"... and {len(devices) - 5} more", "-", "-", "-")\n    \n    return table\n\ndef render_screen(step: int, devices: List[Dict[str, str]], demo: bool) -> Group:\n    header = build_header(step)\n    matrix = Panel(\n        Align.center(matrix_text()),\n        border_style="green",\n        title="[bold]SCAN MATRIX[/bold]",\n        title_align="left",\n        padding=(0, 1),\n    )\n    device_table = build_device_table(devices)\n    status_panel = build_status_panel(bool(devices))\n    \n    mode = Text(f"Mode: {'DEMO' if demo else 'LIVE'} | Devices: {len(devices)}", style="bold bright_magenta")\n    \n    return Group(\n        header,\n        matrix,\n        Panel(device_table, border_style="bright_yellow", title="[bold]USB DEVICES[/bold]", title_align="left"),\n        Panel(mode, border_style="bright_white", padding=(0, 2)),\n        status_panel,\n    )\n\ndef main(demo: bool = False) -> None:\n    console = Console()\n    step = 0\n    \n    with Live(console=console, refresh_per_second=20, screen=False, auto_refresh=True) as live:\n        while True:\n            try:\n                if demo:\n                    devices = [{\n                        "name": "Demo USB Device [1A2B:3C4D]",\n                        "vendor": "1A2B",\n                        "product": "3C4D",\n                        "bus": "1",\n                        "dev": "3",\n                        "serial": "DEMO123456",\n                        "path": "/demo",\n                        "source": "demo"\n                    }]\n                else:\n                    devices = detect_usb_devices()\n                \n                live.update(render_screen(step, devices, demo))\n                step += 1\n                time.sleep(0.15)\n            except KeyboardInterrupt:\n                console.print("\\n[bold red]Scanner stopped.[/bold red]")\n                break\n            except Exception as e:\n                console.print(f"[bold red]Error: {e}[/bold red]")\n                break\n\nif __name__ == "__main__":\n    parser = argparse.ArgumentParser(description="Advanced USB-C scanner for Termux")\n    parser.add_argument("--demo", action="store_true", help="Run in demo mode")\n    args = parser.parse_args()\n    \n    try:\n        main(demo=args.demo)\n    except Exception as e:\n        print(f"[ERROR] {e}")\n        sys.exit(1)\nSCANNER\n\nchmod +x usb_scanner.py\n\necho -e "\033[1;33m[5/6]\033[0m Downloading diagnostic tool..."\ncat > diagnose.py << 'DIAG'\n#!/usr/bin/env python3\n"""USB Device Detection Diagnostic Tool"""\n\nimport glob\nimport os\nimport subprocess\n\ndef safe_read(path: str) -> str:\n    try:\n        with open(path, "r", encoding="utf-8", errors="ignore") as f:\n            return f.read().strip()\n    except Exception:\n        return ""\n\ndef main():\n    print("\\n" + "="*60)\n    print("USB DEVICE DETECTION DIAGNOSTIC")\n    print("="*60)\n    \n    # Check permissions\n    print("\\n[*] Checking permissions...")\n    sysfs = "/sys/bus/usb/devices"\n    if os.path.exists(sysfs) and os.access(sysfs, os.R_OK):\n        print(f"    ✓ Can read {sysfs}")\n    else:\n        print(f"    ✗ Cannot read {sysfs}")\n    \n    dev_path = "/dev/bus/usb"\n    if os.path.exists(dev_path) and os.access(dev_path, os.R_OK):\n        print(f"    ✓ Can read {dev_path}")\n    else:\n        print(f"    ✗ Cannot read {dev_path}")\n    \n    # Check sysfs\n    print("\\n[*] Checking /sys/bus/usb/devices...")\n    count = 0\n    for path in glob.glob(sysfs + "/*"):\n        name = os.path.basename(path)\n        if name.startswith("usb") or ":" in name:\n            continue\n        vendor = safe_read(f"{path}/idVendor")\n        if vendor:\n            count += 1\n            print(f"    Found: {name} [{vendor}]")\n    if count == 0:\n        print("    No devices found")\n    \n    # Check lsusb\n    print("\\n[*] Checking lsusb...")\n    try:\n        result = subprocess.run(["lsusb"], capture_output=True, text=True, timeout=2, check=False)\n        if result.returncode == 0 and result.stdout.strip():\n            lines = result.stdout.strip().split("\\n")\n            print(f"    Found {len(lines)} device(s)")\n            for line in lines:\n                print(f"    {line}")\n        else:\n            print("    lsusb not available")\n    except Exception as e:\n        print(f"    Error: {e}")\n    \n    # Check /dev/bus/usb\n    print("\\n[*] Checking /dev/bus/usb...")\n    devs = glob.glob("/dev/bus/usb/*/*")\n    if devs:\n        print(f"    Found {len(devs)} device file(s)")\n        for dev in devs:\n            print(f"    {dev}")\n    else:\n        print("    No device files found")\n    \n    print("\\n" + "="*60)\n    print("If no devices are found, your Android/Termux does not")\n    print("expose USB information. This is common on many devices.")\n    print("="*60 + "\\n")\n\nif __name__ == "__main__":\n    main()\nDIAG\n\nchmod +x diagnose.py\n\necho -e "\033[1;33m[6/6]\033[0m Creating launch scripts..."\ncat > run.sh << 'RUN'\n#!/bin/bash\ncd ~/usb-scanner\npython usb_scanner.py "$@"\nRUN\n\nchmod +x run.sh\n\ncat > demo.sh << 'DEMO'\n#!/bin/bash\ncd ~/usb-scanner\npython usb_scanner.py --demo\nDEMO\n\nchmod +x demo.sh\n\ncat > diagnose.sh << 'DIAG_SH'\n#!/bin/bash\ncd ~/usb-scanner\npython diagnose.py\nDIAG_SH\n\nchmod +x diagnose.sh\n\necho ""\necho -e "\033[1;32m╔═════════════════════════════════════════════╗\033[0m"\necho -e "\033[1;32m║     ✓ INSTALLATION COMPLETE               ║\033[0m"\necho -e "\033[1;32m╚═════════════════════════════════════════════╝\033[0m"\necho ""\necho -e "\033[1;36mLocation: ~/usb-scanner/\033[0m"\necho ""\necho -e "\033[1;35mCOMMANDS:\033[0m"\necho -e "  \033[1;33m./run.sh\033[0m          - Live USB scanner"\necho -e "  \033[1;33m./demo.sh\033[0m         - Demo mode"\necho -e "  \033[1;33m./diagnose.sh\033[0m    - Check what your system detects"\necho ""\necho -e "\033[1;35mFROM ANYWHERE:\033[0m"\necho -e "  \033[1;33mcd ~/usb-scanner && ./run.sh\033[0m"\necho -e "  \033[1;33mpython ~/usb-scanner/usb_scanner.py\033[0m"\necho ""\necho -e "\033[1;36mSTEP 1: Run diagnostic to check if your system exposes USB\033[0m"\necho -e "  \033[1;33m./diagnose.sh\033[0m"\necho ""\necho -e "\033[1;36mSTEP 2: Try the scanner\033[0m"\necho -e "  \033[1;33m./run.sh\033[0m (or ./demo.sh for demo)\necho ""\necho -e "\033[1;36mPress CTRL+C to stop\033[0m"\necho ""\n
