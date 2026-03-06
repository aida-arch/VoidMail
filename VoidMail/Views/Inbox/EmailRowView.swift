import SwiftUI

struct EmailRowView: View {
    let email: Email
    var accountColor: Color = .accentSkyBlue
    @State private var appeared = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Avatar + Account color bar (left side)
            ZStack(alignment: .topLeading) {
                InitialsAvatar(email.from.displayName, size: 44)

                // Account color indicator bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(accountColor)
                    .frame(width: 3, height: 44)
                    .offset(x: -8)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Sender + Timestamp
                HStack {
                    Text(email.from.displayName)
                        .font(email.isRead ? Typo.body : Typo.headline)
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Text(email.date.relativeFormatted)
                        .monoTimestamp()
                }

                // Subject
                Text(email.subject)
                    .font(email.isRead ? Typo.subhead : Typo.body)
                    .foregroundColor(email.isRead ? .textSecondary : .textPrimary)
                    .lineLimit(1)

                // Preview
                Text(email.snippet)
                    .font(Typo.subhead)
                    .foregroundColor(.textTertiary)
                    .lineLimit(2)
                    .lineSpacing(2)

                // Indicators
                HStack(spacing: 10) {
                    if email.isStarred {
                        Image(systemName: "star.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.accentPink)
                    }
                    if !email.attachments.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "paperclip")
                                .font(.system(size: 13))
                            Text("\(email.attachments.count)")
                                .font(Typo.meta)
                        }
                        .foregroundColor(.textTertiary)
                    }
                    if email.aiSummary != nil {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13))
                            .foregroundColor(.accentSkyBlue)
                    }
                    if email.isAIPriority {
                        HStack(spacing: 3) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 11))
                            Text("AI PRIORITY")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(.accentPink)
                    }
                }
                .padding(.top, 2)
            }

            // Unread indicator bar on trailing edge
            if !email.isRead {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.accentSkyBlue)
                    .frame(width: 3, height: 30)
            }
        }
        .padding(20)
        .background(Color.bgEmailRow)
        .cornerRadius(8)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                appeared = true
            }
        }
    }
}

// MARK: - Date Formatting

extension Date {
    var relativeFormatted: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: self)
        } else if calendar.isDateInYesterday(self) {
            return "Yesterday"
        } else if calendar.isDate(self, equalTo: Date(), toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            return formatter.string(from: self)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: self)
        }
    }
}
