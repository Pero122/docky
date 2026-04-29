#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

[[ stitchable ]] half4 onboardingGrain(float2 position, half4 color, float grainScale, float grainOpacity) {
    float2 cell = floor(position / max(grainScale, 1.0));
    float noise = fract(sin(dot(cell, float2(12.9898, 78.233))) * 43758.5453);
    float centeredNoise = (noise - 0.5) * 2.0;
    half3 grain = half3(0.5 + centeredNoise * grainOpacity);
    return half4(grain, 1.0);
}
