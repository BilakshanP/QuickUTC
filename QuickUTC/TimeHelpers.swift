import Foundation

/// Parses a time string like "14:30", "2pm", "0930" into (hour, minute) tuple.
func parseTime(_ input: String) -> (Int, Int)? {
    let s = input.trimmingCharacters(in: .whitespaces).lowercased()
    if s.isEmpty { return nil }

    var h: Int, m: Int
    let isPM = s.hasSuffix("pm")
    let isAM = s.hasSuffix("am")
    let stripped = s.replacingOccurrences(of: "pm", with: "")
                    .replacingOccurrences(of: "am", with: "")
                    .trimmingCharacters(in: .whitespaces)

    if stripped.contains(":") {
        let parts = stripped.split(separator: ":")
        guard parts.count == 2, let hr = Int(parts[0]), let mn = Int(parts[1]) else { return nil }
        h = hr; m = mn
    } else if let num = Int(stripped) {
        if num >= 0 && num <= 23 && stripped.count <= 2 {
            h = num; m = 0
        } else if stripped.count == 3 || stripped.count == 4 {
            h = num / 100; m = num % 100
        } else { return nil }
    } else { return nil }

    if isPM && h < 12 { h += 12 }
    if isAM && h == 12 { h = 0 }

    guard h >= 0 && h < 24 && m >= 0 && m < 60 else { return nil }
    return (h, m)
}
