import AVFAudio

/// A loaded plugin, set up for mono in and stereo out.
final class Plugin {
  /// The most frames a single render can ask for.
  /// Device buffers stay within it, so only a sample rate change means preparing again.
  static let maximumFrames: AUAudioFrameCount = 4096

  let supportedPlugin: SupportedPlugin
  let audioUnit: AUAudioUnit

  private init(supportedPlugin: SupportedPlugin, audioUnit: AUAudioUnit) {
    self.supportedPlugin = supportedPlugin
    self.audioUnit = audioUnit
  }

  static func load(_ supportedPlugin: SupportedPlugin) async throws -> Plugin {
    let audioUnit = try await AUAudioUnit.instantiate(
      with: supportedPlugin.componentDescription, options: .loadInProcess)
    return Plugin(supportedPlugin: supportedPlugin, audioUnit: audioUnit)
  }

  func prepare(sampleRate: Double) throws {
    // Formats can only change while render resources are deallocated.
    if audioUnit.renderResourcesAllocated {
      audioUnit.deallocateRenderResources()
    }

    // These only return nil above two channels, so `!` is safe.
    let mono = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    let stereo = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
    try audioUnit.inputBusses[0].setFormat(mono)
    try audioUnit.outputBusses[0].setFormat(stereo)

    // Input buses start disabled, enabling one is what connects it.
    // Bus 0 carries the guitar. Nothing feeds the side-chain.
    for index in 0..<audioUnit.inputBusses.count {
      audioUnit.inputBusses[index].isEnabled = index == 0
    }

    audioUnit.maximumFramesToRender = Self.maximumFrames

    try audioUnit.allocateRenderResources()
  }
}
