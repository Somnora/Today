import SwiftUI

struct ReadingMetrics {
    let density: ReadingDensity

    init(density: ReadingDensity) {
        self.density = density
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
        case .compact: return 38
        case .standard: return 42
        case .comfortable: return 44
        }
    }

    var rootSubtitleSize: CGFloat { 13 }

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
        case .compact: return 31
        case .standard: return 34
        case .comfortable: return 36
        }
    }

    var cardTitleSize: CGFloat {
        switch density {
        case .compact: return 23
        case .standard: return 25
        case .comfortable: return 27
        }
    }

    var cardSummarySize: CGFloat {
        switch density {
        case .compact: return 15
        case .standard: return 16
        case .comfortable: return 17
        }
    }

    var cardContextSize: CGFloat {
        switch density {
        case .compact: return 14
        case .standard: return 15
        case .comfortable: return 16
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
        case .compact: return 4
        case .standard: return 5
        case .comfortable: return 6
        }
    }

    var cardContextLineSpacing: CGFloat {
        switch density {
        case .compact: return 2
        case .standard: return 3
        case .comfortable: return 4
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
        case .compact: return 40
        case .standard: return 44
        case .comfortable: return 46
        }
    }

    var detailTitleSize: CGFloat {
        switch density {
        case .compact: return 28
        case .standard: return 30
        case .comfortable: return 32
        }
    }

    var detailLeadSize: CGFloat {
        switch density {
        case .compact: return 18
        case .standard: return 20
        case .comfortable: return 21
        }
    }

    var detailBodySize: CGFloat {
        switch density {
        case .compact: return 16
        case .standard: return 17
        case .comfortable: return 18
        }
    }

    var detailContextSize: CGFloat {
        switch density {
        case .compact: return 16
        case .standard: return 17
        case .comfortable: return 18
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
        case .compact: return 6
        case .standard: return 7
        case .comfortable: return 8
        }
    }

    var detailBodyLineSpacing: CGFloat {
        switch density {
        case .compact: return 7
        case .standard: return 8
        case .comfortable: return 9
        }
    }

    var detailContextLineSpacing: CGFloat {
        switch density {
        case .compact: return 3
        case .standard: return 4
        case .comfortable: return 5
        }
    }

    var detailEditorialBodySize: CGFloat {
        switch density {
        case .compact: return 15
        case .standard: return 16
        case .comfortable: return 17
        }
    }

    var detailEditorialBodyLineSpacing: CGFloat {
        switch density {
        case .compact: return 6
        case .standard: return 7
        case .comfortable: return 8
        }
    }
}
