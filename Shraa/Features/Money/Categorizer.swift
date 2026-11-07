import Foundation

/// Guesses a category from merchant / UPI names. Your own corrections (MerchantRule) always win.
enum Categorizer {
    static let builtIn: [(SpendCategory, [String])] = [
        (.transfers, ["cred club", "cred.club", "credit card payment", "cc payment", "self transfer", "billdesk cc"]),
        (.food, ["swiggy", "zomato", "domino", "pizza", "mcdonald", "kfc", "starbucks", "cafe", "restaurant",
                 "burger", "eatsure", "box8", "chaayos", "haldiram", "biryani", "bakery", "dunkin", "subway",
                 "third wave", "blue tokai", "hotel", "food", "kitchen", "dhaba"]),
        (.groceries, ["blinkit", "zepto", "bigbasket", "instamart", "dmart", "jiomart", "grofers",
                      "reliance fresh", "ratnadeep", "more retail", "dunzo", "milk", "kirana", "supermarket",
                      "vegetable", "fruits"]),
        (.transport, ["uber", "olacabs", "ola cabs", "ani technologies", "rapido", "metro", "namma yatri", "fastag", "parking", "bmtc", "tsrtc"]),
        (.fuel, ["petrol", "fuel", "hpcl", "bpcl", "iocl", "indian oil", "shell", "bharat petroleum"]),
        (.subscriptions, ["netflix", "spotify", "prime video", "amazon prime", "hotstar", "youtube", "apple.com",
                          "google play", "openai", "anthropic", "claude", "chatgpt", "icloud", "linkedin",
                          "jiocinema", "sonyliv", "zee5", "runway", "canva", "notion"]),
        (.bills, ["airtel", "jio", "vodafone", "bsnl", "bescom", "electricity", "tneb", "tsspdcl", "apspdcl",
                  "act fibernet", "broadband", "recharge", "bharat gas", "indane", "hp gas", "water bill",
                  "postpaid", "dth", "tata play"]),
        (.shopping, ["amazon", "flipkart", "myntra", "ajio", "meesho", "nykaa", "tata cliq", "croma",
                     "reliance digital", "ikea", "lenskart", "zara", "h&m", "westside", "lifestyle", "pantaloons"]),
        (.entertainment, ["bookmyshow", "pvr", "inox", "district", "steam", "playstation", "paytm insider"]),
        (.health, ["apollo", "pharmeasy", "1mg", "netmeds", "medplus", "hospital", "clinic", "pharmacy",
                   "diagnostic", "dental", "practo"]),
        (.fitness, ["cult", "cultfit", "gym", "decathlon", "healthifyme", "fitness"]),
        (.education, ["udemy", "coursera", "unacademy", "byju", "upgrad", "college", "school", "exam", "course"]),
        (.travel, ["irctc", "makemytrip", "goibibo", "indigo", "air india", "akasa", "redbus", "oyo",
                   "cleartrip", "booking.com", "airbnb", "ixigo", "spicejet", "vistara"]),
        (.investments, ["zerodha", "groww", "upstox", "kuvera", "mutual fund", "nps", "ppf", "indmoney",
                        "smallcase"]),
        (.rent, ["rent", "nobroker", "housing.com"])
    ]

    static func category(for merchant: String, direction: TxnDirection, isBillPayment: Bool,
                         rules: [(keyword: String, category: SpendCategory)]) -> SpendCategory {
        if isBillPayment { return .transfers }
        let m = merchant.lowercased()
        if let rule = rules.first(where: { !$0.keyword.isEmpty && m.contains($0.keyword) }) {
            return rule.category
        }
        if let hit = builtIn.first(where: { $0.1.contains(where: { m.contains($0) }) }) {
            // Refunds from a shop are still that shop's category, so the category total nets out.
            return hit.0
        }
        return direction == .credit ? .income : .other
    }

    /// The part of a merchant name worth remembering as a rule: "SWIGGY LTD" → "swiggy", "uber.rides@ybl" → "uber.rides".
    static func ruleKeyword(from merchant: String) -> String {
        let lower = merchant.lowercased()
        let base = lower.split(separator: "@").first.map(String.init) ?? lower
        let noise: Set<String> = ["ltd", "limited", "pvt", "private", "india", "technologies", "services", "the"]
        let words = base.split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "." })
            .map(String.init).filter { !noise.contains($0) && $0.count > 1 }
        return words.first ?? base
    }
}
