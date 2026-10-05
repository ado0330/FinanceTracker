import Foundation

extension Date {

    // MARK: - Period Boundaries

    /// The first instant of the month containing `self` (00:00:00 on the 1st).
    var startOfMonth: Date {
        Calendar.current.dateInterval(of: .month, for: self)?.start ?? self
    }

    /// The last instant of the month containing `self` (23:59:59 on the last day).
    var endOfMonth: Date {
        guard let end = Calendar.current.dateInterval(of: .month, for: self)?.end else { return self }
        return end.addingTimeInterval(-1)
    }

    /// The first instant of the ISO week containing `self`.
    var startOfWeek: Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: self)?.start ?? self
    }

    /// The last instant of the ISO week containing `self`.
    var endOfWeek: Date {
        guard let end = Calendar.current.dateInterval(of: .weekOfYear, for: self)?.end else { return self }
        return end.addingTimeInterval(-1)
    }

    /// The first instant of the year containing `self` (00:00:00 on Jan 1st).
    var startOfYear: Date {
        Calendar.current.dateInterval(of: .year, for: self)?.start ?? self
    }

    /// The last instant of the year containing `self` (23:59:59 on Dec 31st).
    var endOfYear: Date {
        guard let end = Calendar.current.dateInterval(of: .year, for: self)?.end else { return self }
        return end.addingTimeInterval(-1)
    }

    /// Midnight (00:00:00) on the day of `self`.
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    // MARK: - Granularity Comparisons

    func isSameYear(as other: Date) -> Bool {
        Calendar.current.isDate(self, equalTo: other, toGranularity: .year)
    }

    func isSameMonth(as other: Date) -> Bool {
        Calendar.current.isDate(self, equalTo: other, toGranularity: .month)
    }

    func isSameWeek(as other: Date) -> Bool {
        Calendar.current.isDate(self, equalTo: other, toGranularity: .weekOfYear)
    }

    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, equalTo: other, toGranularity: .day)
    }

    // MARK: - Arithmetic

    /// Safely adds a calendar component without crashing on nil.
    func adding(_ component: Calendar.Component, value: Int) -> Date {
        Calendar.current.date(byAdding: component, value: value, to: self) ?? self
    }

    // MARK: - Chart & Summary Helpers

    /// Returns the **start-of-month** dates for the past `count` months,
    /// ordered oldest → newest. Used to drive the trend line chart X-axis.
    ///
    /// Example: `Date.pastMonthStarts(count: 6)` returns the 1st of each of
    /// the last 6 months up to and including the current month.
    static func pastMonthStarts(count: Int) -> [Date] {
        let now = Date.now
        return (0 ..< count)
            .reversed()
            .compactMap { offset in
                Calendar.current.date(byAdding: .month, value: -offset, to: now)?
                    .startOfMonth
            }
    }

    /// Checks whether `self` falls within [start, end] (inclusive).
    func isInRange(_ start: Date, _ end: Date) -> Bool {
        self >= start && self <= end
    }

    // MARK: - Display Strings

    /// "October 2026"
    var monthYearString: String {
        formatted(.dateTime.month(.wide).year())
    }

    /// "Oct"
    var shortMonthString: String {
        formatted(.dateTime.month(.abbreviated))
    }

    /// "Oct 4, 2026"
    var shortDateString: String {
        formatted(date: .abbreviated, time: .omitted)
    }

    /// "1:15 AM"
    var timeString: String {
        formatted(date: .omitted, time: .shortened)
    }

    /// "Today", "Yesterday", or the short date string.
    var relativeOrShortString: String {
        let cal = Calendar.current
        if cal.isDateInToday(self)     { return "Today" }
        if cal.isDateInYesterday(self) { return "Yesterday" }
        return shortDateString
    }

    /// "Mon, Oct 4"
    var weekdayShortDateString: String {
        formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    // MARK: - Aliases (used by TransactionListView / TransactionRowView)

    /// "October 2026" — month filter in transaction list.
    var monthYearDisplay: String { monthYearString }

    /// "Oct 4, 2026" — compact date shown inside a transaction row.
    var shortDisplay: String { shortDateString }

    /// "Today · 4 Oct 2026", "Yesterday · 3 Oct 2026", or "Fri, 2 Oct 2026"
    var daySectionDisplay: String {
        let cal = Calendar.current
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "d MMM yyyy"
        let dateStr = dayFormatter.string(from: self)
        if cal.isDateInToday(self) {
            return "Today · \(dateStr)"
        } else if cal.isDateInYesterday(self) {
            return "Yesterday · \(dateStr)"
        } else {
            let weekdayFormatter = DateFormatter()
            weekdayFormatter.dateFormat = "EEE, d MMM yyyy"
            return weekdayFormatter.string(from: self)
        }
    }
}
