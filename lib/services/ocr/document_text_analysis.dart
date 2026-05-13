import 'dart:math' as math;

import '../../models/document_insights.dart';

/// Top-level for [compute] — keep logic pure (no Flutter bindings).
Map<String, dynamic> analyzeDocumentTextIsolate(String text) {
  return DocumentTextAnalyzer.buildMap(text);
}

/// Heuristic extraction + naming + summaries from raw OCR text.
abstract final class DocumentTextAnalyzer {
  static Map<String, dynamic> buildMap(String raw) {
    final text = raw.replaceAll('\r\n', '\n').trim();
    if (text.isEmpty) {
      return DocumentInsights.empty().toMap();
    }
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final lower = text.toLowerCase();

    final totals = _extractTotals(text, lines);
    final dates = _extractDates(text);
    final invoiceNumbers = _extractInvoiceNumbers(text);
    final emails = _extractEmails(text);
    final phones = _extractPhones(text);
    final addresses = _extractAddresses(lines);
    final merchants = _extractMerchants(lines, lower);

    final importantLines = _importantLines(lines);
    final topics = _detectTopics(lower);
    final summaryBullets = _buildSummaryBullets(lines, importantLines, merchants, totals, dates);
    final nameIdeas = _buildNameIdeas(
      lower: lower,
      lines: lines,
      merchants: merchants,
      invoiceNumbers: invoiceNumbers,
      topics: topics,
    );

    return DocumentInsights(
      totals: _uniq(totals, 12),
      dates: _uniq(dates, 10),
      invoiceNumbers: _uniq(invoiceNumbers, 8),
      emails: _uniq(emails, 8),
      phones: _uniq(phones, 8),
      addresses: _uniq(addresses, 6),
      merchants: _uniq(merchants, 5),
      summaryBullets: _uniq(summaryBullets, 8),
      importantLines: _uniq(importantLines, 10),
      topics: _uniq(topics, 8),
      nameIdeas: _uniq(nameIdeas, 6),
    ).toMap();
  }

  static List<String> _extractTotals(String text, List<String> lines) {
    final out = <String>[];
    final money = RegExp(r'(?:USD|US\$|\$|€|£)\s*\d{1,3}(?:[,\s]\d{3})*(?:\.\d{2})?', caseSensitive: false);
    for (final m in money.allMatches(text)) {
      out.add(m.group(0)!.replaceAll(RegExp(r'\s+'), ' ').trim());
    }
    final labeled = RegExp(
      r'(?:(?:total|amount\s*due|balance\s*due|subtotal|grand\s*total|tax))\s*[:\-]?\s*(\$?\d{1,3}(?:[,\s]\d{3})*(?:\.\d{2})?)',
      caseSensitive: false,
    );
    for (final m in labeled.allMatches(text)) {
      final g = m.group(1);
      if (g != null) out.add(g.trim());
    }
    for (final line in lines) {
      if (RegExp(r'total|amount due', caseSensitive: false).hasMatch(line) &&
          RegExp(r'\d').hasMatch(line)) {
        out.add(line.length > 80 ? '${line.substring(0, 77)}…' : line);
      }
    }
    return out;
  }

  static List<String> _extractDates(String text) {
    final out = <String>[];
    final p1 = RegExp(r'\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b');
    final p2 = RegExp(
      r'\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)[a-z]*\.?\s+\d{1,2},?\s+\d{4}\b',
      caseSensitive: false,
    );
    final p3 = RegExp(r'\b\d{4}[/-]\d{1,2}[/-]\d{1,2}\b');
    for (final r in [p1, p2, p3]) {
      for (final m in r.allMatches(text)) {
        out.add(m.group(0)!);
      }
    }
    return out;
  }

  static List<String> _extractInvoiceNumbers(String text) {
    final out = <String>[];
    final r = RegExp(
      r'\b(?:invoice|inv\.?|receipt|order|confirmation)\s*#?\s*[:\-]?\s*([A-Z0-9][A-Z0-9\-]{4,})\b',
      caseSensitive: false,
    );
    for (final m in r.allMatches(text)) {
      final g = m.group(1);
      if (g != null) out.add(g.trim());
    }
    final r2 = RegExp(r'\b(?:#|no\.?)\s*(\d{4,10})\b', caseSensitive: false);
    for (final m in r2.allMatches(text)) {
      out.add(m.group(1)!);
    }
    return out;
  }

  static List<String> _extractEmails(String text) {
    final r = RegExp(r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b', caseSensitive: false);
    return r.allMatches(text).map((m) => m.group(0)!).toList();
  }

  static List<String> _extractPhones(String text) {
    final out = <String>[];
    final r = RegExp(r'\+?\d[\d\-\s().]{8,}\d');
    for (final m in r.allMatches(text)) {
      final s = m.group(0)!.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (s.replaceAll(RegExp(r'\D'), '').length >= 10) out.add(s);
    }
    return out;
  }

  static List<String> _extractAddresses(List<String> lines) {
    final out = <String>[];
    final zip = RegExp(r'\b\d{5}(?:-\d{4})?\b');
    final street = RegExp(
      r'\b\d+\s+[A-Za-z0-9.\s]+(?:street|st\.?|avenue|ave\.?|road|rd\.?|drive|dr\.?|lane|ln\.?|blvd\.?|court|ct\.?)\b',
      caseSensitive: false,
    );
    for (final line in lines) {
      if (zip.hasMatch(line) || street.hasMatch(line)) {
        out.add(line.length > 120 ? '${line.substring(0, 117)}…' : line);
      }
    }
    return out;
  }

  static List<String> _extractMerchants(List<String> lines, String lower) {
    final out = <String>[];
    final skip = RegExp(r'^(date|time|total|subtotal|tax|thank|page\s*\d)', caseSensitive: false);
    for (var i = 0; i < math.min(6, lines.length); i++) {
      final line = lines[i];
      if (line.length < 3 || line.length > 64) continue;
      if (skip.hasMatch(line)) continue;
      if (RegExp(r'^\d+[./-]\d').hasMatch(line)) continue;
      if (RegExp(r'@').hasMatch(line)) continue;
      if (lower.contains('walmart') && i == 0) {
        out.add('Walmart');
        continue;
      }
      if (RegExp(r'\b(LLC|Inc\.?|Corp\.?|Ltd\.?|Co\.)\b', caseSensitive: false).hasMatch(line)) {
        out.add(line);
      } else if (i <= 2 && !RegExp(r'^\d+\.\d{2}$').hasMatch(line)) {
        out.add(line);
      }
    }
    if (lower.contains('walmart') && !out.any((e) => e.toLowerCase().contains('walmart'))) {
      out.insert(0, 'Walmart');
    }
    if (lower.contains('target') && !out.any((e) => e.toLowerCase().contains('target'))) {
      out.insert(0, 'Target');
    }
    if (lower.contains('costco')) out.add('Costco');
    if (lower.contains('amazon')) out.add('Amazon');
    return out;
  }

  static List<String> _importantLines(List<String> lines) {
    final scored = <String>[];
    for (final line in lines) {
      if (line.length < 28) continue;
      if (RegExp(r'^[=_\-]{4,}$').hasMatch(line)) continue;
      scored.add(line.length > 140 ? '${line.substring(0, 137)}…' : line);
      if (scored.length >= 12) break;
    }
    return scored.take(8).toList();
  }

  static List<String> _detectTopics(String lower) {
    final topics = <String>[];
    void add(String t, bool cond) {
      if (cond && !topics.contains(t)) topics.add(t);
    }

    add('Finance & receipts', RegExp(r'invoice|receipt|payment|balance|total|tax').hasMatch(lower));
    add('Shipping & delivery', RegExp(r'ship|tracking|deliver|carrier|ups|fedex|usps').hasMatch(lower));
    add('Medical', RegExp(r'patient|diagnosis|prescription|mg\b|clinic|hospital').hasMatch(lower));
    add('Legal', RegExp(r'contract|agreement|party|whereas|liable|terms\s+and\s+conditions').hasMatch(lower));
    add('Education', RegExp(r'homework|chapter|exam|midterm|physics|chemistry|lecture').hasMatch(lower));
    add('Real estate', RegExp(r'lease|rent|landlord|tenant|security\s+deposit').hasMatch(lower));
    add('HR / Offer', RegExp(r'employment|salary|offer\s+letter|benefits').hasMatch(lower));
    return topics;
  }

  static List<String> _buildSummaryBullets(
    List<String> lines,
    List<String> important,
    List<String> merchants,
    List<String> totals,
    List<String> dates,
  ) {
    final bullets = <String>[];
    if (merchants.isNotEmpty) {
      bullets.add('Likely merchant or header: ${merchants.first}.');
    }
    if (dates.isNotEmpty) {
      bullets.add('Detected date(s): ${dates.take(3).join(', ')}.');
    }
    if (totals.isNotEmpty) {
      bullets.add('Monetary amounts spotted: ${totals.take(3).join(', ')}.');
    }
    for (final imp in important.take(3)) {
      bullets.add('Notable line: $imp');
    }
    if (bullets.isEmpty && lines.isNotEmpty) {
      bullets.add('Document opens with: ${lines.first.length > 100 ? '${lines.first.substring(0, 97)}…' : lines.first}');
    }
    if (lines.length > 8) {
      bullets.add('${lines.length} non-empty lines — structured form or multi-section document.');
    }
    return bullets.take(8).toList();
  }

  static List<String> _buildNameIdeas({
    required String lower,
    required List<String> lines,
    required List<String> merchants,
    required List<String> invoiceNumbers,
    required List<String> topics,
  }) {
    final ideas = <String>{};
    if (merchants.isNotEmpty) {
      final m = merchants.first;
      if (lower.contains('receipt') || lower.contains('sale')) {
        ideas.add('$m Receipt');
      } else {
        ideas.add('$m Document');
      }
    }
    if (invoiceNumbers.isNotEmpty) {
      ideas.add('Invoice #${invoiceNumbers.first}');
    }
    if (topics.contains('Education') || RegExp(r'physics|chemistry|homework|chapter', caseSensitive: false).hasMatch(lower)) {
      ideas.add('Physics Notes');
      ideas.add('Study Notes');
    }
    if (topics.contains('Real estate') || RegExp(r'lease|rental', caseSensitive: false).hasMatch(lower)) {
      ideas.add('Rental Contract');
    }
    if (topics.contains('Legal')) {
      ideas.add('Signed Agreement');
    }
    if (lines.isNotEmpty) {
      final head = lines.first;
      if (head.length >= 6 && head.length <= 42 && !RegExp(r'^\d').hasMatch(head)) {
        ideas.add(head);
      }
    }
    if (ideas.isEmpty) {
      ideas.addAll(['Scanned Document', 'Important Papers', 'Archive Scan']);
    }
    return ideas.toList();
  }

  static List<String> _uniq(List<String> input, int max) {
    final seen = <String>{};
    final out = <String>[];
    for (final s in input) {
      final t = s.trim();
      if (t.isEmpty) continue;
      final k = t.toLowerCase();
      if (seen.contains(k)) continue;
      seen.add(k);
      out.add(t);
      if (out.length >= max) break;
    }
    return out;
  }
}
