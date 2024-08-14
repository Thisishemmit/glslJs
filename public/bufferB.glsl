#version 300 es
precision highp float;
uniform vec2 resolution;
uniform float time;
uniform sampler2D bufferA;
out vec4 fragColor;

void main() {
    vec2 uv = gl_FragCoord.xy / resolution.xy;
    vec4 colorA = texture(bufferA, uv);
    fragColor = vec4(1.0 - colorA.rgb, 1.0);
}
