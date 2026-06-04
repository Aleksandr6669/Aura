import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ring_ble_manager.dart';
import 'scope_chart.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  int _selectedTab = 0;
  StreamSubscription<GestureRule>? _gestureSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final manager = Provider.of<RingBleManager>(context, listen: false);
      _gestureSubscription = manager.onGestureTriggered.listen((rule) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF152A22),
            content: Text(
              "Жест распознан! Запущено действие: ${rule.name}",
              style: const TextStyle(color: Color(0xFFA6E3A1), fontWeight: FontWeight.bold),
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      });
    });
  }

  @override
  void dispose() {
    _gestureSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // We use Selectors and Consumers down in the widget tree to rebuild only what is necessary.

    return Scaffold(
      backgroundColor: const Color(0xFF0B0A11), // Deep dark space theme
      appBar: AppBar(
        backgroundColor: const Color(0xFF13111C),
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.blur_on_rounded, color: Color(0xFF74C7EC), size: 28),
            const SizedBox(width: 8),
            const Text(
              "Aura Ring Connect",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            // Only rebuild battery badge when battery info changes
            Selector<RingBleManager, (bool, String)>(
              selector: (_, m) => (m.isConnected, m.batteryInfo),
              builder: (context, data, _) {
                final isConnected = data.$1;
                final batteryInfo = data.$2;
                if (!isConnected) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C2C30),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF28565F)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.battery_std_rounded, color: Color(0xFFA6E3A1), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        batteryInfo,
                        style: const TextStyle(
                          color: Color(0xFFA6E3A1),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _selectedTab,
        children: [
          // Tab 1: Scope (listens to high-frequency stream)
          const ScopeTabContent(),
          // Tab 2: Gestures
          const GesturesTabContent(),
          // Tab 3: Devices
          const DevicesTabContent(),
          // Tab 4: Logs
          const LogsTabContent(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF232035), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedTab,
          onTap: (index) {
            setState(() {
              _selectedTab = index;
            });
          },
          backgroundColor: const Color(0xFF13111C),
          selectedItemColor: const Color(0xFF74C7EC),
          unselectedItemColor: const Color(0xFF5D5A75),
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics_outlined),
              activeIcon: Icon(Icons.analytics_rounded),
              label: "График",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.gesture_rounded),
              activeIcon: Icon(Icons.gesture_rounded),
              label: "Жесты",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bluetooth_searching_rounded),
              activeIcon: Icon(Icons.bluetooth_connected_rounded),
              label: "Устройства",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.terminal_outlined),
              activeIcon: Icon(Icons.terminal_rounded),
              label: "Логи",
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// TAB 1: SCOPE TAB (High-frequency updates allowed)
// ==========================================
class ScopeTabContent extends StatelessWidget {
  const ScopeTabContent({super.key});

  @override
  Widget build(BuildContext context) {
    // This widget registers as a full listener, which is correct because the Scope tab
    // shows real-time accelerometer stream updates.
    final manager = Provider.of<RingBleManager>(context);
    Color statusColor = manager.isConnected ? const Color(0xFFA6E3A1) : const Color(0xFFF38BA8);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection Status bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF13111C),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF232035)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    manager.isConnected ? "ПОДКЛЮЧЕНО" : "ОТКЛЮЧЕНО",
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const Spacer(),
                  Text(
                    manager.connectionStatus,
                    style: const TextStyle(color: Color(0xFF9E9BAC), fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Main Scope chart view
            Container(
              height: 250,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0C0D12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF232035)),
              ),
              child: Stack(
                children: [
                  ScopeChart(
                    historyX: manager.historyX,
                    historyY: manager.historyY,
                    historyZ: manager.historyZ,
                    historyMag: manager.historyMag,
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Row(
                      children: [
                        _buildLegendItem("X", const Color(0xFFF38BA8)),
                        _buildLegendItem("Y", const Color(0xFFA6E3A1)),
                        _buildLegendItem("Z", const Color(0xFF89B4FA)),
                        _buildLegendItem("Mag", const Color(0xFFFAB387)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Readouts grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _buildValueCard("Ось X (Roll)", manager.lastX, const Color(0xFFF38BA8)),
                _buildValueCard("Ось Y (Pitch)", manager.lastY, const Color(0xFFA6E3A1)),
                _buildValueCard("Ось Z (Yaw)", manager.lastZ, const Color(0xFF89B4FA)),
                _buildValueCard("Амплитуда", manager.lastMag, const Color(0xFFFAB387)),
              ],
            ),
            const SizedBox(height: 16),

            // Stream status & toggle card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: manager.isStreaming ? const Color(0xFF152A22) : const Color(0xFF1E1C2E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: manager.isStreaming ? const Color(0xFF225741) : const Color(0xFF2E2A44),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    manager.isStreaming ? Icons.sensors_rounded : Icons.sensors_off_rounded,
                    color: manager.isStreaming ? const Color(0xFFA6E3A1) : const Color(0xFFF38BA8),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          manager.isStreaming ? "Обработка жестов активна" : "Обработка жестов выключена",
                          style: TextStyle(
                            color: manager.isStreaming ? const Color(0xFFA6E3A1) : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          manager.isStreaming
                              ? "Кольцо передает данные и распознает жесты"
                              : "Включите для запуска стрима и прослушивания",
                          style: const TextStyle(color: Color(0xFF9E9BAC), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: manager.gestureActionsEnabled,
                    onChanged: manager.isConnected
                        ? (val) {
                            manager.saveGestureSettings(enabled: val);
                          }
                        : null,
                    activeThumbColor: const Color(0xFFA6E3A1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Clear history control
            ElevatedButton.icon(
              onPressed: () => manager.clearScope(),
              icon: const Icon(Icons.clear_all_rounded, size: 16),
              label: const Text("Очистить график"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF201D30),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValueCard(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF13111C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF232035)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF6C6E85), fontSize: 11, fontWeight: FontWeight.bold),
          ),
          Text(
            value.toStringAsFixed(1),
            style: TextStyle(
              color: color,
              fontSize: 26,
              fontFamily: 'Fira Code',
              fontWeight: FontWeight.w800,
            ),
          ),
          Container(height: 3, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1.5))),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// TAB 2: CONTROLS TAB (Optimized to ignore high-frequency stream)
// ==========================================
class ControlsTabContent extends StatefulWidget {
  const ControlsTabContent({super.key});

  @override
  State<ControlsTabContent> createState() => _ControlsTabContentState();
}

class _ControlsTabContentState extends State<ControlsTabContent> {
  final TextEditingController _cmdController = TextEditingController(text: "SOS");
  final TextEditingController _gesturePayloadController = TextEditingController();
  final FocusNode _gestureFocusNode = FocusNode();

  @override
  void dispose() {
    _cmdController.dispose();
    _gesturePayloadController.dispose();
    _gestureFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<RingBleManager>(context, listen: false);

    // Rebuilds ONLY when settings or connection state changes
    return Selector<RingBleManager, (bool, bool, double, String, String, bool, bool, bool)>(
      selector: (_, m) => (
        m.isConnected,
        m.gestureActionsEnabled,
        m.gestureThreshold,
        m.assignedActionType,
        m.assignedActionPayload,
        m.gestureTriggeredAlert,
        m.wakeGestureEnabled,
        m.wakeGestureActive,
      ),
      builder: (context, data, _) {
        final isConnected = data.$1;
        final gestureActionsEnabled = data.$2;
        final gestureThreshold = data.$3;
        final assignedActionType = data.$4;
        final assignedActionPayload = data.$5;
        final gestureTriggeredAlert = data.$6;
        final wakeGestureEnabled = data.$7;
        final wakeGestureActive = data.$8;

        // Update controller value only when not focused to avoid infinite rebuild loops
        if (_gesturePayloadController.text != assignedActionPayload && !_gestureFocusNode.hasFocus) {
          _gesturePayloadController.text = assignedActionPayload;
        }

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Commands card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E1D2F), Color(0xFF13111C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF2E2A44)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Ring Command Center",
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "Send Morse signals, raw HEX command protocols, or trigger/stop ring sensor updates.",
                        style: TextStyle(color: Color(0xFF9E9BAC), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Manual command input panel
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13111C),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF232035)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        "COMMAND INPUT",
                        style: TextStyle(color: Color(0xFF74C7EC), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _cmdController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF0B0A11),
                          hintText: "E.g. SOS or A104",
                          hintStyle: const TextStyle(color: Color(0xFF5D5A75)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Color(0xFF232035)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Color(0xFF74C7EC)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: isConnected ? () => manager.sendMorse(_cmdController.text) : null,
                              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                              label: const Text("Morse"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2A283E),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: const Color(0xFF181622),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: isConnected ? () => manager.writeCommand(_cmdController.text) : null,
                              icon: const Icon(Icons.code_rounded, size: 16),
                              label: const Text("Send HEX"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2A283E),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: const Color(0xFF181622),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Sensor control buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13111C),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF232035)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        "SENSOR CONTROLS",
                        style: TextStyle(color: Color(0xFF74C7EC), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: isConnected ? () => manager.writeCommand("a104") : null,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text("Enable Sensor (a104)"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFA6E3A1),
                          foregroundColor: const Color(0xFF0B0A11),
                          disabledBackgroundColor: const Color(0xFF181622),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: isConnected ? () => manager.writeCommand("a102") : null,
                        icon: const Icon(Icons.stop_rounded),
                        label: const Text("Disable Sensor (a102)"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF38BA8),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF181622),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: isConnected ? () => manager.writeCommand("03") : null,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text("Refresh Battery State"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF74C7EC),
                          side: const BorderSide(color: Color(0xFF74C7EC)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
                // ─── Wake Gesture card ───────────────────────────────────
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: wakeGestureActive
                        ? const Color(0xFF1A2B3A)
                        : const Color(0xFF13111C),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: wakeGestureActive
                          ? const Color(0xFF89B4FA)
                          : wakeGestureEnabled
                              ? const Color(0xFF2A4060)
                              : const Color(0xFF232035),
                      width: wakeGestureActive ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.gesture_rounded,
                            color: Color(0xFF89B4FA),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            "WAKE GESTURE (ЖЕСТ КОЛЬЦА)",
                            style: TextStyle(
                              color: Color(0xFF89B4FA),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          if (wakeGestureActive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: gestureActionsEnabled
                                    ? const Color(0xFF1C3A28)
                                    : const Color(0xFF3A1C1C),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                gestureActionsEnabled ? "⚡ ON" : "⚡ OFF",
                                style: TextStyle(
                                  color: gestureActionsEnabled
                                      ? const Color(0xFFA6E3A1)
                                      : const Color(0xFFF38BA8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Жест подъема руки или резкого движения на самом кольце переключает режим прослушивания — полностью пассивно и без постоянного стриминга.",
                        style: TextStyle(color: Color(0xFF6C6E85), fontSize: 11),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Включить wake-жест кольца",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Switch(
                            value: wakeGestureEnabled,
                            onChanged: (val) {
                              manager.saveGestureSettings(wakeEnabled: val);
                            },
                            activeThumbColor: const Color(0xFF89B4FA),
                          ),
                        ],
                      ),
                      if (wakeGestureEnabled) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B0A11),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF232035)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                color: Color(0xFF89B4FA),
                                size: 14,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  gestureActionsEnabled
                                      ? "Прослушивание жестов: АКТИВНО — сделайте жест на кольце для выключения"
                                      : "Прослушивание жестов: ВЫКЛЮЧЕНО — сделайте жест на кольце для включения",
                                  style: TextStyle(
                                    color: gestureActionsEnabled
                                        ? const Color(0xFFA6E3A1)
                                        : const Color(0xFF9E9BAC),
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ─── Gesture Action Triggers card ─────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: gestureTriggeredAlert ? const Color(0xFF2E1B2D) : const Color(0xFF13111C),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: gestureTriggeredAlert ? const Color(0xFFF38BA8) : const Color(0xFF232035),
                      width: gestureTriggeredAlert ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Text(
                            "GESTURE TRIGGERS (SHAKE / TAP)",
                            style: TextStyle(color: Color(0xFF74C7EC), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          if (gestureTriggeredAlert)
                            const Text(
                              "💥 TRIGGERED!",
                              style: TextStyle(color: Color(0xFFF38BA8), fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Enable Gesture Actions",
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          Switch(
                            value: gestureActionsEnabled,
                            onChanged: (val) {
                              manager.saveGestureSettings(enabled: val);
                            },
                            activeThumbColor: const Color(0xFF74C7EC),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Sensitivity Threshold: ${gestureThreshold.toStringAsFixed(0)}",
                        style: const TextStyle(color: Color(0xFF9E9BAC), fontSize: 12),
                      ),
                      Slider(
                        value: gestureThreshold,
                        min: 1200.0,
                        max: 3500.0,
                        divisions: 23,
                        activeColor: const Color(0xFF74C7EC),
                        inactiveColor: const Color(0xFF232035),
                        onChanged: (val) {
                          manager.saveGestureSettings(threshold: val);
                        },
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "ACTION TYPE",
                        style: TextStyle(color: Color(0xFF6C6E85), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: assignedActionType,
                        dropdownColor: const Color(0xFF13111C),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF0B0A11),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Color(0xFF232035)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: "webhook",
                            child: Text("HTTP Webhook Request", style: TextStyle(color: Colors.white, fontSize: 13)),
                          ),
                          DropdownMenuItem(
                            value: "ble_command",
                            child: Text("Send BLE HEX Command", style: TextStyle(color: Colors.white, fontSize: 13)),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            manager.saveGestureSettings(type: val);
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        "ACTION PAYLOAD",
                        style: TextStyle(color: Color(0xFF6C6E85), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _gesturePayloadController,
                        focusNode: _gestureFocusNode,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF0B0A11),
                          hintText: assignedActionType == "webhook"
                              ? "E.g. http://192.168.1.50/api/trigger"
                              : "E.g. a102",
                          hintStyle: const TextStyle(color: Color(0xFF5D5A75)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Color(0xFF232035)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Color(0xFF74C7EC)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (val) {
                          manager.saveGestureSettings(payload: val);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ==========================================
// TAB 3: DEVICES TAB (Optimized to ignore high-frequency stream)
// ==========================================
class DevicesTabContent extends StatelessWidget {
  const DevicesTabContent({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<RingBleManager>(context, listen: false);

    // Rebuilds ONLY when scanned devices, scanning state, showNamelessSetting, or connection state changes
    return Selector<RingBleManager, (List<DiscoveredDevice>, bool, bool, BluetoothDevice?)>(
      selector: (_, m) {
        // Filter out the connected device from scanner results to avoid duplication
        final filtered = m.discoveredDevices.where((d) {
          if (m.connectedDevice != null && d.device.remoteId == m.connectedDevice!.remoteId) {
            return false;
          }
          if (m.showNamelessDevices) return true;
          return d.device.platformName.trim().isNotEmpty || d.advertisementData.advName.trim().isNotEmpty;
        }).toList();
        return (filtered, m.isScanning, m.showNamelessDevices, m.connectedDevice);
      },
      builder: (context, data, _) {
        final filteredList = data.$1;
        final isScanning = data.$2;
        final showNamelessDevices = data.$3;
        final connectedDevice = data.$4;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text(
                    "BLE СКАНЕР",
                    style: TextStyle(color: Color(0xFF74C7EC), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (isScanning)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF74C7EC)),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              ElevatedButton.icon(
                onPressed: isScanning ? manager.stopManualScan : manager.startManualScan,
                icon: Icon(isScanning ? Icons.stop_rounded : Icons.search_rounded),
                label: Text(isScanning ? "Остановить поиск" : "Поиск устройств"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isScanning ? const Color(0xFFF38BA8) : const Color(0xFF74C7EC),
                  foregroundColor: const Color(0xFF0B0A11),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),

              // Toggle nameless devices
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF13111C),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF232035)),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: showNamelessDevices,
                      onChanged: (val) {
                        manager.toggleShowNameless(val ?? false);
                      },
                      activeColor: const Color(0xFF74C7EC),
                    ),
                    const Expanded(
                      child: Text(
                        "Показывать безымянные BLE устройства",
                        style: TextStyle(color: Color(0xFF9E9BAC), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 1. Render Connected Device Card at the top
              if (connectedDevice != null) ...[
                const Text(
                  "МОЕ УСТРОЙСТВО (ПОДКЛЮЧЕНО / ПОДКЛЮЧЕНИЕ)",
                  style: TextStyle(color: Color(0xFF6C6E85), fontSize: 10, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildConnectedDeviceCard(context, manager, connectedDevice),
                const SizedBox(height: 16),
                const Text(
                  "ДОСТУПНЫЕ УСТРОЙСТВА",
                  style: TextStyle(color: Color(0xFF6C6E85), fontSize: 10, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
              ],

              // 2. Render Available Devices
              Expanded(
                child: filteredList.isEmpty && connectedDevice == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bluetooth_disabled_rounded, size: 48, color: const Color(0xFF5D5A75).withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            const Text(
                              "Устройства еще не найдены.\nНажмите Поиск устройств для сканирования эфира.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF5D5A75), fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredList.length,
                        itemBuilder: (context, idx) {
                          if (idx >= filteredList.length) return const SizedBox.shrink();
                          final scanResult = filteredList[idx];
                          final device = scanResult.device;
                          final isPresent = scanResult.isPresent;
                          
                          final name = device.platformName.isEmpty 
                              ? (scanResult.advertisementData.advName.isEmpty 
                                  ? "[Unnamed Device]" 
                                  : scanResult.advertisementData.advName)
                              : device.platformName;

                          final id = device.remoteId.str;
                          final rssi = scanResult.rssi;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF13111C),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF232035)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.bluetooth_rounded,
                                  color: isPresent ? const Color(0xFF74C7EC) : Colors.grey,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: TextStyle(
                                          color: isPresent ? Colors.white : Colors.grey,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        id,
                                        style: TextStyle(
                                          color: isPresent ? const Color(0xFF6C6E85) : Colors.grey.shade700,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      "$rssi dBm",
                                      style: TextStyle(
                                        color: !isPresent
                                            ? Colors.grey
                                            : rssi > -70
                                                ? const Color(0xFFA6E3A1)
                                                : const Color(0xFFFAB387),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    SizedBox(
                                      height: 28,
                                      child: ElevatedButton(
                                        onPressed: () => manager.connectToDevice(device),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isPresent ? const Color(0xFF2A283E) : const Color(0xFF1E1C2E),
                                          foregroundColor: isPresent ? Colors.white : Colors.grey,
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: const Text(
                                          "Подключить",
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnectedDeviceCard(BuildContext context, RingBleManager manager, BluetoothDevice device) {
    final name = device.platformName.isEmpty ? "[Сохраненное кольцо]" : device.platformName;
    final id = device.remoteId.str;
    final isConnecting = manager.connectionStatus == "Connecting...";

    return GestureDetector(
      onTap: () {
        if (manager.isConnected) {
          _showServicesBottomSheet(context, manager, device);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF152A22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF225741), width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.bluetooth_connected_rounded,
              color: Color(0xFFA6E3A1),
              size: 26,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    id,
                    style: const TextStyle(color: Color(0xFF9E9BAC), fontSize: 11),
                  ),
                  if (isConnecting) ...[
                    const SizedBox(height: 4),
                    const Text(
                      "Подключение...",
                      style: TextStyle(color: Color(0xFFF9E2AF), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ] else if (manager.isConnected) ...[
                    const SizedBox(height: 4),
                    const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 10, color: Color(0xFFA6E3A1)),
                        SizedBox(width: 4),
                        Text(
                          "Нажмите для просмотра сервисов и характеристик",
                          style: TextStyle(color: Color(0xFFA6E3A1), fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            ElevatedButton(
              onPressed: manager.disconnectDevice,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF38BA8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                "Отключить",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showServicesBottomSheet(BuildContext context, RingBleManager manager, BluetoothDevice device) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0F17),
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E2A47),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.cable_rounded, color: Color(0xFF74C7EC)),
                      const SizedBox(width: 8),
                      const Text(
                        "GATT Сервисы и Характеристики",
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF9E9BAC)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF232035), height: 16),
                  
                  // 1. Mapped Channels
                  const Text(
                    "АКТИВНЫЕ НАЗНАЧЕННЫЕ КАНАЛЫ",
                    style: TextStyle(color: Color(0xFF89B4FA), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF13111C),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF232035)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Канал записи (отправка команд):",
                          style: TextStyle(color: Color(0xFF6C6E85), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          manager.writeChar?.uuid.toString().toLowerCase() ?? "Не назначен",
                          style: const TextStyle(color: Color(0xFFA6E3A1), fontSize: 11, fontFamily: 'monospace'),
                        ),
                        const Divider(color: Color(0xFF232035), height: 16),
                        const Text(
                          "Канал уведомлений (получение данных):",
                          style: TextStyle(color: Color(0xFF6C6E85), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          manager.notifyChar?.uuid.toString().toLowerCase() ?? "Не назначен",
                          style: const TextStyle(color: Color(0xFFFAB387), fontSize: 11, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. Discovered GATT Services
                  Text(
                    "ОБНАРУЖЕННЫЕ СЕРВИСЫ (${manager.discoveredServicesList.length})",
                    style: const TextStyle(color: Color(0xFFCBA6F7), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...manager.discoveredServicesList.map((service) {
                    final sUuid = service.uuid.toString().toLowerCase();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF13111C),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF232035)),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          title: Text(
                            sUuid,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                          ),
                          leading: const Icon(Icons.settings_input_component_rounded, color: Color(0xFFCBA6F7), size: 16),
                          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          expandedAlignment: Alignment.centerLeft,
                          children: service.characteristics.map((char) {
                            final cUuid = char.uuid.toString().toLowerCase();
                            List<String> props = [];
                            if (char.properties.read) props.add("READ");
                            if (char.properties.write) props.add("WRITE");
                            if (char.properties.writeWithoutResponse) props.add("WRITE_NO_RESP");
                            if (char.properties.notify) props.add("NOTIFY");
                            if (char.properties.indicate) props.add("INDICATE");
                            
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.radio_button_checked_rounded, color: Color(0xFF9E9BAC), size: 11),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          cUuid,
                                          style: const TextStyle(color: Color(0xFFD9E0EE), fontSize: 11, fontFamily: 'monospace'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (props.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 19.0),
                                      child: Text(
                                        "[${props.join(', ')}]",
                                        style: const TextStyle(color: Color(0xFF74C7EC), fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ==========================================
// TAB 4: LOGS TAB (Optimized to ignore high-frequency stream)
// ==========================================
class LogsTabContent extends StatefulWidget {
  const LogsTabContent({super.key});

  @override
  State<LogsTabContent> createState() => _LogsTabContentState();
}

class _LogsTabContentState extends State<LogsTabContent> {
  final ScrollController _logScrollController = ScrollController();

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _logScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<RingBleManager>(context, listen: false);

    // Rebuilds ONLY when logs size changes
    return Selector<RingBleManager, int>(
      selector: (_, m) => m.logs.length,
      builder: (context, logsCount, _) {
        _scrollToBottom();

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text(
                    "СИСТЕМНЫЕ ЛОГИ КОНСОЛИ",
                    style: TextStyle(color: Color(0xFF74C7EC), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        manager.logs.clear();
                      });
                    },
                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFF38BA8), size: 20),
                    tooltip: "Очистить логи",
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF09090E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF232035)),
                  ),
                  child: ListView.builder(
                    controller: _logScrollController,
                    itemCount: logsCount,
                    itemBuilder: (context, idx) {
                      final log = manager.logs[idx];
                      Color tagColor = const Color(0xFF89B4FA); // Blue info
                      if (log.tag == 'success') tagColor = const Color(0xFFA6E3A1);
                      if (log.tag == 'warn') tagColor = const Color(0xFFF9E2AF);
                      if (log.tag == 'error') tagColor = const Color(0xFFF38BA8);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(fontFamily: 'Fira Code', fontSize: 11, height: 1.3),
                            children: [
                              TextSpan(text: "[${log.timestamp}] ", style: const TextStyle(color: Color(0xFF5D5A75))),
                              TextSpan(text: log.text, style: TextStyle(color: tagColor)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ==========================================
// TAB 2: GESTURES TAB (Real-time gesture configurations)
// ==========================================
class GesturesTabContent extends StatefulWidget {
  const GesturesTabContent({super.key});

  @override
  State<GesturesTabContent> createState() => _GesturesTabContentState();
}

class _GesturesTabContentState extends State<GesturesTabContent> {
  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<RingBleManager>(context, listen: false);

    return Selector<RingBleManager, (bool, double, int, bool)>(
      selector: (_, m) => (
        m.gestureActionsEnabled,
        m.gestureThreshold,
        m.rulesVersion,
        m.wakeGestureEnabled,
      ),
      builder: (context, data, _) {
        final gestureActionsEnabled = data.$1;
        final gestureThreshold = data.$2;
        // rulesVersion (data.$3) is used by Selector to trigger rebuilds
        final wakeGestureEnabled = data.$4;
        final gestureRules = manager.gestureRules;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [


                  // 2. Main Master Switch Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E1D2F), Color(0xFF13111C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF2E2A44)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.gesture_rounded, color: Color(0xFF74C7EC)),
                                SizedBox(width: 8),
                                Text(
                                  "Обработка жестов",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Switch(
                              value: gestureActionsEnabled,
                              onChanged: (val) {
                                manager.saveGestureSettings(enabled: val);
                              },
                              activeThumbColor: const Color(0xFF74C7EC),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Привяжите встряхивание, двойной тап или ваш собственный записанный жест к отправке GET/POST вебхуков или BLE-команд.",
                          style: TextStyle(color: Color(0xFF9E9BAC), fontSize: 12, height: 1.4),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B0A11),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF232035)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Всего правил автоматизации:",
                                style: TextStyle(color: Color(0xFF6C6E85), fontSize: 12),
                              ),
                              Text(
                                "${gestureRules.length}",
                                style: const TextStyle(
                                  color: Color(0xFF74C7EC),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Settings Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF13111C),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF232035)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          "ЧУВСТВИТЕЛЬНОСТЬ И ПРОБУЖДЕНИЕ",
                          style: TextStyle(color: Color(0xFF74C7EC), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Порог встряхивания (Shake)",
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              gestureThreshold.toStringAsFixed(0),
                              style: const TextStyle(
                                color: Color(0xFF74C7EC),
                                fontSize: 13,
                                fontFamily: 'Fira Code',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: gestureThreshold,
                          min: 1200.0,
                          max: 3500.0,
                          divisions: 23,
                          activeColor: const Color(0xFF74C7EC),
                          inactiveColor: const Color(0xFF232035),
                          onChanged: (val) {
                            manager.saveGestureSettings(threshold: val);
                          },
                        ),
                        const Divider(color: Color(0xFF232035), height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Жест пробуждения кольца (Wake)",
                                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  "Двойной тап запястья включает/выключает режим",
                                  style: TextStyle(color: Color(0xFF6C6E85), fontSize: 11),
                                ),
                              ],
                            ),
                            Switch(
                              value: wakeGestureEnabled,
                              onChanged: (val) {
                                manager.saveGestureSettings(wakeEnabled: val);
                              },
                              activeThumbColor: const Color(0xFF89B4FA),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4. Header for rules list
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "ПРАВИЛА И ДЕЙСТВИЯ",
                        style: TextStyle(
                          color: Color(0xFF89B4FA),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _showAddRuleSheet(context, manager),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text("Добавить"),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF74C7EC),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 5. Rules List View
                  if (gestureRules.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF13111C),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF232035)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.rule_folder_outlined,
                            size: 48,
                            color: const Color(0xFF5D5A75).withOpacity(0.5),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "Нет настроенных правил жестов",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Нажмите кнопку 'Добавить' или кнопку '+' ниже, чтобы создать первое правило.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF6C6E85), fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: gestureRules.length,
                      itemBuilder: (context, index) {
                        final rule = gestureRules[index];
                        return _buildRuleCard(context, manager, rule);
                      },
                    ),
                  const SizedBox(height: 80), // Bottom padding for FAB overlap
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddRuleSheet(context, manager),
            backgroundColor: const Color(0xFF74C7EC),
            foregroundColor: const Color(0xFF0B0A11),
            child: const Icon(Icons.add_rounded),
          ),
        );
      },
    );
  }

  Widget _buildRuleCard(BuildContext context, RingBleManager manager, GestureRule rule) {
    IconData triggerIcon = Icons.vibration_rounded;
    String triggerLabel = "Встряхивание (Shake)";
    Color triggerColor = const Color(0xFFFAB387);
    if (rule.triggerType == "wrist_tap") {
      triggerIcon = Icons.touch_app_rounded;
      triggerLabel = "Тап запястьем (Wrist Tap)";
      triggerColor = const Color(0xFFCBA6F7);
    } else if (rule.triggerType == "custom") {
      triggerIcon = Icons.gesture_rounded;
      triggerLabel = "Записанный жест (Custom)";
      triggerColor = const Color(0xFF89B4FA);
    }

    String actionLabel = "GET";
    Color actionBadgeColor = const Color(0xFFA6E3A1);
    if (rule.actionType == "post") {
      actionLabel = "POST";
      actionBadgeColor = const Color(0xFF74C7EC);
    } else if (rule.actionType == "ble_command") {
      actionLabel = "BLE";
      actionBadgeColor = const Color(0xFFF38BA8);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF13111C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF232035)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: triggerColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(triggerIcon, color: triggerColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rule.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      triggerLabel,
                      style: TextStyle(
                        color: triggerColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: actionBadgeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: actionBadgeColor.withOpacity(0.3)),
                ),
                child: Text(
                  actionLabel,
                  style: TextStyle(
                    color: actionBadgeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Run Test trigger button
              IconButton(
                icon: const Icon(Icons.play_circle_outline_rounded, color: Color(0xFFA6E3A1), size: 22),
                onPressed: () {
                  manager.executeRule(rule.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF152A22),
                      content: Text(
                        "Запущено действие: ${rule.name}",
                        style: const TextStyle(color: Color(0xFFA6E3A1), fontWeight: FontWeight.bold),
                      ),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                tooltip: "Тест запуска действия",
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(width: 8),
              // Delete Button
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFF38BA8), size: 22),
                onPressed: () {
                  _showDeleteConfirmDialog(context, manager, rule);
                },
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0B0A11),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  rule.actionType == "ble_command" ? Icons.settings_bluetooth_rounded : Icons.link_rounded,
                  color: const Color(0xFF5D5A75),
                  size: 14,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rule.payload,
                    style: const TextStyle(
                      color: Color(0xFFE0DEF4),
                      fontFamily: 'Fira Code',
                      fontSize: 11,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (rule.triggerType == "custom" && rule.template != null) ...[
            const SizedBox(height: 8),
            Text(
              "Шаблон: ${rule.template!.length} точек сигнала акселерометра",
              style: const TextStyle(color: Color(0xFF6C6E85), fontSize: 10, fontStyle: FontStyle.italic),
            ),
          ],
          if (rule.actionType == "post" && rule.postData != null && rule.postData!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0E17),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF232035)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "POST Body (JSON):",
                    style: TextStyle(color: Color(0xFF6C6E85), fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rule.postData!,
                    style: const TextStyle(
                      color: Color(0xFFA6E3A1),
                      fontFamily: 'Fira Code',
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, RingBleManager manager, GestureRule rule) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF13111C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            "Удалить '${rule.name}'?",
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "Вы уверены, что хотите удалить это правило автоматизации жестов?",
            style: TextStyle(color: Color(0xFF9E9BAC), fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Отмена", style: TextStyle(color: Color(0xFF74C7EC))),
            ),
            ElevatedButton(
              onPressed: () {
                manager.removeGestureRule(rule.id);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF38BA8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("Удалить"),
            ),
          ],
        );
      },
    );
  }

  void _showAddRuleSheet(BuildContext context, RingBleManager manager) {
    final formKey = GlobalKey<FormState>();
    String name = "";
    String triggerType = "shake";
    String actionType = "get";
    String payload = "";
    String postData = "";
    List<double> capturedTemplate = [];

    manager.clearRecordedSamples();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0F17),
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final double availableHeight = MediaQuery.of(context).size.height * 0.85 - MediaQuery.of(context).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: availableHeight,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E2A47),
                            borderRadius: BorderRadius.circular(2.5),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.playlist_add_rounded, color: Color(0xFF74C7EC)),
                          const SizedBox(width: 8),
                          const Text(
                            "Новое правило жеста",
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF9E9BAC)),
                            onPressed: () {
                              if (manager.isRecordingGesture) {
                                manager.stopRecordingGesture();
                              }
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                      const Divider(color: Color(0xFF232035), height: 16),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                        
                        // 1. Rule Name Input
                        const Text(
                          "НАЗВАНИЕ ПРАВИЛА",
                          style: TextStyle(color: Color(0xFF6C6E85), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF0B0A11),
                            hintText: "Например, Включить свет в зале",
                            hintStyle: const TextStyle(color: Color(0xFF5D5A75), fontSize: 13),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Color(0xFF232035)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Color(0xFF74C7EC)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return "Введите название правила";
                            }
                            return null;
                          },
                          onSaved: (val) => name = val!.trim(),
                        ),
                        const SizedBox(height: 16),

                        // 2. Trigger Type Dropdown
                        const Text(
                          "ЖЕСТ (ТРИГГЕР)",
                          style: TextStyle(color: Color(0xFF6C6E85), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: triggerType,
                          dropdownColor: const Color(0xFF0F0F17),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF0B0A11),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Color(0xFF232035)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: "shake",
                              child: Text("Встряхивание (Shake)", style: TextStyle(color: Colors.white, fontSize: 13)),
                            ),
                            DropdownMenuItem(
                              value: "wrist_tap",
                              child: Text("Двойной тап запястья (Wrist Tap)", style: TextStyle(color: Colors.white, fontSize: 13)),
                            ),
                            DropdownMenuItem(
                              value: "custom",
                              child: Text("Записать свой жест (Custom)", style: TextStyle(color: Colors.white, fontSize: 13)),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                triggerType = val;
                              });
                            }
                          },
                        ),
                        
                        // 2.5 Real-time gesture recorder panel
                        if (triggerType == "custom") ...[
                          const SizedBox(height: 16),
                          const Text(
                            "ФИЗИЧЕСКАЯ ЗАПИСЬ ДВИЖЕНИЯ",
                            style: TextStyle(color: Color(0xFF6C6E85), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Consumer<RingBleManager>(
                            builder: (context, liveManager, _) {
                              final isWaiting = liveManager.isWaitingForGesture;
                              final isRecording = liveManager.isRecordingGesture;
                              final countdown = liveManager.recordingCountdown;
                              final samplesCount = liveManager.recordedSamples.length;
                              final statusMsg = liveManager.recordingStatusMessage;

                              // Sync capturedTemplate when recording finishes
                              if (liveManager.recordingDone &&
                                  capturedTemplate.isEmpty &&
                                  liveManager.recordedSamples.isNotEmpty) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  setModalState(() {
                                    capturedTemplate = List<double>.from(liveManager.recordedSamples);
                                  });
                                });
                              }

                              // ─── Phase: ОЖИДАНИЕ — ждём движения ───
                              if (isWaiting) {
                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1C1B2A),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF74C7EC)),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF74C7EC)),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            "ОЖИДАНИЕ ЖЕСТА... ($countdown с)",
                                            style: const TextStyle(color: Color(0xFF74C7EC), fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        "Сделайте жест кольцом — система автоматически начнёт запись",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Color(0xFF6C6E85), fontSize: 11),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              // ─── Phase: ЗАПИСЬ — активная запись движения ───
                              if (isRecording) {
                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2A1B1C),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFF38BA8)),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF38BA8)),
                                          ),
                                          const SizedBox(width: 10),
                                          const Text(
                                            "ЗАПИСЬ ДВИЖЕНИЯ...",
                                            style: TextStyle(color: Color(0xFFF38BA8), fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Собрано: $samplesCount точек (~${(samplesCount / 50.0).toStringAsFixed(1)} с)",
                                        style: const TextStyle(color: Color(0xFF6C6E85), fontSize: 11),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        "Остановите движение — запись завершится автоматически",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Color(0xFF5D5A75), fontSize: 10),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              // ─── Phase: ГОТОВО / СТАРТ ───
                              final hasRecorded = capturedTemplate.isNotEmpty;

                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: hasRecorded ? const Color(0xFF152A22) : const Color(0xFF13111C),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: hasRecorded ? const Color(0xFF225741) : const Color(0xFF232035),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    if (hasRecorded) ...[
                                      const Row(
                                        children: [
                                          Icon(Icons.check_circle_outline_rounded, color: Color(0xFFA6E3A1), size: 18),
                                          SizedBox(width: 8),
                                          Text(
                                            "Жест успешно записан!",
                                            style: TextStyle(color: Color(0xFFA6E3A1), fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Длина: ${capturedTemplate.length} точек (~${(capturedTemplate.length / 50.0).toStringAsFixed(1)} с)",
                                        style: const TextStyle(color: Color(0xFF9E9BAC), fontSize: 11),
                                      ),
                                      const SizedBox(height: 12),
                                    ] else ...[
                                      if (statusMsg.isNotEmpty) ...[
                                        Row(
                                          children: [
                                            const Icon(Icons.warning_amber_rounded, color: Color(0xFFEBA0AC), size: 15),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                statusMsg,
                                                style: const TextStyle(color: Color(0xFFEBA0AC), fontSize: 11),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                      const Text(
                                        "Нажмите кнопку и сделайте жест. Запись начнется сразу и завершится через 5 секунд или при нажатии кнопки 'Завершить'.",
                                        style: TextStyle(color: Color(0xFF6C6E85), fontSize: 11),
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                    ElevatedButton.icon(
                                      onPressed: liveManager.isConnected
                                          ? () {
                                              // Reset done flag so next recording starts fresh
                                              if (hasRecorded) {
                                                setModalState(() {
                                                  capturedTemplate = [];
                                                });
                                                liveManager.clearRecordedSamples();
                                              }
                                              liveManager.startRecordingGesture();
                                            }
                                          : null,
                                      icon: Icon(hasRecorded ? Icons.refresh_rounded : Icons.fiber_manual_record_rounded),
                                      label: Text(hasRecorded ? "Перезаписать жест" : "Начать запись (5 сек)"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: hasRecorded ? const Color(0xFF232035) : const Color(0xFF2A1C2B),
                                        foregroundColor: hasRecorded ? Colors.white : const Color(0xFFCBA6F7),
                                        disabledBackgroundColor: const Color(0xFF181622),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                        const SizedBox(height: 16),

                        // 3. Action Type Dropdown
                        const Text(
                          "ДЕЙСТВИЕ",
                          style: TextStyle(color: Color(0xFF6C6E85), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: actionType,
                          dropdownColor: const Color(0xFF0F0F17),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF0B0A11),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Color(0xFF232035)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: "get",
                              child: Text("Отправить HTTP GET запрос", style: TextStyle(color: Colors.white, fontSize: 13)),
                            ),
                            DropdownMenuItem(
                              value: "post",
                              child: Text("Отправить HTTP POST запрос (JSON)", style: TextStyle(color: Colors.white, fontSize: 13)),
                            ),
                            DropdownMenuItem(
                              value: "ble_command",
                              child: Text("Отправить BLE команду на кольцо", style: TextStyle(color: Colors.white, fontSize: 13)),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                actionType = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // 4. Payload input
                        Text(
                          actionType == "ble_command" ? "HEX КОМАНДА КОЛЬЦА" : "URL АДРЕС ВЕБХУКА",
                          style: const TextStyle(color: Color(0xFF6C6E85), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Fira Code'),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF0B0A11),
                            hintText: actionType == "ble_command"
                                ? "Например, a104 или a102 (нечетные команды, авторасчет CRC)"
                                : "Например, https://api.smart-home.ru/v1/devices/toggle",
                            hintStyle: const TextStyle(color: Color(0xFF5D5A75), fontSize: 12, fontFamily: 'sans-serif'),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Color(0xFF232035)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Color(0xFF74C7EC)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return "Поле обязательно для заполнения";
                            }
                            if (actionType != "ble_command") {
                              final urlStr = value.trim().toLowerCase();
                              if (!urlStr.startsWith("http://") && !urlStr.startsWith("https://")) {
                                return "Адрес должен начинаться с http:// или https://";
                              }
                            }
                            return null;
                          },
                          onSaved: (val) => payload = val!.trim(),
                        ),

                        // 5. POST body JSON textfield
                        if (actionType == "post") ...[
                          const SizedBox(height: 16),
                          const Text(
                            "JSON ДАННЫЕ POST-ЗАПРОСА (ОПЦИОНАЛЬНО)",
                            style: TextStyle(color: Color(0xFF6C6E85), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            maxLines: 4,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Fira Code'),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFF0B0A11),
                              hintText: '{\n  "state": "toggle",\n  "brightness": 100\n}',
                              hintStyle: const TextStyle(color: Color(0xFF5D5A75), fontSize: 12, fontFamily: 'sans-serif'),
                              contentPadding: const EdgeInsets.all(12),
                              enabledBorder: OutlineInputBorder(
                                borderSide: const BorderSide(color: Color(0xFF232035)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(color: Color(0xFF74C7EC)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (value) {
                              if (value != null && value.trim().isNotEmpty) {
                                try {
                                  jsonDecode(value);
                                } catch (e) {
                                  return "Некорректный JSON: $e";
                                }
                              }
                              return null;
                            },
                            onSaved: (val) => postData = val ?? "",
                          ),
                        ], // closes collection-if
                      ], // closes inner Column children
                    ), // closes inner Column
                  ), // closes SingleChildScrollView
                ), // closes Expanded
                const SizedBox(height: 16),

                      // Submit Button
                      ElevatedButton(
                        onPressed: () {
                          if (triggerType == "custom" && capturedTemplate.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: Color(0xFF3A1C1C),
                                content: Text(
                                  "Вы выбрали пользовательский жест. Сначала запишите движение кольца!",
                                  style: TextStyle(color: Color(0xFFF38BA8), fontWeight: FontWeight.bold),
                                ),
                              ),
                            );
                            return;
                          }

                          if (formKey.currentState!.validate()) {
                            formKey.currentState!.save();
                            final newRule = GestureRule(
                              id: DateTime.now().millisecondsSinceEpoch.toString(),
                              name: name,
                              triggerType: triggerType,
                              actionType: actionType,
                              payload: payload,
                              postData: postData.isNotEmpty ? postData : null,
                              template: triggerType == "custom" ? capturedTemplate : null,
                            );
                            manager.addGestureRule(newRule);
                            Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF74C7EC),
                          foregroundColor: const Color(0xFF0B0A11),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text(
                          "Создать правило жеста",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      if (manager.isRecordingGesture) {
        manager.stopRecordingGesture();
      }
      manager.clearRecordedSamples();
    });
  }
}
