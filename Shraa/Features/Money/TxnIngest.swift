import Foundation
import SwiftData

/// Turns SMS / manual input into saved transactions: account matching, categorising, duplicate check.
@MainActor
enum TxnIngest {

    enum Outcome {
        case saved(Txn)
        case duplicate
        case ignored
        case sentToReview
    }

    @discardableResult
    static func ingestSMS(_ text: String, receivedAt: Date = .now, context: ModelContext) -> Outcome {
        switch BankSMSParser.parse(text, receivedAt: receivedAt) {
        case .ignore:
            return .ignored
        case .unreadable:
            context.insert(UnparsedSMS(text: text, receivedAt: receivedAt))
            try? context.save()
            return .sentToReview
        case .txn(let p):
            return save(p, rawText: text, context: context)
        }
    }

    static func save(_ p: ParsedTxn, rawText: String?, context: ModelContext) -> Outcome {
        if isDuplicate(p, context: context) { return .duplicate }

        let account = matchOrCreateAccount(for: p, context: context)
        let rules = (try? context.fetch(FetchDescriptor<MerchantRule>())) ?? []
        let category = Categorizer.category(
            for: p.merchant, direction: p.direction, isBillPayment: p.isCardBillPayment,
            rules: rules.map { ($0.keyword, SpendCategory(rawValue: $0.categoryRaw) ?? .other) })

        let txn = Txn(date: p.date, amount: p.amount, direction: p.direction, merchant: p.merchant,
                      category: category, bank: p.bank, accountLast4: account?.last4 ?? p.accountLast4,
                      isCard: p.isCard, upiRef: p.upiRef, source: .sms, rawText: rawText,
                      isTransfer: category == .transfers)
        context.insert(txn)
        try? context.save()
        return .saved(txn)
    }

    /// Same UPI ref, or same amount + direction + account within 10 minutes.
    static func isDuplicate(_ p: ParsedTxn, context: ModelContext) -> Bool {
        let from = p.date.addingTimeInterval(-600)
        let to = p.date.addingTimeInterval(600)
        let amount = p.amount
        let dir = p.direction.rawValue
        var d = FetchDescriptor<Txn>(predicate: #Predicate {
            $0.amount == amount && $0.directionRaw == dir && $0.date >= from && $0.date <= to
        })
        d.fetchLimit = 10
        let near = (try? context.fetch(d)) ?? []
        if let ref = p.upiRef, near.contains(where: { $0.upiRef == ref }) { return true }
        if let ref = p.upiRef {
            var byRef = FetchDescriptor<Txn>(predicate: #Predicate { $0.upiRef == ref })
            byRef.fetchLimit = 1
            if let hit = try? context.fetch(byRef), !hit.isEmpty { return true }
        }
        return near.contains(where: { $0.accountLast4 == p.accountLast4 || $0.accountLast4.isEmpty })
    }

    static func matchOrCreateAccount(for p: ParsedTxn, context: ModelContext) -> Account? {
        guard !p.accountLast4.isEmpty else { return nil }
        let all = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        // Banks mask differently (XX383 vs XX0383), so match on suffix.
        if let hit = all.first(where: {
            $0.bank == p.bank && ($0.last4.hasSuffix(p.accountLast4) || p.accountLast4.hasSuffix($0.last4))
        }) {
            return hit
        }
        let kind: AccountKind = p.isCreditCard ? .creditCard : (p.isCard ? .debitCard : .bank)
        let name = "\(p.bank) \(kind == .creditCard ? "Credit Card" : kind == .debitCard ? "Debit Card" : "A/c") ••\(p.accountLast4)"
        let acc = Account(name: name, bank: p.bank, last4: p.accountLast4, kind: kind)
        context.insert(acc)
        return acc
    }

    /// When you change a transaction's category, remember it for that merchant.
    static func learn(merchant: String, category: SpendCategory, context: ModelContext) {
        let key = Categorizer.ruleKeyword(from: merchant)
        guard key.count >= 3 else { return }
        let existing = (try? context.fetch(FetchDescriptor<MerchantRule>(predicate: #Predicate { $0.keyword == key }))) ?? []
        if let rule = existing.first {
            rule.categoryRaw = category.rawValue
        } else {
            context.insert(MerchantRule(keyword: key, category: category))
        }
        try? context.save()
    }
}
