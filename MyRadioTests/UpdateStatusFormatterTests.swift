//
//  UpdateStatusFormatterTests.swift
//  MyRadioTests
//

import Foundation
import Testing
@testable import MyRadio

struct UpdateStatusFormatterTests {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - lastChecked

    @Test func lastCheckedNilSaysNotChecked() {
        #expect(UpdateStatusFormatter.lastChecked(at: nil, now: now) == "Not checked yet")
    }

    @Test func lastCheckedJustNowWithinHalfMinute() {
        let recent = now.addingTimeInterval(-5)
        #expect(UpdateStatusFormatter.lastChecked(at: recent, now: now) == "Last checked just now")
    }

    @Test func lastCheckedHasPrefix() {
        // We don't lock the locale-formatted suffix, but the "Last checked " prefix is ours.
        let earlier = now.addingTimeInterval(-12 * 60)
        let result = UpdateStatusFormatter.lastChecked(at: earlier, now: now)
        #expect(result.hasPrefix("Last checked "))
    }

    // MARK: - nextCheck

    @Test func nextCheckNilWhenNeverChecked() {
        #expect(UpdateStatusFormatter.nextCheck(after: nil, interval: 3600, now: now) == nil)
    }

    @Test func nextCheckShowsRoundedRemainder() {
        let lastCheck = now.addingTimeInterval(-30 * 60)            // 30 min ago
        let result = UpdateStatusFormatter.nextCheck(after: lastCheck, interval: 24 * 3600, now: now)
        #expect(result == "next check in ~23h")
    }

    @Test func nextCheckMinutesWhenLessThanHour() {
        let lastCheck = now.addingTimeInterval(-(24 * 3600 - 5 * 60))  // 5 min remaining
        let result = UpdateStatusFormatter.nextCheck(after: lastCheck, interval: 24 * 3600, now: now)
        #expect(result == "next check in ~5 min")
    }

    @Test func nextCheckDueWhenIntervalPassed() {
        let lastCheck = now.addingTimeInterval(-2 * 24 * 3600)
        let result = UpdateStatusFormatter.nextCheck(after: lastCheck, interval: 24 * 3600, now: now)
        #expect(result == "next check due")
    }

    // MARK: - approximateDuration

    @Test func approximateDurationBuckets() {
        #expect(UpdateStatusFormatter.approximateDuration(20)        == "~1 min")
        #expect(UpdateStatusFormatter.approximateDuration(5 * 60)    == "~5 min")
        #expect(UpdateStatusFormatter.approximateDuration(2 * 3600)  == "~2h")
        #expect(UpdateStatusFormatter.approximateDuration(86_400)    == "~1 day")
        #expect(UpdateStatusFormatter.approximateDuration(3 * 86_400) == "~3 days")
    }
}
