#import <AudioToolbox/AudioToolbox.h>

#import "RenderCallback.h"

NS_ASSUME_NONNULL_BEGIN

/// Creates the render state for a plugin. `outputUnit` is AUHAL, the audio unit connected to the audio device.
///
/// The plugin's render block is read here in Objective-C because Swift would pass on a wrapper
/// instead of the block itself, and the wrapper would run Swift on the audio thread.
RenderState *_Nullable RenderStateCreateForPlugin(AudioUnit outputUnit, AUAudioUnit *plugin);

NS_ASSUME_NONNULL_END
