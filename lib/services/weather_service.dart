import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class WeatherService {
  static const String _apiKey = '1d9f67d0424565d80bd3360a24cf5832';
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5';

  // Get current weather by coordinates
  Future<Map<String, dynamic>?> getCurrentWeather(double lat, double lon) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/weather?lat=$lat&lon=$lon&appid=$_apiKey&units=metric',
      );
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
        } else {
        debugPrint('Error fetching weather: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching weather: $e');
      return null;
    }
  }

  // Get 3-day forecast
  Future<Map<String, dynamic>?> getForecast(double lat, double lon) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/forecast?lat=$lat&lon=$lon&appid=$_apiKey&units=metric&cnt=24', // 24 data points (3 days, 8 per day)
      );
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
        } else {
        debugPrint('Error fetching forecast: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching forecast: $e');
      return null;
    }
  }

  // Get air quality and UV data
  Future<Map<String, dynamic>?> getAirQuality(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'http://api.openweathermap.org/data/2.5/air_pollution?lat=$lat&lon=$lon&appid=$_apiKey',
      );
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching air quality: $e');
      return null;
    }
  }

  // Parse weather data for display
  Map<String, dynamic> parseWeatherData(Map<String, dynamic> data) {
    return {
      'temperature': data['main']['temp'].toDouble(),
      'feelsLike': data['main']['feels_like'].toDouble(),
      'humidity': data['main']['humidity'],
      'pressure': data['main']['pressure'],
      'windSpeed': data['wind']['speed'].toDouble(),
      'windDeg': data['wind']['deg'],
      'description': data['weather'][0]['description'],
      'icon': data['weather'][0]['icon'],
      'main': data['weather'][0]['main'],
      'cloudiness': data['clouds']['all'],
      'visibility': data['visibility'],
      'rain': data.containsKey('rain') ? data['rain']['1h'] ?? 0.0 : 0.0,
      'cityName': data['name'],
    };
  }

  // Get weather icon URL
  String getIconUrl(String iconCode) {
    return 'https://openweathermap.org/img/wn/$iconCode@2x.png';
  }

  // Get UV index (using One Call API 3.0 - free tier)
  Future<Map<String, dynamic>?> getUVIndex(double lat, double lon) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/onecall?lat=$lat&lon=$lon&appid=$_apiKey&exclude=minutely,hourly&units=metric',
      );
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'uvi': data['current']['uvi'],
          'alerts': data['alerts'] ?? [],
        };
      } else {
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching UV data: $e');
      return null;
    }
  }

  // Parse forecast data to get daily summaries
  List<Map<String, dynamic>> parseForecastData(Map<String, dynamic> data) {
    final List<dynamic> list = data['list'];
    final Map<String, Map<String, dynamic>> dailyData = {};

    for (var item in list) {
      final DateTime date = DateTime.fromMillisecondsSinceEpoch(item['dt'] * 1000);
      final String dateKey = '${date.year}-${date.month}-${date.day}';

      if (!dailyData.containsKey(dateKey)) {
        dailyData[dateKey] = {
          'date': date,
          'tempMin': item['main']['temp_min'].toDouble(),
          'tempMax': item['main']['temp_max'].toDouble(),
          'humidity': item['main']['humidity'],
          'description': item['weather'][0]['description'],
          'icon': item['weather'][0]['icon'],
          'rain': item.containsKey('rain') ? (item['rain']['3h'] ?? 0.0) : 0.0,
          'windSpeed': item['wind']['speed'].toDouble(),
        };
      } else {
        // Update min/max temperatures
        if (item['main']['temp_min'] < dailyData[dateKey]!['tempMin']) {
          dailyData[dateKey]!['tempMin'] = item['main']['temp_min'].toDouble();
        }
        if (item['main']['temp_max'] > dailyData[dateKey]!['tempMax']) {
          dailyData[dateKey]!['tempMax'] = item['main']['temp_max'].toDouble();
        }
        // Accumulate rain
        if (item.containsKey('rain')) {
          dailyData[dateKey]!['rain'] += (item['rain']['3h'] ?? 0.0);
        }
      }
    }

    return dailyData.values.take(3).toList();
  }

  // Get agricultural weather recommendation
  String getAgricultureRecommendation(Map<String, dynamic> weather, double? uvi) {
    final temp = weather['temperature'];
    final humidity = weather['humidity'];
    final rain = weather['rain'];
    final windSpeed = weather['windSpeed'];

    List<String> warnings = [];

    if (temp > 35) {
      warnings.add('⚠️ High temperature - Increase watering frequency');
    } else if (temp < 10) {
      warnings.add('❄️ Low temperature - Protect sensitive plants');
    }

    if (humidity > 85) {
      warnings.add('💧 High humidity - Monitor for fungal diseases');
    } else if (humidity < 30) {
      warnings.add('🌵 Low humidity - Increase irrigation');
    }

    if (rain > 10) {
      warnings.add('🌧️ Heavy rainfall expected - Check drainage');
    } else if (rain > 5) {
      warnings.add('☔ Moderate rainfall - Delay watering');
    }

    if (windSpeed > 15) {
      warnings.add('💨 Strong winds - Secure tall plants');
    }

    if (uvi != null && uvi > 8) {
      warnings.add('☀️ High UV index - Provide shade for sensitive crops');
    }

    if (warnings.isEmpty) {
      return '✅ Good conditions for plant care';
    }

    return warnings.join('\n');
  }
}
