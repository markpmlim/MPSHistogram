//
//  Shaders.metal
//  PassThrough Shader
//
//  Created by Mark PM Lim on 03/01/19.
//  Copyright © 2019 Incremental Innovation. All rights reserved.
//

#include <metal_stdlib>

using namespace metal;

struct VertexInOut
{
    float4  position [[position]];
    float2  texCoords;
};

vertex VertexInOut
passThroughVertex(uint vid                      [[ vertex_id ]],
                  device VertexInOut *vertices  [[buffer(0)]])
{
    VertexInOut outVertex;

    outVertex.position  = vertices[vid].position;
    outVertex.texCoords = vertices[vid].texCoords;

    return outVertex;
}

fragment float4
passThroughFragment(VertexInOut inFrag      [[stage_in]],
                    texture2d<float> inTexture [[ texture(0) ]])
{  
    constexpr sampler colorSampler(mag_filter::linear, min_filter::linear);
    float4 color = float4(inTexture.sample(colorSampler, inFrag.texCoords));
    return color;
}
