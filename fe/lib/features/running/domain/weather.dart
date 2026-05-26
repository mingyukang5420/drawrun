class Weather {
  final double temperature;
  final String sido;
  final String gu;
  final String message;
  final String precipitation;
  final String skyCondition;

  // 위치·API 실패 시 기본 표시값
  static const Weather fallback = Weather(
    temperature: 18,
    sido: '서울특별시',
    gu: '강남구',
    message: '빗속 러닝도 매력 있어요!',
    precipitation: '비',
    skyCondition: '흐림',
  );

  const Weather({
    required this.temperature,
    required this.sido,
    required this.gu,
    required this.message,
    required this.precipitation,
    required this.skyCondition,
  });

  factory Weather.fromJson(Map<String, dynamic> json) => Weather(
        temperature: (json['temperature'] as num).toDouble(),
        sido: json['sido'] as String,
        gu: json['gu'] as String,
        message: json['message'] as String,
        precipitation: json['precipitation'] as String,
        skyCondition: json['weather'] as String? ?? '',
      );

  String get weatherEmoji {
    if (precipitation == '비' || precipitation == '소나기') return '🌧️';
    if (precipitation == '비/눈' || precipitation == '눈') return '🌨️';
    return switch (skyCondition) {
      '맑음'    => '☀️',
      '구름많음' => '⛅',
      '흐림'    => '☁️',
      _         => '🌤️',
    };
  }

  String get locationLine =>
      '$sido $gu ${temperature.toStringAsFixed(0)}°C $weatherEmoji';
}
