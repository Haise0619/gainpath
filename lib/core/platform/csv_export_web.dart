import 'dart:js_interop';
import 'package:web/web.dart' as web;

void downloadCsv(String filename, List<List<Object?>> rows) {
  final csv = rows.map((row) => row.map(_escape).join(',')).join('\r\n');
  final blob = web.Blob([csv.toJS].toJS, web.BlobPropertyBag(type: 'text/csv;charset=utf-8'));
  final url = web.URL.createObjectURL(blob);
  web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..click();
  web.URL.revokeObjectURL(url);
}

String _escape(Object? value) {
  final text = value?.toString() ?? '';
  if (text.contains(',') || text.contains('"') || text.contains('\n')) {
    return '"${text.replaceAll('"', '""')}"';
  }
  return text;
}
