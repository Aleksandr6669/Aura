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
  final TextEditingController _cmdController = TextEditingController(text: "SOS");
  final ScrollController _logScrollController = ScrollController();

  @override
  void dispose() {
    _cmdController.dispose();
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

    // Auto-scroll logs to bottom when a new entry is added
    _scrollToBottom();

    Color statusColor = const Color(0xFFF38BA8); // Red
    if (manager.connectionStatus == "Connected") {
      statusColor = const Color(0xFFA6E3A1); // Green
    } else if (manager.connectionStatus.contains("Scan") || manager.connectionStatus == "Connecting...") {
      statusColor = const Color(0xFFF9E2AF); // Yellow
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F17),
      body: Column(
        children: [
          // Header Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            color: const Color(0xFF161622),
            child: Row(
              children: [
                const Text(
                  "🏃 AccelScope - Smart Ring Dashboard",
                  style: TextStyle(
                    color: Color(0xFF74C7EC),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  "🔋 Battery: ${manager.batteryInfo}",
                  style: const TextStyle(color: Color(0xFFE0E0ED), fontSize: 13),
                ),
                const SizedBox(width: 25),
                // Status dot indicator
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  manager.connectionStatus,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Main Workspace
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: Row(
                children: [
                  // Left Pane: Value cards and controls
                  SizedBox(
                    width: 320,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Stat Readouts
                        _buildStatCard("X-AXIS (ROLL)", manager.lastX, const Color(0xFFF38BA8)),
                        _buildStatCard("Y-AXIS (PITCH)", manager.lastY, const Color(0xFFA6E3A1)),
                        _buildStatCard("Z-AXIS (VERTICAL)", manager.lastZ, const Color(0xFF89B4FA)),
                        _buildStatCard("VECTOR MAGNITUDE", manager.lastMag, const Color(0xFFFAB387)),

                        const SizedBox(height: 5),

                        // System Controls Panel
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: const Color(0xFF161622),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    "SYSTEM CONTROLS & COMMANDS",
                                    style: TextStyle(
                                      color: Color(0xFF74C7EC),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // Text Input Entry
                                  TextField(
                                    controller: _cmdController,
                                    style: const TextStyle(color: Color(0xFFE0E0ED), fontSize: 13),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: const Color(0xFF0F0F17),
                                      hintText: "Enter command or Morse",
                                      hintStyle: const TextStyle(color: Color(0xFF6C6E85)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: const BorderSide(color: Color(0xFF2B2B3D)),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: const BorderSide(color: Color(0xFF74C7EC)),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Action Buttons Row 1
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: manager.isConnected
                                              ? () => manager.sendMorse(_cmdController.text)
                                              : null,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF2B2B3D),
                                            disabledBackgroundColor: const Color(0xFF161622),
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                          ),
                                          child: const Text("💬 Morse", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: manager.isConnected
                                              ? () => manager.writeCommand(_cmdController.text)
                                              : null,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF2B2B3D),
                                            disabledBackgroundColor: const Color(0xFF161622),
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                          ),
                                          child: const Text("⚙ Send HEX", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),

                                  // Action Buttons Row 2
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: manager.isConnected
                                              ? () => manager.writeCommand("03")
                                              : null,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF2B2B3D),
                                            disabledBackgroundColor: const Color(0xFF161622),
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                          ),
                                          child: const Text("🔋 Battery Info", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () => manager.clearScope(),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF2B2B3D),
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                          ),
                                          child: const Text("🧹 Clear Scope", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Live data control buttons
                                  ElevatedButton(
                                    onPressed: manager.isConnected
                                        ? () => manager.writeCommand("a104")
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF74C7EC),
                                      disabledBackgroundColor: const Color(0xFF0F0F17),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    ),
                                    child: const Text("▶ Enable Live Data (a104)", style: TextStyle(color: Color(0xFF0F0F17), fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(height: 6),
                                  ElevatedButton(
                                    onPressed: manager.isConnected
                                        ? () => manager.writeCommand("a102")
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFF38BA8),
                                      disabledBackgroundColor: const Color(0xFF0F0F17),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    ),
                                    child: const Text("■ Stop Live Data (a102)", style: TextStyle(color: Color(0xFF0F0F17), fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(height: 12),

                                  // Filter switch
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: manager.filterEnabled,
                                        onChanged: (val) => manager.toggleFilter(val ?? true),
                                        activeColor: const Color(0xFF74C7EC),
                                        checkColor: const Color(0xFF0F0F17),
                                      ),
                                      const Expanded(
                                        child: Text(
                                          "Enable Low-Pass Filter",
                                          style: TextStyle(color: Color(0xFFE0E0ED), fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Right Pane: Scope Chart
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF161622),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                            child: Row(
                              children: [
                                const Text(
                                  "REAL-TIME ACCELEROMETER OSCILLOSCOPE",
                                  style: TextStyle(
                                    color: Color(0xFF74C7EC),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                _buildLegendItem("X", const Color(0xFFF38BA8)),
                                _buildLegendItem("Y", const Color(0xFFA6E3A1)),
                                _buildLegendItem("Z", const Color(0xFF89B4FA)),
                                _buildLegendItem("Mag", const Color(0xFFFAB387)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0C0D12),
                                border: Border.all(color: const Color(0xFF2B2B3D)),
                              ),
                              child: ScopeChart(
                                historyX: manager.historyX,
                                historyY: manager.historyY,
                                historyZ: manager.historyZ,
                                historyMag: manager.historyMag,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Bar: Terminal Console logs
          Container(
            height: 120,
            margin: const EdgeInsets.only(left: 15, right: 15, bottom: 15),
            decoration: BoxDecoration(
              color: const Color(0xFF09090E),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  color: const Color(0xFF11111A),
                  child: const Text(
                    "📟 Activity Console & System Log",
                    style: TextStyle(color: Color(0xFF6C6E85), fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: _logScrollController,
                    padding: const EdgeInsets.all(10),
                    itemCount: manager.logs.length,
                    itemBuilder: (context, idx) {
                      final log = manager.logs[idx];
                      Color tagColor = const Color(0xFF89B4FA); // Blue info
                      if (log.tag == 'success') tagColor = const Color(0xFFA6E3A1);
                      if (log.tag == 'warn') tagColor = const Color(0xFFF9E2AF);
                      if (log.tag == 'error') tagColor = const Color(0xFFF38BA8);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(fontFamily: 'Fira Code', fontSize: 11),
                            children: [
                              TextSpan(text: "[${log.timestamp}] ", style: const TextStyle(color: Color(0xFF6C6E85))),
                              TextSpan(text: log.text, style: TextStyle(color: tagColor)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, double value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        color: Color(0xFF161622),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6C6E85),
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Container(height: 3, color: color),
          const SizedBox(height: 4),
          Text(
            value.toStringAsFixed(1),
            textAlign: TextAlign.right,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontFamily: 'Fira Code',
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Color(0xFFE0E0ED), fontSize: 11),
          ),
        ],
      ),
    );
  }
}
