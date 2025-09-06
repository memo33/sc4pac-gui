import 'package:test/test.dart';
import 'package:sc4pac_gui/model.dart';

void main() {
  test('RingBuffer', () {
    final b = RingBuffer(capacity: 5);
    b.add(0);
    expect(b.length, equals(1));
    expect(b.takeRight(5), equals([0]));
    b.add(1);
    b.add(2);
    b.add(3);
    expect(b.length, equals(4));
    expect(b.takeRight(5), equals([0,1,2,3]));
    b.add(4);
    b.add(5);
    b.add(6);
    expect(b.length, equals(5));
    expect(b.takeRight(5), equals([2,3,4,5,6]));
    expect(b.takeRight(3), equals([4,5,6]));
    b.add(7);
    b.add(8);
    b.add(9);
    b.add(10);
    expect(b.length, equals(5));
    expect(b.takeRight(10), equals([6,7,8,9,10]));
    expect(b.takeRight(3), equals([8,9,10]));
  });
}
