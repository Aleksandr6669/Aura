import 'dart:async';
import 'dart:convert';
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

class SensorPoint {
  final double x;
  final double y;
  final double z;
  final double mag;
  SensorPoint(this.x, this.y, this.z, this.mag);
}

class GestureRule {
  final String id;
  final String name;
  final String triggerType; // "shake", "wrist_tap", or "custom"
  final String actionType;  // "get", "post", "ble_command"
  final String payload;     // URL or BLE HEX command
  final String? postData;   // JSON payload for POST (optional)
  final List<double>? template; // acceleration magnitude profile

  GestureRule({
    required this.id,
    required this.name,
    required this.triggerType,
    required this.actionType,
    required this.payload,
    this.postData,
    this.template,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'triggerType': triggerType,
    'actionType': actionType,
    'payload': payload,
    'postData': postData,
    'template': template,
  };

  factory GestureRule.fromJson(Map<String, dynamic> json) => GestureRule(
    id: json['id'],
    name: json['name'],
    triggerType: json['triggerType'],
    actionType: json['actionType'],
    payload: json['payload'],
    postData: json['postData'],
    template: json['template'] != null
        ? List<double>.from(json['template'].map((x) => (x as num).toDouble()))
        : null,
  );
}

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

  bool isConnected = false;
  bool get isStreaming => _playbackTimer != null;
  String connectionStatus = "Scanning...";
  String batteryInfo = "-";
  List<BluetoothService> discoveredServicesList = [];

  // Real-time trace values
  double lastX = 0.0;
  double lastY = 0.0;
  double lastZ = 0.0;
  double lastMag = 0.0;

  // History buffers for high-speed custom painter
  static const int maxPoints = 200;
  final List<double> historyX = List.filled(maxPoints, 0.0, growable: true);
  final List<double> historyY = List.filled(maxPoints, 0.0, growable: true);
  final List<double> historyZ = List.filled(maxPoints, 0.0, growable: true);
  final List<double> historyMag = List.filled(maxPoints, 0.0, growable: true);

  // Smooth playback buffer for iOS Bluetooth batching/jitter
  final List<SensorPoint> _pendingPoints = [];
  Timer? _playbackTimer;

  // Custom mapped gesture rules list
  List<GestureRule> gestureRules = [];
  int rulesVersion = 0;

  // Stream for gesture trigger events to show snackbars in UI
  final StreamController<GestureRule> _gestureTriggerStreamController = StreamController<GestureRule>.broadcast();
  Stream<GestureRule> get onGestureTriggered => _gestureTriggerStreamController.stream;

  // App running indicator
  bool isDisposed = false;

  // Terminal Console Logs
  final List<LogMessage> logs = [];

  List<DiscoveredDevice> discoveredDevices = [];
  bool isScanning = false;

  bool gestureActionsEnabled = false;
  double gestureThreshold = 2200.0;
  double customGestureThreshold = 0.65;
  String assignedActionType = "webhook"; // "webhook" or "ble_command"
  String assignedActionPayload = "";
  bool showNamelessDevices = false;
  DateTime? _lastGestureTrigger;
  bool gestureTriggeredAlert = false;
  bool wakeGestureEnabled = false;
  bool wakeGestureActive = false;

  // Sliding window buffer for real-time custom gestures
  // Packet rate measurement
  int _packetCount = 0;
  DateTime? _lastRateCheck;

  // Dynamic recording state variables
  bool isRecordingGesture = false;        // true = actively collecting samples
  bool isWaitingForGesture = false;       // true = armed, waiting for motion to start
  bool recordingDone = false;             // true when recording just finished successfully
  String recordingStatusMessage = "";    // error/status message shown in the modal UI
  List<double> recordedSamples = [];
  Timer? _recordingTimer;                 // max-duration safety timeout
  Timer? _silenceTimer;                   // fires when motion stops
  int recordingCountdown = 0;             // UI countdown (seconds remaining)

  // Live calibration buffer (first N packets during wait = resting baseline)
  final List<double> _baselineWindow = [];
  bool isCalibrating = false; // kept for UI compat

  // Active motion gesture recognition fields
  final List<double> _activeMotionBuffer = [];
  bool _isMovingActive = false;
  int _quietSampleCount = 0;
  double _runningBaseline = 1000.0;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<bool>? _scanningStateSub;
  Timer? _batteryTimer;
  Timer? _streamTimeoutTimer;

  void _resetStreamTimeout() {
    _streamTimeoutTimer?.cancel();
    _streamTimeoutTimer = Timer(const Duration(seconds: 30), () {
      if (isStreaming && !isRecordingGesture && !isWaitingForGesture) {
        addLog("⏰ Временное окно вышло (30 сек без жестов) — отключаем стрим для экономии батареи", tag: 'info');
        stopStream();
      }
    });
  }

  void addLog(String text, {String tag = 'info'}) {
    logs.add(LogMessage(text, tag: tag));
    if (logs.length > 300) logs.removeAt(0);
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
      customGestureThreshold = prefs.getDouble("custom_gesture_threshold") ?? 0.65;
      assignedActionType = prefs.getString("assigned_action_type") ?? "webhook";
      assignedActionPayload = prefs.getString("assigned_action_payload") ?? "";
      wakeGestureEnabled = prefs.getBool("wake_gesture_enabled") ?? false;
      await loadGestureRules();
      notifyListeners();
    } catch (e) {
      addLog("Failed to load gesture settings: $e", tag: 'warn');
    }
  }

  Future<void> loadGestureRules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList("gesture_rules");
      if (list != null) {
        gestureRules = list.map((s) => GestureRule.fromJson(jsonDecode(s))).toList();
        rulesVersion++;
      } else {
        // Add default example rules
        gestureRules = [
          GestureRule(
            id: "default_shake",
            name: "Vibrate / Disable (Example BLE)",
            triggerType: "shake",
            actionType: "ble_command",
            payload: "a102",
          ),
          GestureRule(
            id: "default_webhook",
            name: "Query Server (Example GET)",
            triggerType: "wrist_tap",
            actionType: "get",
            payload: "https://httpbin.org/get",
          ),
        ];
        await saveGestureRules();
      }
    } catch (e) {
      addLog("Failed to load gesture rules: $e", tag: 'warn');
    }
  }

  Future<void> saveGestureRules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = gestureRules.map((r) => jsonEncode(r.toJson())).toList();
      await prefs.setStringList("gesture_rules", list);
    } catch (e) {
      addLog("Failed to save gesture rules: $e", tag: 'warn');
    }
  }

  void addGestureRule(GestureRule rule) {
    gestureRules.add(rule);
    rulesVersion++;
    saveGestureRules();
    notifyListeners();
    addLog("Added gesture rule: ${rule.name}", tag: 'success');
  }

  void updateGestureRule(GestureRule rule) {
    final idx = gestureRules.indexWhere((r) => r.id == rule.id);
    if (idx != -1) {
      gestureRules[idx] = rule;
      rulesVersion++;
      saveGestureRules();
      notifyListeners();
      addLog("Updated gesture rule: ${rule.name}", tag: 'success');
    }
  }

  void removeGestureRule(String id) {
    final idx = gestureRules.indexWhere((r) => r.id == id);
    if (idx != -1) {
      final name = gestureRules[idx].name;
      gestureRules.removeAt(idx);
      rulesVersion++;
      saveGestureRules();
      notifyListeners();
      addLog("Removed gesture rule: $name", tag: 'info');
    }
  }

  Future<void> saveGestureSettings({
    bool? enabled,
    double? threshold,
    double? customThreshold,
    String? type,
    String? payload,
    bool? wakeEnabled,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (enabled != null) {
        gestureActionsEnabled = enabled;
        await prefs.setBool("gesture_actions_enabled", enabled);
        if (enabled) {
          await startStream();
        } else {
          await stopStream();
        }
      }
      if (threshold != null) {
        gestureThreshold = threshold;
        await prefs.setDouble("gesture_threshold", threshold);
      }
      if (customThreshold != null) {
        customGestureThreshold = customThreshold;
        await prefs.setDouble("custom_gesture_threshold", customThreshold);
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

    if (gestureActionsEnabled) {
      startStream();
    } else {
      stopStream();
    }

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

    _triggerRulesFor("shake");
  }

  void _triggerRulesFor(String triggerTypeOrId, {bool isManual = false}) async {
    _resetStreamTimeout();
    final rules = gestureRules.where((r) => r.triggerType == triggerTypeOrId || r.id == triggerTypeOrId).toList();
    if (rules.isEmpty) return;

    for (var rule in rules) {
      addLog("Executing action '${rule.name}'...", tag: 'info');

      if (!isManual) {
        _gestureTriggerStreamController.add(rule);
      }
      if (rule.actionType == "ble_command") {
        await writeCommand(rule.payload);
      } else if (rule.actionType == "get") {
        try {
          final client = HttpClient();
          client.connectionTimeout = const Duration(seconds: 5);
          final uri = Uri.parse(rule.payload.trim());
          final request = await client.getUrl(uri);
          final response = await request.close();
          addLog("GET '${rule.name}' response: ${response.statusCode}", tag: 'success');
          client.close();
        } catch (e) {
          addLog("GET '${rule.name}' failed: $e", tag: 'error');
        }
      } else if (rule.actionType == "post") {
        try {
          final client = HttpClient();
          client.connectionTimeout = const Duration(seconds: 5);
          final uri = Uri.parse(rule.payload.trim());
          final request = await client.postUrl(uri);
          request.headers.set('content-type', 'application/json');
          if (rule.postData != null && rule.postData!.isNotEmpty) {
            request.add(utf8.encode(rule.postData!));
          }
          final response = await request.close();
          addLog("POST '${rule.name}' response: ${response.statusCode}", tag: 'success');
          client.close();
        } catch (e) {
          addLog("POST '${rule.name}' failed: $e", tag: 'error');
        }
      }
    }
  }

  // Dynamic Time Warping (DTW) algorithm for pattern matching
  double calculateDtw(List<double> seq1, List<double> seq2) {
    final n = seq1.length;
    final m = seq2.length;
    if (n == 0 || m == 0) return double.infinity;

    final dtw = List.generate(n + 1, (_) => List.filled(m + 1, double.infinity));
    dtw[0][0] = 0.0;

    for (int i = 1; i <= n; i++) {
      for (int j = 1; j <= m; j++) {
        final cost = (seq1[i - 1] - seq2[j - 1]).abs();
        final minPrev = math.min(
          dtw[i - 1][j], // Insertion
          math.min(
            dtw[i][j - 1], // Deletion
            dtw[i - 1][j - 1], // Match
          ),
        );
        dtw[i][j] = cost + minPrev;
      }
    }

    return dtw[n][m];
  }

  // Standardization (Z-score normalization) to make pattern matching scale-invariant
  List<double> standardize(List<double> seq) {
    if (seq.isEmpty) return seq;
    double sum = 0.0;
    for (var x in seq) {
      sum += x;
    }
    double mean = sum / seq.length;

    double varianceSum = 0.0;
    for (var x in seq) {
      varianceSum += (x - mean) * (x - mean);
    }
    double stdDev = math.sqrt(varianceSum / seq.length);
    if (stdDev < 0.0001) stdDev = 1.0; // Prevent division by zero

    return seq.map((x) => (x - mean) / stdDev).toList();
  }

  // Process the collected gesture once movement stops
  void _processFinishedGesture() {
    final now = DateTime.now();
    // Cooldown of 2 seconds between triggers
    if (_lastGestureTrigger != null && now.difference(_lastGestureTrigger!) < const Duration(milliseconds: 2000)) {
      _activeMotionBuffer.clear();
      return;
    }

    final gestureData = _activeMotionBuffer.sublist(
      0,
      math.max(0, _activeMotionBuffer.length - _quietSampleCount),
    );
    _activeMotionBuffer.clear();

    if (gestureData.length < 8) {
      // Too short to be a gesture
      return;
    }

    addLog("⚡ Движение завершено. Длина: ${gestureData.length} точек. Распознавание...", tag: 'info');

    GestureRule? bestRule;
    double bestNormalizedDist = double.infinity;

    for (var rule in gestureRules) {
      if (rule.triggerType != "custom" || rule.template == null || rule.template!.length < 5) continue;

      final liveNormalized = standardize(gestureData);
      final templateNormalized = standardize(rule.template!);

      final rawDist = calculateDtw(liveNormalized, templateNormalized);
      final normalizedDist = rawDist / rule.template!.length;

      if (normalizedDist < bestNormalizedDist) {
        bestNormalizedDist = normalizedDist;
        bestRule = rule;
      }
    }

    // Threshold: normalized DTW per-point distance less than user settings is a match
    if (bestRule != null) {
      addLog("🔍 Наилучшее совпадение: '${bestRule.name}' с DTW: ${bestNormalizedDist.toStringAsFixed(3)}", tag: 'info');
      if (bestNormalizedDist < customGestureThreshold) {
        _lastGestureTrigger = now;
        _triggerCustomGestureAction(bestRule, bestNormalizedDist);
      } else {
        addLog("❌ Жест не распознан (DTW ${bestNormalizedDist.toStringAsFixed(3)} > порога $customGestureThreshold)", tag: 'warn');
      }
    } else {
      addLog("❌ Нет подходящих шаблонов жестов", tag: 'warn');
    }
  }

  void _triggerCustomGestureAction(GestureRule rule, double normalizedDist) {
    addLog("Жест '${rule.name}' совпал! (DTW: ${normalizedDist.toStringAsFixed(3)} на точку)", tag: 'success');
    gestureTriggeredAlert = true;
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 800), () {
      gestureTriggeredAlert = false;
      notifyListeners();
    });
    _triggerRulesFor(rule.id);
  }

  void executeRule(String ruleId) {
    _triggerRulesFor(ruleId, isManual: true);
  }

  // ─── Smart gesture recording ─────────────────────────────────────────────
  Future<void> startRecordingGesture() async {
    if (!isConnected) {
      addLog("Кольцо не подключено — запись невозможна", tag: 'error');
      return;
    }

    // Reset all state cleanly
    _recordingTimer?.cancel();
    _silenceTimer?.cancel();
    recordedSamples.clear();
    _baselineWindow.clear();
    isCalibrating = false;
    isWaitingForGesture = false;
    isRecordingGesture = true;
    recordingCountdown = 20; // Exactly 20 seconds
    notifyListeners();

    // Ensure raw accelerometer stream is running
    await startStream();
    // Give ring 200ms to start sending packets
    await Future.delayed(const Duration(milliseconds: 200));

    addLog("🔴 Запись пошла! Сделайте жест...", tag: 'info');

    // Countdown and automatic stop timer
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isRecordingGesture) {
        timer.cancel();
        return;
      }
      recordingCountdown--;
      if (recordingCountdown <= 0) {
        timer.cancel();
        stopRecordingGesture();
      } else {
        notifyListeners();
      }
    });
  }

  /// Called from _parseNotificationData while waiting or recording
  void _handleRecordingSample(double mag) {

    // ─── RECORDING PHASE ────────────────────────────────────────────────────
    if (isRecordingGesture) {
      recordedSamples.add(mag);
      notifyListeners();
    }
  }

  void stopRecordingGesture() {
    if (!isRecordingGesture && !isWaitingForGesture) return;
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _silenceTimer?.cancel();
    _silenceTimer = null;
    isRecordingGesture = false;
    isWaitingForGesture = false;
    if (recordedSamples.length >= 2) {
      recordingDone = true;
      recordingStatusMessage = "";
      addLog("✅ Жест записан: ${recordedSamples.length} точек (~${(recordedSamples.length / 50.0).toStringAsFixed(1)} сек)", tag: 'success');
    } else {
      recordingStatusMessage = "Жест слишком короткий (${recordedSamples.length} точек) — попробуйте ещё раз";
      recordedSamples.clear();
      addLog("⚠️ Жест слишком короткий (${recordedSamples.length} точек)", tag: 'warn');
    }
    if (!gestureActionsEnabled) {
      stopStream();
    }
    notifyListeners();
  }



  void clearRecordedSamples() {
    recordedSamples.clear();
    _baselineWindow.clear();
    isRecordingGesture = false;
    isWaitingForGesture = false;
    isCalibrating = false;
    recordingDone = false;
    recordingStatusMessage = "";
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _silenceTimer?.cancel();
    _silenceTimer = null;
    if (!gestureActionsEnabled) {
      stopStream();
    }
    notifyListeners();
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
    _connSub = device.connectionState.listen((state) async {
      if (state == BluetoothConnectionState.connected) {
        isConnected = true;
        connectionStatus = "Connected";
        notifyListeners();
        addLog("Connected successfully to smart ring.", tag: 'success');
        
        if (Platform.isAndroid) {
          try {
            await device.requestConnectionPriority(connectionPriorityRequest: ConnectionPriority.high);
            addLog("Requested high connection priority on Android", tag: 'success');
          } catch (e) {
            addLog("Could not set priority: $e", tag: 'warn');
          }
        }
        
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

      // Disable notifications before disconnecting
      for (var char in notifyChars) {
        try {
          await char.setNotifyValue(false);
          addLog("Notifications disabled for ${char.uuid.toString().substring(0, 8)}", tag: 'info');
        } catch (e) {
          addLog("Could not disable notifications: $e", tag: 'warn');
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

        // Start battery monitoring timer (every 5 seconds)
        _batteryTimer?.cancel();
        _batteryTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
          if (isConnected) {
            writeCommand("03");
          } else {
            timer.cancel();
          }
        });

        if (gestureActionsEnabled) {
          await startStream();
        } else {
          addLog("Ring ready. Turn on gesture actions to stream data.", tag: 'info');
        }
      } else {
        addLog("Error: Could not map GATT interface characteristics", tag: 'error');
      }
    } catch (e) {
      addLog("GATT Service Discovery failed: $e", tag: 'error');
    }
  }

  void _parseNotificationData(List<int> data) {
    if (data.isEmpty) return;

    // Track accel packet rate — logs Hz every 3 seconds
    if (data[0] == 0xA1 && data.length >= 8 && data[1] == 0x03) {
      _packetCount++;
      final now = DateTime.now();
      _lastRateCheck ??= now;
      final elapsed = now.difference(_lastRateCheck!).inMilliseconds;
      if (elapsed >= 3000) {
        final hz = (_packetCount * 1000 / elapsed).toStringAsFixed(1);
        addLog("📡 Частота данных кольца: $hz Гц ($_packetCount пакетов за ${(elapsed/1000).toStringAsFixed(1)}с)", tag: 'info');
        _packetCount = 0;
        _lastRateCheck = now;
      }
    }

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

        double currentX = accX.toDouble();
        double currentY = accY.toDouble();
        double currentZ = accZ.toDouble();

        // Vector Magnitude calculation
        double currentMag = math.sqrt(currentX * currentX + currentY * currentY + currentZ * currentZ);

        // 1. Smart gesture recording / calibrating / waiting (directly on incoming packets)
        if (isCalibrating || isWaitingForGesture || isRecordingGesture) {
          _handleRecordingSample(currentMag);
        }

        // 2. Process real-time custom gesture DTW matching with active motion detection
        if (gestureActionsEnabled && !isRecordingGesture && !isWaitingForGesture) {
          // Update baseline slowly when not actively moving
          if (!_isMovingActive) {
            _runningBaseline = _runningBaseline * 0.95 + currentMag * 0.05;
          }

          final deviation = (currentMag - _runningBaseline).abs();
          const double motionThreshold = 180.0;

          if (deviation > motionThreshold) {
            if (!_isMovingActive) {
              _isMovingActive = true;
              _activeMotionBuffer.clear();
              addLog("⚡ Начато движение для жеста...", tag: 'info');
            }
            _resetStreamTimeout();
            _quietSampleCount = 0;
            _activeMotionBuffer.add(currentMag);
          } else {
            if (_isMovingActive) {
              _activeMotionBuffer.add(currentMag);
              _quietSampleCount++;
              // 15 samples of quiet at ~50Hz is about 300ms
              if (_quietSampleCount > 15) {
                _isMovingActive = false;
                _processFinishedGesture();
              }
            }
          }

          if (_activeMotionBuffer.length > 300) {
            // More than 6 seconds of movement, reset
            _isMovingActive = false;
            _activeMotionBuffer.clear();
            addLog("⚠️ Движение слишком длинное, сброс", tag: 'warn');
          }
        }

        // 3. Built-in shake gesture action check
        if (gestureActionsEnabled) {
          if (currentMag > gestureThreshold) {
            final now = DateTime.now();
            if (_lastGestureTrigger == null || now.difference(_lastGestureTrigger!) > const Duration(seconds: 2)) {
              _lastGestureTrigger = now;
              _triggerGestureAction();
            }
          }
        }

        // Add to the playback queue
        _pendingPoints.add(SensorPoint(currentX, currentY, currentZ, currentMag));

        // Start playback timer automatically if not running
        if (_playbackTimer == null) {
          _startPlaybackTimer();
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

      // Auto-start streaming to allow custom gestures, and set the 30s timeout
      if (gestureActionsEnabled) {
        if (!isStreaming) {
          startStream();
        }
        _resetStreamTimeout();
      }

      if (wakeGestureEnabled) {
        _triggerWakeToggle();
      }
      if (gestureActionsEnabled) {
        _triggerRulesFor("wrist_tap");
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
    if (writeChars.isEmpty || !isConnected) {
      addLog("Cannot write command: no write characteristic mapped", tag: 'error');
      return;
    }
    final bytes = createCommand(hexString);
    for (var char in writeChars) {
      try {
        final withoutResp = char.properties.writeWithoutResponse;
        addLog("Writing: $hexString to ${char.uuid.toString().substring(0, 8)} (noResp=$withoutResp)...", tag: 'info');
        await char.write(bytes, withoutResponse: withoutResp);
        addLog("Write successful to ${char.uuid.toString().substring(0, 8)}: $hexString", tag: 'success');
      } catch (e) {
        addLog("Transmission error on ${char.uuid.toString().substring(0, 8)}: $e", tag: 'warn');
      }
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

  Future<void> startStream() async {
    if (!isConnected) return;
    _startPlaybackTimer();
    addLog("🟢 Запуск стрима акселерометра...", tag: 'info');
    await writeCommand("0a0200");
    await Future.delayed(const Duration(milliseconds: 300));
    await writeCommand("a104");
    _resetStreamTimeout();
  }

  Future<void> stopStream() async {
    if (!isConnected) return;
    _stopPlaybackTimer();
    addLog("🔴 Остановка стрима...", tag: 'info');
    await writeCommand("a102");
  }

  void _startPlaybackTimer() {
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 20), (timer) {
      if (_pendingPoints.isEmpty) {
        // If queue is empty, push last values to keep graph moving
        _pushToHistory(lastX, lastY, lastZ, lastMag);
        notifyListeners();
        return;
      }

      // Check queue size to catch up if iOS batching introduces too much delay
      int pointsToProcess = 1;
      if (_pendingPoints.length > 150) {
        pointsToProcess = 4;
      } else if (_pendingPoints.length > 50) {
        pointsToProcess = 2;
      }

      for (int i = 0; i < pointsToProcess; i++) {
        if (_pendingPoints.isEmpty) break;
        final point = _pendingPoints.removeAt(0);

        lastX = point.x;
        lastY = point.y;
        lastZ = point.z;
        lastMag = point.mag;

        _pushToHistory(point.x, point.y, point.z, point.mag);
      }
      notifyListeners();
    });
  }

  void _stopPlaybackTimer() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    _pendingPoints.clear();
  }

  void _pushToHistory(double x, double y, double z, double mag) {
    historyX.removeAt(0);
    historyY.removeAt(0);
    historyZ.removeAt(0);
    historyMag.removeAt(0);

    historyX.add(x);
    historyY.add(y);
    historyZ.add(z);
    historyMag.add(mag);
  }

  void _handleDisconnect({bool autoScanReconnect = true}) async {
    isConnected = false;
    connectedDevice = null;
    writeChars.clear();
    notifyChars.clear();
    discoveredServicesList.clear();
    batteryInfo = "-";
    _stopPlaybackTimer();
    _batteryTimer?.cancel();
    _batteryTimer = null;
    
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
    _stopPlaybackTimer();
    _batteryTimer?.cancel();
    _batteryTimer = null;
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

    _gestureTriggerStreamController.close();
    super.dispose();
  }
}
