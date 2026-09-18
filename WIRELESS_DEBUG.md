# Wireless Debugging Setup

## Prerequisites

- Phone and PC on the same Wi-Fi network
- USB cable (needed once for initial setup)
- ADB path: `C:\Users\corpt\AppData\Local\Android\Sdk\platform-tools\adb.exe`

## Steps

### 1. Connect via USB first

Plug in the USB cable and verify the phone is detected:

```powershell
flutter devices
```

### 2. Enable wireless mode

```powershell
& "C:\Users\corpt\AppData\Local\Android\Sdk\platform-tools\adb.exe" tcpip 5555
```

### 3. Get phone IP address

```powershell
& "C:\Users\corpt\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell ip route | Select-String -Pattern "src"
```

Look for the IP after `src` (e.g., `10.11.240.24`)

### 4. Connect wirelessly

```powershell
& "C:\Users\corpt\AppData\Local\Android\Sdk\platform-tools\adb.exe" connect 192.168.1.2:5555
```

### 5. Unplug USB cable

### 6. Run the app

```powershell
flutter run -d <phone-ip>:5555
```

## Reconnect (if connection drops)

The wireless connection drops when the phone sleeps or IP changes. To reconnect:

```powershell
# Plug USB, re-enable wireless, connect, unplug
& "C:\Users\corpt\AppData\Local\Android\Sdk\platform-tools\adb.exe" tcpip 5555
& "C:\Users\corpt\AppData\Local\Android\Sdk\platform-tools\adb.exe" connect <phone-ip>:5555
```

## Build Release APK (no device needed)

```powershell
flutter build apk --release
```

Output: `build\app\outputs\flutter-apk\app-release.apk`

## Install APK on phone

```powershell
& "C:\Users\corpt\AppData\Local\Android\Sdk\platform-tools\adb.exe" install -r build\app\outputs\flutter-apk\app-release.apk
```
