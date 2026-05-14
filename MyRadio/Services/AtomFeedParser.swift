//
//  AtomFeedParser.swift
//  MyRadio
//
//  Minimal Atom feed parser tailored to GitHub /releases.atom shape.
//

import Foundation

final class AtomFeedParser: NSObject, XMLParserDelegate {
    struct LatestEntry {
        let version: String
        let url: URL
    }

    /// Returns the newest non-prerelease entry, or nil if none.
    static func parseLatestStable(data: Data) -> LatestEntry? {
        let delegate = AtomFeedParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.entries.first { !UpdateChecker.isPrerelease($0.tag) }
            .flatMap { entry in
                guard let version = extractVersion(fromTag: entry.tag) ?? extractVersion(fromTitle: entry.title),
                      let url = entry.url else { return nil }
                return LatestEntry(version: version, url: url)
            }
    }

    private struct RawEntry {
        var title: String
        var tag: String   // last path segment of href, e.g. "v1.1.2"
        var url: URL?
    }

    private var entries: [RawEntry] = []
    private var insideEntry = false
    private var currentElement: String?
    private var titleBuffer = ""

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String: String]) {
        if elementName == "entry" {
            insideEntry = true
            entries.append(RawEntry(title: "", tag: "", url: nil))
            titleBuffer = ""
            return
        }
        guard insideEntry else { return }
        currentElement = elementName
        if elementName == "link", entries.last?.url == nil {
            let rel = attributeDict["rel"] ?? "alternate"
            if rel == "alternate", let href = attributeDict["href"], let url = URL(string: href) {
                entries[entries.count - 1].url = url
                entries[entries.count - 1].tag = url.lastPathComponent
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard insideEntry, currentElement == "title" else { return }
        titleBuffer += string
    }

    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?) {
        if elementName == "title", insideEntry, entries.last?.title.isEmpty == true {
            entries[entries.count - 1].title = titleBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            titleBuffer = ""
        }
        if elementName == "entry" {
            insideEntry = false
        }
        currentElement = nil
    }

    /// Strip leading "v" and accept "1", "1.2", "1.2.3", "1.2.3.4".
    static func extractVersion(fromTag tag: String) -> String? {
        let stripped = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        return matchVersion(in: stripped)
    }

    static func extractVersion(fromTitle title: String) -> String? {
        matchVersion(in: title)
    }

    private static func matchVersion(in raw: String) -> String? {
        let pattern = #"(\d+(?:\.\d+){0,3})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(raw.startIndex..., in: raw)
        guard let match = regex.firstMatch(in: raw, range: range),
              let r = Range(match.range(at: 1), in: raw) else { return nil }
        return String(raw[r])
    }
}
