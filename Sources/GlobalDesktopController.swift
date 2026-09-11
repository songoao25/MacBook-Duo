import AppKit
import ScreenCaptureKit
import Carbon
import CoreMedia

// Capture and render are local only. No recordings or network output.
@MainActor
final class GlobalDesktopController: NSObject, @preconcurrency SCStreamOutput, SCStreamDelegate {
    private let model: AppModel
    private weak var setupWindow: NSWindow?
    private var overlay: NSWindow?
    private var renderer: GlassMetalView?
    private var stream: SCStream?
    private var timer: Timer?
    private var statusItem: NSStatusItem!
    private var hotKeys: [EventHotKeyRef] = []
    private var eventHandler: EventHandlerRef?
    private var generation = 0
    private var starting = false
    private var startedAt = Date()
    private var lastDelivery = Date()
    private var receivedFrame = false
    private var requestedVisible = false
    private var previewUntil = Date.distantPast
    private var previewRequested = false
    private var frameCount = 0
    private var capturedDisplayID: CGDirectDisplayID?
    private var statusLine: NSMenuItem!
    private var statusTick = 0
    private var observers: [NSObjectProtocol] = []
    private var resumeWanted = false
    private var sleepReasons = Set<String>()
    private var recoveryTimer: Timer?
    private var recoveryFailures = 0
    private var nextRecoveryAttempt = Date.distantPast
    // The setup window is hidden during capture. After wake, on-screen content
    // may omit our process, but the SCApplication from this process remains valid.
    private var captureApplication: SCRunningApplication?

    init(model: AppModel, setupWindow: NSWindow) {
        self.model = model
        self.setupWindow = setupWindow
        super.init()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let url = Bundle.main.url(forResource: "MacBookDuo", withExtension: "png"),
           let icon = NSImage(contentsOf: url) {
            icon.size = NSSize(width: 18, height: 18)
            statusItem.button?.image = icon
        }
        statusItem.button?.setAccessibilityLabel("MacBook Duo")
        let menu = NSMenu()
        statusLine = NSMenuItem(title: "尚未启动", action: nil, keyEquivalent: "")
        menu.addItem(statusLine)
        for (title, action) in [
            ("测试实时效果（8秒）", #selector(preview)),
            ("开启 / 停止全局效果   ⌘⇧G", #selector(toggle)),
            ("保存当前铰链终点   ⌘⇧K", #selector(calibrate)),
            ("打开设置   ⌘⇧Esc", #selector(showSetup)),
            ("退出 MacBook Duo", #selector(quit))
        ] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        statusItem.menu = menu
        registerKeys()
        for (name, key) in [(NSWorkspace.willSleepNotification, "system"),
                            (NSWorkspace.screensDidSleepNotification, "display"),
                            (NSWorkspace.sessionDidResignActiveNotification, "session")] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(
                forName: name, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.sleepReasons.insert(key)
                        self?.suspend(reason: "已暂停，开盖唤醒后自动恢复")
                    }
                })
        }
        for (name, key) in [(NSWorkspace.didWakeNotification, "system"),
                            (NSWorkspace.screensDidWakeNotification, "display"),
                            (NSWorkspace.sessionDidBecomeActiveNotification, "session")] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(
                forName: name, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.sleepReasons.remove(key)
                        self?.recoverIfReady()
                    }
                })
        }
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            // Retain the texture across Space changes; sleep/session guards
            // prevent the desktop overlay from being drawn over a locked session.
            MainActor.assumeIsolated {
                self?.overlay?.orderOut(nil)
                self?.startedAt = Date()
            }
        })
    }

    @objc func preview() {
        previewRequested = true
        if stream != nil {
            previewUntil = Date().addingTimeInterval(8)
        } else { start() }
    }

    @objc private func toggle() {
        if stream != nil || starting || resumeWanted { stop(reason: "全局效果已停止") } else { start() }
    }
    @objc private func calibrate() {
        guard model.sensor.isAvailable else { return }
        // Global mode always calibrates the real hinge, never a preview slider.
        model.useSensor = true
        model.saveOpenAngle()
    }
    @objc func showSetup() {
        stop(reason: "全局效果已停止")
        model.returnToSetup()
        NSApp.presentationOptions = [.autoHideDock, .autoHideMenuBar]
        setupWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc private func quit() {
        stop(reason: "已停止")
        NSApp.terminate(nil)
    }

    func start(automatically: Bool = false) {
        guard !model.permissionsPreparing else { return }
        guard !starting && stream == nil else { return }
        guard !hotKeys.isEmpty else {
            model.globalStatus = "紧急停止快捷键注册失败，未启用覆盖层"
            return
        }
        guard model.sensor.isAvailable else {
            model.globalStatus = "没有可用的真实铰链传感器，请使用截图测试模式"
            return
        }
        if !automatically {
            recoveryFailures = 0
            nextRecoveryAttempt = .distantPast
        }
        resumeWanted = true
        guard sleepReasons.isEmpty else {
            suspend(reason: "等待屏幕唤醒后自动恢复")
            return
        }
        starting = true
        generation += 1
        let token = generation
        model.globalStatus = "正在请求桌面捕获；如出现系统提示，请允许屏幕录制"
        Task { @MainActor in
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard token == generation else { return }
                // Target the built-in panel. External displays aren't hinge-driven.
                guard let display = content.displays.first(where: { CGDisplayIsBuiltin($0.displayID) != 0 }),
                      let screen = NSScreen.screens.first(where: {
                          ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == display.displayID
                      }) else { throw GlobalError.noInternalDisplay }
                let ownPID = ProcessInfo.processInfo.processIdentifier
                if let application = content.applications.first(where: { $0.processID == ownPID }) {
                    captureApplication = application
                }
                guard let application = captureApplication, application.processID == ownPID else {
                    throw GlobalError.cannotExcludeSelf
                }
                let excluded = [application]
                let filter = SCContentFilter(display: display, excludingApplications: excluded, exceptingWindows: [])
                let config = SCStreamConfiguration()
                // Logical resolution for prototype power budget; native panel output.
                config.width = Int(screen.frame.width)
                config.height = Int(screen.frame.height)
                config.pixelFormat = kCVPixelFormatType_32BGRA
                config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
                config.queueDepth = 3
                config.showsCursor = false
                config.capturesAudio = false
                let renderer = self.renderer ?? GlassMetalView()
                guard renderer.device != nil else { throw GlobalError.noGPU }
                let overlay = (self.overlay as? NSPanel) ?? NSPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
                overlay.hidesOnDeactivate = false
                overlay.becomesKeyOnlyIfNeeded = true
                overlay.isReleasedWhenClosed = false
                overlay.backgroundColor = .black
                overlay.hasShadow = false
                overlay.ignoresMouseEvents = true
                // A nonactivating panel may join other applications' native
                // fullscreen spaces without taking their keyboard focus.
                // Include Dock/Launchpad, menu bar and ordinary pop-up menus in
                // the live composite. Keep below screen saver/security surfaces.
                // Mouse events still pass through; global emergency keys remain.
                overlay.level = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue + 1)
                overlay.collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications,
                                              .fullScreenAuxiliary, .stationary, .ignoresCycle]
                overlay.contentView = renderer
                overlay.setFrame(screen.frame, display: false)
                self.renderer = renderer
                self.overlay = overlay
                capturedDisplayID = display.displayID
                let stream = SCStream(filter: filter, configuration: config, delegate: self)
                try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)
                self.stream = stream
                frameCount = 0
                setupWindow?.orderOut(nil)
                NSApp.presentationOptions = []
                startedAt = Date()
                lastDelivery = Date()
                if !automatically { receivedFrame = false }
                try await stream.startCapture()
                guard token == generation else {
                    try? await stream.stopCapture()
                    return
                }
                starting = false
                if !sleepReasons.isEmpty {
                    suspend(reason: "保留画面，等待开盖继续")
                    return
                }
                recoveryTimer?.invalidate()
                recoveryTimer = nil
                if previewRequested {
                    previewUntil = Date().addingTimeInterval(8)
                    previewRequested = false
                }
                model.globalRunning = true
                model.globalStatus = "实时桌面已启用 · ⌘⇧Esc 停止并恢复设置"
                statusItem.button?.toolTip = model.globalStatus
                NSLog("Global capture started")
                resumeRendering()
            } catch {
                guard token == generation else { return }
                let failedStream = self.stream
                self.stream = nil
                starting = false
                if let failedStream { Task { try? await failedStream.stopCapture() } }
                if automatically && recoveryFailures < 3 {
                    recoveryFailures += 1
                    nextRecoveryAttempt = Date().addingTimeInterval(Double(recoveryFailures))
                    suspend(reason: "唤醒后正在重试（\(recoveryFailures)/3）：\(error.localizedDescription)")
                    return
                }
                stop(reason: "无法启动：\(error.localizedDescription)。请检查系统设置 → 隐私与安全性 → 屏幕录制权限。")
                setupWindow?.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    private func suspend(reason: String) {
        guard resumeWanted || stream != nil || starting else { return }
        // Suspension must not destroy the window, GPU textures, or healthy stream.
        timer?.invalidate()
        timer = nil
        renderer?.isPaused = true
        if sleepReasons.contains("session") { overlay?.orderOut(nil) }
        model.globalRunning = true
        model.globalStatus = reason
        statusLine?.title = reason
        NSLog("Global suspended (resources retained): %@", reason)
        if recoveryTimer == nil {
            let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.recoverIfReady() }
            }
            recoveryTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func recoverIfReady() {
        guard resumeWanted, sleepReasons.isEmpty, !starting,
              Date() >= nextRecoveryAttempt,
              !model.permissionsPreparing, model.sensor.isAvailable,
              Date().timeIntervalSince(model.sensor.lastSuccessfulUpdate) < 0.5,
              NSScreen.screens.contains(where: {
                  guard let id = ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value else { return false }
                  return CGDisplayIsBuiltin(id) != 0 && CGDisplayIsActive(id) != 0
              }) else { return }
        if stream != nil {
            recoveryTimer?.invalidate()
            recoveryTimer = nil
            startedAt = Date()
            resumeRendering()
            model.globalStatus = "开盖继续显示 · 窗口与画面已保留"
            NSLog("Global resumed using existing stream and renderer")
            return
        }
        // Wake recovery must never open a fresh permission prompt by itself.
        guard CGPreflightScreenCaptureAccess() else {
            stop(reason: "屏幕录制权限不可用，请手动启用实时效果并允许权限")
            return
        }
        start(automatically: true)
    }

    private func resumeRendering() {
        renderer?.isPaused = false
        timer?.invalidate()
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.update() }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        update()
    }

    func stop(reason: String, preserveIntent: Bool = false) {
        if !preserveIntent {
            resumeWanted = false
            recoveryTimer?.invalidate()
            recoveryTimer = nil
        }
        generation += 1
        starting = false
        overlay?.orderOut(nil)
        overlay = nil
        renderer = nil
        capturedDisplayID = nil
        timer?.invalidate()
        timer = nil
        let oldStream = stream
        stream = nil
        if let oldStream { Task { try? await oldStream.stopCapture() } }
        receivedFrame = false
        requestedVisible = false
        previewRequested = false
        previewUntil = .distantPast
        model.globalRunning = preserveIntent
        model.globalStatus = reason
        statusItem?.button?.toolTip = reason
        statusItem?.button?.title = preserveIntent ? " 待" : " 停"
        statusLine?.title = reason
        NSLog("Global stopped: %@", reason)
    }

    func screenConfigurationChanged() {
        // Menu/Dock visibility also posts screen-parameter notifications.
        // Only stop for a real change to the captured display or its full frame.
        guard let id = capturedDisplayID, let overlay else { return }
        let screen = NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == id
        }
        if screen == nil || screen!.frame != overlay.frame {
            if let screen {
                overlay.setFrame(screen.frame, display: false)
                let oldStream = stream
                stream = nil
                if let oldStream { Task { try? await oldStream.stopCapture() } }
            }
            suspend(reason: "内建显示器变化，等待恢复实时效果")
        }
    }

    private func update() {
        guard sleepReasons.isEmpty else { return }
        guard let renderer, let overlay else { return }
        if Date().timeIntervalSince(model.sensor.lastSuccessfulUpdate) > 2 {
            suspend(reason: "等待铰链数据恢复后自动继续")
            return
        }
        if !receivedFrame && Date().timeIntervalSince(startedAt) > 8 {
            if recoveryFailures < 3 {
                recoveryFailures += 1
                suspend(reason: "等待唤醒后的桌面画面，正在重新连接")
            } else {
                stop(reason: "桌面捕获超时，已撤掉覆盖层；按 ⌘⇧G 重试")
            }
            return
        }
        // A static desktop may legitimately produce no new complete frames.
        // Keep the last valid texture; explicit stream errors still stop immediately.
        let remaining = Date() < previewUntil ? 0.35 : max(0, 1 - model.sensor.angle / model.openAngle)
        renderer.setLiveAngle(remaining * 80)
        // Hysteresis prevents overlay flicker near the calibrated endpoint.
        if remaining > 0.008 { requestedVisible = true }
        if remaining == 0 && renderer.settled { requestedVisible = false }
        if requestedVisible && receivedFrame && renderer.readyForDisplay {
            if !overlay.isVisible { overlay.orderFrontRegardless() }
        } else { overlay.orderOut(nil) }
        statusTick += 1
        if statusTick % 30 == 0 {
            let state = overlay.isVisible ? "效果显示中" : "原桌面"
            statusItem.button?.title = " \(Int(model.sensor.angle))°"
            statusLine.title = "\(state) · 已捕获 \(frameCount) 帧 · 终点 \(Int(model.openAngle))°"
            if statusTick % 120 == 0 { NSLog("%@", statusLine.title) }
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard self.stream === stream, type == .screen, sampleBuffer.isValid else { return }
        guard sleepReasons.isEmpty else { return }
        lastDelivery = Date()
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let raw = attachments.first?[.status] as? Int,
              SCFrameStatus(rawValue: raw) == .complete,
              let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        renderer?.receive(buffer)
        recoveryFailures = 0
        receivedFrame = true
        frameCount += 1
    }

    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor in
            guard self.stream === stream else { return }
            self.stream = nil
            if recoveryFailures < 3 {
                recoveryFailures += 1
                suspend(reason: "捕获暂时中断，等待恢复：\(error.localizedDescription)")
            } else {
                stop(reason: "捕获恢复失败，请手动重新启用：\(error.localizedDescription)")
            }
        }
    }

    private func registerKeys() {
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, pointer in
            guard let event, let pointer else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            let controller = Unmanaged<GlobalDesktopController>.fromOpaque(pointer).takeUnretainedValue()
            switch id.id {
            case 1: controller.showSetup()
            case 2: controller.toggle()
            case 3: controller.calibrate()
            default: break
            }
            return noErr
        }, 1, &event, pointer, &eventHandler)
        for (id, code) in [(UInt32(1), UInt32(kVK_Escape)), (2, UInt32(kVK_ANSI_G)), (3, UInt32(kVK_ANSI_K))] {
            var ref: EventHotKeyRef?
            let result = RegisterEventHotKey(code, UInt32(cmdKey | shiftKey),
                EventHotKeyID(signature: 0x48474C53, id: id), GetApplicationEventTarget(), 0, &ref)
            if result == noErr, let ref { hotKeys.append(ref) }
            else if id == 1 { break } // Never start without an emergency exit.
        }
    }

    enum GlobalError: LocalizedError {
        case noInternalDisplay, cannotExcludeSelf, noGPU
        var errorDescription: String? {
            switch self {
            case .noInternalDisplay: return "未找到内建显示屏"
            case .cannotExcludeSelf: return "无法排除自身窗口，为避免重复捕获已取消"
            case .noGPU: return "Metal 不可用"
            }
        }
    }
}
