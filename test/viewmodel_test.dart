import 'package:test/test.dart';
import 'package:sc4pac_gui/viewmodel.dart';

void main() {
  test('World.isSubpathSymmetric', () {
    expect(World.isSubpathSymmetric('/a', '/a'), equals(true));
    expect(World.isSubpathSymmetric('/a', '/b'), equals(false));
    expect(World.isSubpathSymmetric('/a', '/a/b'), equals(true));
    expect(World.isSubpathSymmetric('/a/a', '/a/b'), equals(false));
    expect(World.isSubpathSymmetric('/a/a', '/b/a'), equals(false));
    expect(World.isSubpathSymmetric('/a//b', '/a/b'), equals(true));
    expect(World.isSubpathSymmetric('/a/b/c', '/a'), equals(true));
    expect(World.isSubpathSymmetric(r'C:\a', r'C:\a'), equals(true));
    expect(World.isSubpathSymmetric(r'C:\a', r'C:\b'), equals(false));
    expect(World.isSubpathSymmetric(r'C:\a', r'C:\a\b'), equals(true));
    expect(World.isSubpathSymmetric(r'C:\a\a', r'C:\a\b'), equals(false));
    expect(World.isSubpathSymmetric(r'C:\a\a', r'C:\b\a'), equals(false));
    expect(World.isSubpathSymmetric(r'C:\a\\b', r'C:\a\b'), equals(true));
    expect(World.isSubpathSymmetric(r'C:\a\b\c', r'C:\a'), equals(true));
  });
}
