#version 450

// A fork may declare a u_fs_customParams block: its members are filled by name from the
// component's shader uniforms (Properties window, setShaderUniform). Two names are
// written by the engine instead: "time" (seconds since startup) and "resolution"
// (xy = render target size, zw = 1 / size). Do not mix int and float members: GL
// uploads the block typed after its first member.
//
//   uniform u_fs_customParams {
//       float time;
//       vec4 tint;
//   } customParams;

out vec4 frag_color;

in vec3 uv;

uniform textureCube u_skyTexture;
uniform sampler u_sky_smp;

uniform u_fs_skyParams {
    vec4 color; //sRGB
} skyParams;

void main(){
    frag_color = skyParams.color * texture(samplerCube(u_skyTexture, u_sky_smp), uv);
}