import Foundation

/// What a bank SMS turned into.
struct ParsedTxn: Equatable {
    var amount: Double
    var direction: TxnDirection
    var bank: String
    var accountLast4: String
    var isCard: Bool
    var isCreditCard: Bool
    var merchant: String
    var upiRef: String?
    var date: Date
    var isCardBillPayment: Bool
}

enum SMSParseResult: Equatable {
    case txn(ParsedTxn)
    /// Not a transaction (OTP, reminder, promo, failed txn). Dropped silently.
    case ignore
    /// Looks like a bank transaction but couldn't be read. Goes to the Review inbox.
    case unreadable
}

/// Reads Indian bank transaction SMS (HDFC and ICICI tested; most other banks work through the generic rules).
/// Pure Foundation so it is unit-testable without the app.
enum BankSMSParser {

    static func parse(_ raw: String, receivedAt: Date = .now) -> SMSParseResult {
        let flat = raw.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        let lower = flat.lowercased()

        // 1. Things that are never a completed transaction.
        let ignoreMarkers = ["otp", "one time password", "will be debited", "is due", "amt due", "amount due",
                             "due by", "due date", "has requested", "requested money", "collect request",
                             "declined", "failed", "unsuccessful", "is pending", "will be credited",
                             "pre-approved", "apply now", "offer"]
        if ignoreMarkers.contains(where: { lower.contains($0) }) { return .ignore }

        let looksLikeBank = lower.range(of: #"\b(debited|credited|spent|sent|a/c|acct|account|card|upi)\b"#,
                                        options: .regularExpression) != nil

        // 2. Amount.
        guard let amountStr = firstGroup(#"(?i)(?:rs\.?|inr|₹)\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)"#, in: flat),
              let amount = Double(amountStr.replacingOccurrences(of: ",", with: "")), amount > 0 else {
            return looksLikeBank ? .unreadable : .ignore
        }

        // 3. Direction: whichever keyword comes first wins.
        //    ICICI: "Acct XX383 debited for Rs 483 ...; Swiggy Ltd credited" → debit.
        let debitAt = firstIndex(#"\b(debited|spent|sent|paid|withdrawn|purchase|debit of)\b"#, in: lower)
        let creditAt = firstIndex(#"\b(credited|received|deposited|refund(ed)?|reversed|credit of)\b"#, in: lower)
        let direction: TxnDirection
        switch (debitAt, creditAt) {
        case let (d?, c?): direction = d < c ? .debit : .credit
        case (_?, nil): direction = .debit
        case (nil, _?): direction = .credit
        default: return .unreadable
        }

        // 4. Bank, account, card.
        let bank = detectBank(lower)
        var last4 = ""
        var isCard = false
        if let m = firstMatch(#"(?i)\b(a/c|acct|account|card)(?:\s+no\.?)?(?:\s+ending(?:\s+(?:with|in))?)?\s*[:\-]?\s*(?:[0-9]{0,4}[x*]+)?\s*([0-9]{3,6})\b"#, in: flat),
           m.count >= 3 {
            last4 = String(m[2].suffix(4))
            isCard = m[1].lowercased() == "card"
        }
        let isCreditCard = lower.contains("credit card")
            || (isCard && (lower.contains("avl limit") || lower.contains("available limit")
                           || lower.contains("avl lmt") || lower.contains("credit limit")))

        // 5. Counterparty / merchant.
        let merchant = extractMerchant(raw: raw, flat: flat, direction: direction, isCard: isCard)

        // 6. Reference, date.
        let upiRef = firstGroup(#"(?i)(?:upi(?:\s*ref(?:\s*no)?)?|ref(?:\s*no)?|rrn)[\s:.#\-]*([0-9]{9,14})\b"#, in: flat)
        let date = extractDate(flat, receivedAt: receivedAt)

        // 7. Credit card bill payment = money moving between your own accounts.
        let isBillPayment = direction == .credit && isCreditCard
            && (lower.contains("payment") || lower.contains("received towards"))

        return .txn(ParsedTxn(amount: amount, direction: direction, bank: bank, accountLast4: last4,
                              isCard: isCard, isCreditCard: isCreditCard, merchant: merchant,
                              upiRef: upiRef, date: date, isCardBillPayment: isBillPayment))
    }

    // MARK: - Pieces

    static func detectBank(_ lower: String) -> String {
        let banks: [(String, String)] = [
            ("hdfc", "HDFC"), ("icici", "ICICI"), ("sbi", "SBI"), ("state bank", "SBI"), ("axis", "Axis"),
            ("kotak", "Kotak"), ("yes bank", "Yes Bank"), ("idfc", "IDFC First"), ("indusind", "IndusInd"),
            ("bank of baroda", "Bank of Baroda"), ("canara", "Canara"), ("pnb", "PNB"), ("federal", "Federal"),
            ("au bank", "AU"), ("au small", "AU"), ("rbl", "RBL"), ("amex", "Amex"), ("onecard", "OneCard")
        ]
        return banks.first(where: { lower.contains($0.0) })?.1 ?? "Bank"
    }

    static func extractMerchant(raw: String, flat: String, direction: TxnDirection, isCard: Bool) -> String {
        var candidates: [String?] = []
        let stop = #"(?=\s+on\s|\s+\(|\s+ref\b|\s+upi\b|\s+avl|\s+info|\.\s|\.$|;|$)"#

        // ICICI: "...; Swiggy Ltd credited."
        candidates.append(firstGroup(#"(?i);\s*([^;]+?)\s+credited\b"#, in: flat))
        // HDFC multi-line: "Sent Rs.483.00\nFrom HDFC Bank A/C *1481\nTo SWIGGY\nOn 06/11/26"
        if direction == .debit {
            candidates.append(firstGroup(#"(?im)^\s*to\s+(.+?)\s*$"#, in: raw))
        } else {
            candidates.append(firstGroup(#"(?im)^\s*from\s+(?!.*\b(?:a/c|acct|account)\b)(.+?)\s*$"#, in: raw))
        }
        // ICICI card: "spent using ICICI Bank Card XX1234 on 06-Nov-26 on SWIGGY."
        candidates.append(firstGroup(#"(?i)\bon\s+\d{1,2}[-/][A-Za-z0-9]{2,3}[-/]\d{2,4}\s+(?:on|at)\s+(.+?)"# + stop, in: flat))
        // Card spends: "At SWIGGY On 2026-11-06"
        if isCard {
            candidates.append(firstGroup(#"(?i)\bat\s+(.+?)"# + stop, in: flat))
        }
        if direction == .debit {
            candidates.append(firstGroup(#"(?i)\b(?:to|towards|for)\s+(?:vpa\s+)?(.+?)"# + stop, in: flat))
            candidates.append(firstGroup(#"(?i)\bat\s+(.+?)"# + stop, in: flat))
        } else {
            candidates.append(firstGroup(#"(?i)\b(?:from|by)\s+(?:vpa\s+)?(.+?)"# + stop, in: flat))
        }

        for c in candidates {
            guard let cleaned = clean(c) else { continue }
            return cleaned
        }
        return direction == .credit ? "Incoming money" : "Unknown"
    }

    private static func clean(_ s: String?) -> String? {
        guard var s = s?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:-"))
        let l = s.lowercased()
        let bad = ["a/c", "acct", "account", "bank card", "your ", "rs", "inr"]
        if s.count < 2 || bad.contains(where: { l.hasPrefix($0) || l.contains(" a/c") }) { return nil }
        if l.range(of: #"^[0-9\-/: ]+$"#, options: .regularExpression) != nil { return nil }
        if s.count > 40 { s = String(s.prefix(40)) }
        return s
    }

    static func extractDate(_ flat: String, receivedAt: Date) -> Date {
        let cal = Calendar.current
        var comps: DateComponents?
        let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]

        if let m = firstMatch(#"\b(\d{1,2})[-/ ]([A-Za-z]{3})[-/ ,]*(\d{2,4})\b"#, in: flat),
           let idx = months.firstIndex(of: m[2].lowercased()) {
            comps = DateComponents(year: year(m[3]), month: idx + 1, day: Int(m[1]))
        } else if let m = firstMatch(#"\b(20\d{2})-(\d{1,2})-(\d{1,2})"#, in: flat) {
            comps = DateComponents(year: Int(m[1]), month: Int(m[2]), day: Int(m[3]))
        } else if let m = firstMatch(#"\b(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})\b"#, in: flat) {
            comps = DateComponents(year: year(m[3]), month: Int(m[2]), day: Int(m[1]))
        }

        guard var c = comps, let day = cal.date(from: c) else { return receivedAt }
        // Bad parse guard: future dates or >60 days old fall back to when the SMS arrived.
        if day > receivedAt.addingTimeInterval(86_400) || day < receivedAt.addingTimeInterval(-60 * 86_400) {
            return receivedAt
        }
        if cal.isDate(day, inSameDayAs: receivedAt) { return receivedAt }
        c.hour = 12
        return cal.date(from: c) ?? day
    }

    private static func year(_ s: String) -> Int? {
        guard let y = Int(s) else { return nil }
        return y < 100 ? 2000 + y : y
    }

    // MARK: - Regex helpers

    static func firstMatch(_ pattern: String, in text: String) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return (0..<m.numberOfRanges).map { i in
            guard let r = Range(m.range(at: i), in: text) else { return "" }
            return String(text[r])
        }
    }

    static func firstGroup(_ pattern: String, in text: String) -> String? {
        guard let m = firstMatch(pattern, in: text), m.count > 1, !m[1].isEmpty else { return nil }
        return m[1]
    }

    static func firstIndex(_ pattern: String, in text: String) -> Int? {
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return m.range.location
    }
}
