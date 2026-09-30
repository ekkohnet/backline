#include "RenderCallback.h"

#include <Block.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>

struct RenderState {
  AudioUnit outputUnit;
  RenderBlock pluginRenderBlock;
  PullInputBlock pullInputBlock;

  // Written by the audio thread while Swift reads them from the main thread.
  _Atomic uint64_t renderCount;
  _Atomic uint64_t pullCount;
  _Atomic OSStatus lastRenderStatus;
  _Atomic OSStatus lastPullStatus;
};

// Fills the buffers with zeros, which play as silence.
// Skips any with no memory attached.
static void silence(AudioBufferList *buffers) {
  for (UInt32 i = 0; i < buffers->mNumberBuffers; i++) {
    AudioBuffer *buffer = &buffers->mBuffers[i];
    if (buffer->mData) {
      memset(buffer->mData, 0, buffer->mDataByteSize);
    }
  }
}

RenderState *RenderStateCreate(AudioUnit outputUnit, RenderBlock pluginRenderBlock) {
  RenderState *state = calloc(1, sizeof *state);
  if (!state) return NULL;

  state->outputUnit = outputUnit;
  state->pluginRenderBlock = Block_copy(pluginRenderBlock);

  // Made here, once, rather than in the render callback. A block made in the callback
  // would need a memory allocation on the audio thread if the plugin held on to it.
  PullInputBlock pullInputBlock = ^OSStatus(
      AudioUnitRenderActionFlags *actionFlags,
      const AudioTimeStamp *timestamp,
      uint32_t frameCount,
      long inputBusNumber,
      AudioBufferList *inputData) {
    // Only bus 0 is enabled, but silence anything else rather than leave it undefined.
    if (inputBusNumber != 0) {
      silence(inputData);
      return noErr;
    }

    // Device input comes from AUHAL's element 1.
    OSStatus status = AudioUnitRender(state->outputUnit, actionFlags, timestamp, 1, frameCount, inputData);

    atomic_fetch_add_explicit(&state->pullCount, 1, memory_order_relaxed);
    atomic_store_explicit(&state->lastPullStatus, status, memory_order_relaxed);
    return status;
  };
  state->pullInputBlock = Block_copy(pullInputBlock);

  return state;
}

void RenderStateDestroy(RenderState *state) {
  Block_release(state->pullInputBlock);
  Block_release(state->pluginRenderBlock);
  free(state);
}

RenderCounts RenderStateCounts(RenderState *state) {
  return (RenderCounts){
    .renderCount = atomic_load_explicit(&state->renderCount, memory_order_relaxed),
    .pullCount = atomic_load_explicit(&state->pullCount, memory_order_relaxed),
    .lastRenderStatus = atomic_load_explicit(&state->lastRenderStatus, memory_order_relaxed),
    .lastPullStatus = atomic_load_explicit(&state->lastPullStatus, memory_order_relaxed),
  };
}

OSStatus RenderCallback(
    void *refCon,
    AudioUnitRenderActionFlags *actionFlags,
    const AudioTimeStamp *timestamp,
    UInt32 busNumber,
    UInt32 frameCount,
    AudioBufferList *outputData) {
  RenderState *state = refCon;
  if (!outputData) return noErr;

  OSStatus status = state->pluginRenderBlock(actionFlags, timestamp, frameCount, 0, outputData, state->pullInputBlock);

  // A failed render leaves the buffers undefined. Play silence instead.
  if (status != noErr) silence(outputData);

  atomic_fetch_add_explicit(&state->renderCount, 1, memory_order_relaxed);
  atomic_store_explicit(&state->lastRenderStatus, status, memory_order_relaxed);

  // Buffers are safe to play either way. The real result is in lastRenderStatus.
  return noErr;
}
