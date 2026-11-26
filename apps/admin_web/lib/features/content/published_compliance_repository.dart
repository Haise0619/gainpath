import 'package:gainpath_domain/content.dart';

typedef ComplianceCall = Future<Map<String, dynamic>> Function(
    String action, Map<String, dynamic> input);

const legalDocumentNames = {
  'terms': 'Terms & Conditions',
  'privacy': 'Privacy Policy',
  'health': 'Health Disclaimer',
};

class PublishedComplianceRepository implements ComplianceDocumentRepository {
  PublishedComplianceRepository(this.kind, this.call);

  final String kind;
  final ComplianceCall call;
  List<Map<String, dynamic>> publications = const [];

  @override
  Future<ComplianceDocumentSnapshot> load() async {
    final data = await call('adminOverview', {'kind': kind});
    publications = (data['history'] as List)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList(growable: false);
    final draft = data['draft'];
    return ComplianceDocumentSnapshot(
      current: draft == null ? null : _decode(draft as Map),
      history: (data['draftHistory'] as List)
          .map((value) => _decode(value as Map))
          .toList(growable: false),
      editBaseline: _Baseline(this),
    );
  }

  @override
  Future<ComplianceDocumentSnapshot> save(ComplianceDocumentSnapshot original,
      {required String text, required bool isArchived}) async {
    _check(original);
    await call('saveDraft', {
      'kind': kind,
      'baseRevision': original.current?.revision ?? 0,
      'text': text,
      'isArchived': isArchived,
    });
    return load();
  }

  Future<String> publish(ComplianceDocumentSnapshot original,
      {required bool requireConsent}) async {
    _check(original);
    final response = await call('publish', {
      'kind': kind,
      'baseRevision': original.current?.revision ?? 0,
      'requireConsent': requireConsent,
    });
    return response['version'] as String;
  }

  void _check(ComplianceDocumentSnapshot original) {
    final baseline = original.editBaseline;
    if (baseline is! _Baseline || !identical(baseline.owner, this)) {
      throw const ComplianceDocumentConflict();
    }
  }

  ComplianceDocument _decode(Map data) => ComplianceDocument(
        text: data['text'] as String,
        isArchived: data['isArchived'] == true,
        revision: data['revision'] as int,
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(data['updatedAtMillis'] as int),
      );
}

class _Baseline extends ComplianceDocumentEditBaseline {
  _Baseline(this.owner);
  final PublishedComplianceRepository owner;
}
