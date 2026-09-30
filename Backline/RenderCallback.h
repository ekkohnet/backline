// The render callback runs on the audio thread, where any delay is heard as a click.
// It's in C because Swift can add work of its own, such as asking for memory, that causes delays.

#ifndef RenderCallback_h
#define RenderCallback_h

#include <AudioToolbox/AudioToolbox.h>

#pragma clang assume_nonnull begin

// AUAudioUnit.h is Objective-C only, so its render and pull-input block types are restated here for C.
// They match the originals: AUAudioFrameCount is uint32_t and NSInteger is long.
typedef OSStatus (^PullInputBlock)(
  AudioUnitRenderActionFlags *actionFlags,
  const AudioTimeStamp *timestamp,
  uint32_t frameCount,
  long inputBusNumber,
  AudioBufferList *inputData);

typedef OSStatus (^RenderBlock)(
  AudioUnitRenderActionFlags *actionFlags,
  const AudioTimeStamp *timestamp,
  uint32_t frameCount,
  long outputBusNumber,
  AudioBufferList *outputData,
  PullInputBlock _Nullable pullInputBlock);

/// What the render callback keeps between calls.
typedef struct RenderState RenderState;

/// A copy of the render callback's counters, for Swift to read.
typedef struct {
  uint64_t renderCount;
  uint64_t pullCount;
  OSStatus lastRenderStatus;
  OSStatus lastPullStatus;
} RenderCounts;

/// Create before AUHAL starts. Swift creates it through RenderStateCreateForPlugin instead,
/// so the render block never passes through Swift.
RenderState *_Nullable RenderStateCreate(AudioUnit outputUnit, RenderBlock pluginRenderBlock)
  __attribute__((availability(swift, unavailable)));

/// Call only after AUHAL has stopped. The render callback uses the state until then.
void RenderStateDestroy(RenderState *state);

/// Safe to call while audio is running.
RenderCounts RenderStateCounts(RenderState *state);

/// AUHAL calls this for each batch of samples, and it gets the plugin to fill outputData.
/// Register it with the render state as its refCon.
OSStatus RenderCallback(
  void *refCon,
  AudioUnitRenderActionFlags *actionFlags,
  const AudioTimeStamp *timestamp,
  UInt32 busNumber,
  UInt32 frameCount,
  AudioBufferList *_Nullable outputData);

#pragma clang assume_nonnull end

#endif /* RenderCallback_h */
