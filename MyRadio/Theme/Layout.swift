import CoreGraphics

enum AppLayout {
    // Window
    static let windowWidth:    CGFloat = 1280
    static let titlebarHeight: CGFloat = 38
    static let contentHeight:  CGFloat = 760
    static let windowHeight:   CGFloat = titlebarHeight + contentHeight  // 798

    // Panels
    static let playerWidth:    CGFloat = 420
    static let debugHeight:    CGFloat = 240

    // Player padding
    static let playerPaddingH: CGFloat = 26
    static let playerPaddingT: CGFloat = 22
    static let playerPaddingB: CGFloat = 18

    // Border radii
    static let rWindow: CGFloat = 12
    static let rLg:     CGFloat = 14
    static let rMd:     CGFloat = 10
    static let rSm:     CGFloat = 7
    static let rPill:   CGFloat = 999

    // Station row
    static let coverSize:      CGFloat = 44
    static let rowNumWidth:    CGFloat = 28
    static let rowGap:         CGFloat = 14
    static let rowPaddingV:    CGFloat = 8
    static let rowPaddingH:    CGFloat = 8

    // Transport
    static let playButtonSize: CGFloat = 56

    // Debug
    static let debugHeadHeight: CGFloat = 36

    // Traffic lights (macOS system positions)
    static let trafficLightsX: CGFloat = 14
    static let trafficLightsY: CGFloat = 13
    static let trafficDotSize: CGFloat = 12
    static let trafficGap:     CGFloat = 8
}
