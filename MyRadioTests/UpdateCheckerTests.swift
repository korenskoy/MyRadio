//
//  UpdateCheckerTests.swift
//  MyRadioTests
//

import Foundation
import Testing
@testable import MyRadio

struct UpdateCheckerTests {

    // MARK: - compareSemver

    @Test func equalVersions() {
        #expect(UpdateChecker.compareSemver("1.2.3", "1.2.3") == .orderedSame)
    }

    @Test func minorBump() {
        #expect(UpdateChecker.compareSemver("1.3", "1.2") == .orderedDescending)
        #expect(UpdateChecker.compareSemver("1.2", "1.3") == .orderedAscending)
    }

    @Test func patchBump() {
        #expect(UpdateChecker.compareSemver("1.1.2", "1.1.1") == .orderedDescending)
    }

    @Test func numericNotLexicographic() {
        // The classic semver trap: "1.10" must be greater than "1.2".
        #expect(UpdateChecker.compareSemver("1.10", "1.2") == .orderedDescending)
        #expect(UpdateChecker.compareSemver("1.2", "1.10") == .orderedAscending)
    }

    @Test func differentLengths() {
        // Missing components are treated as 0.
        #expect(UpdateChecker.compareSemver("1.2", "1.2.0") == .orderedSame)
        #expect(UpdateChecker.compareSemver("1.2.1", "1.2") == .orderedDescending)
        #expect(UpdateChecker.compareSemver("2", "1.9.9") == .orderedDescending)
    }

    @Test func leadingZerosAreNumeric() {
        // "01" parses to 1 — same as "1".
        #expect(UpdateChecker.compareSemver("1.01", "1.1") == .orderedSame)
    }

    @Test func nonNumericComponentsTreatedAsZero() {
        // Falls back to 0 for unparseable parts. Defensive, not semver-spec-perfect.
        #expect(UpdateChecker.compareSemver("1.x", "1.0") == .orderedSame)
    }

    // MARK: - isPrerelease

    @Test func stableTagsAreNotPrerelease() {
        #expect(!UpdateChecker.isPrerelease("v1.2.3"))
        #expect(!UpdateChecker.isPrerelease("MyRadio 1.1.1"))
        #expect(!UpdateChecker.isPrerelease("1.0"))
    }

    @Test func prereleaseTagsAreFiltered() {
        #expect(UpdateChecker.isPrerelease("v1.2.0-beta"))
        #expect(UpdateChecker.isPrerelease("v1.2.0-rc1"))
        #expect(UpdateChecker.isPrerelease("v1.0-beta3"))
        #expect(UpdateChecker.isPrerelease("1.0-alpha"))
        #expect(UpdateChecker.isPrerelease("v2.0-preview"))
        #expect(UpdateChecker.isPrerelease("v2.0-dev"))
        #expect(UpdateChecker.isPrerelease("nightly-2026-01-01"))
    }

    @Test func caseInsensitivePrerelease() {
        #expect(UpdateChecker.isPrerelease("v1.0-BETA"))
        #expect(UpdateChecker.isPrerelease("v1.0-Alpha"))
    }

    @Test func substringsInsideOtherWordsDoNotTrigger() {
        // "dev" must not match "developer", "device", "development".
        #expect(!UpdateChecker.isPrerelease("MyRadio 1.0 (developer build)"))
        #expect(!UpdateChecker.isPrerelease("v1.0-developer"))
        // "rc" must not match "march", "research".
        #expect(!UpdateChecker.isPrerelease("MyRadio March release 1.0"))
        #expect(!UpdateChecker.isPrerelease("research-build-1.0"))
        // "beta" must not match "alphabetagram" (synthetic, but proves boundary).
        #expect(!UpdateChecker.isPrerelease("alphabetagram-1.0"))
    }

    // MARK: - AtomFeedParser

    @Test func parserPicksFirstStableEntry() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom">
          <entry>
            <id>tag:github.com,2008:Repository/x/v1.2.0-beta</id>
            <link rel="alternate" type="text/html" href="https://github.com/korenskoy/MyRadio/releases/tag/v1.2.0-beta"/>
            <title>MyRadio 1.2.0-beta</title>
          </entry>
          <entry>
            <id>tag:github.com,2008:Repository/x/v1.1.2</id>
            <link rel="alternate" type="text/html" href="https://github.com/korenskoy/MyRadio/releases/tag/v1.1.2"/>
            <title>MyRadio 1.1.2</title>
          </entry>
          <entry>
            <id>tag:github.com,2008:Repository/x/v1.1.1</id>
            <link rel="alternate" type="text/html" href="https://github.com/korenskoy/MyRadio/releases/tag/v1.1.1"/>
            <title>MyRadio 1.1.1</title>
          </entry>
        </feed>
        """
        let data = Data(xml.utf8)
        let latest = try #require(AtomFeedParser.parseLatestStable(data: data))
        #expect(latest.version == "1.1.2")
        #expect(latest.url.absoluteString == "https://github.com/korenskoy/MyRadio/releases/tag/v1.1.2")
    }

    @Test func parserReturnsNilOnEmptyFeed() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom"></feed>
        """
        #expect(AtomFeedParser.parseLatestStable(data: Data(xml.utf8)) == nil)
    }

    @Test func parserReturnsNilWhenAllPrerelease() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom">
          <entry>
            <link rel="alternate" type="text/html" href="https://github.com/korenskoy/MyRadio/releases/tag/v2.0-beta"/>
            <title>MyRadio 2.0-beta</title>
          </entry>
        </feed>
        """
        #expect(AtomFeedParser.parseLatestStable(data: Data(xml.utf8)) == nil)
    }
}
