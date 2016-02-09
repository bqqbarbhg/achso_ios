/*

Genres exist in two forms, a culture-invariant ID such as "good_work" or "problem" and a localized string such as "Good work" or "Ongelma".

This mapping is often required so the localizations are defined here.

*/

import Foundation

struct Genre {
    let id: String
    let localizedName: String
    
    static let genres = [
        Genre(id: "good_work", localizedName: NSLocalizedString("good_work", comment: "Video genre for good work")),
        Genre(id: "problem", localizedName: NSLocalizedString("problem", comment: "Video genre for problems")),
        Genre(id: "site_overview", localizedName: NSLocalizedString("site_overview", comment: "Video genre for site overviews")),
        Genre(id: "trick_of_trade", localizedName: NSLocalizedString("trick_of_trade", comment: "Video genre for tricks of trade")),
    ]
    
    init(id: String, localizedName: String) {
        self.id = id
        self.localizedName = localizedName
    }
}
