import CoreAudio

/// A connected audio device, identified by Core Audio's object ID.
struct AudioDevice {
  let id: AudioObjectID

  /// Every audio device Core Audio knows about.
  static func all() throws -> [AudioDevice] {
    var address = propertyAddress(kAudioHardwarePropertyDevices)
    let system = AudioObjectID(kAudioObjectSystemObject)

    var size: UInt32 = 0
    try check(AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size), "counting audio devices")
    var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
    try check(AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids), "listing audio devices")

    return ids.map { AudioDevice(id: $0) }
  }

  func name() throws -> String {
    let name: Unmanaged<CFString> = try read(kAudioObjectPropertyName, "reading the device name")
    // Core Audio hands over a string we're responsible for releasing.
    return name.takeRetainedValue() as String
  }

  func sampleRate() throws -> Double {
    try read(kAudioDevicePropertyNominalSampleRate, "reading the sample rate")
  }

  func bufferSizeRange() throws -> ClosedRange<UInt32> {
    let range: AudioValueRange = try read(kAudioDevicePropertyBufferFrameSizeRange, "reading the buffer size range")
    return UInt32(range.mMinimum)...UInt32(range.mMaximum)
  }

  func bufferSize() throws -> UInt32 {
    try read(kAudioDevicePropertyBufferFrameSize, "reading the buffer size")
  }

  /// The device may not give exactly the size asked for, so read it back afterwards.
  func setBufferSize(_ frames: UInt32) throws {
    try write(kAudioDevicePropertyBufferFrameSize, frames, "setting the buffer size")
  }

  /// Reads a single fixed-size value from the device.
  private func read<Value>(_ selector: AudioObjectPropertySelector, _ action: String) throws -> Value {
    var address = propertyAddress(selector)
    var size = UInt32(MemoryLayout<Value>.size)
    let value = UnsafeMutablePointer<Value>.allocate(capacity: 1)
    defer { value.deallocate() }
    try check(AudioObjectGetPropertyData(id, &address, 0, nil, &size, value), action)
    return value.move()
  }

  private func write<Value: BitwiseCopyable>(
    _ selector: AudioObjectPropertySelector, _ value: Value, _ action: String
  ) throws {
    var address = propertyAddress(selector)
    var value = value
    try check(AudioObjectSetPropertyData(id, &address, 0, nil, UInt32(MemoryLayout<Value>.size), &value), action)
  }
}

private func propertyAddress(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
  AudioObjectPropertyAddress(
    mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain
  )
}
