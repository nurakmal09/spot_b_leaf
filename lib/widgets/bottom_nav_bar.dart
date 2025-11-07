import 'package:flutter/material.dart';
import '../pages/dashboard_page.dart';
import '../pages/treatment_page.dart';
import '../pages/my_garden_page.dart';
import '../pages/report_page.dart';
import '../pages/scanner_page.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
  });

  void _onItemTapped(BuildContext context, int index) {
    // Don't navigate if already on the same page
    if (index == currentIndex) return;

    if (index == 2) {
      // Center camera button action - Open Scanner
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ScannerPage()),
      );
      return;
    }

    // Navigate to the appropriate page
    Widget page;
    switch (index) {
      case 0:
        page = const DashboardPage();
        break;
      case 1:
        page = const TreatmentPage();
        break;
      case 3:
        page = const MyGardenPage();
        break;
      case 4:
        page = const ReportPage();
        break;
      default:
        return;
    }

    // Replace current route with new page
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.2),
                spreadRadius: 1,
                blurRadius: 10,
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: (index) => _onItemTapped(context, index),
            selectedItemColor: Colors.green[600],
            unselectedItemColor: Colors.grey,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            backgroundColor: Colors.white,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.medical_services),
                label: 'Treatment',
              ),
              BottomNavigationBarItem(
                icon: SizedBox(height: 24), // Placeholder for center button
                label: '',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.yard),
                label: 'My Garden',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.description),
                label: 'Report',
              ),
            ],
          ),
        ),
        // Floating center camera button
        Positioned(
          top: -25,
          child: GestureDetector(
            onTap: () => _onItemTapped(context, 2),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.teal[400],
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withValues(alpha: 0.4),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
