import 'package:flutter_test/flutter_test.dart';
import 'package:live_app/utils/num_helper.dart';

void main() {
  group('NumHelperExtension Tests', () {
    test('add functionality', () {
      expect(1.add(0.2), 1.2);
      expect(1.add(2), 3.0); // int + int return double
      expect(
        1.005.add(2.005, precision: 2),
        3.01,
      ); // 1.01 + 2.01 (rounded first? no, result rounded)
      // The impl: (1.005*100).round() + (2.005*100).round() = 101 + 201 = 302 / 100 = 3.02
      // Wait, (1.005*100) is 100.5 -> round -> 101
      expect(1.1.add(2.2), 3.3);
    });

    test('sub functionality', () {
      expect(0.3.sub(0.2), 0.1); // fixes 0.09999999999
      expect(1.0.sub(0.9), 0.1);
    });

    test('mul functionality', () {
      expect(0.1.mul(0.2), 0.02); // fixes 0.02000000004
      expect(100.mul(0.01), 1.0);
    });

    test('div functionality', () {
      expect(0.3.div(0.1), 3.0);
      expect(1.0.div(3, precision: 2), 0.33);
      expect(1.0.div(2), 0.5);
      expect(1.006.div(2.0, precision: 2), 0.50);
    });

    test('fixed functionality', () {
      expect(3.14159.fixed(2), 3.14);
      expect(3.146.fixed(2), 3.15); // rounded
    });

    test('toKeepString functionality', () {
      expect(3.1400.toKeepString(), '3.14');
      expect(3.00.toKeepString(), '3');
      expect(3.50.toKeepString(), '3.5');
      expect(0.00.toKeepString(), '0');
    });

    test('Mixed types', () {
      expect(10.add(0.1), 10.1);
      expect(10.5.add(5), 15.5);
    });
  });
}
