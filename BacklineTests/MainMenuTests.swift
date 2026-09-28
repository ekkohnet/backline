import AppKit
import Testing

@testable import Backline

struct MainMenuTests {
  @Test func menuBarHasTheStandardMenus() {
    let titles = MainMenu.build().items.map { $0.submenu?.title }
    #expect(titles == ["Backline", "Edit", "Window", "Help"])
  }
}
