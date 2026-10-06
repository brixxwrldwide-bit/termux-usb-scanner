#!/usr/bin/env python3
"""USB Device Detector - Diagnostic Tool for Termux

Scans multiple USB detection methods and shows what's available.
"""

import glob
import os
import subprocess
import sys

def safe_read(path: str) -> str:
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            return f.read().strip()
    except Exception:
        return ""

def check_sysfs():
    """Check /sys/bus/usb/devices"""
    print("\n[*] Checking /sys/bus/usb/devices...")
    devices = []
    for path in sorted(glob.glob("/sys/bus/usb/devices/*")):
        name = os.path.basename(path)
        if name.startswith("usb"):
            continue
        
        vendor = safe_read(f"{path}/idVendor")
        product = safe_read(f"{path}/idProduct")
        
        if vendor or product:
            devices.append({
                "name": name,
                "vendor": vendor,
                "product": product,
                "path": path
            })
    
    if devices:
        print(f"    Found {len(devices)} device(s)")
        for d in devices:
            print(f"    - {d['name']}: {d['vendor']}:{d['product']}")
    else:
        print("    No devices found")
    return devices

def check_lsusb():
    """Check lsusb command"""
    print("\n[*] Checking lsusb...")
    try:
        result = subprocess.run(["lsusb"], capture_output=True, text=True, timeout=2, check=False)
        if result.returncode == 0 and result.stdout.strip():
            lines = result.stdout.strip().split("\n")
            print(f"    Found {len(lines)} device(s)")
            for line in lines[:5]:
                print(f"    {line}")
            if len(lines) > 5:
                print(f"    ... and {len(lines) - 5} more")
            return True
        else:
            print("    lsusb command failed or no output")
            return False
    except Exception as e:
        print(f"    Error running lsusb: {e}")
        return False

def check_dev():
    """Check /dev/bus/usb"""
    print("\n[*] Checking /dev/bus/usb...")
    try:
        devices = []
        for path in glob.glob("/dev/bus/usb/*/*"):
            devices.append(path)
        
        if devices:
            print(f"    Found {len(devices)} device(s)")
            for d in devices[:5]:
                print(f"    {d}")
            if len(devices) > 5:
                print(f"    ... and {len(devices) - 5} more")
        else:
            print("    No devices found")
        return devices
    except Exception as e:
        print(f"    Error: {e}")
        return []

def check_permissions():
    """Check if we have permission to read USB"""
    print("\n[*] Checking permissions...")
    sysfs_path = "/sys/bus/usb/devices"
    dev_path = "/dev/bus/usb"
    
    if os.path.exists(sysfs_path):
        if os.access(sysfs_path, os.R_OK):
            print(f"    ✓ Can read {sysfs_path}")
        else:
            print(f"    ✗ Cannot read {sysfs_path} (permission denied)")
    else:
        print(f"    ✗ {sysfs_path} does not exist")
    
    if os.path.exists(dev_path):
        if os.access(dev_path, os.R_OK):
            print(f"    ✓ Can read {dev_path}")
        else:
            print(f"    ✗ Cannot read {dev_path} (permission denied)")
    else:
        print(f"    ✗ {dev_path} does not exist")

def main():
    print("="*60)
    print("USB DEVICE DETECTION DIAGNOSTIC")
    print("="*60)
    
    check_permissions()
    check_sysfs()
    check_lsusb()
    check_dev()
    
    print("\n" + "="*60)
    print("SUMMARY")
    print("="*60)
    print("""
If no devices are found:
1. Connect a USB device and wait 2-3 seconds
2. Run this tool again to see if it's detected
3. On some Android setups, USB OTG permissions may be required
4. Try: adb shell pm grant com.termux android.permission.ACCESS_USB

If you see devices but the scanner isn't showing them:
- The scanner may need root or special permissions
- Try running the scanner with --verbose flag
""")

if __name__ == "__main__":
    main()
