import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ring_ble_manager.dart';
import 'scope_chart.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({Key? key}) : super(key: key);

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  int _selectedTab = 0;
  final TextEditingController _cmdController = TextEditingController(text: "SOS");
  final TextEditingController _gesturePayloadController = TextEditingController();
  final ScrollController _logScrollController = ScrollController();

  @override
  void dispose() {
    _cmdController.dispose();
    _gesturePayloadController.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

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
  Widget build(BuildContext context) {
    final manager = Provider.of<RingBleManager>(context);

    // Auto-scroll logs when Logs tab is active
    if (_selectedTab == 3) {
      _scrollToBottom();
    }

    // Sync gesture payload controller value if different
    if (_gesturePayloadController.text != manager.assignedActionPayload) {
      _gesturePayloadController.text = manager.assignedActionPayload;
    }

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
            _buildBatteryBadge(manager),
          ],
        ),
      ),
      body: IndexedStack(
        index: _selectedTab,
        children: [
          _buildScopeTab(manager),
          _buildControlsTab(manager),
          _buildDevicesTab(manager),
          _buildLogsTab(manager),
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

  Widget _buildBatteryBadge(RingBleManager manager) {
    if (!manager.isConnected) return const SizedBox.shrink();
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
            manager.batteryInfo,
            style: const TextStyle(
              color: Color(0xFFA6E3A1),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: SCOPE ---
  Widget _buildScopeTab(RingBleManager manager) {
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

  // --- TAB 2: CONTROLS ---
  Widget _buildControlsTab(RingBleManager manager) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Controls instruction card
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

            // Command input panel
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

                  // Actions row
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: manager.isConnected
                              ? () => manager.sendMorse(_cmdController.text)
                              : null,
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
                          onPressed: manager.isConnected
                              ? () => manager.writeCommand(_cmdController.text)
                              : null,
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

            // Live Update control actions
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
                    onPressed: manager.isConnected
                        ? () => manager.writeCommand("a104")
                        : null,
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
                    onPressed: manager.isConnected
                        ? () => manager.writeCommand("a102")
                        : null,
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
                    onPressed: manager.isConnected
                        ? () => manager.writeCommand("03")
                        : null,
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

            // Gesture Triggers setup card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: manager.gestureTriggeredAlert ? const Color(0xFF2E1B2D) : const Color(0xFF13111C),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: manager.gestureTriggeredAlert ? const Color(0xFFF38BA8) : const Color(0xFF232035),
                  width: manager.gestureTriggeredAlert ? 2 : 1,
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
                      if (manager.gestureTriggeredAlert)
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
                        value: manager.gestureActionsEnabled,
                        onChanged: (val) {
                          manager.saveGestureSettings(enabled: val);
                        },
                        activeColor: const Color(0xFF74C7EC),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Sensitivity Threshold: ${manager.gestureThreshold.toStringAsFixed(0)}",
                    style: const TextStyle(color: Color(0xFF9E9BAC), fontSize: 12),
                  ),
                  Slider(
                    value: manager.gestureThreshold,
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
                    value: manager.assignedActionType,
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
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF0B0A11),
                      hintText: manager.assignedActionType == "webhook"
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
  }

  // --- TAB 3: DEVICES ---
  Widget _buildDevicesTab(RingBleManager manager) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Device Scanner Header
          Row(
            children: [
              const Text(
                "BLE SCANNER",
                style: TextStyle(color: Color(0xFF74C7EC), fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (manager.isScanning)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF74C7EC)),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Scan Trigger Button
          ElevatedButton.icon(
            onPressed: manager.isScanning ? manager.stopManualScan : manager.startManualScan,
            icon: Icon(manager.isScanning ? Icons.stop_rounded : Icons.search_rounded),
            label: Text(manager.isScanning ? "Stop Scanning" : "Scan for Devices"),
            style: ElevatedButton.styleFrom(
              backgroundColor: manager.isScanning ? const Color(0xFFF38BA8) : const Color(0xFF74C7EC),
              foregroundColor: const Color(0xFF0B0A11),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),

          // Scanning results list
          Expanded(
            child: manager.scanResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bluetooth_disabled_rounded, size: 48, color: const Color(0xFF5D5A75).withOpacity(0.5)),
                        const SizedBox(height: 12),
                        const Text(
                          "No smart rings scanned yet.\nClick Scan to discover surrounding devices.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF5D5A75), fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: manager.scanResults.length,
                    itemBuilder: (context, idx) {
                      final scanResult = manager.scanResults[idx];
                      final device = scanResult.device;
                      final name = device.platformName.isEmpty ? "[Unknown Device]" : device.platformName;
                      final id = device.remoteId.str;
                      final rssi = scanResult.rssi;
                      final isCurrent = manager.connectedDevice?.remoteId == device.remoteId;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isCurrent ? const Color(0xFF152A22) : const Color(0xFF13111C),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCurrent ? const Color(0xFF225741) : const Color(0xFF232035),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.bluetooth_rounded,
                              color: isCurrent ? const Color(0xFFA6E3A1) : const Color(0xFF74C7EC),
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
                                    onPressed: isCurrent
                                        ? manager.disconnectDevice
                                        : () => manager.connectToDevice(device),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isCurrent ? const Color(0xFFF38BA8) : const Color(0xFF2A283E),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: Text(
                                      isCurrent ? "Disconnect" : "Connect",
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
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
  }

  // --- TAB 4: LOGS ---
  Widget _buildLogsTab(RingBleManager manager) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logs header
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

          // Logs Terminal
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
                itemCount: manager.logs.length,
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
  }
}
