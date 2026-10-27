import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';

/// Web addresses ("https://…", "http://…", "www.…") and e-mail addresses in
/// a text, as people write them in messages.
final _links = RegExp(
  r'(?:https?://|www\.)[^\s<>"„”«»]+'
  r'|[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+',
  caseSensitive: false,
);

/// Marks that end a sentence or close a quote rather than belong to the
/// address before them.
const _trailing = '.,;:!?\'"”»…';

/// [text] cut into its plain parts and its links, in order: a part with a
/// [link] is an address to open, the web one in a browser and an e-mail
/// address in the mail app. Only web and mail links come out of it.
List<({String text, Uri? link})> linkParts(String text) {
  final parts = <({String text, Uri? link})>[];
  void plain(String value) {
    if (value.isEmpty) return;
    if (parts.isNotEmpty && parts.last.link == null) {
      parts.last = (text: parts.last.text + value, link: null);
    } else {
      parts.add((text: value, link: null));
    }
  }

  var start = 0;
  for (final match in _links.allMatches(text)) {
    var address = match[0]!;
    address = _trimmed(address);
    final link = _linkOf(address);
    plain(text.substring(start, match.start));
    if (link == null) {
      plain(address);
    } else {
      parts.add((text: address, link: link));
    }
    // What was cut off the end stays text.
    start = match.start + address.length;
  }
  plain(text.substring(start));
  return parts;
}

/// [address] without the punctuation after it, and without a closing
/// bracket it does not open itself, as in "(see https://example.pl)".
String _trimmed(String address) {
  var value = address;
  while (value.isNotEmpty) {
    final last = value[value.length - 1];
    final unopened = switch (last) {
      ')' => '('.allMatches(value).length < ')'.allMatches(value).length,
      ']' => '['.allMatches(value).length < ']'.allMatches(value).length,
      _ => false,
    };
    if (!_trailing.contains(last) && !unopened) break;
    value = value.substring(0, value.length - 1);
  }
  return value;
}

/// The link [address] opens, or null when it is not one after all.
Uri? _linkOf(String address) {
  if (address.contains('@') && !address.contains('/')) {
    return Uri(scheme: 'mailto', path: address);
  }
  final lower = address.toLowerCase();
  final full = lower.startsWith('www.') ? 'https://$address' : address;
  final uri = Uri.tryParse(full);
  if (uri == null || uri.host.isEmpty || uri.host == 'www') return null;
  return uri;
}

/// [text] whose links open with a tap, the rest of it as selectable as
/// before. Text selected in a link offers to open the link or copy it.
class LinkedText extends StatefulWidget {
  const LinkedText(
    this.text, {
    this.style,
    this.onOpenFailed,
    this.onOpened,
    super.key,
  });

  final String text;
  final TextStyle? style;

  /// Called when a link could not be opened, to say so.
  final VoidCallback? onOpenFailed;

  /// Called when a link opened, to take back a word that one did not.
  final VoidCallback? onOpened;

  /// Opens a link outside the app; true when it did. Tests put their own
  /// here.
  static Future<bool> Function(Uri link) open = _launch;

  static Future<bool> _launch(Uri link) =>
      launchUrl(link, mode: LaunchMode.externalApplication);

  @override
  State<LinkedText> createState() => _LinkedTextState();
}

class _LinkedTextState extends State<LinkedText> {
  late List<({String text, Uri? link})> _parts;
  final _recognizers = <TapGestureRecognizer>[];

  /// Where the selection lies in the text, to tell whether in a link.
  final _selection = SelectionListenerNotifier();

  @override
  void initState() {
    super.initState();
    _split();
  }

  @override
  void didUpdateWidget(LinkedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _split();
  }

  @override
  void dispose() {
    _forgetRecognizers();
    _selection.dispose();
    super.dispose();
  }

  void _split() {
    _forgetRecognizers();
    _parts = linkParts(widget.text);
    for (final part in _parts) {
      if (part.link case final link?) {
        _recognizers.add(TapGestureRecognizer()..onTap = () => _open(link));
      }
    }
  }

  void _forgetRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  Future<void> _open(Uri link) async {
    var opened = false;
    try {
      opened = await LinkedText.open(link);
    } on Object {
      opened = false;
    }
    if (!mounted) return;
    if (opened) {
      widget.onOpened?.call();
    } else {
      widget.onOpenFailed?.call();
    }
  }

  /// The first link the selection takes in, whole or in part.
  Uri? _selectedLink() {
    if (!_selection.registered) return null;
    final range = _selection.selection.range;
    if (range == null) return null;
    final start = min(range.startOffset, range.endOffset);
    final end = max(range.startOffset, range.endOffset);
    if (start == end) return null;
    var offset = 0;
    for (final part in _parts) {
      final partEnd = offset + part.text.length;
      if (part.link case final link? when start < partEnd && end > offset) {
        return link;
      }
      offset = partEnd;
    }
    return null;
  }

  /// What a link copies: an e-mail address without "mailto:".
  static String _copied(Uri link) =>
      link.scheme == 'mailto' ? link.path : link.toString();

  Widget _menu(BuildContext context, SelectableRegionState region) {
    final link = _selectedLink();
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: region.contextMenuAnchors,
      buttonItems: [
        if (link != null) ...[
          ContextMenuButtonItem(
            label: context.tr('linkOpen'),
            onPressed: () {
              ContextMenuController.removeAny();
              _open(link);
            },
          ),
          ContextMenuButtonItem(
            label: context.tr('linkCopy'),
            onPressed: () {
              ContextMenuController.removeAny();
              Clipboard.setData(ClipboardData(text: _copied(link)));
            },
          ),
        ],
        ...region.contextMenuButtonItems,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    var next = 0;
    return SelectionArea(
      contextMenuBuilder: _menu,
      child: SelectionListener(
        selectionNotifier: _selection,
        child: Text.rich(
          TextSpan(
            style: widget.style,
            children: [
              for (final part in _parts)
                if (part.link == null)
                  TextSpan(text: part.text)
                else
                  TextSpan(
                    text: part.text,
                    style: TextStyle(
                      color: color,
                      decoration: TextDecoration.underline,
                      decorationColor: color,
                    ),
                    mouseCursor: SystemMouseCursors.click,
                    recognizer: _recognizers[next++],
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
