import AVFoundation
import AppKit
import os

final class AppDelegate: NSObject, NSApplicationDelegate {
  private var window: NSWindow?
  private var plugin: Plugin?
  private var audioEngine: AudioEngine?

  private let logger = Logger(subsystem: "net.ekkoh.Backline", category: "hosting")

  func applicationWillFinishLaunching(_ notification: Notification) {
    NSApp.mainMenu = MainMenu.build()
    NSWindow.allowsAutomaticWindowTabbing = false
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    // When running tests, Xcode launches the app to host them.
    // Skip normal launch so tests don't open windows or start audio.
    if ProcessInfo.processInfo.environment.keys.contains(where: { $0.hasPrefix("XCTest") }) {
      return
    }

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 800, height: 500),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.title = "Backline"
    window.isRestorable = false
    window.isReleasedWhenClosed = false
    window.center()
    window.makeKeyAndOrderFront(nil)

    self.window = window

    Task { await start() }
  }

  func applicationWillTerminate(_ notification: Notification) {
    guard let audioEngine else { return }
    audioEngine.stop()
    logger.notice("Stopped audio")
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }

  func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    true
  }

  private func start() async {
    guard await AVCaptureDevice.requestAccess(for: .audio) else {
      logger.error("Audio input access was denied.")
      return
    }

    guard let device = findDevice() else { return }
    setUpAudio(on: device)
    guard let audioEngine else { return }
    await loadPlugin(sampleRate: audioEngine.sampleRate)
    guard let plugin else { return }

    do {
      try audioEngine.start(with: plugin)
      logger.notice("Started audio")
      Task { await logCounts() }
    } catch {
      logger.error("Couldn't start audio: \(error, privacy: .public)")
      return
    }

    await showEditor(of: plugin)
  }

  private func showEditor(of plugin: Plugin) async {
    guard let editor = await plugin.requestEditor() else {
      logger.error("\(plugin.supportedPlugin.name, privacy: .public) has no editor.")
      return
    }
    let size = editor.view.frame.size
    logger.notice(
      "Editor is \(size.width, format: .fixed(precision: 0)) × \(size.height, format: .fixed(precision: 0))")
    window?.contentViewController = editor
    fitWindow(toEditorSize: size)
  }

  /// Opens at twice the editor's default size, within the screen, and never smaller than the default.
  private func fitWindow(toEditorSize editorSize: NSSize) {
    guard let window, let screen = window.screen else { return }
    let available = window.contentRect(forFrameRect: screen.visibleFrame).size
    let size = NSSize(
      width: max(min(editorSize.width * 2, available.width), editorSize.width),
      height: max(min(editorSize.height * 2, available.height), editorSize.height),
    )
    window.contentMinSize = editorSize
    window.setContentSize(size)
    window.center()
  }

  private func logCounts() async {
    while let counts = audioEngine?.counts() {
      logger.notice(
        """
        Renders \(counts.renderCount) (last status \(counts.lastRenderStatus)), \
        input pulls \(counts.pullCount) (last status \(counts.lastPullStatus))
        """
      )
      try? await Task.sleep(for: .seconds(1))
    }
  }

  private func findDevice() -> AudioDevice? {
    do {
      // A stand-in until choosing devices arrives.
      guard let device = try AudioDevice.all().first(where: { try $0.name().contains("HELIX") }) else {
        logger.error("No Helix is connected.")
        return nil
      }

      let name = try device.name()
      let sampleRate = try device.sampleRate()
      let bufferSizes = try device.bufferSizeRange()
      logger.notice(
        """
        Found \(name, privacy: .public) at \(sampleRate, format: .fixed(precision: 0)) Hz, \
        buffer sizes \(bufferSizes.lowerBound)–\(bufferSizes.upperBound)
        """
      )
      return device
    } catch {
      logger.error("Couldn't find the Helix: \(error, privacy: .public)")
      return nil
    }
  }

  private func setUpAudio(on device: AudioDevice) {
    do {
      // Stand-ins until choosing channels arrives.
      audioEngine = try AudioEngine(device: device, inputChannel: 7, outputChannel: 1)
      let bufferSize = try device.bufferSize()
      logger.notice("Set up AUHAL with a buffer of \(bufferSize) samples")
    } catch {
      logger.error("Couldn't set up audio: \(error, privacy: .public)")
    }
  }

  private func loadPlugin(sampleRate: Double) async {
    guard let supportedPlugin = SupportedPlugin.all.first(where: \.isInstalled) else {
      logger.error("No supported plugin is installed.")
      return
    }
    do {
      let plugin = try await Plugin.load(supportedPlugin)

      try plugin.prepare(sampleRate: sampleRate)
      self.plugin = plugin

      let input = plugin.audioUnit.inputBusses[0].format
      let output = plugin.audioUnit.outputBusses[0].format

      logger.notice(
        """
        Prepared \(supportedPlugin.name, privacy: .public): \
        \(input.channelCount) in / \(output.channelCount) out at \(output.sampleRate, format: .fixed(precision: 0)) Hz, \
        latency \(plugin.audioUnit.latency * 1000, format: .fixed(precision: 2)) ms
        """
      )
    } catch {
      logger.error(
        "Couldn't load \(supportedPlugin.name, privacy: .public): \(error, privacy: .public)"
      )
    }
  }
}
