import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;

/// Shared presentation conversion for rich diary text. Protocol/raw metadata
/// stays untouched; the app's selectable text keeps readable paragraphs/links.
String pluginText(String value) {
  final document = html.parseFragment(value);
  for (final hidden in document.querySelectorAll('script,style,template')) {
    hidden.remove();
  }
  for (final anchor in document.querySelectorAll('a')) {
    final target = (anchor.attributes['href'] ?? '').trim();
    final uri = Uri.tryParse(target);
    if (uri == null ||
        !const {'https', 'http', 'mailto'}.contains(uri.scheme)) {
      continue;
    }
    final address = uri.scheme == 'mailto' ? target.substring(7) : target;
    if (anchor.text.trim() != address && anchor.text.trim() != target) {
      anchor.append(dom.Text(' ($address)'));
    }
  }
  for (final line in document.querySelectorAll('br')) {
    line.replaceWith(dom.Text('\n'));
  }
  for (final block in document.querySelectorAll(
    'p,div,li,tr,h1,h2,h3,h4,h5,h6',
  )) {
    block.append(dom.Text('\n'));
  }
  return (document.text ?? '').replaceAll('\u00a0', ' ').trim();
}
