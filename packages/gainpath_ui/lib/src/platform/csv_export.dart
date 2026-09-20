import 'csv_export_stub.dart' if (dart.library.html) 'csv_export_web.dart' as impl;

/// Triggers a real browser CSV download of [rows] (first row is the
/// header) named [filename] — a genuine file, not a toast pretending to
/// export one. Web-only, matching the rest of this admin console; on any
/// other platform it's a no-op (there's no browser to hand a file to).
void downloadCsv(String filename, List<List<Object?>> rows) => impl.downloadCsv(filename, rows);
