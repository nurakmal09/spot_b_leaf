import 'package:flutter/material.dart';
import 'dart:ui';
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
    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom,
      ),
      child: Container(
        height: 70,
        margin: const EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 20,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.15),
              spreadRadius: 0,
              blurRadius: 25,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.08),
              spreadRadius: 0,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color.fromARGB(255, 99, 144, 83).withValues(alpha: 0.7),
                    const Color.fromARGB(255, 23, 147, 33).withValues(alpha: 0.9),
                  ],
                ),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 0.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(
                      context: context,
                      icon: Icons.home,
                      label: 'Home',
                      index: 0,
                      isSelected: currentIndex == 0,
                    ),
                    _buildNavItem(
                      context: context,
                      icon: Icons.medical_services,
                      label: 'Treatment',
                      index: 1,
                      isSelected: currentIndex == 1,
                    ),
                    _buildCenterButton(context),
                    _buildNavItem(
                      context: context,
                      icon: Icons.yard,
                      label: 'My Garden',
                      index: 3,
                      isSelected: currentIndex == 3,
                    ),
                    _buildNavItem(
                      context: context,
                      icon: Icons.description,
                      label: 'Report',
                      index: 4,
                      isSelected: currentIndex == 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required int index,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => _onItemTapped(context, index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 26,
              decoration: BoxDecoration(
                color: isSelected 
                    ? const Color.fromARGB(255, 9, 91, 8).withValues(alpha: 0.8)
                    : const Color.fromARGB(0, 78, 76, 76),
                borderRadius: BorderRadius.circular(14),
                border: isSelected 
                    ? null
                    : Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 0.5,
                      ),
              ),
              child: Icon(
                icon,
                color: isSelected 
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.6),
                size: 20,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected 
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _onItemTapped(context, 2),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color.fromARGB(255, 17, 95, 17),
              const Color.fromARGB(255, 80, 139, 80).withValues(alpha: 0.7),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFAFE1AF).withValues(alpha: 0.3),
              spreadRadius: 0,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.camera_alt,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}
