
const vsShader: string = `
            attribute vec4 aVertexPosition;
            void main() {
                gl_Position = aVertexPosition;
            }
        `;


async function loadShaderFile(url: string): Promise<string> {
    const response = await fetch(url);

    return response.text();
}


let gl: WebGL2RenderingContext;
let program: WebGLProgram;
let timeLocation: WebGLUniformLocation;
let resolutionLocation: WebGLUniformLocation;
let startTime: number;
let bufferA: WebGLProgram;
let bufferB: WebGLProgram;
let finalBuffer: WebGLProgram;
let bufferATexture: WebGLTexture;
let bufferBTexture: WebGLTexture;
let fboA: WebGLFramebuffer;
let fboB: WebGLFramebuffer;

async function initGL() {
    const canvas: HTMLCanvasElement = document.getElementById("glCanvas") as HTMLCanvasElement;
    gl = canvas.getContext("webgl2")!;
    if (gl === null) {
        console.log("Unable to initialize WebGL2. Your browser may not support it.");
        return;
    }

    console.log("WebGL2 initialized");
    bufferA = createProgram(gl, vsShader, await loadShaderFile("bufferA.glsl"))!;
    bufferB = createProgram(gl, vsShader, await loadShaderFile("bufferB.glsl"))!;
    finalBuffer = createProgram(gl, vsShader, await loadShaderFile("finalBuffer.glsl"))!;
    console.log(program);

    if (program === null) {
        console.log("Unable to create program");
        return;
    }
    console.log("Program created");
    gl.useProgram(program);

    const positionBuffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);

    const positions = [
        -1.0, 1.0,
        1.0, 1.0,
        -1.0, -1.0,
        1.0, -1.0,
    ];

    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(positions), gl.STATIC_DRAW);

    const positionAttributeLocation = gl.getAttribLocation(program, "aVertexPosition");
    gl.enableVertexAttribArray(positionAttributeLocation);
    gl.vertexAttribPointer(positionAttributeLocation, 2, gl.FLOAT, false, 0, 0);

    timeLocation = gl.getUniformLocation(program, "time")!;
    resolutionLocation = gl.getUniformLocation(program, "resolution")!;

    startTime = Date.now();


    resizeCanvas();
    window.addEventListener("resize", resizeCanvas);
    requestAnimationFrame(render);
}

function createProgram(gl: WebGL2RenderingContext, vsSource: string, fsSource: string): WebGLProgram | null {
    const vertexShader = loadShader(gl, gl.VERTEX_SHADER, vsSource)!;
    const fragmentShader = loadShader(gl, gl.FRAGMENT_SHADER, fsSource)!;

    const program = gl.createProgram();
    if (!program) {
        return null;
    }

    gl.attachShader(program, vertexShader);
    gl.attachShader(program, fragmentShader);
    gl.linkProgram(program);

    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
        console.error('Error linking program:', gl.getProgramInfoLog(program));
        gl.deleteProgram(program);
        return null;
    }

    return program;
}

function loadShader(gl: WebGL2RenderingContext, type: number, source: string): WebGLShader | null {
    const shader = gl.createShader(type);
    if (!shader) {
        return null;
    }

    gl.shaderSource(shader, source);
    gl.compileShader(shader);

    if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
        console.error('Error compiling shader:', gl.getShaderInfoLog(shader));
        gl.deleteShader(shader);
        return null;
    }

    return shader;
}

function resizeCanvas() {
    const canvas: HTMLCanvasElement = gl.canvas as HTMLCanvasElement;
    const displayWidth = canvas.clientWidth;
    const displayHeight = canvas.clientHeight;
    if (canvas.width !== displayWidth || canvas.height !== displayHeight) {
        canvas.width = displayWidth;
        canvas.height = displayHeight;
        gl.viewport(0, 0, canvas.width, canvas.height);
    }
}

function render() {
    const currentTime = (Date.now() - startTime) / 1000;
    gl.uniform1f(timeLocation, currentTime);
    gl.uniform2f(resolutionLocation, gl.canvas.width, gl.canvas.height);
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
    requestAnimationFrame(render);
}

window.onload = initGL;
