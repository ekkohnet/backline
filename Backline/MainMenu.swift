import AppKit

enum MainMenu {
  static func build() -> NSMenu {

    // Menus the system fills in: available services, open windows, and Help's search.
    let services = NSMenu(title: "Services")
    let help = NSMenu(title: "Help")
    let window = windowMenu()
    NSApp.servicesMenu = services
    NSApp.windowsMenu = window
    NSApp.helpMenu = help

    let main = NSMenu()
    main.items = [
      submenu(appMenu(services: services)),
      submenu(editMenu()),
      submenu(window),
      submenu(help),
    ]
    return main
  }

  private static func appMenu(services: NSMenu) -> NSMenu {
    let menu = NSMenu(title: "Backline")
    menu.items = [
      item("About Backline", #selector(NSApplication.orderFrontStandardAboutPanel(_:))),
      .separator(),
      submenu(services),
      .separator(),
      item("Hide Backline", #selector(NSApplication.hide(_:)), key: "h"),
      item(
        "Hide Others", #selector(NSApplication.hideOtherApplications(_:)), key: "h", modifiers: [.command, .option]),
      item("Show All", #selector(NSApplication.unhideAllApplications(_:))),
      .separator(),
      item("Quit Backline", #selector(NSApplication.terminate(_:)), key: "q"),
    ]
    return menu
  }

  private static func editMenu() -> NSMenu {
    let menu = NSMenu(title: "Edit")
    menu.items = [
      item("Undo", Selector(("undo:")), key: "z"),
      item("Redo", Selector(("redo:")), key: "z", modifiers: [.command, .shift]),
      .separator(),
      item("Cut", #selector(NSText.cut(_:)), key: "x"),
      item("Copy", #selector(NSText.copy(_:)), key: "c"),
      item("Paste", #selector(NSText.paste(_:)), key: "v"),
      item("Select All", #selector(NSText.selectAll(_:)), key: "a"),
    ]
    return menu
  }

  private static func windowMenu() -> NSMenu {
    let menu = NSMenu(title: "Window")
    menu.items = [
      item("Minimize", #selector(NSWindow.performMiniaturize(_:)), key: "m"),
      item("Zoom", #selector(NSWindow.performZoom(_:))),
      .separator(),
      item("Bring All to Front", #selector(NSApplication.arrangeInFront(_:))),
    ]
    return menu
  }

  // MARK: Menu Helpers

  private static func item(
    _ title: String, _ action: Selector, key: String = "", modifiers: NSEvent.ModifierFlags = .command
  ) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
    item.keyEquivalentModifierMask = modifiers
    return item
  }

  private static func submenu(_ menu: NSMenu) -> NSMenuItem {
    let item = NSMenuItem(title: menu.title, action: nil, keyEquivalent: "")
    item.submenu = menu
    return item
  }
}
