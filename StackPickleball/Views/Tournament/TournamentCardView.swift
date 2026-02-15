import SwiftUI

struct TournamentCardView: View {
    let tournament: Tournament

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text(tournament.name)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.black)

            // Dates
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 14))
                    .foregroundColor(.stackGreen)
                Text(dateRange)
                    .font(.system(size: 15))
                    .foregroundColor(.black)
            }

            // Location
            if let location = tournament.locationName {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.circle")
                        .font(.system(size: 14))
                        .foregroundColor(.stackGreen)
                    Text(location)
                        .font(.system(size: 15))
                        .foregroundColor(.black)
                }
            }

            // Skill divisions
            if let divisions = tournament.skillDivisions, !divisions.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "trophy")
                        .font(.system(size: 14))
                        .foregroundColor(.stackGreen)
                    Text(divisions.joined(separator: ", "))
                        .font(.system(size: 14))
                        .foregroundColor(.stackSecondaryText)
                }
            }

            // Description
            if let desc = tournament.description {
                Text(desc)
                    .font(.system(size: 14))
                    .foregroundColor(.stackSecondaryText)
                    .lineLimit(2)
            }

            // Registration link
            if let urlString = tournament.registrationUrl, let url = URL(string: urlString) {
                Link(destination: url) {
                    Text("Register")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.stackGreen)
                        .cornerRadius(10)
                }
            }
        }
        .padding(16)
        .background(Color.stackCardWhite)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 3)
    }

    private var dateRange: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let start = formatter.string(from: tournament.startDate)
        let end = formatter.string(from: tournament.endDate)
        return "\(start) - \(end)"
    }
}
