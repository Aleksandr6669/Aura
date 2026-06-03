import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ring_ble_manager.dart';
import 'scope_chart.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({Key? key}) : super(key: key);

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  int _selectedTab = 0;

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
          // Tab 2: Controls (uses selector to ignore accelerometer stream)
          const ControlsTabContent(),
          // Tab 3: Devices (uses selector to ignore accelerometer stream)
          const DevicesTabContent(),
          // Tab 4: Logs (uses selector for logs updates)
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
              label: "Scope",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.tune_rounded),
              activeIcon: Icon(Icons.tune_rounded),
              label: "Controls",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bluetooth_searching_rounded),
              activeIcon: Icon(Icons.bluetooth_connected_rounded),
              label: "Devices",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.terminal_outlined),
              activeIcon: Icon(Icons.terminal_rounded),
              label: "Logs",
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
  const ScopeTabContent({Key? key}) : super(key: key);

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
                    manager.isConnected ? "CONNECTED" : "DISCONNECTED",
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
                _buildValueCard("X-Axis (Roll)", manager.lastX, const Color(0xFFF38BA8)),
                _buildValueCard("Y-Axis (Pitch)", manager.lastY, const Color(0xFFA6E3A1)),
                _buildValueCard("Z-Axis (Yaw)", manager.lastZ, const Color(0xFF89B4FA)),
                _buildValueCard("Magnitude", manager.lastMag, const Color(0xFFFAB387)),
              ],
            ),
            const SizedBox(height: 16),

            // Fast controls
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => manager.clearScope(),
                    icon: const Icon(Icons.clear_all_rounded, size: 18),
                    label: const Text("Clear Scope"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF201D30),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF13111C),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF232035)),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: manager.filterEnabled,
                        onChanged: (val) => manager.toggleFilter(val ?? true),
                        activeColor: const Color(0xFF74C7EC),
                      ),
                      const Text(
                        "Filter",
                        style: TextStyle(color: Color(0xFF9E9BAC), fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),
              ],
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
  const ControlsTabContent({Key? key}) : super(key: key);

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
    return Selector<RingBleManager, (bool, bool, double, String, String, bool, bool, double, bool)>(
      selector: (_, m) => (
        m.isConnected,
        m.gestureActionsEnabled,
        m.gestureThreshold,
        m.assignedActionType,
        m.assignedActionPayload,
        m.gestureTriggeredAlert,
        m.wakeGestureEnabled,
        m.wakeGestureThreshold,
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
        final wakeGestureThreshold = data.$8;
        final wakeGestureActive = data.$9;

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
                const SizedBox(height: 16),

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
                            "WAKE GESTURE (ДВОЙНОЙ ТАП)",
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
                        "Двойной тап по кольцу включает/выключает прослушивание жестов — без огней.",
                        style: TextStyle(color: Color(0xFF6C6E85), fontSize: 11),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Включить wake-жест",
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
                            activeColor: const Color(0xFF89B4FA),
                          ),
                        ],
                      ),
                      if (wakeGestureEnabled) ...[
                        const SizedBox(height: 8),
                        Text(
                          "Чувствительность: ${wakeGestureThreshold.toStringAsFixed(0)}",
                          style: const TextStyle(color: Color(0xFF9E9BAC), fontSize: 12),
                        ),
                        Slider(
                          value: wakeGestureThreshold,
                          min: 800.0,
                          max: 2500.0,
                          divisions: 17,
                          activeColor: const Color(0xFF89B4FA),
                          inactiveColor: const Color(0xFF232035),
                          onChanged: (val) {
                            manager.saveGestureSettings(wakeThreshold: val);
                          },
                        ),
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
                                      ? "Прослушивание жестов: АКТИВНО — дважды тапни чтобы выключить"
                                      : "Прослушивание жестов: ВЫКЛЮЧЕНО — дважды тапни чтобы включить",
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
                            activeColor: const Color(0xFF74C7EC),
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
                        value: assignedActionType,
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
  const DevicesTabContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<RingBleManager>(context, listen: false);

    // Rebuilds ONLY when scanned devices, scanning state, showNamelessSetting, or connection state changes
    return Selector<RingBleManager, (List<ScanResult>, bool, bool, BluetoothDevice?)>(
      selector: (_, m) {
        // Filter out the connected device from scanner results to avoid duplication
        final filtered = m.scanResults.where((r) {
          if (m.connectedDevice != null && r.device.remoteId == m.connectedDevice!.remoteId) {
            return false;
          }
          if (m.showNamelessDevices) return true;
          return r.device.platformName.trim().isNotEmpty || r.advertisementData.advName.trim().isNotEmpty;
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
                    "BLE SCANNER",
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
                label: Text(isScanning ? "Stop Scanning" : "Scan for Devices"),
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
                        "Show unnamed BLE devices",
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
                  "MY DEVICE (CONNECTED / CONNECTING)",
                  style: TextStyle(color: Color(0xFF6C6E85), fontSize: 10, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildConnectedDeviceCard(manager, connectedDevice),
                const SizedBox(height: 16),
                const Text(
                  "AVAILABLE DEVICES",
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
                              "No matching BLE devices scanned yet.\nClick Scan to discover surrounding devices.",
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
                                const Icon(
                                  Icons.bluetooth_rounded,
                                  color: Color(0xFF74C7EC),
                                  size: 24,
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
                                        style: const TextStyle(color: Color(0xFF6C6E85), fontSize: 11),
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
                                        color: rssi > -70 ? const Color(0xFFA6E3A1) : const Color(0xFFFAB387),
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
                                          backgroundColor: const Color(0xFF2A283E),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: const Text(
                                          "Connect",
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

  Widget _buildConnectedDeviceCard(RingBleManager manager, BluetoothDevice device) {
    final name = device.platformName.isEmpty ? "[Saved Device / Smart Ring]" : device.platformName;
    final id = device.remoteId.str;
    final isConnecting = manager.connectionStatus == "Connecting...";

    return Container(
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
                    "Connecting...",
                    style: TextStyle(color: Color(0xFFF9E2AF), fontSize: 11, fontWeight: FontWeight.bold),
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
              "Disconnect",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// TAB 4: LOGS TAB (Optimized to ignore high-frequency stream)
// ==========================================
class LogsTabContent extends StatefulWidget {
  const LogsTabContent({Key? key}) : super(key: key);

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
                    "SYSTEM CONSOLE LOGS",
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
                    tooltip: "Clear Logs",
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
