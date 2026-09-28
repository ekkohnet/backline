import AVFAudio
import AppKit
import os

final class AppDelegate: NSObject, NSApplicationDelegate {
  private var window: NSWindow?
  private var plugin: Plugin?

  private let logger = Logger(subsystem: "net.ekkoh.Backline", category: "hosting")

  func applicationWillFinishLaunching(_ notification: Notification) {
    NSApp.mainMenu = MainMenu.build()
    NSWindow.allowsAutomaticWindowTabbing = false
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    // When running tests, Xcode launches the app to host them.
    // Skip the normal launch so tests don't open windows or start audio.
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

    Task { await loadPlugin() }
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }

  func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    true
  }

  private func loadPlugin() async {
    guard let supported = SupportedPlugin.all.first(where: \.isInstalled) else {
      logger.error("No supported plugin is installed.")
      return
    }
    do {
      let plugin = try await Plugin.load(supported)

      // A stand-in until the audio device provides the real rate.
      try plugin.prepare(sampleRate: 48_000)
      self.plugin = plugin

      let input = plugin.audioUnit.inputBusses[0].format
      let output = plugin.audioUnit.outputBusses[0].format

      logger.notice(
        """
        Prepared \(supported.name, privacy: .public): \
        \(input.channelCount) in / \(output.channelCount) out at \(output.sampleRate, format: .fixed(precision: 0)) Hz, \
        latency \(plugin.audioUnit.latency * 1000, format: .fixed(precision: 2)) ms
        """
      )
    } catch {
      logger.error(
        "Couldn't load \(supported.name, privacy: .public): \(error, privacy: .public)"
      )
    }
  }
}
