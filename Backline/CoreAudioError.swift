import CoreAudio

/// A failed Core Audio call. Core Audio reports failures as a status number rather than throwing.
struct CoreAudioError: Error, CustomStringConvertible {
  let status: OSStatus
  let action: String

  var description: String { "\(action) failed with status \(status)" }
}

/// Throws if a Core Audio call didn't succeed. `action` says what was being attempted.
func check(_ status: OSStatus, _ action: String) throws {
  guard status == noErr else {
    throw CoreAudioError(status: status, action: action)
  }
}
