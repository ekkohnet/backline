#import "RenderStateForPlugin.h"

RenderState *RenderStateCreateForPlugin(AudioUnit outputUnit, AUAudioUnit *plugin) {
  return RenderStateCreate(outputUnit, plugin.renderBlock);
}
