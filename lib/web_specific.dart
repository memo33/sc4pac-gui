import 'package:web/web.dart' show window;

void changeWindowUrl(Uri uri) {
  window.history.pushState(null, "", uri.toString());
}
