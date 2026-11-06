class UnifiedAdminSummary {
  UnifiedAdminSummary._(this.existingMembers,this.fypMembers,this.existingCoaches,this.fypCoaches,this.simulatedMinor,this.membershipMinor,this.coachingMinor,this.illustrativeMinor,this.subscriptions,this.appointments,this.monthly,this.catalogCounts,this.directoryTotals,this.memberTrend);
  final int existingMembers,fypMembers,existingCoaches,fypCoaches,simulatedMinor,membershipMinor,coachingMinor,illustrativeMinor;
  final Map<String,int> subscriptions,appointments;
  final List<UnifiedRevenueMonth> monthly;
  final Map<String,int> catalogCounts,directoryTotals;
  final List<UnifiedMemberDay> memberTrend;
  factory UnifiedAdminSummary.parse(Object? value) {
    Map<String,dynamic> map(Object? x)=>Map<String,dynamic>.from(x as Map);
    int integer(Object? x) {if(x is! int||x<0||x>9007199254740991)throw const FormatException('Invalid unified count');return x;}
    final q=map(value),sources=map(q['sourceBreakdown']),a=map(sources['existing']),b=map(sources['fyp']),sample=map(q['sampleBusiness']);
    if(q['schemaVersion']!=1||sample['provenance']!='fyp_business_simulation'||sample['currency']!='MYR')throw const FormatException('Invalid unified provenance');
    final total=integer(sample['simulatedRevenueMinor']),membership=integer(sample['membershipRevenueMinor']),coaching=integer(sample['coachingRevenueMinor']);
    final months=(sample['monthly'] as List).map((x){final r=map(x);return UnifiedRevenueMonth(r['month'] as String,integer(r['amountMinor']));}).toList();
    if(total!=membership+coaching||months.fold<int>(0,(n,x)=>n+x.minor)!=total)throw const FormatException('Unified money mismatch');
    return UnifiedAdminSummary._(integer(a['members']),integer(b['members']),integer(a['coaches']),integer(b['coaches']),total,membership,coaching,integer(q['illustrativeRevenueMinor']),map(sample['subscriptions']).map((k,v)=>MapEntry(k,integer(v))),map(sample['appointments']).map((k,v)=>MapEntry(k,integer(v))),months,map(q['catalogCounts']??{}).map((k,v)=>MapEntry(k,integer(v))),map(q['directoryTotals']??{}).map((k,v)=>MapEntry(k,integer(v))),((q['recordCreationTrend'] as List?)??[]).map((x){final r=map(x);return UnifiedMemberDay(r['date'] as String,integer(r['existing']),integer(r['fyp']));}).toList());
  }
  List<List<Object?>> toCsv()=>[
    ['GainPath FYP business simulation','MYR minor units; not settled income or entitlements'],
    ['Existing active Members',existingMembers],['FYP active Members',fypMembers],['Existing active Coaches',existingCoaches],['FYP active Coaches',fypCoaches],
    ['Simulated membership revenue minor',membershipMinor],['Simulated coaching revenue minor',coachingMinor],['Total simulated revenue minor',simulatedMinor],['Illustrative existing Sandbox + simulation minor',illustrativeMinor],
    for(final e in subscriptions.entries)['Sample subscription ${e.key}',e.value],for(final e in appointments.entries)['Sample appointment ${e.key}',e.value],
    ['Malaysia month','Simulated revenue minor'],for(final r in monthly)[r.month,r.minor]
    ,for(final e in catalogCounts.entries)['Published catalog ${e.key}',e.value],for(final e in directoryTotals.entries)['Administrative directory ${e.key}',e.value],
    ['Malaysia date','Existing Member records created','FYP Member records provisioned'],for(final d in memberTrend)[d.date,d.existing,d.fyp],
  ];
}
class UnifiedRevenueMonth {const UnifiedRevenueMonth(this.month,this.minor);final String month;final int minor;}
class UnifiedMemberDay {const UnifiedMemberDay(this.date,this.existing,this.fyp);final String date;final int existing,fyp;}
