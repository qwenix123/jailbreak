import SwiftUI
import UIKit

// MARK: - Models
struct TweakItem: Identifiable, Equatable {
    let id: String
    let name: String
    let author: String
    let desc: String
    let iconSystemName: String
    let iconColor: Color
    let version: String
    let size: String
    let repo: String
}

struct LogEntry: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let type: LogType
    
    enum LogType {
        case muted, info, success, warning, error
        
        var color: Color {
            switch self {
            case .muted: return Color(white: 0.45)
            case .info: return .white
            case .success: return Color(red: 0.19, green: 0.82, blue: 0.35)
            case .warning: return Color(red: 1.0, green: 0.84, blue: 0.04)
            case .error: return Color(red: 1.0, green: 0.27, blue: 0.23)
            }
        }
    }
}

struct FileItem: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let isFolder: Bool
    let path: String
}

// MARK: - Main ContentView
struct ContentView: View {
    @AppStorage("nowera1n_installed") private var isInstalled: Bool = false
    @AppStorage("selected_exploit") private var selectedExploit: String = "cha1n"
    @AppStorage("installed_tweaks_csv") private var installedTweaksCsv: String = ""
    
    @State private var currentTab: Tab = .home
    @State private var logs: [LogEntry] = []
    @State private var progress: Double = 0.0
    @State private var isInstalling: Bool = false
    @State private var showSettings: Bool = false
    @State private var selectedTweak: TweakItem? = nil
    @State private var showRespringBanner: Bool = false
    @State private var isRespringing: Bool = false
    @State private var showTrollStore: Bool = false
    @State private var showFilza: Bool = false
    @State private var currentTime: String = ""
    @State private var sessionId: String = "SESS-8492"
    
    enum Tab {
        case home, tweaks
    }
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    let tweaks: [TweakItem] = [
        TweakItem(id: "filza", name: "Filza File Manager", author: "TIGI Software", desc: "Complete iOS File Manager.", iconSystemName: "folder.fill", iconColor: .blue, version: "3.9.8", size: "14.2 MB", repo: "TIGI"),
        TweakItem(id: "snowboard", name: "SnowBoard", author: "SparkDev", desc: "Icon theming engine for iOS.", iconSystemName: "paintbrush.fill", iconColor: .purple, version: "1.5.26", size: "2.1 MB", repo: "SparkDev"),
        TweakItem(id: "trollstorelite", name: "TrollStore Lite", author: "opa334", desc: "Lightweight IPA installer.", iconSystemName: "shippingbox.fill", iconColor: .cyan, version: "1.0.1", size: "1.4 MB", repo: "Havoc"),
        TweakItem(id: "aim", name: "AIM", author: "Havoc", desc: "Advanced Interface Modifier.", iconSystemName: "slider.horizontal.3", iconColor: .orange, version: "2.0.3", size: "5.8 MB", repo: "Havoc"),
        TweakItem(id: "gesturesxv", name: "GesturesXV", author: "Havoc", desc: "Custom navigation gestures.", iconSystemName: "hand.draw.fill", iconColor: .green, version: "1.2.0", size: "800 KB", repo: "Havoc")
    ]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Tab Content
                if currentTab == .home {
                    HomeTabView(
                        isInstalled: $isInstalled,
                        selectedExploit: selectedExploit,
                        isInstalling: isInstalling,
                        progress: progress,
                        logs: logs,
                        sessionId: sessionId,
                        currentTime: currentTime,
                        onOpenSettings: { showSettings = true },
                        onStartInstall: { startExploitChain() }
                    )
                } else {
                    TweaksTabView(
                        tweaks: tweaks,
                        installedTweaksCsv: installedTweaksCsv,
                        onSelectTweak: { tweak in
                            selectedTweak = tweak
                        }
                    )
                }
                
                Spacer(minLength: 0)
                
                // Bottom Tab Bar
                CustomTabBar(currentTab: $currentTab, isInstalled: isInstalled)
            }
            
            // Respring Banner
            if showRespringBanner {
                VStack {
                    Spacer()
                    Button(action: triggerRespring) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 15, weight: .bold))
                            Text("Respring to apply")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .cornerRadius(100)
                        .shadow(color: .black.opacity(0.8), radius: 15, y: 5)
                    }
                    .padding(.bottom, 80)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            
            // Fullscreen Native Respring Animation
            if isRespringing {
                RespringView()
                    .transition(.opacity)
                    .zIndex(9999)
            }
        }
        .sheet(item: $selectedTweak) { tweak in
            TweakDetailSheet(
                tweak: tweak,
                isInstalled: isTweakInstalled(tweak.id),
                onToggleInstall: {
                    toggleTweakInstall(tweak.id)
                },
                onOpenApp: {
                    if tweak.id == "filza" {
                        showFilza = true
                    } else if tweak.id == "trollstorelite" {
                        showTrollStore = true
                    }
                }
            )
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(
                selectedExploit: $selectedExploit,
                onUninstall: {
                    isInstalled = false
                    installedTweaksCsv = ""
                    logs.removeAll()
                    progress = 0
                    showRespringBanner = false
                    showSettings = false
                    addLog("nowera1n uninstalled. Environment reset.", type: .warning)
                }
            )
        }
        .fullScreenCover(isPresented: $showFilza) {
            FilzaAppView(isPresented: $showFilza)
        }
        .fullScreenCover(isPresented: $showTrollStore) {
            TrollStoreAppView(isPresented: $showTrollStore)
        }
        .onAppear {
            updateTime()
            sessionId = "SESS-\(Int.random(in: 1000...9999))"
            if logs.isEmpty {
                if isInstalled {
                    addLog("[INFO] Environment check passed.", type: .muted)
                    addLog("[INFO] Device kernel slide: 0x1e800000", type: .muted)
                    addLog("[SUCCESS] nowera1n is already active.", type: .success)
                } else {
                    addLog("[INFO] nowera1n v2.4.0 (arm64)", type: .muted)
                    addLog("[INFO] Environment check passed. iOS device detected.", type: .muted)
                    addLog("[INFO] Ready to install nowera1n.", type: .muted)
                }
            }
        }
        .onReceive(timer) { _ in
            updateTime()
        }
    }
    
    // MARK: - Helpers
    private func updateTime() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        currentTime = formatter.string(from: Date())
    }
    
    private func addLog(_ text: String, type: LogEntry.LogType) {
        logs.append(LogEntry(text: text, type: type))
    }
    
    private func isTweakInstalled(_ id: String) -> Bool {
        installedTweaksCsv.split(separator: ",").contains(Substring(id))
    }
    
    private func toggleTweakInstall(_ id: String) {
        var set = Set(installedTweaksCsv.split(separator: ",").map(String.init))
        if set.contains(id) {
            set.remove(id)
        } else {
            set.insert(id)
        }
        installedTweaksCsv = set.joined(separator: ",")
        withAnimation {
            showRespringBanner = true
        }
    }
    
    // MARK: - Detailed Jailbreak Log Chain
    private func startExploitChain() {
        guard !isInstalling else { return }
        isInstalling = true
        progress = 0.0
        logs.removeAll()
        
        let steps: [(text: String, type: LogEntry.LogType, delay: Double, prog: Double)] = [
            ("[INFO] Initializing nowera1n v2.4.0 exploit chain...", .info, 0.2, 0.03),
            ("[INFO] Selected kernel backend: \(selectedExploit.uppercased())", .muted, 0.3, 0.06),
            ("[DEBUG] Querying host_get_special_port(4)...", .muted, 0.25, 0.09),
            ("[DEBUG] Target Mach port obtained: 0x103", .muted, 0.25, 0.12),
            ("[INFO] Probing kernel memory mappings via kcall leak...", .info, 0.35, 0.16),
            ("[DEBUG] Kernel slide discovered at 0x1d400000", .muted, 0.3, 0.20),
            ("[DEBUG] Kernel base address: 0xfffffff007004000 + 0x1d400000", .muted, 0.3, 0.25),
            ("[INFO] Triggering race condition in vm_map_entry_t...", .info, 0.45, 0.30),
            ("[DEBUG] Exploiting use-after-free in IOSurfaceRootUserClient...", .muted, 0.4, 0.35),
            ("[SUCCESS] Gained fake task port (tfp0 / kernel_task)...", .success, 0.35, 0.42),
            ("[INFO] Escaping sandbox restrictions (seatbelt)...", .info, 0.3, 0.47),
            ("[DEBUG] Overwriting cred->cr_posix.cr_uid = 0 (root obtained)", .muted, 0.3, 0.52),
            ("[DEBUG] Overwriting task->t_flags |= TF_PLATFORM", .muted, 0.25, 0.56),
            ("[INFO] Bypassing Apple Mobile File Integrity (AMFI)...", .info, 0.4, 0.61),
            ("[DEBUG] Hooking cs_validate_page() & trust cache lookups...", .muted, 0.3, 0.66),
            ("[INFO] Disabling Page Protection Layer (PPL) enforcement...", .warning, 0.45, 0.72),
            ("[DEBUG] Injecting rootless trust cache into kernel memory...", .muted, 0.35, 0.77),
            ("[INFO] Mounting rootless bootstrap filesystem to /var/jb...", .info, 0.4, 0.82),
            ("[DEBUG] Extracting base packages: dpkg, bash, tar, coreutils...", .muted, 0.35, 0.86),
            ("[DEBUG] Creating symlinks: /var/jb/bin/sh -> /var/jb/bin/bash...", .muted, 0.25, 0.90),
            ("[INFO] Launching ellekit injection hook daemon...", .info, 0.35, 0.94),
            ("[DEBUG] Setting up launchd environment variables...", .muted, 0.3, 0.97),
            ("[SUCCESS] nowera1n jailbreak environment installed!", .success, 0.3, 1.0)
        ]
        
        var totalDelay = 0.0
        for step in steps {
            totalDelay += step.delay
            DispatchQueue.main.asyncAfter(deadline: .now() + totalDelay) {
                withAnimation(.linear(duration: 0.2)) {
                    self.progress = step.prog
                    self.addLog(step.text, type: step.type)
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDelay + 0.6) {
            self.isInstalled = true
            self.isInstalling = false
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            withAnimation {
                self.showRespringBanner = true
            }
        }
    }
    
    // MARK: - Native Respring (Never breaks, repeatable!)
    private func triggerRespring() {
        withAnimation(.easeIn(duration: 0.2)) {
            isRespringing = true
            showRespringBanner = false
        }
        
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        
        // Simulates realistic SpringBoard reload
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.4)) {
                isRespringing = false
            }
            let successGen = UINotificationFeedbackGenerator()
            successGen.notificationOccurred(.success)
            addLog("[INFO] SpringBoard reloaded successfully (respring).", type: .success)
        }
    }
}

// MARK: - Home Tab View
struct HomeTabView: View {
    @Binding var isInstalled: Bool
    let selectedExploit: String
    let isInstalling: Bool
    let progress: Double
    let logs: [LogEntry]
    let sessionId: String
    let currentTime: String
    let onOpenSettings: () -> Void
    let onStartInstall: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 8) {
                    // App Logo Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(LinearGradient(colors: [Color(white: 0.15), Color(white: 0.05)], startPoint: .top, endPoint: .bottom))
                            .frame(width: 72, height: 72)
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(white: 0.2), lineWidth: 1))
                        
                        Image(systemName: "bolt.shield.fill")
                            .font(.system(size: 34))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 10)
                    
                    Text("nowera1n")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(UIDevice.current.model + " • iOS " + UIDevice.current.systemVersion)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(white: 0.7))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color(white: 0.1))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(white: 0.18), lineWidth: 1))
                    
                    Text("Exploit: \(selectedExploit.uppercased()) • arm64e")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(white: 0.45))
                }
                .frame(maxWidth: .infinity)
                
                // Settings Gear Button
                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(white: 0.7))
                        .frame(width: 36, height: 36)
                        .background(Color(white: 0.1))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color(white: 0.2), lineWidth: 1))
                }
                .padding(.trailing, 20)
                .padding(.top, 10)
            }
            .padding(.bottom, 12)
            
            // Monospace Console Box
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(logs) { entry in
                            Text(entry.text)
                                .font(.system(size: 11.5, design: .monospaced))
                                .foregroundColor(entry.type.color)
                                .id(entry.id)
                        }
                    }
                    .padding(14)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(white: 0.04))
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(white: 0.12), lineWidth: 1))
                .padding(.horizontal, 20)
                .onChange(of: logs.count) { _ in
                    if let last = logs.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Progress Bar
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(white: 0.15))
                    .frame(height: 3)
                
                Capsule()
                    .fill(LinearGradient(colors: [Color.green, Color.white], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, min(CGFloat(progress), 1.0)) * (UIScreen.main.bounds.width - 40), height: 3)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .opacity(isInstalling || progress > 0 ? 1 : 0)
            
            // Action Button
            Button(action: onStartInstall) {
                Text(isInstalled ? "nowera1n Installed" : (isInstalling ? "Installing..." : "Install nowera1n"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isInstalled ? Color(white: 0.4) : .black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(isInstalled ? Color(white: 0.1) : Color.white)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isInstalled ? Color(white: 0.2) : Color.clear, lineWidth: 1)
                    )
            }
            .disabled(isInstalled || isInstalling)
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
            
            // Footer Meta
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text(sessionId)
                }
                Spacer()
                Text(currentTime)
            }
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(Color(white: 0.45))
            .padding(.horizontal, 24)
            .padding(.bottom, 6)
        }
    }
}

// MARK: - Tweaks Tab View
struct TweaksTabView: View {
    let tweaks: [TweakItem]
    let installedTweaksCsv: String
    let onSelectTweak: (TweakItem) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tweaks")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.top, 10)
            
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(tweaks) { tweak in
                        Button(action: { onSelectTweak(tweak) }) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color(white: 0.12))
                                        .frame(width: 54, height: 54)
                                    
                                    Image(systemName: tweak.iconSystemName)
                                        .font(.system(size: 24))
                                        .foregroundColor(tweak.iconColor)
                                }
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(tweak.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    Text(tweak.author)
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(white: 0.45))
                                    
                                    Text(tweak.desc)
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(white: 0.6))
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                Text(isInstalled(tweak.id) ? "OPEN" : "GET")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(isInstalled(tweak.id) ? Color.green : .black)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(isInstalled(tweak.id) ? Color(white: 0.12) : Color.white)
                                    .cornerRadius(100)
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color(white: 0.3))
                            }
                            .padding(12)
                            .background(Color(white: 0.06))
                            .cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(white: 0.12), lineWidth: 1))
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    private func isInstalled(_ id: String) -> Bool {
        installedTweaksCsv.split(separator: ",").contains(Substring(id))
    }
}

// MARK: - Bottom Tab Bar
struct CustomTabBar: View {
    @Binding var currentTab: ContentView.Tab
    let isInstalled: Bool
    
    var body: some View {
        HStack {
            Spacer()
            Button(action: { currentTab = .home }) {
                VStack(spacing: 4) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 20))
                    Text("Home")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(currentTab == .home ? .white : Color(white: 0.4))
            }
            Spacer()
            Button(action: {
                if isInstalled { currentTab = .tweaks }
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 20))
                    Text("Tweaks")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(currentTab == .tweaks ? .white : (isInstalled ? Color(white: 0.4) : Color(white: 0.2)))
            }
            .disabled(!isInstalled)
            Spacer()
        }
        .frame(height: 60)
        .background(Color(white: 0.05))
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color(white: 0.12)), alignment: .top)
    }
}

// MARK: - Native Respring View
struct RespringView: View {
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.6)
            }
        }
    }
}

// MARK: - Tweak Detail Sheet
struct TweakDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let tweak: TweakItem
    let isInstalled: Bool
    let onToggleInstall: () -> Void
    let onOpenApp: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(white: 0.12))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: tweak.iconSystemName)
                            .font(.system(size: 36))
                            .foregroundColor(tweak.iconColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tweak.name)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(tweak.author)
                            .font(.system(size: 13))
                            .foregroundColor(Color(white: 0.5))
                        
                        HStack(spacing: 10) {
                            Button(action: {
                                onToggleInstall()
                                dismiss()
                            }) {
                                Text(isInstalled ? "REMOVE" : "INSTALL")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(isInstalled ? .red : .black)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(isInstalled ? Color(red: 0.2, green: 0.05, blue: 0.05) : Color.white)
                                    .cornerRadius(100)
                            }
                            
                            if isInstalled && (tweak.id == "filza" || tweak.id == "trollstorelite") {
                                Button(action: {
                                    dismiss()
                                    onOpenApp()
                                }) {
                                    Text("OPEN")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.blue)
                                        .cornerRadius(100)
                                }
                            }
                        }
                        .padding(.top, 6)
                    }
                }
                .padding(.top, 24)
                
                Divider().background(Color(white: 0.2))
                
                // Meta Grid
                HStack {
                    Spacer()
                    VStack {
                        Text("VERSION").font(.system(size: 10, weight: .bold)).foregroundColor(Color(white: 0.45))
                        Text(tweak.version).font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                    }
                    Spacer()
                    VStack {
                        Text("SIZE").font(.system(size: 10, weight: .bold)).foregroundColor(Color(white: 0.45))
                        Text(tweak.size).font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                    }
                    Spacer()
                    VStack {
                        Text("REPO").font(.system(size: 10, weight: .bold)).foregroundColor(Color(white: 0.45))
                        Text(tweak.repo).font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
                
                Divider().background(Color(white: 0.2))
                
                // Description
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(tweak.desc)
                        .font(.system(size: 14))
                        .foregroundColor(Color(white: 0.7))
                        .lineSpacing(4)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Settings Sheet
struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedExploit: String
    let onUninstall: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Settings")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 20)
                
                Text("Select kernel exploit chain")
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.5))
                
                // Segmented Control
                HStack(spacing: 4) {
                    Button(action: { selectedExploit = "cha1n" }) {
                        VStack(spacing: 2) {
                            Text("Cha1n").font(.system(size: 14, weight: .bold))
                            Text("A15 – A18").font(.system(size: 9)).opacity(0.7)
                        }
                        .foregroundColor(selectedExploit == "cha1n" ? .black : Color(white: 0.5))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(selectedExploit == "cha1n" ? Color.white : Color.clear)
                        .cornerRadius(10)
                    }
                    
                    Button(action: { selectedExploit = "trox1n" }) {
                        VStack(spacing: 2) {
                            Text("troX1n").font(.system(size: 14, weight: .bold))
                            Text("A6 – A13").font(.system(size: 9)).opacity(0.7)
                        }
                        .foregroundColor(selectedExploit == "trox1n" ? .black : Color(white: 0.5))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(selectedExploit == "trox1n" ? Color.white : Color.clear)
                        .cornerRadius(10)
                    }
                }
                .padding(4)
                .background(Color(white: 0.08))
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(white: 0.16), lineWidth: 1))
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: onUninstall) {
                        Text("Uninstall nowera1n")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(red: 0.18, green: 0.04, blue: 0.04))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.3), lineWidth: 1))
                    }
                    
                    Button(action: { dismiss() }) {
                        Text("Close")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(white: 0.12))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - Interactive TrollStore Lite View
struct TrollStoreAppView: View {
    @Binding var isPresented: Bool
    @State private var selectedTab: Int = 0
    @State private var urlSchemeEnabled: Bool = true
    @State private var installWithTS: Bool = true
    @State private var autoRefresh: Bool = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    HStack(spacing: 10) {
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.cyan)
                        Text("TrollStore Lite")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Text("Done")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color(white: 0.1))
                
                // Segmented Tabs
                Picker("Tabs", selection: $selectedTab) {
                    Text("Apps").tag(0)
                    Text("Settings").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(14)
                
                if selectedTab == 0 {
                    // Apps List
                    ScrollView {
                        VStack(spacing: 12) {
                            HStack(spacing: 14) {
                                Image(systemName: "app.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.purple)
                                    .frame(width: 50, height: 50)
                                    .background(Color(white: 0.12))
                                    .cornerRadius(12)
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("GitHub Mobile")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("v3.115.0 • Unsigned")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(white: 0.5))
                                }
                                Spacer()
                                Image(systemName: "lock.fill")
                                    .foregroundColor(Color(white: 0.4))
                            }
                            .padding(12)
                            .background(Color(white: 0.08))
                            .cornerRadius(14)
                            
                            HStack(spacing: 14) {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.blue)
                                    .frame(width: 50, height: 50)
                                    .background(Color(white: 0.12))
                                    .cornerRadius(12)
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Telegram")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("v10.2.0 • Decrypted")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(white: 0.5))
                                }
                                Spacer()
                                Button(action: {
                                    if let url = URL(string: "tg://") {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    Text("OPEN")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(Color.blue)
                                        .cornerRadius(100)
                                }
                            }
                            .padding(12)
                            .background(Color(white: 0.08))
                            .cornerRadius(14)
                        }
                        .padding(.horizontal, 20)
                    }
                } else {
                    // Settings List
                    VStack(spacing: 0) {
                        Toggle("Enable URL Scheme", isOn: $urlSchemeEnabled)
                            .padding(14)
                            .foregroundColor(.white)
                        Divider().background(Color(white: 0.2))
                        Toggle("Install with TrollStore", isOn: $installWithTS)
                            .padding(14)
                            .foregroundColor(.white)
                        Divider().background(Color(white: 0.2))
                        Toggle("Auto-Refresh Apps", isOn: $autoRefresh)
                            .padding(14)
                            .foregroundColor(.white)
                    }
                    .background(Color(white: 0.08))
                    .cornerRadius(14)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Interactive Filza View
struct FilzaAppView: View {
    @Binding var isPresented: Bool
    @State private var currentPath: String = "/var"
    @State private var selectedFileContent: String? = nil
    @State private var selectedFileName: String = ""
    
    let fileSystem: [String: [FileItem]] = [
        "/var": [
            FileItem(name: "mobile", isFolder: true, path: "/var/mobile"),
            FileItem(name: "jb", isFolder: true, path: "/var/jb"),
            FileItem(name: "root", isFolder: true, path: "/var/root"),
            FileItem(name: "tmp", isFolder: true, path: "/var/tmp")
        ],
        "/var/jb": [
            FileItem(name: "Applications", isFolder: true, path: "/var/jb/Applications"),
            FileItem(name: "Library", isFolder: true, path: "/var/jb/Library"),
            FileItem(name: "usr", isFolder: true, path: "/var/jb/usr"),
            FileItem(name: "bootstrap.sh", isFolder: false, path: "/var/jb/bootstrap.sh"),
            FileItem(name: ".installed_nowera1n", isFolder: false, path: "/var/jb/.installed_nowera1n")
        ],
        "/var/jb/usr": [
            FileItem(name: "bin", isFolder: true, path: "/var/jb/usr/bin"),
            FileItem(name: "lib", isFolder: true, path: "/var/jb/usr/lib"),
            FileItem(name: "share", isFolder: true, path: "/var/jb/usr/share")
        ],
        "/var/jb/usr/bin": [
            FileItem(name: "bash", isFolder: false, path: "/var/jb/usr/bin/bash"),
            FileItem(name: "sbreload", isFolder: false, path: "/var/jb/usr/bin/sbreload"),
            FileItem(name: "dpkg", isFolder: false, path: "/var/jb/usr/bin/dpkg"),
            FileItem(name: "apt", isFolder: false, path: "/var/jb/usr/bin/apt")
        ],
        "/var/mobile": [
            FileItem(name: "Documents", isFolder: true, path: "/var/mobile/Documents"),
            FileItem(name: "Library", isFolder: true, path: "/var/mobile/Library"),
            FileItem(name: "Media", isFolder: true, path: "/var/mobile/Media")
        ]
    ]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    if currentPath != "/var" {
                        Button(action: goBack) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.blue)
                        }
                    } else {
                        Color.clear.frame(width: 50, height: 20)
                    }
                    
                    Spacer()
                    Text(currentPath)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                    
                    Button(action: { isPresented = false }) {
                        Text("Done")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color(white: 0.1))
                
                // File List
                List {
                    ForEach(currentFiles) { file in
                        Button(action: { handleFileTap(file) }) {
                            HStack(spacing: 12) {
                                Image(systemName: file.isFolder ? "folder.fill" : "doc.text.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(file.isFolder ? .blue : .gray)
                                
                                Text(file.name)
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                if file.isFolder {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(white: 0.3))
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color(white: 0.06))
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .sheet(item: Binding<FileContent?>(
            get: { selectedFileContent != nil ? FileContent(name: selectedFileName, text: selectedFileContent!) : nil },
            set: { _ in selectedFileContent = nil }
        )) { file in
            FileViewerSheet(fileName: file.name, content: file.text)
        }
    }
    
    private var currentFiles: [FileItem] {
        fileSystem[currentPath] ?? [
            FileItem(name: "Preferences.plist", isFolder: false, path: currentPath + "/Preferences.plist"),
            FileItem(name: "data.bin", isFolder: false, path: currentPath + "/data.bin")
        ]
    }
    
    private func handleFileTap(_ file: FileItem) {
        if file.isFolder {
            currentPath = file.path
        } else {
            selectedFileName = file.name
            if file.name == "bootstrap.sh" {
                selectedFileContent = "#!/bin/bash\n# nowera1n rootless bootstrap\nexport PATH=/var/jb/usr/bin:/var/jb/bin:$PATH\necho \"[nowera1n] Environment successfully loaded.\""
            } else if file.name == "sbreload" {
                selectedFileContent = "#!/bin/bash\n# SpringBoard reload binary\nexec killall -9 SpringBoard"
            } else {
                selectedFileContent = "{\n  \"package\": \"com.nowera1n.core\",\n  \"version\": \"2.4.0\",\n  \"status\": \"installed\"\n}"
            }
        }
    }
    
    private func goBack() {
        var parts = currentPath.split(separator: "/").map(String.init)
        if !parts.isEmpty {
            parts.removeLast()
            currentPath = "/" + parts.joined(separator: "/")
            if currentPath.isEmpty { currentPath = "/var" }
        }
    }
}

struct FileContent: Identifiable {
    let id = UUID()
    let name: String
    let text: String
}

struct FileViewerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let fileName: String
    let content: String
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Text(fileName)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .bold))
                }
                .padding()
                .background(Color(white: 0.1))
                
                ScrollView {
                    Text(content)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }
        }
    }
}
