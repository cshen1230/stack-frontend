import SwiftUI

struct TournamentCardView: View {
    let tournament: Tournament

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text(tournament.name)
                .font(AppFonts.headline())
                .fontWeight(.bold)
                .foregroundColor(.primary)

            // Dates
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 14))
                    .foregroundColor(.stackGreen)
                Text(dateRange)
                    .font(AppFonts.body())
                    .foregroundColor(.primary)
            }

            // Location
            if let location = tournament.locationName {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.circle")
                        .font(.system(size: 14))
                        .foregroundColor(.stackGreen)
                    Text(location)
                        .font(AppFonts.body())
                        .foregroundColor(.primary)
                }
            }

            // Skill divisions
            if let divisions = tournament.skillDivisions, !divisions.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "trophy")
                        .font(.system(size: 14))
                        .foregroundColor(.stackGreen)
                    Text(divisions.joined(separator: ", "))
                        .font(AppFonts.callout())
                        .foregroundColor(.stackSecondaryText)
                }
            }

            // Description
            if let desc = tournament.description {
                Text(desc)
                    .font(AppFonts.callout())
                    .foregroundColor(.stackSecondaryText)
                    .lineLimit(2)
            }

            // Registration link
            if let urlString = tournament.registrationUrl, let url = URL(string: urlString) {
                Link(destination: url) {
                    Text("Register")
                        .font(AppFonts.body())
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.stackGreen)
                        .cornerRadius(AppConstants.buttonCornerRadius)
                }
            }
        }
        .cardStyle()
    }

    private var dateRange: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let start = formatter.string(from: tournament.startDate)
        let end = formatter.string(from: tournament.endDate)
        return "\(start) - \(end)"
    }
}
