import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math' as math;
import '../auth.dart';
import '../widgets/bottom_nav_bar.dart';
import '../services/weather_service.dart';
import '../services/location_service.dart';
import 'settings_page.dart';


class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});


  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final Auth _auth = Auth();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final WeatherService _weatherService = WeatherService();
  final LocationService _locationService = LocationService();
  
  StreamSubscription<QuerySnapshot>? _plantsSubscription;
  
  DateTime selectedDate = DateTime.now();
  
  // Statistics from Firestore
  int totalPlants = 0;
  int healthyPlants = 0;
  int diseasedPlants = 0;
  
  // Weather data
  Map<String, dynamic>? currentWeather;
  List<Map<String, dynamic>>? forecast;
  double? uvIndex;
  String? weatherRecommendation;
  bool isLoadingWeather = true;
  Position? currentPosition;

  @override
  void initState() {
    super.initState();
    _loadPlantsFromFirestore();
    _loadWeatherData();
  }

  @override
  void dispose() {
    _plantsSubscription?.cancel();
    super.dispose();
  }

  // Load all plants from Firestore and calculate statistics
  void _loadPlantsFromFirestore() {
    final user = _auth.currentUser;
    if (user == null) return;

    _plantsSubscription = _firestore
        .collection('plant')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        // Reset counts
        totalPlants = 0;
        healthyPlants = 0;
        diseasedPlants = 0;

        // Count plants by status
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final statusList = data['status'] as List<dynamic>?;
          
          totalPlants++;
          
          if (statusList != null && statusList.isNotEmpty) {
            final statusStr = statusList[0].toString().toLowerCase();
            if (statusStr == 'diseased') {
              diseasedPlants++;
            } else if (statusStr == 'healthy') {
              healthyPlants++;
            } else {
              // Warning counts as healthy for now
              healthyPlants++;
            }
          } else {
            // If no status specified, count as healthy
            healthyPlants++;
          }
        }
      });
    });
  }

  // Load weather data from API
  Future<void> _loadWeatherData() async {
    if (!mounted) return;
    
    setState(() {
      isLoadingWeather = true;
    });

    try {
      // Get current location
      final position = await _locationService.getCurrentLocation();
      
      if (position == null) {
        if (!mounted) return;
        setState(() {
          isLoadingWeather = false;
        });
        return;
      }

      currentPosition = position;

      // Fetch weather data
      final weatherData = await _weatherService.getCurrentWeather(
        position.latitude,
        position.longitude,
      );

      if (weatherData != null) {
        currentWeather = _weatherService.parseWeatherData(weatherData);
      }

      // Fetch forecast
      final forecastData = await _weatherService.getForecast(
        position.latitude,
        position.longitude,
      );

      if (forecastData != null) {
        forecast = _weatherService.parseForecastData(forecastData);
      }

      // Fetch UV index
      final uvData = await _weatherService.getUVIndex(
        position.latitude,
        position.longitude,
      );

      if (uvData != null) {
        uvIndex = uvData['uvi'];
      }

      // Generate agricultural recommendation
      if (currentWeather != null) {
        weatherRecommendation = _weatherService.getAgricultureRecommendation(
          currentWeather!,
          uvIndex,
        );
      }

      if (!mounted) return;
      setState(() {
        isLoadingWeather = false;
      });
    } catch (e) {
      print('Error loading weather: $e');
      if (!mounted) return;
      setState(() {
        isLoadingWeather = false;
      });
    }
  }

  // Load weather with default location (for testing)
  Future<void> _loadWeatherWithDefaultLocation() async {
    setState(() {
      isLoadingWeather = true;
    });

    try {
      // Use Kuala Lumpur as default location
      const double defaultLat = 3.1319;
      const double defaultLon = 101.6841;

      // Fetch weather data
      final weatherData = await _weatherService.getCurrentWeather(
        defaultLat,
        defaultLon,
      );

      if (weatherData != null) {
        currentWeather = _weatherService.parseWeatherData(weatherData);
      }

      // Fetch forecast
      final forecastData = await _weatherService.getForecast(
        defaultLat,
        defaultLon,
      );

      if (forecastData != null) {
        forecast = _weatherService.parseForecastData(forecastData);
      }

      // Fetch UV index
      final uvData = await _weatherService.getUVIndex(
        defaultLat,
        defaultLon,
      );

      if (uvData != null) {
        uvIndex = uvData['uvi'];
      }

      // Generate agricultural recommendation
      if (currentWeather != null) {
        weatherRecommendation = _weatherService.getAgricultureRecommendation(
          currentWeather!,
          uvIndex,
        );
      }

      setState(() {
        isLoadingWeather = false;
      });
    } catch (e) {
      print('Error loading weather: $e');
      setState(() {
        isLoadingWeather = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[600]!, Colors.green[500]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Farm Dashboard',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Real-time monitoring',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.settings, color: Colors.white),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SettingsPage(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Selector
                    _buildDateSelector(),
                    const SizedBox(height: 20),

                    // Weather Card
                    _buildWeatherCard(),
                    const SizedBox(height: 20),

                    // Metrics Cards
                    _buildMetricsCards(),
                    const SizedBox(height: 24),

                    // Health Distribution
                    _buildHealthDistribution(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 0),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                selectedDate = selectedDate.subtract(const Duration(days: 1));
              });
            },
          ),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                '${_getMonthName(selectedDate.month)} ${selectedDate.day}, ${selectedDate.year}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                selectedDate = selectedDate.add(const Duration(days: 1));
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherCard() {
    if (isLoadingWeather) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue[500]!, Colors.blue[400]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.3),
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (currentWeather == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue[500]!, Colors.blue[400]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.3),
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            const Icon(Icons.location_off, color: Colors.white, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Unable to load weather',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Please enable location services in your device settings',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _loadWeatherData,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue[600],
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    await Geolocator.openLocationSettings();
                  },
                  icon: const Icon(Icons.settings, size: 18),
                  label: const Text('Settings'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.9),
                    foregroundColor: Colors.blue[600],
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'OR',
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadWeatherWithDefaultLocation,
              icon: const Icon(Icons.location_city, size: 18),
              label: const Text('Use Demo Location (KL)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[500]!, Colors.blue[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.3),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current weather
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentWeather!['cityName'] ?? 'Current Location',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentWeather!['description'].toString().toUpperCase(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${currentWeather!['temperature'].toStringAsFixed(1)}°C',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Feels like ${currentWeather!['feelsLike'].toStringAsFixed(1)}°C',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                _getWeatherIcon(currentWeather!['main']),
                color: Colors.white,
                size: 72,
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Weather details grid
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildWeatherDetail(Icons.water_drop, '${currentWeather!['humidity']}%', 'Humidity'),
                    _buildWeatherDetail(Icons.air, '${currentWeather!['windSpeed'].toStringAsFixed(1)} m/s', 'Wind'),
                    if (uvIndex != null)
                      _buildWeatherDetail(Icons.wb_sunny, uvIndex!.toStringAsFixed(1), 'UV Index'),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildWeatherDetail(Icons.umbrella, '${currentWeather!['rain'].toStringAsFixed(1)} mm', 'Rain'),
                    _buildWeatherDetail(Icons.compress, '${currentWeather!['pressure']} hPa', 'Pressure'),
                    _buildWeatherDetail(Icons.cloud, '${currentWeather!['cloudiness']}%', 'Clouds'),
                  ],
                ),
              ],
            ),
          ),
          
          // Agricultural recommendation
          if (weatherRecommendation != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      weatherRecommendation!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // 3-day forecast
          if (forecast != null && forecast!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              '3-Day Forecast',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: forecast!.take(3).map((day) {
                return _buildForecastDay(day);
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getWeatherIcon(String condition) {
    switch (condition.toLowerCase()) {
      case 'clear':
        return Icons.wb_sunny;
      case 'clouds':
        return Icons.cloud;
      case 'rain':
      case 'drizzle':
        return Icons.water_drop;
      case 'thunderstorm':
        return Icons.flash_on;
      case 'snow':
        return Icons.ac_unit;
      case 'mist':
      case 'fog':
        return Icons.cloud_queue;
      default:
        return Icons.wb_cloudy;
    }
  }

  Widget _buildForecastDay(Map<String, dynamic> day) {
    final date = day['date'] as DateTime;
    final dayName = _getDayName(date.weekday);
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            dayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Icon(
            _getWeatherIcon(day['description']),
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            '${day['tempMax'].toStringAsFixed(0)}°',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '${day['tempMin'].toStringAsFixed(0)}°',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _getDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  Widget _buildWeatherDetail(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            icon: Icons.eco,
            color: Colors.green,
            value: totalPlants.toString(),
            label: 'Total Plants',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            icon: Icons.check_circle,
            color: Colors.green,
            value: healthyPlants.toString(),
            label: 'Healthy',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            icon: Icons.warning,
            color: Colors.red,
            value: diseasedPlants.toString(),
            label: 'Diseased',
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHealthDistribution() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Health Distribution',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: SizedBox(
              height: 200,
              width: 200,
              child: CustomPaint(
                painter: DonutChartPainter(
                  healthy: healthyPlants,
                  diseased: diseasedPlants,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLegendItem(
                Colors.green,
                'Healthy',
                totalPlants > 0 
                    ? '${((healthyPlants / totalPlants) * 100).toStringAsFixed(0)}%'
                    : '0%',
              ),
              _buildLegendItem(
                Colors.red,
                'Diseased',
                totalPlants > 0
                    ? '${((diseasedPlants / totalPlants) * 100).toStringAsFixed(0)}%'
                    : '0%',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, String percentage) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              percentage,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
}

// Custom Painter for Donut Chart
class DonutChartPainter extends CustomPainter {
  final int healthy;
  final int diseased;

  DonutChartPainter({required this.healthy, required this.diseased});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final strokeWidth = 40.0;

    final total = healthy + diseased;
    final healthyAngle = (healthy / total) * 2 * math.pi;
    final diseasedAngle = (diseased / total) * 2 * math.pi;

    // Draw healthy segment (green)
    final healthyPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      -math.pi / 2,
      healthyAngle,
      false,
      healthyPaint,
    );

    // Draw diseased segment (red)
    final diseasedPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      -math.pi / 2 + healthyAngle,
      diseasedAngle,
      false,
      diseasedPaint,
    );

    // Draw light gray segment (gap filler)
    final gapPaint = Paint()
      ..color = Colors.grey[200]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      -math.pi / 2 + healthyAngle + diseasedAngle,
      2 * math.pi - healthyAngle - diseasedAngle,
      false,
      gapPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
