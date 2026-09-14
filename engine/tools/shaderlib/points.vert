#version 450

// A fork may declare a u_vs_customParams block: its members are filled by name from the
// component's shader uniforms (Properties window, setShaderUniform). Two names are
// written by the engine instead: "time" (seconds since startup) and "resolution"
// (xy = render target size, zw = 1 / size). Do not mix int and float members: GL
// uploads the block typed after its first member.
//
//   uniform u_vs_customParams {
//       float time;
//       vec4 tint;
//   } customParams;

uniform u_vs_pointsParams {
    mat4 mvpMatrix;
    float pointScale;
} pointsParams;

in vec3 a_position;

in float a_pointsize;

#ifdef HAS_TEXTURE
    in float a_pointrotation;
    out float v_pointrotation;
#endif

#ifdef HAS_VERTEX_COLOR_VEC3
    in vec3 a_color;
    out vec3 v_color;
#endif

#ifdef HAS_VERTEX_COLOR_VEC4
    in vec4 a_color;
    out vec4 v_color;
#endif

#ifdef HAS_TEXTURERECT
    in vec4 a_texturerect;
    out vec4 v_texturerect;
#endif


void main() {

    #ifdef HAS_TEXTURE
        v_pointrotation = a_pointrotation;
    #endif

    #if defined(HAS_VERTEX_COLOR_VEC3) || defined(HAS_VERTEX_COLOR_VEC4)
        v_color = a_color;
    #endif

    #ifdef HAS_TEXTURERECT
        v_texturerect = a_texturerect;
    #endif

    gl_Position = pointsParams.mvpMatrix * vec4(a_position, 1.0);

    // gl_Position.w is the eye-space depth for perspective and exactly 1.0 for
    // ortho/UI, so this single expression gives world-space sizing in both cases.
    gl_PointSize = max(a_pointsize * pointsParams.pointScale / gl_Position.w, 1.0);

    #ifdef IS_VULKAN
        // GL [-1,1] to Vulkan [0,1] depth range (spirv-cross fixup_clipspace equivalent)
        gl_Position.z = (gl_Position.z + gl_Position.w) * 0.5;
    #endif
}