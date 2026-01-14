//
//  ProxyGroupManagementView.swift
//  SurgeProxy
//
//  Proxy group management view
//

import SwiftUI

struct ProxyGroupManagementView: View {
    @StateObject private var viewModel = ProxyGroupManagementViewModel()
    @State private var showingAddSheet = false
    @State private var selectedGroup: ProxyGroupConfigModel?
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.groups) { group in
                    ProxyGroupRow(group: group)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedGroup = group
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task {
                                    await viewModel.deleteGroup(name: group.name)
                                }
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                }
            }
            .navigationTitle("代理组")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showingAddSheet = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                    }
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("刷新") {
                        Task {
                            await viewModel.loadGroups()
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                ProxyGroupEditorSheet(
                    mode: .add,
                    availableProxies: viewModel.availableProxies
                ) { group in
                    await viewModel.addGroup(group)
                }
            }
            .sheet(item: $selectedGroup) { group in
                ProxyGroupEditorSheet(
                    mode: .edit(group),
                    availableProxies: viewModel.availableProxies
                ) { updatedGroup in
                    await viewModel.updateGroup(name: group.name, group: updatedGroup)
                }
            }
        }
        .task {
            await viewModel.loadData()
        }
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定", role: .cancel) { }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }
}

// MARK: - Proxy Group Row

struct ProxyGroupRow: View {
    let group: ProxyGroupConfigModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: groupIcon)
                    .foregroundColor(groupColor)
                    .font(.title3)
                
                Text(group.name)
                    .font(.headline)
                
                Spacer()
                
                Text(group.type.uppercased())
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(groupColor.opacity(0.2))
                    .foregroundColor(groupColor)
                    .cornerRadius(4)
            }
            
            HStack {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(group.proxies.count) 个代理")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let url = group.url {
                    Divider()
                        .frame(height: 12)
                    
                    Image(systemName: "link")
                        .font(.caption2)
                    Text(url)
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundColor(.blue)
                }
            }
            
            // 显示代理列表
            if !group.proxies.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(group.proxies.prefix(5), id: \.self) { proxy in
                            Text(proxy)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                        
                        if group.proxies.count > 5 {
                            Text("+\(group.proxies.count - 5)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var groupIcon: String {
        switch group.type {
        case "select": return "hand.tap.fill"
        case "url-test": return "speedometer"
        case "fallback": return "arrow.triangle.branch"
        case "load-balance": return "scale.3d"
        case "relay": return "arrow.forward.square.fill"
        default: return "folder.fill"
        }
    }
    
    private var groupColor: Color {
        switch group.type {
        case "select": return .blue
        case "url-test": return .green
        case "fallback": return .orange
        case "load-balance": return .purple
        case "relay": return .red
        default: return .gray
        }
    }
}

// MARK: - Proxy Group Editor Sheet

struct ProxyGroupEditorSheet: View {
    enum Mode {
        case add
        case edit(ProxyGroupConfigModel)
    }
    
    let mode: Mode
    let availableProxies: [String]
    let onSave: (ProxyGroupConfigModel) async -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ProxyGroupEditorViewModel
    
    init(mode: Mode, availableProxies: [String], onSave: @escaping (ProxyGroupConfigModel) async -> Void) {
        self.mode = mode
        self.availableProxies = availableProxies
        self.onSave = onSave
        
        switch mode {
        case .add:
            _viewModel = StateObject(wrappedValue: ProxyGroupEditorViewModel(availableProxies: availableProxies))
        case .edit(let group):
            _viewModel = StateObject(wrappedValue: ProxyGroupEditorViewModel(group: group, availableProxies: availableProxies))
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("名称", text: $viewModel.name)
                    
                    Picker("类型", selection: $viewModel.type) {
                        ForEach(ProxyGroupType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type.rawValue)
                        }
                    }
                }
                
                Section(header: Text("代理列表")) {
                    ForEach(viewModel.selectedProxies, id: \.self) { proxy in
                        HStack {
                            Text(proxy)
                            Spacer()
                            Button(action: {
                                viewModel.removeProxy(proxy)
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    Menu {
                        ForEach(viewModel.unselectedProxies, id: \.self) { proxy in
                            Button(proxy) {
                                viewModel.addProxy(proxy)
                            }
                        }
                    } label: {
                        Label("添加代理", systemImage: "plus.circle.fill")
                    }
                    .disabled(viewModel.unselectedProxies.isEmpty)
                }
                
                if viewModel.type == "url-test" || viewModel.type == "fallback" || viewModel.type == "smart" {
                    Section(header: Text("测试设置")) {
                        TextField("测试 URL", text: $viewModel.testURL)
                        
                        if viewModel.type == "smart" {
                            Toggle("使用前评估", isOn: $viewModel.evaluateBeforeUse)
                            Text("首次使用前强制测试（可能会增加初始延迟）")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if viewModel.type == "url-test" || viewModel.type == "smart" {
                            HStack {
                                Text("测试间隔")
                                Spacer()
                                TextField("秒", value: $viewModel.interval, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                                    .multilineTextAlignment(.trailing)
                                Text("秒")
                            }
                        }
                            
                        if viewModel.type == "url-test" {
                            HStack {
                                Text("容错值")
                                Spacer()
                                TextField("毫秒", value: $viewModel.tolerance, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                                    .multilineTextAlignment(.trailing)
                                Text("ms")
                            }
                        }
                    }
                }
            }
            .navigationTitle(mode.isEdit ? "编辑代理组" : "添加代理组")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            let group = viewModel.buildGroup()
                            await onSave(group)
                            dismiss()
                        }
                    }
                    .disabled(!viewModel.isValid)
                }
            }
        }
    }
}

extension ProxyGroupEditorSheet.Mode {
    var isEdit: Bool {
        if case .edit = self {
            return true
        }
        return false
    }
}

// MARK: - View Models

@MainActor
class ProxyGroupManagementViewModel: ObservableObject {
    @Published var groups: [ProxyGroupConfigModel] = []
    @Published var availableProxies: [String] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage: String?
    
    private let apiClient = APIClient.shared
    
    func loadData() async {
        await loadGroups()
        await loadAvailableProxies()
    }
    
    func loadGroups() async {
        do {
            groups = try await apiClient.fetchAllProxyGroups()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    func loadAvailableProxies() async {
        do {
            let proxies = try await apiClient.fetchAllProxies()
            availableProxies = proxies.map { $0.name } + ["DIRECT", "REJECT"]
        } catch {
            // Silently fail for now
        }
    }
    
    func addGroup(_ group: ProxyGroupConfigModel) async {
        do {
            try await apiClient.addProxyGroup(group)
            await loadGroups()
        } catch {
            errorMessage = "添加失败: \(error.localizedDescription)"
            showError = true
        }
    }
    
    func updateGroup(name: String, group: ProxyGroupConfigModel) async {
        do {
            try await apiClient.updateProxyGroup(name: name, group: group)
            await loadGroups()
        } catch {
            errorMessage = "更新失败: \(error.localizedDescription)"
            showError = true
        }
    }
    
    func deleteGroup(name: String) async {
        do {
            try await apiClient.deleteProxyGroup(name: name)
            await loadGroups()
        } catch {
            errorMessage = "删除失败: \(error.localizedDescription)"
            showError = true
        }
    }
}

@MainActor
class ProxyGroupEditorViewModel: ObservableObject {
    @Published var name = ""
    @Published var type = "select"
    @Published var selectedProxies: [String] = []
    @Published var testURL = "http://www.gstatic.com/generate_204"
    @Published var interval = 600
    @Published var tolerance = 100
    @Published var evaluateBeforeUse = false
    
    let availableProxies: [String]
    
    init(group: ProxyGroupConfigModel? = nil, availableProxies: [String]) {
        self.availableProxies = availableProxies
        
        if let group = group {
            self.name = group.name
            self.type = group.type
            self.selectedProxies = group.proxies
            self.testURL = group.url ?? "http://www.gstatic.com/generate_204"
            self.interval = group.interval ?? 600
            self.tolerance = group.tolerance ?? 100
            self.evaluateBeforeUse = group.evaluateBeforeUse ?? false
        }
    }
    
    var unselectedProxies: [String] {
        availableProxies.filter { !selectedProxies.contains($0) }
    }
    
    var isValid: Bool {
        !name.isEmpty && !selectedProxies.isEmpty
    }
    
    func addProxy(_ proxy: String) {
        if !selectedProxies.contains(proxy) {
            selectedProxies.append(proxy)
        }
    }
    
    func removeProxy(_ proxy: String) {
        selectedProxies.removeAll { $0 == proxy }
    }
    
    func buildGroup() -> ProxyGroupConfigModel {
        ProxyGroupConfigModel(
            name: name,
            type: type,
            proxies: selectedProxies,
            url: (type == "url-test" || type == "fallback" || type == "smart") ? testURL : nil,
            interval: (type == "url-test" || type == "smart") ? interval : nil,
            tolerance: type == "url-test" ? tolerance : nil,
            timeout: nil,
            updateInterval: nil,
            policyPath: nil,
            policyRegex: nil,
            includeAll: nil,
            hidden: nil,
            noAlert: nil,
            evaluateBeforeUse: (type == "smart") ? evaluateBeforeUse : nil
        )
    }
}

#Preview {
    ProxyGroupManagementView()
}
