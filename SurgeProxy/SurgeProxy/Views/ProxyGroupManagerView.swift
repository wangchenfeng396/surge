//
//  ProxyGroupManagerView.swift
//  SurgeProxy
//
//  Proxy group management view
//

import SwiftUI

struct ProxyGroupManagerView: View {
    @State private var groups: [ProxyGroupConfigModel] = []
    @State private var availableProxies: [String] = []  // Loaded from API
    @State private var showingAddGroup = false
    @State private var editingGroup: ProxyGroupConfigModel?
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        VStack {
            if groups.isEmpty {
                emptyState
            } else {
                groupList
            }
        }
        .navigationTitle("Proxy Groups")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddGroup = true }) {
                    Label("Add Group", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddGroup) {
            ProxyGroupEditorView(group: nil, availableProxies: availableProxies) { newGroup in
                addGroup(newGroup)
            }
        }
        .sheet(item: Binding(
            get: { editingGroup.map { GroupWrapper(group: $0) } },
            set: { editingGroup = $0?.group }
        )) { wrapper in
            ProxyGroupEditorView(group: wrapper.group, availableProxies: availableProxies) { updatedGroup in
                updateGroup(updatedGroup)
            }
        }
        .task {
            await loadData()
        }
        .alert("Error", isPresented: $showError) {
             Button("OK", role: .cancel) { }
        } message: {
             Text(errorMessage ?? "Unknown error")
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No Proxy Groups")
                .font(.title2)
            Text("Create proxy groups to organize your proxies")
                .foregroundColor(.secondary)
            Button("Add First Group") {
                showingAddGroup = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var groupList: some View {
        List {
            ForEach(groups) { group in
                SimpleProxyGroupRow(group: group)
                    .onTapGesture {
                        editingGroup = group
                    }
                    .contextMenu {
                        Button("Edit") {
                            editingGroup = group
                        }
                        Button("Duplicate") {
                            duplicateGroup(group)
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            deleteGroup(group)
                        }
                    }
            }
            .onMove(perform: moveGroups)
            .onDelete(perform: deleteGroups)
        }
    }
    
    // MARK: - API Operations
    
    private func loadData() async {
        do {
            async let groupsTask = APIClient.shared.fetchAllProxyGroups()
            async let proxiesTask = APIClient.shared.fetchAllProxies()
            
            let (fetchedGroups, fetchedProxies) = try await (groupsTask, proxiesTask)
            
            groups = fetchedGroups
            availableProxies = fetchedProxies.map { $0.name } + ["DIRECT", "REJECT", "REJECT-TINYGIF"]
        } catch {
            errorMessage = "Failed to load data: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func addGroup(_ group: ProxyGroupConfigModel) {
        Task {
            do {
                try await APIClient.shared.addProxyGroup(group)
                await loadData()
            } catch {
                errorMessage = "Failed to add group: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    private func updateGroup(_ group: ProxyGroupConfigModel) {
        Task {
            do {
                try await APIClient.shared.updateProxyGroup(name: group.name, group: group)
                await loadData()
            } catch {
                errorMessage = "Failed to update group: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    private func duplicateGroup(_ group: ProxyGroupConfigModel) {
        var newGroup = group
        newGroup.name = "\(group.name) Copy"
        addGroup(newGroup)
    }
    
    private func deleteGroup(_ group: ProxyGroupConfigModel) {
        Task {
            do {
                try await APIClient.shared.deleteProxyGroup(name: group.name)
                await loadData()
            } catch {
                errorMessage = "Failed to delete group: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    private func deleteGroups(at offsets: IndexSet) {
        // Deleting multiple is complex with API, doing one by one
        for index in offsets {
            let group = groups[index]
            deleteGroup(group)
        }
    }
    
    // API does not support reordering yet, so this is local only for now or stubbed
    private func moveGroups(from source: IndexSet, to destination: Int) {
        groups.move(fromOffsets: source, toOffset: destination)
        // Note: Reordering not persisted unless API supports it
    }
}

struct GroupWrapper: Identifiable {
    let id = UUID()
    let group: ProxyGroupConfigModel
}

struct SimpleProxyGroupRow: View {
    let group: ProxyGroupConfigModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(group.name)
                    .font(.headline)
                Spacer()
                Text(group.type)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(4)
            }
            
            if !group.proxies.isEmpty {
                Text("\(group.proxies.count) proxies")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let testURL = group.url {
                 Text("Test: \(testURL)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ProxyGroupEditorView: View {
    @Environment(\.dismiss) var dismiss
    @State private var group: ProxyGroupConfigModel
    let availableProxies: [String]
    let onSave: (ProxyGroupConfigModel) -> Void
    
    init(group: ProxyGroupConfigModel?, availableProxies: [String], onSave: @escaping (ProxyGroupConfigModel) -> Void) {
        self._group = State(initialValue: group ?? ProxyGroupConfigModel(name: "", type: "select", proxies: []))
        self.availableProxies = availableProxies
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic") {
                    TextField("Group Name", text: $group.name)
                    
                    Picker("Type", selection: $group.type) {
                        ForEach(ProxyGroupType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type.rawValue)
                        }
                    }
                }
                
                Section("Proxies") {
                    ForEach(availableProxies, id: \.self) { proxy in
                        Toggle(proxy, isOn: Binding(
                            get: { group.proxies.contains(proxy) },
                            set: { isOn in
                                if isOn {
                                    group.proxies.append(proxy)
                                } else {
                                    group.proxies.removeAll { $0 == proxy }
                                }
                            }
                        ))
                    }
                }
                
                if group.type == ProxyGroupType.urlTest.rawValue {
                    Section("Testing") {
                        TextField("Test URL", text: Binding(
                            get: { group.url ?? "" },
                            set: { group.url = $0.isEmpty ? nil : $0 }
                        ))
                        
                        TextField("Interval (seconds)", value: Binding(
                            get: { group.interval ?? 600 },
                            set: { group.interval = $0 }
                        ), format: .number)
                    }
                }
                
                Section("Advanced") {
                    Toggle("No Alert", isOn: Binding(get: { group.noAlert ?? false }, set: { group.noAlert = $0 }))
                    Toggle("Hidden", isOn: Binding(get: { group.hidden ?? false }, set: { group.hidden = $0 }))
                    Toggle("Include All Proxies", isOn: Binding(get: { group.includeAll ?? false }, set: { group.includeAll = $0 }))
                    
                    TextField("Policy Regex Filter", text: Binding(
                        get: { group.policyRegex ?? "" },
                        set: { group.policyRegex = $0.isEmpty ? nil : $0 }
                    ))
                    
                    TextField("Policy Path (URL)", text: Binding(
                        get: { group.policyPath ?? "" },
                        set: { group.policyPath = $0.isEmpty ? nil : $0 }
                    ))
                }
            }
            .navigationTitle(group.name.isEmpty ? "New Group" : "Edit Group")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(group)
                        dismiss()
                    }
                    .disabled(group.name.isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        ProxyGroupManagerView()
    }
}
