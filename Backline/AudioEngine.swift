import AVFAudio

// AUHAL's two sides. Element 1 brings audio in from the device, and element 0 sends it out.
private let inputElement: AudioUnitElement = 1
private let outputElement: AudioUnitElement = 0

/// Runs audio through the plugin on one audio device, using AUHAL.
final class AudioEngine {
  static let bufferSize: UInt32 = 64

  let sampleRate: Double

  /// AUHAL, the audio unit connected to the audio device.
  private let outputUnit: AudioUnit

  /// What the render callback works with. Created when audio starts.
  private var renderState: OpaquePointer?

  /// Channels are numbered from 1, as on the device. `outputChannel` is the first of a stereo pair.
  init(device: AudioDevice, inputChannel: Int, outputChannel: Int) throws {
    sampleRate = try device.sampleRate()

    var description = AudioComponentDescription(
      componentType: kAudioUnitType_Output, componentSubType: kAudioUnitSubType_HALOutput,
      componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0)
    // AUHAL is part of macOS, so it's always found.
    let component = AudioComponentFindNext(nil, &description)!
    var unit: AudioUnit?
    try check(AudioComponentInstanceNew(component, &unit), "creating AUHAL")
    outputUnit = unit!

    // Input is off by default, and must be switched on before the device is chosen.
    try setProperty(kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, inputElement, UInt32(1), "enabling input")
    try setProperty(kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, device.id, "choosing the device")

    // The formats on our side of AUHAL. Mono from the device's input, stereo to its output.
    let mono = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    let stereo = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
    try setProperty(
      kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, inputElement, mono.streamDescription.pointee,
      "setting the input format")
    try setProperty(
      kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, outputElement, stereo.streamDescription.pointee,
      "setting the output format")

    // Channel maps count from 0. For each channel the input map lists the device channel that feeds it.
    // The output map lists which of ours feeds it, or -1 for none.
    try setChannelMap([Int32(inputChannel - 1)], inputElement, "choosing the input channel")
    var outputMap = [Int32](repeating: -1, count: try deviceOutputChannelCount())
    outputMap[outputChannel - 1] = 0
    outputMap[outputChannel] = 1
    try setChannelMap(outputMap, outputElement, "choosing the output channels")

    try setProperty(
      kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, Plugin.maximumFrames,
      "setting the maximum frames")
    try device.setBufferSize(Self.bufferSize)
  }

  func start(with plugin: Plugin) throws {
    guard let renderState = RenderStateCreateForPlugin(outputUnit, plugin.audioUnit) else {
      throw CoreAudioError(status: kAudio_MemFullError, action: "creating the render state")
    }
    self.renderState = renderState

    let callback = AURenderCallbackStruct(
      inputProc: RenderCallback, inputProcRefCon: UnsafeMutableRawPointer(renderState))
    try setProperty(
      kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, outputElement, callback, "registering the callback")
    try check(AudioUnitInitialize(outputUnit), "initialising AUHAL")
    try check(AudioOutputUnitStart(outputUnit), "starting AUHAL")
  }

  /// The render callback's counters, or nil before audio starts.
  func counts() -> RenderCounts? {
    renderState.map { RenderStateCounts($0) }
  }

  /// Stops audio and frees the render state. Does nothing if audio isn't running.
  func stop() {
    guard let renderState else { return }
    // Stopping waits for the render callback to finish, so the state is no longer in use.
    AudioOutputUnitStop(outputUnit)
    AudioUnitUninitialize(outputUnit)
    RenderStateDestroy(renderState)
    self.renderState = nil
  }

  isolated deinit {
    stop()
    AudioComponentInstanceDispose(outputUnit)
  }

  /// AUHAL's view of the device's output side, which says how many channels it has.
  private func deviceOutputChannelCount() throws -> Int {
    var format = AudioStreamBasicDescription()
    var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
    try check(
      AudioUnitGetProperty(
        outputUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, outputElement, &format, &size),
      "reading the device's output format")
    return Int(format.mChannelsPerFrame)
  }

  private func setProperty<Value: BitwiseCopyable>(
    _ property: AudioUnitPropertyID, _ scope: AudioUnitScope, _ element: AudioUnitElement, _ value: Value,
    _ action: String
  ) throws {
    var value = value
    try check(
      AudioUnitSetProperty(outputUnit, property, scope, element, &value, UInt32(MemoryLayout<Value>.size)), action)
  }

  private func setChannelMap(_ map: [Int32], _ element: AudioUnitElement, _ action: String) throws {
    try check(
      AudioUnitSetProperty(
        outputUnit, kAudioOutputUnitProperty_ChannelMap, kAudioUnitScope_Output, element, map,
        UInt32(MemoryLayout<Int32>.size * map.count)), action)
  }
}
