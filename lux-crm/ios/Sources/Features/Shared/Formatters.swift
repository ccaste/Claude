import Foundation

enum Money {
    static func string(_ value: Double) -> String {
        value.formatted(.currency(code: "USD"))
    }
}

extension Double {
    var usd: String { Money.string(self) }

    // Trim trailing ".0" so "120.0 ft" reads "120 ft".
    var trimmed: String {
        self == rounded() ? String(Int(self)) : String(self)
    }

    func rounded(to places: Int) -> Double {
        let p = pow(10.0, Double(places))
        return (self * p).rounded() / p
    }
}

extension String {
    var nilIfEmpty: String? { trimmingCharacters(in: .whitespaces).isEmpty ? nil : self }
}

enum SeasonYear {
    // The holiday season we're selling/working. After mid-year, default to the
    // upcoming season; early in the year, you're likely still on the prior one.
    static var current: Int {
        let now = Calendar.current.dateComponents([.year, .month], from: Date())
        let year = now.year ?? 2026
        return (now.month ?? 1) >= 6 ? year : year - 1
    }
}
