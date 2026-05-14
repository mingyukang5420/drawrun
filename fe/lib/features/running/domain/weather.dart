class Weather {
  final double temperature;
  final String sido;
  final String gu;
  final String message;
  final String precipitation;

  const Weather({
    required this.temperature,
    required this.sido,
    required this.gu,
    required this.message,
    required this.precipitation,
  });

  factory Weather.fromJson(Map<String, dynamic> json) => Weather(
        temperature: (json['temperature'] as num).toDouble(),
        sido: json['sido'] as String,
        gu: json['gu'] as String,
        message: json['message'] as String,
        precipitation: json['precipitation'] as String,
      );

  String get locationLine => '$sido $gu ${temperature.toStringAsFixed(0)}°C $precipitation';
}
