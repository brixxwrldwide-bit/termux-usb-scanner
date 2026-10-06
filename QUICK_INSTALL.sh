#!/bin/bash

# USB-C Scanner Quick Install Script for Termux
# Copy & Paste this entire script into Termux terminal

echo -e "\033[1;36m╔════════════════════════════════════════════╗\033[0m"
echo -e "\033[1;36m║  USB-C SCANNER QUICK INSTALLER - TERMUX   ║\033[0m"
echo -e "\033[1;36m╚════════════════════════════════════════════╝\033[0m"
echo ""

# Step 1: Update packages
echo -e "\033[1;33m[1/5]\033[0m Updating Termux packages..."
pkg update -y
pkg install -y python git

# Step 2: Clone or create directory
echo -e "\033[1;33m[2/5]\033[0m Setting up USB Scanner directory..."
mkdir -p ~/usb-scanner
cd ~/usb-scanner

# Step 3: Install Python dependencies
echo -e "\033[1;33m[3/5]\033[0m Installing Python dependencies..."
pip install --upgrade pip
pip install rich>=13.7.0

# Step 4: Download scanner script
echo -e "\033[1;33m[4/5]\033[0m Downloading USB Scanner script..."
cat > usb_scanner.py << 'EOFPYTHON'
#!/usr/bin/env python3
"""USB-C scanner for Termux with a Rich animated matrix UI.

Features:
- Detects attached USB devices from /sys and lsusb.
- Shows device details such as name, vendor, product, and ID.
- Presents a matrix-style animated scanning screen.
- Displays a green "CONNECTED" status if a device is found and red if not.
- Works with a --demo flag for preview without hardware.
"""

from __future__ import annotations

import argparse
import glob
import os
import random
import re
import subprocess
import sys
import time
from pathlib import Path
from typing import Dict, List, Optional

from rich.align import Align
from rich.console import Console, Group
from rich.live import Live
from rich.panel import Panel
from rich.table import Table
from rich.text import Text


ASCII_MATRIX = "01ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz░▒▓█@#$%&*+=-:;,.?"


def safe_read(path: str) -> str:
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as handle:
            return handle.read().strip()
    except Exception:
        return ""


def detect_usb_devices() -> List[Dict[str, str]]:
    devices: List[Dict[str, str]] = []

    sysfs_pattern = "/sys/bus/usb/devices/*"
    for path in sorted(glob.glob(sysfs_pattern)):
        name = os.path.basename(path)
        if name in {"usb1", "usb2", "usb3", "usb4"}:
            continue

        vendor = safe_read(f"{path}/idVendor")
        product = safe_read(f"{path}/idProduct")
        manufacturer = safe_read(f"{path}/manufacturer")
        product_name = safe_read(f"{path}/product")
        bus_num = safe_read(f"{path}/busnum") or "?"
        dev_num = safe_read(f"{path}/devnum") or "?"

        if not any([vendor, product, manufacturer, product_name]):
            continue

        label = " ".join(part for part in [manufacturer, product_name] if part)
        if not label:
            label = name

        if vendor and product:
            label = f"{label} [{vendor}:{product}]"

        devices.append(
            {
                "name": label,
                "vendor": vendor,
                "product": product,
                "bus": bus_num,
                "dev": dev_num,
                "path": path,
            }
        )

    if not devices:
        try:
            result = subprocess.run(
                ["lsusb"],
                capture_output=True,
                text=True,
                timeout=2,
                check=False,
            )
            if result.returncode == 0 and result.stdout.strip():
                for line in result.stdout.strip().splitlines():
                    raw = line.strip()
                    if not raw:
                        continue
                    devices.append({"name": raw, "vendor": "", "product": "", "bus": "", "dev": "", "path": ""})
        except Exception:
            pass

    return devices


def render_matrix(rows: int = 14, cols: int = 52) -> Text:
    text = Text()
    for row_index in range(rows):
        chars: List[str] = []
        for col_index in range(cols):
            threshold = 0.18
            if random.random() < threshold:
                char = random.choice(ASCII_MATRIX)
                color = "green" if random.random() > 0.5 else "bright_green"
                text.append(char, style=color)
            else:
                if row_index % 2 == 0 and col_index % 5 == 0 and random.random() < 0.12:
                    text.append(" ", style="dim")
                else:
                    text.append(" ", style="black")

        if row_index < rows - 1:
            text.append("\n")
    return text


def build_device_table(devices: List[Dict[str, str]]) -> Table:
    table = Table(show_header=True, header_style="bold bright_green", box=None, pad_edge=False)
    table.add_column("Device", style="cyan", min_width=28)
    table.add_column("Vendor", style="magenta", min_width=12)
    table.add_column("Product", style="yellow", min_width=12)
    table.add_column("Bus", style="blue", min_width=8)
    table.add_column("Dev", style="blue", min_width=8)

    if not devices:
        table.add_row("No USB device detected", "-", "-", "-", "-")
        return table

    for device in devices:
        table.add_row(
            device.get("name", "Unnamed device"),
            device.get("vendor", "-"),
            device.get("product", "-"),
            device.get("bus", "-"),
            device.get("dev", "-"),
        )

    return table


def build_status_panel(connected: bool) -> Panel:
    status_text = "USB CONNECTED" if connected else "USB NOT DETECTED"
    color = "green" if connected else "red"

    status = Text(status_text, style=f"bold {color}")
    panel = Panel(
        Align.center(status),
        border_style=color,
        padding=(1, 3),
        title="[bold]STATUS[/bold]",
        title_align="left",
    )
    return panel


def build_header() -> Panel:
    title = Text("USB-C SCANNER", style="bold bright_cyan")
    subtitle = Text("Termux • rich matrix monitor", style="dim white")
    return Panel(Group(title, subtitle), border_style="bright_blue", padding=(0, 2))


def print_demo_screen() -> Panel:
    sample = {
        "name": "Demo USB Accessory [1A2B:3C4D]",
        "vendor": "1A2B",
        "product": "3C4D",
        "bus": "1",
        "dev": "3",
    }
    return build_device_table([sample])


def ui_loop(demo: bool = False) -> None:
    console = Console()
    cycle = 0

    with Live(console=console, refresh_per_second=12, screen=False, auto_refresh=True) as live:
        while True:
            try:
                if demo:
                    devices = [{
                        "name": "Demo USB Accessory [1A2B:3C4D]",
                        "vendor": "1A2B",
                        "product": "3C4D",
                        "bus": "1",
                        "dev": "3",
                        "path": "demo",
                    }]
                    connected = True
                    status_line = "Demo mode active"
                else:
                    devices = detect_usb_devices()
                    connected = bool(devices)
                    status_line = "USB detected" if connected else "Waiting for device"

                matrix = render_matrix()
                device_table = build_device_table(devices)
                status_panel = build_status_panel(connected)
                header = build_header()

                vertical = Group(
                    header,
                    Panel(
                        Align.center(matrix),
                        border_style="green",
                        title="[bold]SCAN MATRIX[/bold]",
                        title_align="left",
                        padding=(0, 1),
                    ),
                    Panel(
                        Group(
                            Text(f"Mode: {('DEMO' if demo else 'LIVE')}", style="bold bright_magenta"),
                            Text(f"Status: {status_line}", style="bright_white"),
                            device_table,
                        ),
                        border_style="bright_yellow",
                        title="[bold]DEVICE INFO[/bold]",
                        title_align="left",
                    ),
                    status_panel,
                )

                live.update(vertical)
                time.sleep(0.24)
                cycle += 1
            except KeyboardInterrupt:
                console.print("\n[bold red] Scanner stopped.[/bold red]")
                break


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="USB-C scanner for Termux")
    parser.add_argument("--demo", action="store_true", help="Run in demo mode without real hardware detection")
    args = parser.parse_args()

    try:
        ui_loop(demo=args.demo)
    except Exception as exc:
        print(f"[ERROR] {exc}")
        sys.exit(1)
EOFPYTHON

chmod +x usb_scanner.py

# Step 5: Create launch script
echo -e "\033[1;33m[5/5]\033[0m Creating launch shortcuts..."
cat > run.sh << 'EOFRUN'
#!/bin/bash
cd ~/usb-scanner
python usb_scanner.py "$@"
EOFRUN

chmod +x run.sh

# Create demo launcher
cat > demo.sh << 'EOFDEMO'
#!/bin/bash
cd ~/usb-scanner
python usb_scanner.py --demo
EOFDEMO

chmod +x demo.sh

echo ""
echo -e "\033[1;32m╔════════════════════════════════════════════╗\033[0m"
echo -e "\033[1;32m║        ✓ INSTALLATION COMPLETE             ║\033[0m"
echo -e "\033[1;32m╚════════════════════════════════════════════╝\033[0m"
echo ""
echo -e "\033[1;36m📍 Location: ~/usb-scanner/\033[0m"
echo ""
echo -e "\033[1;35mRUN SCANNER:\033[0m"
echo -e "  \033[1;33m./run.sh\033[0m        (Live USB detection)"
echo -e "  \033[1;33m./demo.sh\033[0m       (Demo mode)"
echo ""
echo -e "\033[1;35mOR from anywhere:\033[0m"
echo -e "  \033[1;33mpython ~/usb-scanner/usb_scanner.py\033[0m"
echo -e "  \033[1;33mpython ~/usb-scanner/usb_scanner.py --demo\033[0m"
echo ""
echo -e "\033[1;36m⌨️  Press CTRL+C to stop scanner\033[0m"
echo ""
