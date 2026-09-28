import AppKit

// NSApplicationMain runs on the main thread, so it's safe to assume the main actor.
MainActor.assumeIsolated {
  let delegate = AppDelegate()
  NSApplication.shared.delegate = delegate

  _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
}
