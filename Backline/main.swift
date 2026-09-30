import AppKit

// NSApplicationMain runs on the main thread, so safe to assume main actor.
MainActor.assumeIsolated {
  let delegate = AppDelegate()
  NSApplication.shared.delegate = delegate

  _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
}
