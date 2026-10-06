# Advanced USB-C Scanner for Termux

A smooth USB scanner made for Termux with:
- Rich UI
- Matrix-style loading animation
- Device detection and info
- Green status if USB is connected
- Red status if nothing is connected

## Install

```bash
bash <(curl -L https://raw.githubusercontent.com/brixxwrldwide-bit/termux-usb-scanner/main/QUICK_INSTALL.sh)
```

## Run

```bash
cd ~/usb-scanner
./run.sh
```

Demo mode:

```bash
cd ~/usb-scanner
./demo.sh
```

## Notes

This tool checks for USB devices visible to Android/Termux. Some devices may not expose USB data depending on the OS and hardware setup.
