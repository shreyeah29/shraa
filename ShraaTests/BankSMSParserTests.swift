import XCTest
@testable import Shraa

final class BankSMSParserTests: XCTestCase {

    // 6 Nov 2026, 20:15 local
    let received = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 6, hour: 20, minute: 15))!

    private func txn(_ sms: String, file: StaticString = #filePath, line: UInt = #line) -> ParsedTxn? {
        guard case .txn(let t) = BankSMSParser.parse(sms, receivedAt: received) else {
            XCTFail("Expected a transaction for: \(sms)", file: file, line: line)
            return nil
        }
        return t
    }

    // MARK: Shreya's real samples

    func testHDFCUPICredit() {
        let t = txn("Credit Alert!\nRs.8000.00 credited to HDFC Bank A/c XX1481 on 06-11-26 from VPA *80-2@ibl (UPI 530912345678)")
        XCTAssertEqual(t?.amount, 8000)
        XCTAssertEqual(t?.direction, .credit)
        XCTAssertEqual(t?.bank, "HDFC")
        XCTAssertEqual(t?.accountLast4, "1481")
        XCTAssertEqual(t?.merchant, "*80-2@ibl")
        XCTAssertEqual(t?.upiRef, "530912345678")
    }

    func testHDFCUPICreditTruncated() {
        let t = txn("Credit Alert!\nRs.8000.00 credited to HDFC Bank A/c XX1481 on 06-11-26 from VPA *80-2@ibl (UPI ")
        XCTAssertEqual(t?.amount, 8000)
        XCTAssertNil(t?.upiRef)
    }

    func testICICIUPIDebit() {
        let t = txn("ICICI Bank Acct XX383 debited for Rs 483.00 on 06-Nov-26; Swiggy Ltd credited. UPI:530998765432. Call 18002662 for dispute. SMS BLOCK 383 to 9215676766.")
        XCTAssertEqual(t?.amount, 483)
        XCTAssertEqual(t?.direction, .debit)
        XCTAssertEqual(t?.bank, "ICICI")
        XCTAssertEqual(t?.accountLast4, "383")
        XCTAssertEqual(t?.merchant, "Swiggy Ltd")
        XCTAssertEqual(Categorizer.category(for: t!.merchant, direction: .debit, isBillPayment: false, rules: []), .food)
    }

    // MARK: Other common formats

    func testHDFCSentMultiline() {
        let t = txn("Sent Rs.250.00\nFrom HDFC Bank A/C *1481\nTo ZEPTO MARKETPLACE PRIVATE LIMITED\nOn 06/11/26\nRef 530911112222\nNot You?\nCall 18002586161/SMS BLOCK UPI to 7308080808")
        XCTAssertEqual(t?.direction, .debit)
        XCTAssertEqual(t?.merchant, "ZEPTO MARKETPLACE PRIVATE LIMITED")
        XCTAssertEqual(t?.upiRef, "530911112222")
    }

    func testHDFCCardSpend() {
        let t = txn("Spent Rs.1299 On HDFC Bank Card 4521 At AMAZON PAY INDIA On 2026-11-06:20:10:05 Not You? To Block+Reissue Call 18002586161")
        XCTAssertEqual(t?.amount, 1299)
        XCTAssertEqual(t?.isCard, true)
        XCTAssertEqual(t?.accountLast4, "4521")
        XCTAssertEqual(t?.merchant, "AMAZON PAY INDIA")
    }

    func testICICICreditCardSpend() {
        let t = txn("INR 649.00 spent using ICICI Bank Card XX9012 on 06-Nov-26 on NETFLIX. Avl Limit: INR 1,24,351.00. If not you, call 1800 2662/SMS BLOCK 9012 to 9215676766")
        XCTAssertEqual(t?.amount, 649)
        XCTAssertEqual(t?.isCreditCard, true)
        XCTAssertEqual(t?.merchant, "NETFLIX")
    }

    func testICICICreditFromPerson() {
        let t = txn("Dear Customer, Acct XX383 is credited with Rs 25,000.00 on 05-Nov-26 from RAHUL KUMAR. UPI:530955556666-ICICI Bank.")
        XCTAssertEqual(t?.amount, 25000)
        XCTAssertEqual(t?.direction, .credit)
        XCTAssertEqual(t?.merchant, "RAHUL KUMAR")
        XCTAssertEqual(Calendar.current.component(.day, from: t!.date), 5)
    }

    func testCreditCardBillPaymentIsTransfer() {
        let t = txn("Payment of Rs 15,000.00 has been received on your ICICI Bank Credit Card Account 4xxx9012 on 06-Nov-26. Thank you.")
        XCTAssertEqual(t?.isCardBillPayment, true)
        XCTAssertEqual(t?.accountLast4, "9012")
    }

    func testHDFCDebitToVPA() {
        let t = txn("Rs.120 debited from HDFC Bank A/c **1481 on 06-11-26 to VPA uber.rides@ybl (UPI Ref No 530977778888). Not you? Call 18002586161")
        XCTAssertEqual(t?.merchant, "uber.rides@ybl")
        XCTAssertEqual(t?.upiRef, "530977778888")
        XCTAssertEqual(Categorizer.category(for: t!.merchant, direction: .debit, isBillPayment: false, rules: []), .transport)
    }

    // MARK: Ignored

    func testIgnoresOTPAndReminders() {
        XCTAssertEqual(BankSMSParser.parse("123456 is OTP for txn of INR 499.00 at AMAZON on HDFC Bank Card 4521.", receivedAt: received), .ignore)
        XCTAssertEqual(BankSMSParser.parse("Your ICICI Bank Credit Card XX9012 statement: Total Amt Due Rs 12,340, Min Amt Due Rs 620, due by 20-Nov-26.", receivedAt: received), .ignore)
        XCTAssertEqual(BankSMSParser.parse("Get a pre-approved loan of Rs 5,00,000 from HDFC Bank. Apply now!", receivedAt: received), .ignore)
    }

    func testRuleKeyword() {
        XCTAssertEqual(Categorizer.ruleKeyword(from: "SWIGGY LTD"), "swiggy")
        XCTAssertEqual(Categorizer.ruleKeyword(from: "uber.rides@ybl"), "uber.rides")
    }
}
