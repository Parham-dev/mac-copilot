import Foundation

protocol ClockProviding {
    var now: Date { get }
}

struct SystemClockProvider: ClockProviding {
    var now: Date { Date() }
}
