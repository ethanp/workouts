const poundsPerKilogram = 2.2046226218;

enum WeightUnit {
  pounds(label: 'lb'),
  kilograms(label: 'kg');

  const WeightUnit({required this.label});

  final String label;
}

class Weight {
  const Weight.kilograms(this.kilograms);

  factory Weight.pounds(double pounds) {
    return Weight.kilograms(pounds / poundsPerKilogram);
  }

  final double kilograms;

  double get pounds => kilograms * poundsPerKilogram;

  static Weight? fromInput(String input, WeightUnit unit) {
    final displayWeight = double.tryParse(input.trim());
    if (displayWeight == null) return null;
    if (unit == WeightUnit.kilograms) return Weight.kilograms(displayWeight);
    return Weight.pounds(displayWeight);
  }

  String format(WeightUnit unit) {
    if (unit == WeightUnit.kilograms) return formatKilograms();
    return formatPounds();
  }

  String inputValue(WeightUnit unit) {
    if (unit == WeightUnit.kilograms) return inputKilograms();
    return inputPounds();
  }

  String formatPounds() => '${_formatNumber(pounds)}lb';

  String formatKilograms() => '${_formatNumber(kilograms)}kg';

  String inputPounds() => _formatNumber(pounds);

  String inputKilograms() => _formatNumber(kilograms);

  static String _formatNumber(double weight) {
    final roundedWeight = weight.roundToDouble();
    if ((weight - roundedWeight).abs() < 0.0001) {
      return roundedWeight.round().toString();
    }
    return weight.toStringAsFixed(1);
  }

  @override
  bool operator ==(Object other) {
    return other is Weight && other.kilograms == kilograms;
  }

  @override
  int get hashCode => kilograms.hashCode;

  @override
  String toString() => 'Weight(${formatKilograms()})';
}
