import Foundation

/// Type aliases + defensive accessors that mirror the Dart models' `fromJson`
/// style: every field has a sane default, so a missing/null key never crashes.
typealias JSON = [String: Any]

extension JSON {
    /// String, or `def` when missing/null/wrong type.
    func string(_ key: String, _ def: String = "") -> String {
        if let s = self[key] as? String { return s }
        return def
    }
    /// Optional String — nil when missing or null.
    func optString(_ key: String) -> String? {
        if self[key] is NSNull { return nil }
        return self[key] as? String
    }
    /// Int, coercing from double or numeric string (Dart's `_toInt`).
    func int(_ key: String, _ def: Int = 0) -> Int {
        guard let v = self[key] else { return def }
        if let i = v as? Int { return i }
        if let n = v as? NSNumber { return n.intValue }
        if let d = v as? Double { return Int(d) }
        if let s = v as? String, let i = Int(s) { return i }
        return def
    }
    /// Optional Int — nil when missing/null.
    func optInt(_ key: String) -> Int? {
        guard let v = self[key], !(v is NSNull) else { return nil }
        if let i = v as? Int { return i }
        if let n = v as? NSNumber { return n.intValue }
        if let d = v as? Double { return Int(d) }
        if let s = v as? String, let i = Int(s) { return i }
        return nil
    }
    func bool(_ key: String, _ def: Bool = false) -> Bool {
        if let b = self[key] as? Bool { return b }
        return def
    }
    func array(_ key: String) -> [Any] {
        return self[key] as? [Any] ?? []
    }
    func json(_ key: String) -> JSON {
        return self[key] as? JSON ?? [:]
    }
    /// Array of JSON objects.
    func jsonArray(_ key: String) -> [JSON] {
        return array(key).compactMap { $0 as? JSON }
    }
    /// [String: Int] map, e.g. by_category / by_payment.
    func intMap(_ key: String) -> [String: Int] {
        guard let m = self[key] as? JSON else { return [:] }
        var out: [String: Int] = [:]
        for (k, v) in m {
            if let i = v as? Int { out[k] = i }
            else if let n = v as? NSNumber { out[k] = n.intValue }
            else if let d = v as? Double { out[k] = Int(d) }
            else { out[k] = 0 }
        }
        return out
    }
}
