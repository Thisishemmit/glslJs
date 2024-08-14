#version 300 es
in vec2 a_position;

uniform vec2 u_resolution;

void main(){
    vec2 uv = (a_position / u_resolution)*2. - 1.;
    gl_Position = vec4(uv * vec2(1,-1 ), 0 , 1);
}
