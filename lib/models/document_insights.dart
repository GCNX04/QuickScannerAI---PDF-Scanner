/// Structured output from heuristic document analysis (runs in an isolate).
class DocumentInsights {
  const DocumentInsights({
    required this.totals,
    required this.dates,
    required this.invoiceNumbers,
    required this.emails,
    required this.phones,
    required this.addresses,
    required this.merchants,
    required this.summaryBullets,
    required this.importantLines,
    required this.topics,
    required this.nameIdeas,
  });

  factory DocumentInsights.empty() => const DocumentInsights(
        totals: [],
        dates: [],
        invoiceNumbers: [],
        emails: [],
        phones: [],
        addresses: [],
        merchants: [],
        summaryBullets: [],
        importantLines: [],
        topics: [],
        nameIdeas: [],
      );

  factory DocumentInsights.fromMap(Map<String, dynamic> map) {
    List<String> ls(String k) {
      final v = map[k];
      if (v is List) {
        return v.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList();
      }
      return const [];
    }

    return DocumentInsights(
      totals: ls('totals'),
      dates: ls('dates'),
      invoiceNumbers: ls('invoiceNumbers'),
      emails: ls('emails'),
      phones: ls('phones'),
      addresses: ls('addresses'),
      merchants: ls('merchants'),
      summaryBullets: ls('summaryBullets'),
      importantLines: ls('importantLines'),
      topics: ls('topics'),
      nameIdeas: ls('nameIdeas'),
    );
  }

  final List<String> totals;
  final List<String> dates;
  final List<String> invoiceNumbers;
  final List<String> emails;
  final List<String> phones;
  final List<String> addresses;
  final List<String> merchants;
  final List<String> summaryBullets;
  final List<String> importantLines;
  final List<String> topics;
  final List<String> nameIdeas;

  bool get isEmpty =>
      totals.isEmpty &&
      dates.isEmpty &&
      invoiceNumbers.isEmpty &&
      emails.isEmpty &&
      phones.isEmpty &&
      addresses.isEmpty &&
      merchants.isEmpty &&
      summaryBullets.isEmpty &&
      importantLines.isEmpty &&
      topics.isEmpty &&
      nameIdeas.isEmpty;

  bool get hasAnySignal => !isEmpty;

  Map<String, dynamic> toMap() => {
        'totals': totals,
        'dates': dates,
        'invoiceNumbers': invoiceNumbers,
        'emails': emails,
        'phones': phones,
        'addresses': addresses,
        'merchants': merchants,
        'summaryBullets': summaryBullets,
        'importantLines': importantLines,
        'topics': topics,
        'nameIdeas': nameIdeas,
      };
}
