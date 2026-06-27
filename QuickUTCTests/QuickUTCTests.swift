import Foundation
import Testing
@testable import QuickUTC

@Suite("parseTime")
struct ParseTimeTests {
    @Test("colon format")
    func colonFormat() {
        #expect(parseTime("14:30") == (14, 30))
        #expect(parseTime("0:00") == (0, 0))
        #expect(parseTime("23:59") == (23, 59))
    }

    @Test("bare number as hour")
    func bareHour() {
        #expect(parseTime("9") == (9, 0))
        #expect(parseTime("0") == (0, 0))
        #expect(parseTime("23") == (23, 0))
    }

    @Test("military style (3-4 digits)")
    func militaryStyle() {
        #expect(parseTime("930") == (9, 30))
        #expect(parseTime("1430") == (14, 30))
        #expect(parseTime("0015") == (0, 15))
    }

    @Test("12-hour with am/pm")
    func amPm() {
        #expect(parseTime("2pm") == (14, 0))
        #expect(parseTime("12am") == (0, 0))
        #expect(parseTime("12pm") == (12, 0))
        #expect(parseTime("11:30pm") == (23, 30))
        #expect(parseTime("12:01am") == (0, 1))
    }

    @Test("whitespace and casing")
    func whitespaceAndCasing() {
        #expect(parseTime("  14:30  ") == (14, 30))
        #expect(parseTime("2PM") == (14, 0))
        #expect(parseTime(" 3pm ") == (15, 0))
    }

    @Test("invalid inputs")
    func invalid() {
        #expect(parseTime("") == nil)
        #expect(parseTime("abc") == nil)
        #expect(parseTime("25:00") == nil)
        #expect(parseTime("12:60") == nil)
        #expect(parseTime("99") == nil)
    }
}

@Suite("TimeZoneStore.offsetString")
struct OffsetStringTests {
    @Test("positive offset")
    func positiveOffset() {
        let tz = TimeZone(identifier: "Asia/Kolkata")!
        let result = TimeZoneStore.offsetString(for: tz)
        #expect(result == "UTC+05:30")
    }

    @Test("negative offset")
    func negativeOffset() {
        let tz = TimeZone(identifier: "America/New_York")!
        let result = TimeZoneStore.offsetString(for: tz)
        // Could be -04:00 or -05:00 depending on DST
        #expect(result.hasPrefix("UTC-0"))
    }

    @Test("UTC itself")
    func utcOffset() {
        let tz = TimeZone(identifier: "Etc/GMT")!
        #expect(TimeZoneStore.offsetString(for: tz) == "UTC+00:00")
    }
}

@Suite("TimeZoneStore mutations")
struct StoreTests {
    @Test("add and remove")
    func addRemove() {
        let store = TimeZoneStore()
        store.add("America/New_York")
        #expect(store.contains("America/New_York"))
        store.remove("America/New_York")
        #expect(!store.contains("America/New_York"))
    }

    @Test("add duplicate is no-op")
    func addDuplicate() {
        let store = TimeZoneStore()
        store.add("Europe/London")
        let count = store.selectedIDs.count
        store.add("Europe/London")
        #expect(store.selectedIDs.count == count)
    }

    @Test("moveUp and moveDown")
    func reorder() {
        let store = TimeZoneStore()
        // Set up a clean state
        store.selectedIDs = ["America/New_York", "Europe/London"]
        store.moveDown(0)
        #expect(store.selectedIDs == ["Europe/London", "America/New_York"])
        store.moveUp(1)
        #expect(store.selectedIDs == ["America/New_York", "Europe/London"])
    }

    @Test("makePrimary")
    func makePrimary() {
        let store = TimeZoneStore()
        store.add("Asia/Tokyo")
        store.makePrimary("Asia/Tokyo")
        #expect(store.primaryID == "Asia/Tokyo")
    }

    @Test("displayName uses custom label")
    func customLabel() {
        let store = TimeZoneStore()
        store.add("America/New_York")
        store.customLabels["America/New_York"] = "NYC"
        #expect(store.displayName(for: "America/New_York") == "NYC")
    }
}

@Suite("NameStyle enum")
struct NameStyleTests {
    @Test("rawValue roundtrip")
    func rawValue() {
        #expect(NameStyle(rawValue: "city") == .city)
        #expect(NameStyle(rawValue: "none") == NameStyle.none)
        #expect(NameStyle(rawValue: "abbreviation") == .abbreviation)
        #expect(NameStyle(rawValue: "invalid") == nil)
    }
}

// Helper to compare tuples
func == (lhs: (Int, Int)?, rhs: (Int, Int)?) -> Bool {
    switch (lhs, rhs) {
    case let (.some(l), .some(r)): return l.0 == r.0 && l.1 == r.1
    case (.none, .none): return true
    default: return false
    }
}
