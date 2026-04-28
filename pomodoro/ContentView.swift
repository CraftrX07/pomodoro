import SwiftUI

// MARK: - Root

struct ContentView: View {
    @StateObject private var store = FocusStore()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        if hasSeenOnboarding {
            MainTabView(store: store)
        } else {
            OnboardingView {
                withAnimation { hasSeenOnboarding = true }
            }
        }
    }
}

// MARK: - Onboarding (画板A)

struct OnboardingView: View {
    var onFinish: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "clock.fill")
                .font(.system(size: 48))
                .foregroundStyle(.indigo)
                .frame(width: 80, height: 80)
                .background(Color.indigo.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 20))

            Text("FocusFlow")
                .font(.largeTitle.bold())

            Text("更专注地完成每一天")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                OnboardingBullet(text: "智能番茄节奏建议")
                OnboardingBullet(text: "任务拆分与优先级")
                OnboardingBullet(text: "专注统计与热力图")
            }
            .padding(.vertical)

            Spacer()

            Button(action: onFinish) {
                Text("立即开始")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)

            Button("查看体验模式") {
                onFinish()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(32)
    }
}

struct OnboardingBullet: View {
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(.green)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.body)
        }
    }
}

// MARK: - Main Tab (画板B底部Tab)

struct MainTabView: View {
    @ObservedObject var store: FocusStore

    var body: some View {
        TabView {
            TimerTab(store: store)
                .tabItem {
                    Label("计时", systemImage: "timer")
                }

            TasksTab(store: store)
                .tabItem {
                    Label("任务", systemImage: "checklist")
                }

            StatsTab(store: store)
                .tabItem {
                    Label("统计", systemImage: "chart.bar.fill")
                }

            SettingsTab(store: store)
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
        }
        .tint(.indigo)
    }
}

// MARK: - Timer Tab (画板B/C/D + E)

struct TimerTab: View {
    @ObservedObject var store: FocusStore
    @State private var remainingSeconds: Int = 0
    @State private var timerState: TimerPhase = .idle
    @State private var timer: Timer?
    @State private var showInterruptAlert = false
    @State private var showCompletion = false

    enum TimerPhase {
        case idle, running, paused, breakTime
    }

    private var totalSeconds: Int {
        timerState == .breakTime ? store.breakLength * 60 : store.currentSessionLength * 60
    }

    private var progress: Double {
        let total = Double(max(totalSeconds, 1))
        return 1 - (Double(remainingSeconds) / total)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if showCompletion {
                    completionView
                } else {
                    timerView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(timerState == .breakTime ? "休息中" : "专注计时")
                        .font(.headline)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if timerState == .running || timerState == .paused {
                        Button {
                            showInterruptAlert = true
                        } label: {
                            Image(systemName: "bell.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .alert("确认中断本轮专注？", isPresented: $showInterruptAlert) {
                Button("继续专注", role: .cancel) {}
                Button("确认中断", role: .destructive) {
                    interruptSession()
                }
            } message: {
                let elapsed = totalSeconds - remainingSeconds
                let mm = elapsed / 60
                let ss = elapsed % 60
                Text("已专注 \(String(format: "%02d:%02d", mm, ss))，本轮将不会计入完成统计。")
            }
        }
        .onAppear {
            if timerState == .idle {
                remainingSeconds = store.currentSessionLength * 60
            }
        }
        .onDisappear {
            stopTicker()
        }
    }

    // MARK: Timer View (画板B/C/D)

    private var timerView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header info
                VStack(spacing: 4) {
                    Text("今日第 \(store.sessionsToday + 1) 个番茄")
                        .font(.headline)
                    Text("目标 8 · 已完成 \(store.sessionsToday)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)

                // Circular timer
                ZStack {
                    Circle()
                        .stroke(Color.indigo.opacity(0.15), lineWidth: 16)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            Color.indigo,
                            style: StrokeStyle(lineWidth: 16, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.3), value: progress)

                    VStack(spacing: 6) {
                        Text(stateLabel)
                            .font(.caption)
                            .foregroundStyle(.indigo)
                        Text(formatTime(remainingSeconds))
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                        Text(stateHint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 260, height: 260)

                // Start / Pause button
                Button {
                    handleMainAction()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: mainActionIcon)
                        Text(mainActionLabel)
                    }
                    .font(.headline)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)

                // Current task
                if let task = store.currentTask {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "list.bullet")
                                .foregroundStyle(.indigo)
                            Text("当前任务")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(task.title)（\(task.completedSessions)/\(task.targetSessions) 番茄）")
                            .font(.subheadline)
                        Text("···")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal)
        }
    }

    // MARK: Completion View (画板E)

    private var completionView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "trophy.fill")
                .font(.system(size: 56))
                .foregroundStyle(.yellow)

            Text("完成一个番茄！")
                .font(.title2.bold())

            Text("你已连续专注 \(store.sessionsToday) 轮，建议休息 \(store.breakLength) 分钟")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 24) {
                StatBubble(value: "\(store.focusedMinutesToday)", label: "专注分钟")
                StatBubble(value: "\(store.sessionsToday)", label: "连续轮次")
                StatBubble(value: "\(store.completionRate)%", label: "完成率")
            }
            .padding(.vertical, 8)

            Button {
                startBreak()
            } label: {
                Text("开始休息 \(formatTime(store.breakLength * 60))")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
            .padding(.horizontal)

            Button("继续下一轮") {
                startNextFocusRound()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
    }

    // MARK: Timer Logic

    private var stateLabel: String {
        switch timerState {
        case .idle: return "准备开始"
        case .running: return "专注中"
        case .paused: return "已暂停"
        case .breakTime: return "休息中"
        }
    }

    private var stateHint: String {
        switch timerState {
        case .idle: return "点击开始专注"
        case .running: return "保持专注"
        case .paused: return "点击继续"
        case .breakTime: return "放松一下"
        }
    }

    private var mainActionLabel: String {
        switch timerState {
        case .idle: return "开始"
        case .running: return "暂停"
        case .paused: return "继续"
        case .breakTime: return "跳过休息"
        }
    }

    private var mainActionIcon: String {
        switch timerState {
        case .idle: return "play.fill"
        case .running: return "pause.fill"
        case .paused: return "play.fill"
        case .breakTime: return "forward.fill"
        }
    }

    private func handleMainAction() {
        switch timerState {
        case .idle:
            timerState = .running
            startTicker()
        case .running:
            timerState = .paused
            stopTicker()
        case .paused:
            timerState = .running
            startTicker()
        case .breakTime:
            startNextFocusRound()
        }
    }

    private func startTicker() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            tick()
        }
    }

    private func stopTicker() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard remainingSeconds > 0 else {
            onTimerFinished()
            return
        }
        remainingSeconds -= 1
    }

    private func onTimerFinished() {
        stopTicker()
        if timerState != .breakTime {
            store.completeSession()
            showCompletion = true
        } else {
            startNextFocusRound()
        }
    }

    private func startBreak() {
        showCompletion = false
        timerState = .breakTime
        remainingSeconds = store.breakLength * 60
        startTicker()
    }

    private func startNextFocusRound() {
        showCompletion = false
        timerState = .idle
        remainingSeconds = store.currentSessionLength * 60
    }

    private func interruptSession() {
        stopTicker()
        timerState = .idle
        remainingSeconds = store.currentSessionLength * 60
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

struct StatBubble: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Tasks Tab (画板F + I empty state)

struct TasksTab: View {
    @ObservedObject var store: FocusStore
    @State private var filter: TaskFilter = .all
    @State private var showAddSheet = false

    enum TaskFilter: String, CaseIterable {
        case all = "全部"
        case inProgress = "进行中"
        case completed = "已完成"
    }

    private var filteredTasks: [FocusTask] {
        switch filter {
        case .all: return store.tasks
        case .inProgress: return store.tasks.filter { !$0.isCompleted }
        case .completed: return store.tasks.filter { $0.isCompleted }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter tabs
                HStack(spacing: 0) {
                    ForEach(TaskFilter.allCases, id: \.self) { tab in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { filter = tab }
                        } label: {
                            Text(tab.rawValue)
                                .font(.subheadline.weight(filter == tab ? .semibold : .regular))
                                .padding(.vertical, 8)
                                .padding(.horizontal, 20)
                                .background(
                                    filter == tab
                                        ? Color.indigo.opacity(0.12)
                                        : Color.clear
                                )
                                .foregroundStyle(filter == tab ? .indigo : .secondary)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                if filteredTasks.isEmpty {
                    emptyTasksView
                } else {
                    taskList
                }
            }
            .navigationTitle("今日任务")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddTaskSheet(store: store)
            }
        }
    }

    // Empty state (画板I)
    private var emptyTasksView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "face.smiling")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("今日还没有任务")
                .font(.headline)
            Text("创建一个任务，开始你的第一轮专注")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("新建任务") {
                showAddSheet = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
            Spacer()
        }
    }

    // Task list (画板F)
    private var taskList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredTasks) { task in
                    TaskCard(task: task, store: store)
                }
            }
            .padding()
        }
    }
}

struct TaskCard: View {
    let task: FocusTask
    @ObservedObject var store: FocusStore

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(task.tag.color)
                .frame(width: 4, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.subheadline.weight(.medium))
                    .strikethrough(task.isCompleted)
                Text("预估 \(task.targetSessions) 个番茄 · \(task.tag.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if task.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            } else {
                Text("\(task.completedSessions)/\(task.targetSessions)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                store.deleteTask(task)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
        .onTapGesture {
            store.toggleTask(task)
        }
    }
}

struct AddTaskSheet: View {
    @ObservedObject var store: FocusStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var tag: FocusTag = .work
    @State private var targetSessions = 2

    var body: some View {
        NavigationStack {
            Form {
                TextField("任务名称", text: $title)

                Picker("标签", selection: $tag) {
                    ForEach(FocusTag.editableCases) { t in
                        Text(t.rawValue).tag(t)
                    }
                }

                Stepper("目标番茄数：\(targetSessions)", value: $targetSessions, in: 1...8)
            }
            .navigationTitle("新建任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        store.addTask(title: title, tag: tag, targetSessions: targetSessions)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Stats Tab (画板G)

struct StatsTab: View {
    @ObservedObject var store: FocusStore
    @State private var dateRange: DateRange = .week

    enum DateRange: String, CaseIterable {
        case day = "日"
        case week = "周"
        case month = "月"
    }

    private let dayLabels = ["一", "二", "三", "四", "五", "六", "日"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Date range picker
                    Picker("范围", selection: $dateRange) {
                        ForEach(DateRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Bar chart — 专注分钟（近7天）
                    VStack(alignment: .leading, spacing: 12) {
                        Text("专注分钟（近7天）")
                            .font(.headline)

                        HStack(alignment: .bottom, spacing: 10) {
                            ForEach(Array(store.weeklyMinutes.enumerated()), id: \.offset) { index, value in
                                VStack(spacing: 6) {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.indigo.gradient)
                                        .frame(width: 28, height: CGFloat(max(value, 4)) * 1.4)

                                    Text(dayLabels[index])
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .cardStyle()

                    // Heat map — 专注热力
                    VStack(alignment: .leading, spacing: 12) {
                        Text("专注热力")
                            .font(.headline)

                        HeatMapView(weeklyMinutes: store.weeklyMinutes)
                    }
                    .cardStyle()

                    // Summary stats
                    HStack(spacing: 16) {
                        SummaryStatCard(
                            value: "\(store.weeklyMinutes.reduce(0, +) / max(store.currentSessionLength, 1))",
                            label: "本周番茄"
                        )
                        SummaryStatCard(
                            value: String(format: "%.1fh", Double(store.weeklyMinutes.reduce(0, +)) / 60),
                            label: "总专注时长"
                        )
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("专注统计")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Image(systemName: "calendar")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct HeatMapView: View {
    let weeklyMinutes: [Int]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(weeklyMinutes.enumerated()), id: \.offset) { _, value in
                VStack(spacing: 4) {
                    ForEach(0..<4, id: \.self) { slot in
                        let threshold = (slot + 1) * 15
                        RoundedRectangle(cornerRadius: 4)
                            .fill(value >= threshold ? Color.green.opacity(0.3 + Double(min(value, 90)) / 120) : Color(.systemGray5))
                            .frame(height: 18)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SummaryStatCard: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Settings Tab (画板H)

struct SettingsTab: View {
    @ObservedObject var store: FocusStore

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("专注时长 \(store.currentSessionLength) 分钟")
                            .font(.subheadline)
                        Slider(
                            value: Binding(
                                get: { Double(store.currentSessionLength) },
                                set: { store.currentSessionLength = Int($0) }
                            ),
                            in: 15...60,
                            step: 5
                        )
                        .tint(.indigo)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("短休息 \(store.breakLength) 分钟")
                            .font(.subheadline)
                        Slider(
                            value: Binding(
                                get: { Double(store.breakLength) },
                                set: { store.breakLength = Int($0) }
                            ),
                            in: 3...10,
                            step: 1
                        )
                        .tint(.indigo)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("长休息 \(store.longBreakLength) 分钟")
                            .font(.subheadline)
                        Slider(
                            value: Binding(
                                get: { Double(store.longBreakLength) },
                                set: { store.longBreakLength = Int($0) }
                            ),
                            in: 10...30,
                            step: 5
                        )
                        .tint(.indigo)
                    }
                }

                Section {
                    Toggle("专注结束提醒", isOn: $store.notificationsEnabled)
                    Toggle("白噪音", isOn: $store.whiteNoiseEnabled)
                    Toggle("自动进入下一轮", isOn: $store.autoStartNextSession)
                }
            }
            .navigationTitle("设置")
        }
    }
}

// MARK: - Models

struct FocusTask: Identifiable, Codable {
    let id: UUID
    var title: String
    var tag: FocusTag
    var targetSessions: Int
    var completedSessions: Int
    var isCompleted: Bool

    init(
        id: UUID = UUID(),
        title: String,
        tag: FocusTag,
        targetSessions: Int,
        completedSessions: Int = 0,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.title = title
        self.tag = tag
        self.targetSessions = targetSessions
        self.completedSessions = completedSessions
        self.isCompleted = isCompleted
    }
}

enum FocusTag: String, CaseIterable, Identifiable, Codable {
    case all = "全部"
    case work = "工作"
    case study = "学习"
    case design = "设计"
    case life = "生活"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .all: return .indigo
        case .work: return .red
        case .study: return .blue
        case .design: return .purple
        case .life: return .orange
        }
    }

    static var editableCases: [FocusTag] {
        allCases.filter { $0 != .all }
    }
}

// MARK: - Store

final class FocusStore: ObservableObject {
    @Published var tasks: [FocusTask] = []
    @Published var sessionsToday: Int = 0
    @Published var focusedMinutesToday: Int = 0
    @Published var completionRate: Int = 0
    @Published var weeklyMinutes: [Int] = [25, 40, 55, 35, 80, 60, 45]
    @Published var currentSessionLength: Int = 25
    @Published var breakLength: Int = 5
    @Published var longBreakLength: Int = 15
    @Published var notificationsEnabled: Bool = true
    @Published var whiteNoiseEnabled: Bool = false
    @Published var autoStartNextSession: Bool = false

    private let saveKey = "focus.store.v2"

    init() {
        load()
        if tasks.isEmpty {
            tasks = [
                FocusTask(title: "输出 PRD V2", tag: .work, targetSessions: 3),
                FocusTask(title: "竞品评审会", tag: .design, targetSessions: 2),
                FocusTask(title: "晨会纪要整理", tag: .study, targetSessions: 1)
            ]
        }
        refreshCompletionRate()
    }

    var currentTask: FocusTask? {
        tasks.first { !$0.isCompleted }
    }

    func addTask(title: String, tag: FocusTag, targetSessions: Int) {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        tasks.insert(
            FocusTask(title: title, tag: tag, targetSessions: max(1, targetSessions)),
            at: 0
        )
        save()
    }

    func deleteTask(_ task: FocusTask) {
        tasks.removeAll { $0.id == task.id }
        refreshCompletionRate()
        save()
    }

    func toggleTask(_ task: FocusTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].isCompleted.toggle()
        refreshCompletionRate()
        save()
    }

    func completeSession() {
        sessionsToday += 1
        focusedMinutesToday += currentSessionLength
        weeklyMinutes[weeklyMinutes.count - 1] += currentSessionLength
        markBestMatchedTaskProgress()
        refreshCompletionRate()
        save()
    }

    private func markBestMatchedTaskProgress() {
        let openIndexes = tasks.indices.filter { !tasks[$0].isCompleted }
        guard let firstIndex = openIndexes.first else { return }
        tasks[firstIndex].completedSessions += 1
        if tasks[firstIndex].completedSessions >= tasks[firstIndex].targetSessions {
            tasks[firstIndex].isCompleted = true
        }
    }

    private func refreshCompletionRate() {
        guard !tasks.isEmpty else {
            completionRate = 0
            return
        }
        let done = tasks.filter(\.isCompleted).count
        completionRate = Int((Double(done) / Double(tasks.count)) * 100)
    }

    private func save() {
        let state = FocusPersistState(
            tasks: tasks,
            sessionsToday: sessionsToday,
            focusedMinutesToday: focusedMinutesToday,
            completionRate: completionRate,
            weeklyMinutes: weeklyMinutes,
            currentSessionLength: currentSessionLength,
            breakLength: breakLength,
            longBreakLength: longBreakLength,
            notificationsEnabled: notificationsEnabled,
            whiteNoiseEnabled: whiteNoiseEnabled,
            autoStartNextSession: autoStartNextSession
        )
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: saveKey)
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: saveKey),
            let state = try? JSONDecoder().decode(FocusPersistState.self, from: data)
        else { return }

        tasks = state.tasks
        sessionsToday = state.sessionsToday
        focusedMinutesToday = state.focusedMinutesToday
        completionRate = state.completionRate
        weeklyMinutes = state.weeklyMinutes
        currentSessionLength = state.currentSessionLength
        breakLength = state.breakLength
        longBreakLength = state.longBreakLength
        notificationsEnabled = state.notificationsEnabled
        whiteNoiseEnabled = state.whiteNoiseEnabled
        autoStartNextSession = state.autoStartNextSession
    }
}

struct FocusPersistState: Codable {
    var tasks: [FocusTask]
    var sessionsToday: Int
    var focusedMinutesToday: Int
    var completionRate: Int
    var weeklyMinutes: [Int]
    var currentSessionLength: Int
    var breakLength: Int
    var longBreakLength: Int
    var notificationsEnabled: Bool
    var whiteNoiseEnabled: Bool
    var autoStartNextSession: Bool
}

// MARK: - View Modifiers

extension View {
    func cardStyle() -> some View {
        self
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
    }
}

#Preview {
    ContentView()
}
