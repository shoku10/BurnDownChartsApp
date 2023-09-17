import SwiftUI

// ChartSettings
class ChartSettings: ObservableObject, Identifiable {
    let id = UUID()
    @Published var materialName: String = ""
    @Published var totalTask: Double = 0
    @Published var startDate: Date = Date()
    @Published var endDate: Date = Date().addingTimeInterval(86400 * 9)
    @Published var actuals: [String] = []  // String array
    @Published var plans: [String] = []
    
    // Moved the progress calculation here to avoid duplication
    var progress: Double {
        let completedTasks = actuals.compactMap { Double($0) }.reduce(0, +)
        return min(completedTasks / totalTask, 1)
    }
    
    // Moved the remaining task calculation here to avoid duplication
    var remainingTasks: Double {
        let completedTasks = actuals.compactMap { Double($0) }.reduce(0, +)
        return max(0, totalTask - completedTasks)
    }
    
    var name: String = ""
}

// ProjectList
class ProjectList: ObservableObject {
    enum SortOption {
        case progress, remaining
    }
    
    enum SortOrder {
        case ascending, descending
        
        mutating func toggle() {
            self = self == .ascending ? .descending : .ascending
        }
    }
    
    @Published var projects: [ChartSettings] = []
    @Published var sortOption: SortOption = .progress
    @Published var currentSortOrder: SortOrder = .ascending
    
    func sortProjects() -> [ChartSettings] {
        let sorted = projects.sorted {
            switch sortOption {
            case .progress:
                return currentSortOrder == .ascending ?
                $0.progress < $1.progress :
                $0.progress > $1.progress
            case .remaining:
                return currentSortOrder == .ascending ?
                $0.remainingTasks < $1.remainingTasks :
                $0.remainingTasks > $1.remainingTasks
            }
        }
        return sorted
    }
    
    func removeProjects(at offsets: IndexSet) {
        projects.remove(atOffsets: offsets)
    }
}

// BurnDownView
struct BurnDownView: View {
    @ObservedObject var settings: ChartSettings
    
    var body: some View {
        MainView(chartSettings: settings)
    }
}


// ContentView.swift
// ContentView.swift
struct ContentView: View {
    @ObservedObject var projectList = ProjectList()
    @State private var showingAlert = false
    @State private var indexSetToDelete: IndexSet? = nil
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    Button("進捗率順") {
                        self.projectList.sortOption = .progress
                        self.projectList.currentSortOrder.toggle()
                    }
                    Button("タスク残り順") {
                        self.projectList.sortOption = .remaining
                        self.projectList.currentSortOrder.toggle()
                    }
                }
                
                List {
                    ForEach(projectList.sortProjects()) { project in
                        NavigationLink(destination: BurnDownView(settings: project)) {
                            VStack(alignment: .leading) {
                                Text(project.materialName) // 教材名を表示
                                    .font(.headline) // フォントを変更して強調（オプション）
                                
                                HStack {
                                    ProgressView(value: project.progress)
                                        .scaleEffect(x: 1, y: 2, anchor: .center)
                                    
                                    Text("\(Int(project.progress * 100))%") // 進捗率の数値（％）を表示
                                        .font(.subheadline) // フォントを変更（オプション）
                                }
                                
                                Text("タスク残り: \(Int(project.remainingTasks))")
                            }
                        }
                    }
                    .onDelete { indexSet in
                        indexSetToDelete = indexSet
                        showingAlert = true
                    }
                    
                    NavigationLink("新規プロジェクト登録", destination: NewProjectView(projectList: projectList))
                }
                .alert(isPresented: $showingAlert) {
                    Alert(
                        title: Text("警告"),
                        message: Text("このプロジェクトを削除しますか？"),
                        primaryButton: .destructive(Text("削除")) {
                            if let indexSet = indexSetToDelete {
                                projectList.projects.remove(atOffsets: indexSet)
                            }
                        },
                        secondaryButton: .cancel()
                    )
                }
                .navigationBarTitle("Projects")
            }
        }
    }
}



// NewProjectView
struct NewProjectView: View {
    @ObservedObject var projectList: ProjectList
    @State var newProject = ChartSettings()
    
    var body: some View {
        SettingsView(chartSettings: newProject, onSave: {
            self.projectList.projects.append(newProject)
        })
    }
}


// 省略: ChartSettings, ProjectList, BurnDownView, ContentView, NewProjectView は同じ

// MainView
struct MainView: View {
    @ObservedObject var chartSettings: ChartSettings
    
    var body: some View {
        NavigationView {
            VStack {
                // 修正: 教材名をプログレスバーの真上に追加
                Text(chartSettings.materialName)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .center) // 左揃え
                
                // バーンダウンチャート
                BurnDownChart(chartSettings: chartSettings)
                
                Spacer() // 離す
                
                // プログレスバー
                HStack {
                    ProgressView(value: chartSettings.progress)  // 進捗率を反映
                        .scaleEffect(x: 1, y: 10, anchor: .center)  // x方向はそのまま、y方向を10倍に
                        .padding(.vertical, 50)
                    
                    Text("\(Int(chartSettings.progress * 100))%")  // 進捗率
                        .font(.headline)
                }
                
                Text("タスク残り: \(chartSettings.remainingTasks, specifier: "%.0f")")  // タスク残り
                    .font(.headline)
            }
            .padding()
            .navigationBarTitle("BurnDown Chart")
            // 修正: 「設定」への NavigationLink を追加
            .navigationBarItems(trailing: NavigationLink("設定", destination: SettingsView(chartSettings: chartSettings)))
        }
    }
}

// 省略: SettingsView, BurnDownChart は同じ


// SettingsView
struct SettingsView: View {
    @ObservedObject var chartSettings: ChartSettings
    var onSave: (() -> Void)? = nil
    
    var body: some View {
        Form {
            TextField("Material Name", text: $chartSettings.materialName)
            TextField("Total Task", value: $chartSettings.totalTask, format: .number)
            DatePicker("Start Date", selection: $chartSettings.startDate, displayedComponents: .date)
            DatePicker("End Date", selection: $chartSettings.endDate, displayedComponents: .date)
            
            Section(header: Text("Actuals and Plans")) {
                ForEach(0..<chartSettings.actuals.count, id: \.self) { index in
                    HStack {
                        Text("計画")
                        TextField("Plan \(index + 1)", text: $chartSettings.plans[index])
                        
                        Text("実績")
                        TextField("Actual \(index + 1)", text: $chartSettings.actuals[index])
                    }
                }
                Button("Add Data") {
                    chartSettings.actuals.append("") // 空文字を追加
                    chartSettings.plans.append("")
                }
            }
        }
        .navigationBarItems(trailing: Button("Save") {
            onSave?()
        })
        .navigationBarTitle("Settings")
    }
}

struct BurnDownChart: View {
    @ObservedObject var chartSettings: ChartSettings
    
    private var days: Int {
        return max(1, Calendar.current.dateComponents([.day], from: chartSettings.startDate, to: chartSettings.endDate).day ?? 0)
    }
    
    private var cumulativeActuals: [Double] {
        var sum: Double = 0
        return chartSettings.actuals.compactMap { value in  // compactMap to remove nils
            if let doubleValue = Double(value) {
                sum += doubleValue
                return max(0, chartSettings.totalTask - sum)
            }
            return nil
        }
    }
    
    private var cumulativePlans: [Double] {
        var sum: Double = 0
        return chartSettings.plans.compactMap { value in  // compactMap to remove nils
            if let doubleValue = Double(value) {
                sum += doubleValue
                return max(0, chartSettings.totalTask - sum)
            }
            return nil
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Draw Ideal Line
                Path { path in
                    let yStart = CGFloat(0)
                    let yEnd = geometry.size.height
                    let xEnd = geometry.size.width
                    let slope = chartSettings.totalTask / Double(days)
                    let yIdealEnd = yEnd - CGFloat(chartSettings.totalTask - slope * Double(days))
                    path.move(to: CGPoint(x: 0, y: yStart))
                    path.addLine(to: CGPoint(x: xEnd, y: yIdealEnd))
                }
                .stroke(Color.red, lineWidth: 2)
                
                // Draw Actual Line
                if chartSettings.totalTask == 0 {
                    Path { path in
                        let yEnd = geometry.size.height
                        path.move(to: CGPoint(x: 0, y: yEnd))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: yEnd))
                    }
                    .stroke(Color.blue, lineWidth: 2)
                } else if !cumulativeActuals.isEmpty && cumulativeActuals.last! >= 0 {
                    Path { path in
                        let yStart = CGFloat(0)
                        let yEnd = geometry.size.height
                        path.move(to: CGPoint(x: 0, y: yStart))
                        for i in 0..<cumulativeActuals.count {
                            let x = geometry.size.width * CGFloat(i) / CGFloat(max(1, days))
                            let y = yEnd - geometry.size.height * CGFloat(cumulativeActuals[i]) / CGFloat(chartSettings.totalTask)
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    .stroke(Color.blue, lineWidth: 2)
                }
                
                // Draw Plan Line
                if chartSettings.totalTask == 0 {
                    Path { path in
                        let yEnd = geometry.size.height
                        path.move(to: CGPoint(x: 0, y: yEnd))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: yEnd))
                    }
                    .stroke(Color.green, lineWidth: 2)
                } else if cumulativePlans.reduce(0, +) > 0 {
                    Path { path in
                        let yStart = CGFloat(0)
                        let yEnd = geometry.size.height
                        path.move(to: CGPoint(x: 0, y: yStart))
                        for i in 0..<cumulativePlans.count {
                            let x = geometry.size.width * CGFloat(i) / CGFloat(max(1, days))
                            let y = yEnd - geometry.size.height * CGFloat(cumulativePlans[i]) / CGFloat(chartSettings.totalTask)
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    .stroke(Color.green, lineWidth: 2)
                }
            }
            .border(Color.black, width: 1)
        }
        .frame(height: 200)
        .clipped()
    }
}
