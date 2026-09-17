import Foundation

enum JSONValue {
    static func object(from data: Data) -> [String: Any]? {
        (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    static func object(from string: String) -> [String: Any]? {
        guard let data = string.data(using: .utf8) else { return nil }
        return object(from: data)
    }

    static func string(_ value: Any?) -> String? {
        switch value {
        case let text as String:
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }

    static func bool(_ value: Any?) -> Bool {
        switch value {
        case let flag as Bool:
            flag
        case let text as String:
            ["1", "true", "yes"].contains(text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        default:
            false
        }
    }

    static func int(_ value: Any?) -> Int? {
        switch value {
        case let number as Int:
            number
        case let number as NSNumber:
            number.intValue
        case let text as String:
            Int(text.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            nil
        }
    }

    static func double(_ value: Any?) -> Double? {
        switch value {
        case let number as Double:
            number
        case let number as Int:
            Double(number)
        case let number as NSNumber:
            number.doubleValue
        case let text as String:
            Double(text.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "%")))
        default:
            nil
        }
    }

    static func value(_ object: [String: Any], _ path: String) -> Any? {
        let parts = path.split(separator: ".").map(String.init)
        var current: Any = object
        for part in parts {
            guard let dict = current as? [String: Any] else { return nil }
            guard let next = dict[part] else { return nil }
            current = next
        }
        return current
    }

    static func firstString(_ object: [String: Any], paths: [String]) -> String? {
        for path in paths {
            if let text = string(value(object, path)) {
                return text
            }
        }
        return nil
    }

    static func firstDouble(_ object: [String: Any], paths: [String]) -> Double? {
        for path in paths {
            if let number = double(value(object, path)) {
                return number
            }
        }
        return nil
    }

    static func clampPercent(_ value: Double) -> Double {
        min(max(value, 0), 100)
    }
}
