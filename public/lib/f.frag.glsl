#version 300 es

precision highp float;

uniform vec4 u_color;
uniform float time;
out vec4 fragColor;

void main(){
    fragColor = u_color;
}
