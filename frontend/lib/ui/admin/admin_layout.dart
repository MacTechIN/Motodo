import 'package:flutter/material.dart';
import '../../core/design_system.dart';
import 'admin_dashboard.dart';
import 'pulse_view.dart';
import 'timeline_view.dart';

class AdminLayout extends StatefulWidget {
  const AdminLayout({super.key});

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const AdminDashboard(), // The existing dashboard with metrics
    const PulseView(),      // New Team Pulse view
    const TimelineView(),   // New Activity Timeline
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: const <NavigationRailDestination>[
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.monitor_heart_outlined),
                selectedIcon: Icon(Icons.monitor_heart),
                label: Text('Pulse'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.timeline),
                selectedIcon: Icon(Icons.timeline),
                label: Text('Timeline'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: _pages[_selectedIndex],
          ),
        ],
      ),
    );
  }
}
