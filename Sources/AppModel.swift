import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    enum Page {
        case setup
        case test
    }

    @Published var page: Page = .setup
    @Published var desktopImage: NSImage?
    @Published var importedFileName = ""
    @Published var useSensor = true
    @Published var simulatedAngle = 105.0
    @Published var controlsHidden = false
    @Published var showOriginal = false
    @Published var calibrationMessage = ""
    @Published var openAngle = 120.0
    @Published var globalStatus = "实时桌面模式需要屏幕录制权限"
    @Published var globalRunning = false
    @Published var permissionsPreparing = true
    var startGlobal: (() -> Void)?
    var previewGlobal: (() -> Void)?

    var currentAngle: Double { useSensor && sensor.isAvailable ? sensor.angle : simulatedAngle }

    func saveOpenAngle() {
        let value = currentAngle
        guard value.isFinite, value >= 1, value <= 180 else {
            calibrationMessage = "请先打开屏幕，再保存展开终点"
            controlsHidden = false
            return
        }
        openAngle = value
        UserDefaults.standard.set(value, forKey: "calibratedOpenAngle")
        calibrationMessage = "已保存展开终点"
    }

    let sensor = LidAngleSensor()

    init() {
        let saved = UserDefaults.standard.object(forKey: "calibratedOpenAngle") as? Double
            ?? UserDefaults(suiteName: "studio.prototype.HingeGlass")?.double(forKey: "calibratedOpenAngle") ?? 120
        if saved >= 1 && saved <= 180 { openAngle = saved }
        sensor.start()
    }

    func importScreenshot() {
        let panel = NSOpenPanel()
        panel.title = "选择桌面截图"
        panel.message = "请选择一张完整的桌面截图，用作玻璃层下方的内容。"
        panel.prompt = "导入截图"
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff]

        guard panel.runModal() == .OK,
              let url = panel.url,
              let image = NSImage(contentsOf: url)
        else { return }

        desktopImage = image
        importedFileName = url.lastPathComponent
    }

    func startTest() {
        guard desktopImage != nil else { return }
        controlsHidden = false
        withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) {
            page = .test
        }
    }

    func returnToSetup() {
        controlsHidden = false
        withAnimation(.easeInOut(duration: 0.3)) {
            page = .setup
        }
    }

    func toggleFullScreen() {
        guard let window = NSApp.keyWindow, let screen = window.screen else { return }
        window.setFrame(screen.frame, display: true)
    }
}
