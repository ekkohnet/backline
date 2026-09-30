import AVFAudio

/// A plugin Backline can host. The list of supported plugins is fixed.
struct SupportedPlugin {
  let name: String
  let componentDescription: AudioComponentDescription

  /// In order of preference. The first one installed is the one loaded.
  static let all = [
    SupportedPlugin(name: "Helix Stadium Native", subtype: "6C63", manufacturer: "LSIX"),
    SupportedPlugin(name: "Helix Native", subtype: "6HPA", manufacturer: "LSIX"),
  ]

  private init(name: String, subtype: String, manufacturer: String) {
    self.name = name
    componentDescription = AudioComponentDescription(
      componentType: kAudioUnitType_MusicEffect,
      componentSubType: fourCharCode(subtype),
      componentManufacturer: fourCharCode(manufacturer),
      componentFlags: 0,
      componentFlagsMask: 0
    )
  }

  var isInstalled: Bool {
    !AVAudioUnitComponentManager.shared().components(matching: componentDescription).isEmpty
  }
}

/// Packs a four-character audio unit code into Core Audio's integer form.
private func fourCharCode(_ code: String) -> OSType {
  code.utf8.reduce(0) { $0 << 8 | OSType($1) }
}
