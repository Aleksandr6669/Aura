import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// BLE UUID Constants for Smart Ring
const String mainServiceUuid = "de5bf728-d711-4e47-af26-65e3012a5dc7";
const String mainWriteCharacteristicUuid = "de5bf72a-d711-4e47-af26-65e3012a5dc7";
const String mainNotifyCharacteristicUuid = "de5bf729-d711-4e47-af26-65e3012a5dc7";
const String rxtxServiceUuid = "6e40fff0-b5a3-f393-e0a9-e50e24dcca9e";
const String rxtxWriteCharacteristicUuid = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";
const String rxtxNotifyCharacteristicUuid = "6e400003-b5a3-f393-e0a9-e50e24dcca9e";

// Ring Selection Details
const String defaultMac = "B0:24:08:02:06:87";
final List<String> deviceKeywords = ["SSR", "RING"];

class LogMessage {
  final String timestamp;
  final String text;
  final String tag; // info, success, warn, error
  LogMessage(this.text, {this.tag = 'info'})
      : timestamp = _formatTime(DateTime.now());

  static String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return "$h:$m:$s";
  }
}

class DiscoveredDevice {
  final BluetoothDevice device;
  final AdvertisementData advertisementData;
  int rssi;
  bool isPresent;

  DiscoveredDevice({
    required this.device,
    required this.advertisementData,
    required this.rssi,
    this.isPresent = true,
  });
}

class RingBleManager extends ChangeNotifier {
  BluetoothDevice? connectedDevice;
  final List<BluetoothCharacteristic> writeChars = [];
  final List<BluetoothCharacteristic> notifyChars = [];
  final List<StreamSubscription<List<int>>> _notifySubs = [];

  BluetoothCharacteristic? get writeChar {
    if (writeChars.isEmpty) return null;
    for (var char in writeChars) {
      if (char.uuid.toString().toLowerCase() == rxtxWriteCharacteristicUuid.toLowerCase()) {
        return char;
      }
    }
    return writeChars.first;
  }

  BluetoothCharacteristic? get notifyChar {
    if (notifyChars.isEmpty) return null;
    for (var char in notifyChars) {
      if (char.uuid.toString().toLowerCase() == rxtxNotifyCharacteristicUuid.toLowerCase()) {
        return char;
      }
    }
    return notifyChars.first;
  }

  bool userDisconnected = false;
  DateTime? _lastNotifyTime;

  bool isConnected = false;
  String connectionStatus = "Scanning...";
  String batteryInfo = "-";
  bool filterEnabled = true;
  List<BluetoothService> discoveredServicesList = [];

  // Real-time trace values
  double lastX = 0.0;
  double lastY = 0.0;
  double lastZ = 0.0;
  double lastMag = 0.0;

  // Smoothing variables (Low Pass Filter)
  double _lastFx = 0.0;
  double _lastFy = 0.0;
  double _lastFz = 0.0;

  // History buffers for high-speed custom painter
  static const int maxPoints = 200;
  final List<double> historyX = List.filled(maxPoints, 0.0, growable: true);
  final List<double> historyY = List.filled(maxPoints, 0.0, growable: true);
  final List<double> historyZ = List.filled(maxPoints, 0.0, growable: true);
  final List<double> historyMag = List.filled(maxPoints, 0.0, growable: true);

  // App running indicator
  bool isDisposed = false;

  // Terminal Console Logs
  final List<LogMessage> logs = [];

  List<DiscoveredDevice> discoveredDevices = [];
  bool isScanning = false;

  bool gestureActionsEnabled = false;
  double gestureThreshold = 2200.0;
  String assignedActionType = "webhook"; // "webhook" or "ble_command"
  String assignedActionPayload = "";
  bool showNamelessDevices = false;
  DateTime? _lastGestureTrigger;
  bool gestureTriggeredAlert = false;
  bool wakeGestureEnabled = false;
  bool wakeGestureActive = false;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<bool>? _scanningStateSub;

  void addLog(String text, {String tag = 'info'}) {
    logs.add(LogMessage(text, tag: tag));
    if (logs.length > 300) logs.removeAt(0);
    notifyListeners();
  }

  void toggleFilter(bool enabled) {
    filterEnabled = enabled;
    addLog("Low-Pass Filter: ${enabled ? 'Enabled' : 'Disabled'}", tag: 'info');
    notifyListeners();
  }

  void toggleShowNameless(bool value) {
    showNamelessDevices = value;
    addLog("Show Nameless Devices: ${value ? 'Enabled' : 'Disabled'}", tag: 'info');
    notifyListeners();
  }

  // Checksum Generator for Colmi 16-byte Protocol Packets
  List<int> createCommand(String hexString) {
    final cleaned = hexString.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final List<int> bytes = [];
    for (int i = 0; i < cleaned.length; i += 2) {
      bytes.add(int.parse(cleaned.substring(i, i + 2), radix: 16));
    }
    while (bytes.length < 15) {
      bytes.add(0);
    }
    final int sum = bytes.reduce((val, element) => val + element);
    bytes.add(sum & 0xFF);
    return bytes;
  }

  Future<void> loadGestureSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      gestureActionsEnabled = prefs.getBool("gesture_actions_enabled") ?? false;
      gestureThreshold = prefs.getDouble("gesture_threshold") ?? 2200.0;
      assignedActionType = prefs.getString("assigned_action_type") ?? "webhook";
      assignedActionPayload = prefs.getString("assigned_action_payload") ?? "";
      wakeGestureEnabled = prefs.getBool("wake_gesture_enabled") ?? false;
      notifyListeners();
    } catch (e) {
      addLog("Failed to load gesture settings: $e", tag: 'warn');
    }
  }

  Future<void> saveGestureSettings({
    bool? enabled,
    double? threshold,
    String? type,
    String? payload,
    bool? wakeEnabled,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (enabled != null) {
        gestureActionsEnabled = enabled;
        await prefs.setBool("gesture_actions_enabled", enabled);
      }
      if (threshold != null) {
        gestureThreshold = threshold;
        await prefs.setDouble("gesture_threshold", threshold);
      }
      if (type != null) {
        assignedActionType = type;
        await prefs.setString("assigned_action_type", type);
      }
      if (payload != null) {
        assignedActionPayload = payload;
        await prefs.setString("assigned_action_payload", payload);
      }
      if (wakeEnabled != null) {
        wakeGestureEnabled = wakeEnabled;
        await prefs.setBool("wake_gesture_enabled", wakeEnabled);
      }
      notifyListeners();
    } catch (e) {
      addLog("Failed to save gesture settings: $e", tag: 'warn');
    }
  }

  void _triggerWakeToggle() {
    gestureActionsEnabled = !gestureActionsEnabled;
    wakeGestureActive = true;
    notifyListeners();

    // Save new state silently (no LEDs)
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool("gesture_actions_enabled", gestureActionsEnabled);
    });

    addLog(
      "⚡ Wake gesture: listening ${gestureActionsEnabled ? 'ON ✓' : 'OFF ✗'}",
      tag: gestureActionsEnabled ? 'success' : 'warn',
    );

    // Clear visual indicator after 1.2s
    Future.delayed(const Duration(milliseconds: 1200), () {
      wakeGestureActive = false;
      notifyListeners();
    });
  }

  void _triggerGestureAction() async {
    addLog("Gesture detected! (Mag: ${lastMag.toStringAsFixed(1)})", tag: 'success');
    
    gestureTriggeredAlert = true;
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 800), () {
      gestureTriggeredAlert = false;
      notifyListeners();
    });

    if (assignedActionPayload.isEmpty) {
      addLog("No action payload configured for gestures", tag: 'warn');
      return;
    }

    if (assignedActionType == "webhook") {
      final urlStr = assignedActionPayload.trim();
      addLog("Triggering Webhook: $urlStr...", tag: 'info');
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 5);
        final uri = Uri.parse(urlStr);
        final request = await client.getUrl(uri);
        final response = await request.close();
        addLog("Webhook response code: ${response.statusCode}", tag: 'success');
        client.close();
      } catch (e) {
        addLog("Webhook trigger failed: $e", tag: 'error');
      }
    } else if (assignedActionType == "ble_command") {
      final cmd = assignedActionPayload.trim();
      addLog("Triggering BLE command: $cmd", tag: 'info');
      await writeCommand(cmd);
    }
  }

  Future<bool> _checkConnectedSystemDevices() async {
    if (isConnected || connectedDevice != null) return true;
    if (userDisconnected) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString("last_connected_device_id");

      // On iOS, we need to provide the service UUIDs to find connected system devices.
      final List<Guid> systemServiceUuids = [
        Guid(mainServiceUuid),
        Guid(rxtxServiceUuid),
      ];

      List<BluetoothDevice> connectedSystem = [];
      try {
        connectedSystem = await FlutterBluePlus.systemDevices(systemServiceUuids);
      } catch (e) {
        try {
          connectedSystem = await FlutterBluePlus.systemDevices([]);
        } catch (e2) {
          addLog("Failed to retrieve system devices: $e2", tag: 'warn');
        }
      }

      for (var device in connectedSystem) {
        final name = device.platformName;
        final address = device.remoteId.str.toUpperCase();
        
        final matchesSaved = savedId != null && address == savedId.toUpperCase();
        final matchesName = deviceKeywords.any((kw) => name.toLowerCase().contains(kw.toLowerCase()));
        final matchesMac = address == defaultMac.toUpperCase();

        if (matchesSaved || (savedId == null && (matchesName || matchesMac))) {
          addLog("Found system-connected device: '$name' [$address]. Connecting...", tag: 'success');
          connectToDevice(device);
          return true;
        }
      }
    } catch (e) {
      addLog("Error checking connected system devices: $e", tag: 'warn');
    }
    return false;
  }

  // Initialize BLE Scanner & Autoconnect setup
  void startAutoconnectLoop() async {
    addLog("Initializing Bluetooth adapter...", tag: 'info');
    await loadGestureSettings();
    
    // Ensure BLE is turned on/supported
    try {
      if (await FlutterBluePlus.isSupported == false) {
        addLog("Bluetooth not supported on this platform", tag: 'error');
        return;
      }
    } catch (e) {
      addLog("BLE compatibility check failed: $e", tag: 'error');
    }

    _scanningStateSub?.cancel();
    _scanningStateSub = FlutterBluePlus.isScanning.listen((scanning) {
      isScanning = scanning;
      notifyListeners();
    });

    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) async {
      if (userDisconnected) return;

      // 1. Mark existing discovered devices as not present first if they aren't in results
      final latestIds = results.map((r) => r.device.remoteId).toSet();
      for (var d in discoveredDevices) {
        if (!latestIds.contains(d.device.remoteId)) {
          d.isPresent = false;
        }
      }

      // 2. Add or update found devices
      for (var r in results) {
        final existingIdx = discoveredDevices.indexWhere((d) => d.device.remoteId == r.device.remoteId);
        if (existingIdx != -1) {
          discoveredDevices[existingIdx].rssi = r.rssi;
          discoveredDevices[existingIdx].isPresent = true;
        } else {
          discoveredDevices.add(DiscoveredDevice(
            device: r.device,
            advertisementData: r.advertisementData,
            rssi: r.rssi,
            isPresent: true,
          ));
        }
      }
      notifyListeners();
      
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString("last_connected_device_id");

      // 1. Auto-connect to previously saved device if set
      if (!isConnected && connectedDevice == null && savedId != null) {
        for (ScanResult r in results) {
          if (r.device.remoteId.str.toUpperCase() == savedId.toUpperCase()) {
            addLog("Found saved device ID [$savedId]. Reconnecting...", tag: 'success');
            stopManualScan();
            connectToDevice(r.device);
            return;
          }
        }
      }

      // 2. Auto-connect fallback to defaultMac or keyword match if no saved ID exists
      if (!isConnected && connectedDevice == null && savedId == null) {
        for (ScanResult r in results) {
          final name = r.device.platformName;
          final address = r.device.remoteId.str.toUpperCase();
          
          final matchesName = deviceKeywords.any((kw) => name.toLowerCase().contains(kw.toLowerCase()));
          final matchesMac = address == defaultMac.toUpperCase();

          if (matchesName || matchesMac) {
            addLog("Auto-connecting to Smart Ring: '$name' [$address]", tag: 'success');
            stopManualScan();
            connectToDevice(r.device);
            break;
          }
        }
      }
    });

    // Check connected system devices before initiating scan
    final foundSystemDevice = await _checkConnectedSystemDevices();
    if (!foundSystemDevice) {
      startManualScan();
    }
  }

  void startManualScan() async {
    if (isConnected || connectedDevice != null) return;

    addLog("Scanning for Bluetooth devices...", tag: 'info');
    
    // Mark existing discovered devices as not present so they become gray
    // until we discover them again in the new scan.
    for (var d in discoveredDevices) {
      d.isPresent = false;
    }

    // Query system-connected devices and add them to the list as active so they can be selected manually
    try {
      final List<Guid> systemServiceUuids = [
        Guid(mainServiceUuid),
        Guid(rxtxServiceUuid),
      ];
      List<BluetoothDevice> connectedSystem = [];
      try {
        connectedSystem = await FlutterBluePlus.systemDevices(systemServiceUuids);
      } catch (_) {
        try {
          connectedSystem = await FlutterBluePlus.systemDevices([]);
        } catch (_) {}
      }

      for (var device in connectedSystem) {
        final existingIdx = discoveredDevices.indexWhere((d) => d.device.remoteId == device.remoteId);
        if (existingIdx != -1) {
          discoveredDevices[existingIdx].isPresent = true;
          discoveredDevices[existingIdx].rssi = -50;
        } else {
          discoveredDevices.add(DiscoveredDevice(
            device: device,
            advertisementData: AdvertisementData(
              advName: device.platformName,
              txPowerLevel: null,
              connectable: true,
              manufacturerData: {},
              serviceData: {},
              serviceUuids: [],
              appearance: null,
            ),
            rssi: -50,
            isPresent: true,
          ));
        }
      }
    } catch (e) {
      addLog("Error reading system devices during scan: $e", tag: 'warn');
    }

    notifyListeners();
    
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    } catch (e) {
      addLog("Scan failed to start: $e", tag: 'error');
    }
  }

  void stopManualScan() async {
    addLog("Stopping scanner...", tag: 'info');
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      addLog("Failed to stop scan: $e", tag: 'error');
    }
  }

  void connectToDevice(BluetoothDevice device) async {
    stopManualScan();
    userDisconnected = false;

    if (connectedDevice != null) {
      disconnectDevice();
    }

    connectedDevice = device;
    connectionStatus = "Connecting...";
    notifyListeners();
    addLog("Connecting to ${device.platformName} [${device.remoteId.str}]...", tag: 'info');

    // Save ID to preferences for persistent auto-connect
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("last_connected_device_id", device.remoteId.str);
      addLog("Saved device ID: ${device.remoteId.str}", tag: 'info');
    } catch (e) {
      addLog("Could not save device ID: $e", tag: 'warn');
    }

    _connSub?.cancel();
    _connSub = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.connected) {
        isConnected = true;
        connectionStatus = "Connected";
        notifyListeners();
        addLog("Connected successfully to smart ring.", tag: 'success');
        _discoverServices(device);
      } else if (state == BluetoothConnectionState.disconnected) {
        // Only handle unexpected disconnects here if we were previously connected.
        // This avoids calling _handleDisconnect() upon subscribing to the stream.
        if (isConnected) {
          _handleDisconnect(autoScanReconnect: true);
        }
      }
    });

    try {
      // Set autoConnect to false to ensure stable GATT service discovery on iOS
      await device.connect(autoConnect: false, timeout: const Duration(seconds: 15));
    } catch (e) {
      addLog("Connection failed: $e", tag: 'error');
      _handleDisconnect(autoScanReconnect: false);
    }
  }

  void disconnectDevice() async {
    if (connectedDevice != null) {
      addLog("Disconnecting from device...", tag: 'info');
      userDisconnected = true;

      // Disable sensors before disconnecting (prevents ring staying in active mode)
      if (writeChars.isNotEmpty && isConnected) {
        try {
          final disableCmd = createCommand("a102");
          await writeChars.first.write(disableCmd, withoutResponse: true);
          addLog("Sensors disabled (a102) before disconnect", tag: 'info');
          await Future.delayed(const Duration(milliseconds: 200));
        } catch (e) {
          addLog("Could not disable sensors: $e", tag: 'warn');
        }
      }

      // Clear preferences so we don't reconnect automatically
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove("last_connected_device_id");
        addLog("Cleared saved device ID", tag: 'info');
      } catch (e) {
        addLog("Could not clear device ID: $e", tag: 'warn');
      }

      try {
        await connectedDevice!.disconnect();
      } catch (e) {
        addLog("Error disconnecting: $e", tag: 'error');
      }
      _handleDisconnect(autoScanReconnect: false);
    }
  }

  void _discoverServices(BluetoothDevice device) async {
    try {
      addLog("Discovering primary GATT services...", tag: 'info');
      await Future.delayed(const Duration(milliseconds: 600));
      final services = await device.discoverServices();
      discoveredServicesList = services;
      notifyListeners();
      
      writeChars.clear();
      notifyChars.clear();

      for (var service in services) {
        for (var char in service.characteristics) {
          final cUuid = char.uuid.toString().toLowerCase();
          
          if (cUuid == rxtxWriteCharacteristicUuid.toLowerCase() ||
              cUuid == mainWriteCharacteristicUuid.toLowerCase()) {
            writeChars.add(char);
          }
          if (cUuid == rxtxNotifyCharacteristicUuid.toLowerCase() ||
              cUuid == mainNotifyCharacteristicUuid.toLowerCase()) {
            notifyChars.add(char);
          }
        }
      }

      if (notifyChars.isNotEmpty && writeChars.isNotEmpty) {
        addLog("UART/Main characteristics discovered: ${writeChars.length} write, ${notifyChars.length} notify.", tag: 'success');
        
        // Start notifications subscription
        for (var sub in _notifySubs) {
          sub.cancel();
        }
        _notifySubs.clear();

        for (var char in notifyChars) {
          try {
            final sub = char.onValueReceived.listen((data) {
              _parseNotificationData(data);
            });
            _notifySubs.add(sub);
            await char.setNotifyValue(true);
            addLog("Subscribed to ${char.uuid.toString().substring(0, 8)}: isNotifying=${char.isNotifying}", tag: char.isNotifying ? 'success' : 'warn');
          } catch (e) {
            addLog("Failed to subscribe to ${char.uuid.toString().substring(0, 8)}: $e", tag: 'warn');
          }
        }

        // Instantly query battery level
        await writeCommand("03");

        addLog("Ring ready. Press 'Start' to stream data.", tag: 'info');
      } else {
        addLog("Error: Could not map GATT interface characteristics", tag: 'error');
      }
    } catch (e) {
      addLog("GATT Service Discovery failed: $e", tag: 'error');
    }
  }

  void _parseNotificationData(List<int> data) {
    if (data.isEmpty) return;

    // 1. Accelerometer packets (0xA1 with subtype 0x03)
    if (data[0] == 0xA1 && data.length >= 8) {
      final subtype = data[1];
      if (subtype == 0x03) {
        // Decode signed 12-bit integer values correctly (0 to 4095 raw, sign-extended at 2048)
        int accX = ((data[6] << 4) | (data[7] & 0xF));
        if (accX >= 2048) accX -= 4096;

        int accY = ((data[2] << 4) | (data[3] & 0xF));
        if (accY >= 2048) accY -= 4096;

        int accZ = ((data[4] << 4) | (data[5] & 0xF));
        if (accZ >= 2048) accZ -= 4096;

        // Apply low pass filter if enabled
        double rx = accX.toDouble();
        double ry = accY.toDouble();
        double rz = accZ.toDouble();

        if (filterEnabled) {
          const double alpha = 0.25;
          lastX = _lastFx + alpha * (rx - _lastFx);
          lastY = _lastFy + alpha * (ry - _lastFy);
          lastZ = _lastFz + alpha * (rz - _lastFz);
        } else {
          lastX = rx;
          lastY = ry;
          lastZ = rz;
        }

        _lastFx = lastX;
        _lastFy = lastY;
        _lastFz = lastZ;

        // Vector Magnitude calculation
        lastMag = math.sqrt(lastX * lastX + lastY * lastY + lastZ * lastZ);

        // Shift and update history lists
        historyX.removeAt(0);
        historyY.removeAt(0);
        historyZ.removeAt(0);
        historyMag.removeAt(0);

        historyX.add(lastX);
        historyY.add(lastY);
        historyZ.add(lastZ);
        historyMag.add(lastMag);

        // Gesture action check
        if (gestureActionsEnabled) {
          if (lastMag > gestureThreshold) {
            final now = DateTime.now();
            if (_lastGestureTrigger == null || now.difference(_lastGestureTrigger!) > const Duration(seconds: 2)) {
              _lastGestureTrigger = now;
              _triggerGestureAction();
            }
          }
        }

        // Throttle UI notification updates to ~60Hz to maintain smooth rendering
        final now = DateTime.now();
        if (_lastNotifyTime == null || now.difference(_lastNotifyTime!) > const Duration(milliseconds: 16)) {
          _lastNotifyTime = now;
          notifyListeners();
        }
      }
    }
    // 2. Battery response packets (0x03)
    else if (data[0] == 0x03 && data.length >= 3) {
      final batLvl = data[1];
      final state = data[2] == 1 ? "⚡ Charging" : "Discharging";
      batteryInfo = "$batLvl% ($state)";
      notifyListeners();
    }
    // 3. Known gesture/event packets from Colmi firmware
    //    0x14 = tap / wrist gesture event
    else if (data[0] == 0x14) {
      final hex = data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
      addLog("👆 GESTURE EVENT [0x14]: $hex", tag: 'success');
      if (wakeGestureEnabled) {
        _triggerWakeToggle();
      }
    }
    // 4. Activity/step event packets
    else if (data[0] == 0x51 || data[0] == 0x52) {
      final hex = data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
      addLog("🏃 ACTIVITY EVENT [0x${data[0].toRadixString(16).toUpperCase()}]: $hex", tag: 'info');
    }
    // 5. A1 packets with unknown subtype — log them for discovery
    else if (data[0] == 0xA1) {
      final hex = data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
      addLog("📦 A1 subtype=0x${data[1].toRadixString(16).toUpperCase()}: $hex", tag: 'info');
    }
    // 6. CATCH-ALL: log every unknown packet so we can discover the gesture protocol
    else {
      final hex = data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
      addLog("❓ UNKNOWN [0x${data[0].toRadixString(16).toUpperCase()}]: $hex", tag: 'warn');
    }
  }

  Future<void> writeCommand(String hexString) async {
    final char = writeChar;
    if (char == null || !isConnected) {
      addLog("Cannot write command: no write characteristic mapped", tag: 'error');
      return;
    }
    try {
      final bytes = createCommand(hexString);
      final withoutResp = char.properties.writeWithoutResponse;
      addLog("Writing: $hexString to ${char.uuid.toString().substring(0, 8)} (noResp=$withoutResp)...", tag: 'info');
      await char.write(bytes, withoutResponse: withoutResp);
      addLog("Write successful: $hexString", tag: 'success');
    } catch (e) {
      addLog("Transmission error: $e", tag: 'error');
    }
  }

  Future<void> sendMorse(String text) async {
    if (writeChars.isEmpty || !isConnected) {
      addLog("Cannot blink Morse: device not connected", tag: 'error');
      return;
    }

    final morseMap = {
      // Latin
      'A': '.-', 'B': '-...', 'C': '-.-.', 'D': '-..', 'E': '.', 'F': '..-.',
      'G': '--.', 'H': '....', 'I': '..', 'J': '.---', 'K': '-.-', 'L': '.-..',
      'M': '--', 'N': '-.', 'O': '---', 'P': '.--.', 'Q': '--.-', 'R': '.-.',
      'S': '...', 'T': '-', 'U': '..-', 'V': '...-', 'W': '.--', 'X': '-..-',
      'Y': '-.--', 'Z': '--..',
      // Russian
      'А': '.-', 'Б': '-...', 'В': '.--', 'Г': '--.', 'Д': '-..', 'Е': '.', 'Ё': '.',
      'Ж': '...-', 'З': '--..', 'И': '..', 'Й': '.---', 'К': '-.-', 'Л': '.-..',
      'М': '--', 'Н': '-.', 'О': '---', 'П': '.--.', 'Р': '.-.', 'С': '...',
      'Т': '-', 'У': '..-', 'Ф': '..-.', 'Х': '....', 'Ц': '-.-.', 'Ч': '---.',
      'Ш': '----', 'Щ': '--.-', 'Ъ': '--.--', 'Ы': '-.--', 'Ь': '-..-', 'Э': '..-..',
      'Ю': '..--', 'Я': '.-.-',
      // Numbers
      '1': '.----', '2': '..---', '3': '...--', '4': '....-', '5': '.....',
      '6': '-....', '7': '--...', '8': '---..', '9': '----.', '0': '-----'
    };

    addLog("Blinking Morse for: '$text'...", tag: 'info');
    final onCmd = createCommand("a104");
    final offCmd = createCommand("a102");

    // Base unit: 200ms (dot). Dash is 3 units (600ms).
    const dotDuration = Duration(milliseconds: 200);
    const dashDuration = Duration(milliseconds: 600);
    const symbolGap = Duration(milliseconds: 200);
    const letterGap = Duration(milliseconds: 600);
    const wordGap = Duration(seconds: 1);

    for (int i = 0; i < text.length; i++) {
      if (isDisposed || !isConnected) break;
      final char = text[i].toUpperCase();

      if (char == ' ') {
        await Future.delayed(wordGap);
        continue;
      }

      if (!morseMap.containsKey(char)) continue;

      final symbols = morseMap[char]!;
      addLog("Blinking '$char': $symbols", tag: 'info');

      for (int s = 0; s < symbols.length; s++) {
        if (isDisposed || !isConnected) break;
        final symbol = symbols[s];

        final char = writeChar;
        if (char != null) {
          await char.write(onCmd, withoutResponse: char.properties.writeWithoutResponse);
        }
        if (symbol == '.') {
          await Future.delayed(dotDuration);
        } else {
          await Future.delayed(dashDuration);
        }

        if (char != null) {
          await char.write(offCmd, withoutResponse: char.properties.writeWithoutResponse);
        }
        await Future.delayed(symbolGap);
      }

      await Future.delayed(letterGap);
    }

    addLog("Finished Morse transmission.", tag: 'success');
  }

  void clearScope() {
    for (int i = 0; i < maxPoints; i++) {
      historyX[i] = 0.0;
      historyY[i] = 0.0;
      historyZ[i] = 0.0;
      historyMag[i] = 0.0;
    }
    notifyListeners();
  }

  void _handleDisconnect({bool autoScanReconnect = true}) async {
    isConnected = false;
    connectedDevice = null;
    writeChars.clear();
    notifyChars.clear();
    discoveredServicesList.clear();
    batteryInfo = "-";
    
    _connSub?.cancel();
    for (var sub in _notifySubs) {
      sub.cancel();
    }
    _notifySubs.clear();
    
    connectionStatus = "Disconnected";
    notifyListeners();
    addLog("Ring disconnected.", tag: 'warn');

    // Auto-scan and reconnect in the background if there's a saved device ID
    if (!isDisposed && autoScanReconnect && !userDisconnected) {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString("last_connected_device_id");
      if (savedId != null) {
        addLog("Saved device ID exists. Scanning to reconnect automatically...", tag: 'info');
        startManualScan();
      }
    }
  }

  @override
  void dispose() {
    isDisposed = true;
    _scanSub?.cancel();
    _connSub?.cancel();
    for (var sub in _notifySubs) {
      sub.cancel();
    }
    _notifySubs.clear();
    _scanningStateSub?.cancel();
    
    // Shut down sensors before disposing to save battery
    if (writeChars.isNotEmpty && isConnected) {
      final disableCmd = createCommand("a102");
      for (var char in writeChars) {
        char.write(disableCmd, withoutResponse: true).catchError((_) {});
      }
    }

    super.dispose();
  }
}
