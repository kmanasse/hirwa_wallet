import 'dart:convert';

import 'package:http/http.dart' as http;

class DollarRate {
  const DollarRate({required this.rwfPerDollar, required this.updated});

  final double rwfPerDollar;
  final String updated;

  factory DollarRate.fromJson(Map<String, dynamic> json) {
    final rates = json['rates'] as Map<String, dynamic>;
    return DollarRate(
      rwfPerDollar: (rates['RWF'] as num).toDouble(),
      updated: json['time_last_update_utc'] as String,
    );
  }
}

Future<DollarRate> fetchDollarRate() async {
  final url = Uri.parse('https://open.er-api.com/v6/latest/USD');
  final response = await http.get(url);
  if (response.statusCode != 200) {
    throw Exception('The rate server answered ${response.statusCode}');
  }
  final data = jsonDecode(response.body) as Map<String, dynamic>;
  if (data['result'] != 'success') {
    throw Exception('The rate server did not return a rate');
  }
  return DollarRate.fromJson(data);
}
