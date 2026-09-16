// Dedicated 2D light path (USE_LIGHT2D). Lights live in the world XY plane with
// an optional virtual Z height for normal-map response; attenuation is a radial
// falloff pow(1 - d/range, falloff). Shadows (USE_SHADOWS_2D) sample per-light
// 1D polar depth rows (one atlas row per light) rendered from Occluder2D segments.

// Normal for the 2D light path. The lit path already has getNormalInfo(), but it
// is compiled out under MATERIAL_UNLIT, so this is a minimal standalone version.
vec3 getNormal2D(){
#ifdef HAS_NORMALS
    #ifdef HAS_TANGENTS
        #if defined(HAS_NORMAL_MAP) && (defined(HAS_UV_SET1) || defined(HAS_UV_SET2))
            vec3 ntex = texture(sampler2D(u_normalTexture, u_normal_smp), getNormalUV()).rgb * 2.0 - vec3(1.0);
            return normalize(v_tbn * ntex);
        #else
            return normalize(v_tbn[2]);
        #endif
    #else
        return normalize(v_normal);
    #endif
#else
    return vec3(0.0, 0.0, 1.0);
#endif
}

#ifdef USE_SHADOWS_2D
// Bound clamped on every backend, constant on HLSL: see shadows.glsl
#ifdef IS_HLSL
const int MAX_SHADOW2D_RADIUS = 2;  // 5 taps; MEDIUM and HIGH render as LOW here
#else
const int MAX_SHADOW2D_RADIUS = 6;  // 13 taps, Shadow2DQuality::HIGH
#endif

// 1D polar shadow map lookup: the row stores, per angle around the light, the
// normalized distance (dist/range) of the nearest occluder. PCF along the row
// with 2*radius+1 taps (radius from the scene's Shadow2DQuality, uniform-driven
// so quality changes need no shader rebuild); the taps span the penumbra
// half-width set by the light's softness, so more taps smooth the same width.
// u wraps with fract() so the seam at theta = +-pi is continuous.
float shadow2DCalculation(float row, vec2 lightToFrag, float dist01, float softness, float bias){
    float theta = atan(lightToFrag.y, lightToFrag.x); // [-pi, pi]
    float u = theta / (2.0 * M_PI) + 0.5;
    float v = (row + 0.5) * lighting2d.atlasInfo.y;
    #ifndef IS_GLSL
        // rows are placed with sokol's bottom-left viewport convention, same as
        // the 3D shadow atlas (see getShadowAtlasUV)
        v = 1.0 - v;
    #endif

    int radius = clamp(int(lighting2d.atlasInfo.w), 0, MAX_SHADOW2D_RADIUS);
    if (radius <= 0){
        float occ = decodeDepth(texture(sampler2D(u_shadow2DAtlas, u_shadow2DAtlas_smp), vec2(u, v)));
        return (dist01 - bias <= occ) ? 1.0 : 0.0;
    }

    float halfWidth = lighting2d.atlasInfo.x * max(softness, 0.5); // in texels
    float tapStep = halfWidth / float(radius);
    float lit = 0.0;
    // The clamp leaves radius at MAX_SHADOW2D_RADIUS
    #ifdef IS_HLSL
    for (int t = -MAX_SHADOW2D_RADIUS; t <= MAX_SHADOW2D_RADIUS; ++t){
    #else
    for (int t = -radius; t <= radius; ++t){
    #endif
        float su = fract(u + float(t) * tapStep);
        float occ = decodeDepth(texture(sampler2D(u_shadow2DAtlas, u_shadow2DAtlas_smp), vec2(su, v)));
        lit += (dist01 - bias <= occ) ? 1.0 : 0.0;
    }
    return lit / float(2 * radius + 1); // 1.0 = fully lit
}
#endif

// Accumulated 2D light at fragPos: ambient2D (optional) + sum of light
// contributions. Each light's shadow attenuates only that light's term.
vec3 getLight2DIntensity(vec3 fragPos, vec3 n, bool includeAmbient){
    vec3 acc = includeAmbient ? lighting2d.ambient.rgb : vec3(0.0);
    int count = int(lighting2d.ambient.w);
    for (int i = 0; i < MAX_LIGHTS_2D; ++i){
        if (i >= count) break;
        vec4 pr = lighting2d.position_range[i];
        vec2 toLight = pr.xy - fragPos.xy;
        float d = length(toLight);
        if (d >= pr.w) continue;
        float atten = pow(clamp(1.0 - d / pr.w, 0.0, 1.0), lighting2d.falloff_shadow[i].x);
        float ndotl = 1.0;
        if (pr.z > 0.0){
            // virtual light height above the sprite plane: gives normal maps a
            // direction to respond to (height 0 = pure radial, ignores normals)
            vec3 l = normalize(vec3(toLight, pr.z));
            ndotl = clamp(dot(n, l), 0.0, 1.0);
        }
        float lit = 1.0;
        #ifdef USE_SHADOWS_2D
            float rowIdx = lighting2d.falloff_shadow[i].y;
            if (rowIdx >= 0.0){
                lit = shadow2DCalculation(rowIdx, -toLight, d / pr.w,
                        lighting2d.falloff_shadow[i].z, lighting2d.falloff_shadow[i].w);
            }
        #endif
        acc += lighting2d.color_intensity[i].rgb * lighting2d.color_intensity[i].w * atten * ndotl * lit;
    }
    return acc;
}
