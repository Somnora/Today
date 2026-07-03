import SwiftUI

struct ReadingMetrics {
    let density: ReadingDensity
    private let typeScale: CGFloat

    /// `typeScale` comes from `@ScaledMetric` in the owning view so reading
    /// type follows the system Dynamic Type setting. It is clamped so the
    /// editorial layout keeps its shape at the extreme accessibility sizes;
    /// spacing and padding intentionally stay fixed.
    init(density: ReadingDensity, typeScale: CGFloat = 1) {
        self.density = density
        self.typeScale = min(max(typeScale, 0.9), 1.5)
    }

    private func scaled(_ size: CGFloat) -> CGFloat {
        (size * typeScale).rounded()
    }

    // MARK: Root screens

    var rootTopPadding: CGFloat {
        switch density {
        case .compact: return 8
        case .standard: return 10
        case .comfortable: return 12
        }
    }

    var rootStackSpacing: CGFloat {
        switch density {
        case .compact: return 18
        case .standard: return 22
        case .comfortable: return 24
        }
    }

    var rootTitleSize: CGFloat {
        switch density {
        case .compact: return scaled(38)
        case .standard: return scaled(42)
        case .comfortable: return scaled(44)
        }
    }

    var rootSubtitleSize: CGFloat { scaled(13) }

    /// Spacing around the small archive header used on Explore and Preferences.
    var archiveHeaderSpacing: CGFloat {
        switch density {
        case .compact: return 6
        case .standard: return 7
        case .comfortable: return 9
        }
    }

    /// Outer spacing for Today's stacked masthead/title/morningNote header block.
    var todayHeaderOuterSpacing: CGFloat {
        switch density {
        case .compact: return 12
        case .standard: return 14
        case .comfortable: return 16
        }
    }

    /// Inner spacing between the masthead, title, and date line on Today.
    var todayHeaderInnerSpacing: CGFloat {
        switch density {
        case .compact: return 6
        case .standard: return 7
        case .comfortable: return 9
        }
    }

    // MARK: Event card

    var cardYearSize: CGFloat {
        switch density {
        case .compact: return scaled(31)
        case .standard: return scaled(34)
        case .comfortable: return scaled(36)
        }
    }

    var cardTitleSize: CGFloat {
        switch density {
        case .compact: return scaled(23)
        case .standard: return scaled(25)
        case .comfortable: return scaled(27)
        }
    }

    var cardSummarySize: CGFloat {
        switch density {
        case .compact: return scaled(15)
        case .standard: return scaled(16)
        case .comfortable: return scaled(17)
        }
    }

    var cardContextSize: CGFloat {
        switch density {
        case .compact: return scaled(14)
        case .standard: return scaled(15)
        case .comfortable: return scaled(16)
        }
    }

    var cardPadding: CGFloat {
        switch density {
        case .compact: return 19
        case .standard: return 22
        case .comfortable: return 24
        }
    }

    var cardStackSpacing: CGFloat {
        switch density {
        case .compact: return 15
        case .standard: return 18
        case .comfortable: return 20
        }
    }

    var cardTitleStackSpacing: CGFloat {
        switch density {
        case .compact: return 8
        case .standard: return 10
        case .comfortable: return 11
        }
    }

    var cardSummaryLineSpacing: CGFloat {
        switch density {
        case .compact: return scaled(4)
        case .standard: return scaled(5)
        case .comfortable: return scaled(6)
        }
    }

    var cardContextLineSpacing: CGFloat {
        switch density {
        case .compact: return scaled(2)
        case .standard: return scaled(3)
        case .comfortable: return scaled(4)
        }
    }

    // MARK: Event detail

    var detailTopPadding: CGFloat {
        switch density {
        case .compact: return 6
        case .standard: return 8
        case .comfortable: return 10
        }
    }

    var detailRootSpacing: CGFloat {
        switch density {
        case .compact: return 22
        case .standard: return 26
        case .comfortable: return 30
        }
    }

    var detailHeadingSpacing: CGFloat {
        switch density {
        case .compact: return 12
        case .standard: return 14
        case .comfortable: return 18
        }
    }

    var detailYearSize: CGFloat {
        switch density {
        case .compact: return scaled(40)
        case .standard: return scaled(44)
        case .comfortable: return scaled(46)
        }
    }

    var detailTitleSize: CGFloat {
        switch density {
        case .compact: return scaled(28)
        case .standard: return scaled(30)
        case .comfortable: return scaled(32)
        }
    }

    var detailLeadSize: CGFloat {
        switch density {
        case .compact: return scaled(18)
        case .standard: return scaled(20)
        case .comfortable: return scaled(21)
        }
    }

    var detailBodySize: CGFloat {
        switch density {
        case .compact: return scaled(16)
        case .standard: return scaled(17)
        case .comfortable: return scaled(18)
        }
    }

    var detailContextSize: CGFloat {
        switch density {
        case .compact: return scaled(16)
        case .standard: return scaled(17)
        case .comfortable: return scaled(18)
        }
    }

    var detailEditorialPadding: CGFloat {
        switch density {
        case .compact: return 18
        case .standard: return 20
        case .comfortable: return 22
        }
    }

    var detailLeadLineSpacing: CGFloat {
        switch density {
        case .compact: return scaled(6)
        case .standard: return scaled(7)
        case .comfortable: return scaled(8)
        }
    }

    var detailBodyLineSpacing: CGFloat {
        switch density {
        case .compact: return scaled(7)
        case .standard: return scaled(8)
        case .comfortable: return scaled(9)
        }
    }

    var detailContextLineSpacing: CGFloat {
        switch density {
        case .compact: return scaled(3)
        case .standard: return scaled(4)
        case .comfortable: return scaled(5)
        }
    }

    var detailEditorialBodySize: CGFloat {
        switch density {
        case .compact: return scaled(15)
        case .standard: return scaled(16)
        case .comfortable: return scaled(17)
        }
    }

    var detailEditorialBodyLineSpacing: CGFloat {
        switch density {
        case .compact: return scaled(6)
        case .standard: return scaled(7)
        case .comfortable: return scaled(8)
        }
    }
}
