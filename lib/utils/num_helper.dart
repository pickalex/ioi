
extension NumHelperExtension on num {
  double add(num other, {int precision = 2}) {
    return (this + other).fixed(precision);
  }

  
  double sub(num other, {int precision = 2}) {
    return (this - other).fixed(precision);
  }

  double mul(num other, {int precision = 2}) {
    return (this * other).fixed(precision);
  }

  double div(num other, {int precision = 2}) {
    if (other == 0) return 0.0;
    return (this / other).fixed(precision);
  }

 
  double fixed(int precision) {
    if (isNaN || isInfinite) return 0.0;
    
    return double.parse(toStringAsFixed(precision));
  }

  String toKeepString({int fractionDigits = 2}) {
    String str = toStringAsFixed(fractionDigits);
    if (str.contains('.')) {
      str = str.replaceAll(RegExp(r'0*$'), '');
      str = str.replaceAll(RegExp(r'\.$'), '');
    }
    return str;
  }
}
