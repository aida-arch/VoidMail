import SwiftUI

struct CalendarTabView: View {
    @StateObject private var calendarService = GoogleCalendarService.shared
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var animateGrid = false
    @Binding var showCreateEvent: Bool

    private let calendar = Calendar.current
    private let daysOfWeek = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color.bgDeep.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // MARK: Month Header
                        monthHeader
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                        // Day headers
                        dayOfWeekHeaders
                            .padding(.horizontal, 16)
                            .padding(.top, 16)

                        // Calendar Grid
                        calendarGrid
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                        // Events
                        VoidDivider()
                            .padding(.horizontal, 20)
                            .padding(.top, 16)

                        selectedDayHeader
                            .padding(.horizontal, 20)
                            .padding(.top, 16)

                        eventsTimeline
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                            .padding(.bottom, 140)
                    }
                }

            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showCreateEvent) {
                CreateEventSheet(selectedDate: selectedDate) {
                    Task {
                        await calendarService.fetchEvents(for: selectedDate)
                        await calendarService.fetchMonthEvents(for: currentMonth)
                    }
                }
            }
        }
        .task {
            await calendarService.fetchEvents(for: selectedDate)
            await calendarService.fetchMonthEvents(for: currentMonth)
        }
        .onChange(of: currentMonth) { _, newMonth in
            Task { await calendarService.fetchMonthEvents(for: newMonth) }
        }
    }

    // MARK: - Month Header

    private var monthHeader: some View {
        HStack {
            Text(monthYearString.uppercased())
                .font(Typo.title2)
                .foregroundColor(.textPrimary)
                .tracking(-0.5)

            Spacer()

            HStack(spacing: 16) {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.textSecondary)
                }

                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedDate = Date()
                        currentMonth = Date()
                    }
                    Task { await calendarService.fetchEvents(for: Date()) }
                } label: {
                    Text("TODAY")
                        .font(Typo.mono)
                        .foregroundColor(.textPrimary)
                        .tracking(1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.bgCard)
                        .clipShape(Capsule())
                }

                Button {
                    withAnimation(.spring(response: 0.3)) {
                        currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.textSecondary)
                }
            }
        }
    }

    // MARK: - Day Headers

    private var dayOfWeekHeaders: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 0) {
            ForEach(daysOfWeek, id: \.self) { day in
                Text(day)
                    .font(Typo.mono)
                    .foregroundColor(.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        let days = generateDays()
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                dayCell(day)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.25)) {
                            selectedDate = day.date
                        }
                        Task { await calendarService.fetchEvents(for: day.date) }
                    }
                    .opacity(animateGrid ? 1 : 0)
                    .offset(y: animateGrid ? 0 : 8)
                    .animation(
                        .spring(response: 0.35).delay(Double(index) * 0.008),
                        value: animateGrid
                    )
            }
        }
        .onAppear {
            withAnimation { animateGrid = true }
        }
    }

    private func dayCell(_ day: CalendarDay) -> some View {
        let isSelected = calendar.isDate(day.date, inSameDayAs: selectedDate)
        let dayEvents = calendarService.monthEvents(on: day.date)

        return VStack(spacing: 4) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.textPrimary)
                        .frame(width: 36, height: 36)
                } else if day.isToday {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.textPrimary, lineWidth: 1.5)
                        .frame(width: 36, height: 36)
                }

                Text("\(day.dayNumber)")
                    .font(.system(size: 15, weight: isSelected || day.isToday ? .bold : .regular, design: .monospaced))
                    .foregroundColor(
                        isSelected ? .textInverse :
                        day.isToday ? .textPrimary :
                        day.isCurrentMonth ? .textSecondary : .textTertiary
                    )
            }
            .frame(width: 36, height: 36)

            // Event indicator dots — uses month-wide fetch
            if !dayEvents.isEmpty {
                HStack(spacing: 3) {
                    ForEach(dayEvents.prefix(3)) { event in
                        Circle()
                            .fill(isSelected ? Color.textInverse.opacity(0.8) : event.color)
                            .frame(width: 5, height: 5)
                    }
                    if dayEvents.count > 3 {
                        Text("+")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(isSelected ? .textInverse.opacity(0.7) : .textTertiary)
                    }
                }
                .frame(height: 5)
            } else {
                Spacer().frame(height: 5)
            }
        }
    }

    // MARK: - Selected Day Header

    private var selectedDayHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedDayString.uppercased())
                    .font(Typo.headline)
                    .foregroundColor(.textPrimary)
                    .tracking(0.5)
                Text("\(calendarService.events.count) EVENT\(calendarService.events.count == 1 ? "" : "S")")
                    .font(Typo.mono)
                    .foregroundColor(.textTertiary)
                    .tracking(1)
            }
            Spacer()
        }
    }

    // MARK: - Events Timeline

    private var eventsTimeline: some View {
        VStack(spacing: 10) {
            if calendarService.isLoading {
                HStack(spacing: 8) {
                    ProgressView().tint(.accentSkyBlue)
                    Text("LOADING...")
                        .font(Typo.mono)
                        .foregroundColor(.textTertiary)
                        .tracking(1)
                }
                .padding(.top, 20)
            } else if calendarService.events.isEmpty {
                EmptyStateView(
                    icon: "calendar.badge.checkmark",
                    title: "No events",
                    subtitle: "Enjoy your free day"
                )
                .padding(.top, 20)
            } else {
                ForEach(calendarService.events) { event in
                    EventCard(event: event)
                }
            }
        }
        .animation(.spring(response: 0.4), value: calendarService.events.map(\.id))
    }

    // MARK: - Helpers

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }

    private var selectedDayString: String {
        let formatter = DateFormatter()
        if calendar.isDateInToday(selectedDate) {
            formatter.dateFormat = "'Today' — EEE, MMM d"
        } else {
            formatter.dateFormat = "EEEE, MMM d"
        }
        return formatter.string(from: selectedDate)
    }

    private func generateDays() -> [CalendarDay] {
        var days: [CalendarDay] = []

        let range = calendar.range(of: .day, in: .month, for: currentMonth)!
        let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!

        var weekday = calendar.component(.weekday, from: firstOfMonth)
        weekday = weekday == 1 ? 7 : weekday - 1

        if weekday > 1 {
            for i in stride(from: weekday - 1, through: 1, by: -1) {
                let date = calendar.date(byAdding: .day, value: -i, to: firstOfMonth)!
                days.append(CalendarDay(date: date, isCurrentMonth: false, isToday: false, events: []))
            }
        }

        for day in range {
            let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth)!
            let isToday = calendar.isDateInToday(date)
            days.append(CalendarDay(date: date, isCurrentMonth: true, isToday: isToday, events: []))
        }

        let remaining = 7 - (days.count % 7)
        if remaining < 7 {
            let lastDate = days.last?.date ?? Date()
            for i in 1...remaining {
                let date = calendar.date(byAdding: .day, value: i, to: lastDate)!
                days.append(CalendarDay(date: date, isCurrentMonth: false, isToday: false, events: []))
            }
        }

        return days
    }
}

// MARK: - Event Card

struct EventCard: View {
    let event: CalendarEvent
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 14) {
            // Time
            VStack(alignment: .trailing, spacing: 2) {
                Text(event.startTimeFormatted)
                    .font(Typo.mono)
                    .foregroundColor(.textSecondary)
                Text(event.duration)
                    .font(Typo.monoSmall)
                    .foregroundColor(.textTertiary)
            }
            .frame(width: 65, alignment: .trailing)

            // Vertical bar — uses event color
            RoundedRectangle(cornerRadius: 2)
                .fill(event.color)
                .frame(width: 3)

            // Event info
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(Typo.headline)
                    .foregroundColor(.textPrimary)

                if let platform = event.meetingPlatform {
                    HStack(spacing: 4) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 11))
                        Text(platform)
                            .font(Typo.mono)
                    }
                    .foregroundColor(.accentSkyBlue)
                } else if let location = event.location {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.system(size: 11))
                        Text(location)
                            .font(Typo.mono)
                    }
                    .foregroundColor(.textTertiary)
                }
            }

            Spacer()

            if event.meetingLink != nil {
                Button {} label: {
                    Text("JOIN")
                        .font(Typo.mono)
                        .foregroundColor(.bgDeep)
                        .tracking(1)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.accentGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .padding(14)
        .background(Color.bgCard)
        .cornerRadius(8)
        .scaleEffect(appeared ? 1 : 0.97)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }
}

// MARK: - Create Event Sheet

struct CreateEventSheet: View {
    let selectedDate: Date
    var onCreated: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(3600)
    @State private var addMeetLink = false
    @State private var attendeesField = ""
    @State private var location = ""
    @State private var notes = ""
    @State private var isCreating = false
    @State private var appeared = false
    @FocusState private var focusedField: EventField?

    enum EventField: Hashable { case title, attendees, location, notes }

    init(selectedDate: Date, onCreated: (() -> Void)? = nil) {
        self.selectedDate = selectedDate
        self.onCreated = onCreated
        _startDate = State(initialValue: selectedDate)
        _endDate = State(initialValue: selectedDate.addingTimeInterval(3600))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgDeep.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // MARK: Event Title (hero field)
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("Event title", text: $title)
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.textPrimary)
                                .tint(.accentPink)
                                .focused($focusedField, equals: .title)

                            Rectangle()
                                .fill(title.isEmpty ? Color.border : Color.accentPink)
                                .frame(height: 2)
                                .animation(.easeInOut(duration: 0.2), value: title.isEmpty)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 24)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : -10)

                        // MARK: Date & Time Card
                        VStack(spacing: 0) {
                            // Start
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.accentGreen.opacity(0.12))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "clock")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.accentGreen)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("STARTS")
                                        .font(Typo.mono)
                                        .foregroundColor(.textTertiary)
                                        .tracking(1)
                                    DatePicker("", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                                        .datePickerStyle(.compact)
                                        .tint(.accentSkyBlue)
                                        .labelsHidden()
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)

                            VoidDivider().padding(.horizontal, 16)

                            // End
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.accentPink.opacity(0.12))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "clock.badge.checkmark")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.accentPink)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("ENDS")
                                        .font(Typo.mono)
                                        .foregroundColor(.textTertiary)
                                        .tracking(1)
                                    DatePicker("", selection: $endDate, in: startDate..., displayedComponents: [.date, .hourAndMinute])
                                        .datePickerStyle(.compact)
                                        .tint(.accentSkyBlue)
                                        .labelsHidden()
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        .background(Color.bgCard)
                        .cornerRadius(14)
                        .padding(.horizontal, 16)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 8)

                        // MARK: Options Card
                        VStack(spacing: 0) {
                            // Google Meet
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.accentSkyBlue.opacity(0.12))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "video.fill")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.accentSkyBlue)
                                }
                                Text("Google Meet")
                                    .font(Typo.body)
                                    .foregroundColor(.textPrimary)
                                Spacer()
                                Toggle("", isOn: $addMeetLink)
                                    .tint(.accentGreen)
                                    .labelsHidden()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)

                            VoidDivider().padding(.horizontal, 16)

                            // Location
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.accentYellow.opacity(0.12))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "mappin")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.accentYellow)
                                }
                                TextField("Add location", text: $location)
                                    .font(Typo.body)
                                    .foregroundColor(.textPrimary)
                                    .tint(.accentSkyBlue)
                                    .focused($focusedField, equals: .location)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)

                            VoidDivider().padding(.horizontal, 16)

                            // Attendees
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.accentPink.opacity(0.12))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "person.2.fill")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.accentPink)
                                }
                                TextField("Add attendees (emails)", text: $attendeesField)
                                    .font(Typo.body)
                                    .foregroundColor(.textPrimary)
                                    .tint(.accentSkyBlue)
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.emailAddress)
                                    .focused($focusedField, equals: .attendees)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .background(Color.bgCard)
                        .cornerRadius(14)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)

                        // MARK: Notes
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.textTertiary.opacity(0.12))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "note.text")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.textTertiary)
                                }
                                Text("NOTES")
                                    .font(Typo.mono)
                                    .foregroundColor(.textTertiary)
                                    .tracking(1)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 14)
                            .padding(.bottom, 4)

                            TextEditor(text: $notes)
                                .font(.system(size: 15))
                                .foregroundColor(.textPrimary)
                                .scrollContentBackground(.hidden)
                                .tint(.accentSkyBlue)
                                .frame(minHeight: 80)
                                .padding(.horizontal, 12)
                                .padding(.bottom, 10)
                        }
                        .background(Color.bgCard)
                        .cornerRadius(14)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                        // MARK: Create Button
                        Button {
                            Task { await createEvent() }
                        } label: {
                            HStack(spacing: 8) {
                                if isCreating {
                                    ProgressView().tint(.bgDeep).scaleEffect(0.8)
                                } else {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                Text("CREATE EVENT")
                                    .font(Typo.mono)
                                    .tracking(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(!title.isEmpty ? Color.accentPink : Color.bgCard)
                            .foregroundColor(!title.isEmpty ? .bgDeep : .textTertiary)
                            .clipShape(Capsule())
                        }
                        .disabled(title.isEmpty || isCreating)
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.textTertiary)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("NEW EVENT")
                        .font(Typo.mono)
                        .foregroundColor(.textPrimary)
                        .tracking(1)
                }
            }
            .toolbarBackground(Color.bgDeep, for: .navigationBar)
        }
        .onAppear {
            focusedField = .title
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                appeared = true
            }
        }
    }

    private func createEvent() async {
        isCreating = true

        let attendees = attendeesField
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let success = await GoogleCalendarService.shared.createEvent(
            title: title,
            start: startDate,
            end: endDate,
            addGoogleMeet: addMeetLink,
            attendees: attendees
        )

        isCreating = false
        if success {
            onCreated?()
            dismiss()
        }
    }
}
