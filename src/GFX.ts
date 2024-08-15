
class GFX {
    private gl: WebGL2RenderingContext;
    private buffers: Map<string, { program: WebGLProgram, texture: WebGLTexture, fbo: WebGLFramebuffer }>;
    private finalProgram: WebGLProgram | null;
    private startTime: number;
    public ready: Promise<void>;
    public log: HTMLParagraphElement;
    private common: string;
    private footer: string;
    private frame: number;



    constructor(canvasId: string) {
        this.log = document.getElementById("log") as HTMLParagraphElement;
        const canvas = document.getElementById(canvasId) as HTMLCanvasElement;
        const gl = canvas.getContext('webgl2');
        if (!gl) {
            throw new Error("WebGL2 not supported");
        }
        this.gl = gl;

        this.common = '';
        this.footer = '';

        this.buffers = new Map();
        this.finalProgram = null;
        this.startTime = 0;
        this.frame = 0;

        window.addEventListener("resize", () => this.resizeCanvas());
        this.resizeCanvas();

        this.ready = this.initialize();
    }

    public addFooter(code: string): void{
        this.footer += '\n' + code;
    }
    public addCommon(code: string): void{
        this.common += code + '\n';
    }

    private insertCommon(shader: string): string {
        const versionReg = /^(#version\s+\d+\s+\w+\s*\n)/;
        const match      = shader.match(versionReg);

        if(match) {
            const versionDirective = match[1];
            const rest = shader.slice(match[1].length);
            return `${versionDirective}\n${this.common}\n${rest}${this.footer}`;
        } else {
            return `${this.common}\n${shader}${this.footer}`;
        }
    }
    private async initialize(): Promise<void> {
        try {
            await this.initializeBuffersAndProgram();
            this.setupVertexBuffer();
            requestAnimationFrame(() => this.render());
        } catch (error) {
            console.error("Initialization failed:", error);
            throw error;
        }
    }

    private async initializeBuffersAndProgram(): Promise<void> {
        const vsShader = this.getVertexShader();

        // Initialize default buffers

        const finalFsShader = await this.loadShaderFile('finalBuffer.glsl');
        const finalProgram = this.createProgram(vsShader, finalFsShader);

        if (!finalProgram) {
            throw new Error("Failed to create final program");
        }
        this.finalProgram = finalProgram;
    }

    async addBuffer(name: string, shaderPath: string): Promise<void> {
        const fsShader = await this.loadShaderFile(shaderPath);
        const program = this.createProgram(this.getVertexShader(), fsShader);
        if (!program) {
            throw new Error(`Failed to create program for buffer ${name}`);
        }
        const { texture, fbo } = this.createTextureAndFBO();
        this.buffers.set(name, { program, texture, fbo });
    }

    private async loadShaderFile(url: string): Promise<string> {
        const response = await fetch(url);
        if (!response.ok) {
            throw new Error(`Failed to load shader file: ${url}`);
        }
        const source = await response.text();
        return this.insertCommon(source);
    }

    private getVertexShader(): string {
        return `#version 300 es
            in vec4 aVertexPosition;
            void main() {
                gl_Position = aVertexPosition;
            }`;
    }

    private createProgram(vsSource: string, fsSource: string): WebGLProgram | null {
        const vertexShader = this.loadShader(this.gl.VERTEX_SHADER, vsSource);
        const fragmentShader = this.loadShader(this.gl.FRAGMENT_SHADER, fsSource);

        if (!vertexShader || !fragmentShader) {
            return null;
        }

        const program = this.gl.createProgram();
        if (!program) {
            return null;
        }

        this.gl.attachShader(program, vertexShader);
        this.gl.attachShader(program, fragmentShader);
        this.gl.linkProgram(program);

        if (!this.gl.getProgramParameter(program, this.gl.LINK_STATUS)) {
            console.error('Error linking program:', this.gl.getProgramInfoLog(program));
            this.gl.deleteProgram(program);
            return null;
        }
        return program;
    }

    private loadShader(type: number, source: string): WebGLShader | null {
        const shader = this.gl.createShader(type);
        if (!shader) {
            console.error('Failed to create shader');
            return null;
        }

        this.gl.shaderSource(shader, source);
        this.gl.compileShader(shader);

        if (!this.gl.getShaderParameter(shader, this.gl.COMPILE_STATUS)) {
            console.error('Error compiling shader:', this.gl.getShaderInfoLog(shader));
            this.gl.deleteShader(shader);
            return null;
        }
        return shader;
    }

    private createTextureAndFBO(): { texture: WebGLTexture, fbo: WebGLFramebuffer } {
        const texture = this.gl.createTexture();
        const fbo = this.gl.createFramebuffer();

        if (!texture || !fbo) {
            throw new Error("Failed to create texture or framebuffer");
        }

        this.gl.bindTexture(this.gl.TEXTURE_2D, texture);
        this.gl.texImage2D(this.gl.TEXTURE_2D, 0, this.gl.RGBA, this.gl.canvas.width, this.gl.canvas.height, 0, this.gl.RGBA, this.gl.UNSIGNED_BYTE, null);
        this.gl.texParameteri(this.gl.TEXTURE_2D, this.gl.TEXTURE_MIN_FILTER, this.gl.LINEAR);
        this.gl.texParameteri(this.gl.TEXTURE_2D, this.gl.TEXTURE_WRAP_S, this.gl.CLAMP_TO_EDGE);
        this.gl.texParameteri(this.gl.TEXTURE_2D, this.gl.TEXTURE_WRAP_T, this.gl.CLAMP_TO_EDGE);

        this.gl.bindFramebuffer(this.gl.FRAMEBUFFER, fbo);
        this.gl.framebufferTexture2D(this.gl.FRAMEBUFFER, this.gl.COLOR_ATTACHMENT0, this.gl.TEXTURE_2D, texture, 0);

        return { texture, fbo };
    }

    private setupVertexBuffer(): void {
        const positionBuffer = this.gl.createBuffer();
        if (!positionBuffer) {
            throw new Error("Failed to create position buffer");
        }

        this.gl.bindBuffer(this.gl.ARRAY_BUFFER, positionBuffer);
        const positions = [
            -1.0, 1.0,
            1.0, 1.0,
            -1.0, -1.0,
            1.0, -1.0,
        ];
        this.gl.bufferData(this.gl.ARRAY_BUFFER, new Float32Array(positions), this.gl.STATIC_DRAW);

        [this.finalProgram, ...this.buffers.values()].forEach((item) => {
            if (item && 'program' in item) {
                const program = item.program;
                if (program) {
                    const positionAttributeLocation = this.gl.getAttribLocation(program, "aVertexPosition");
                    this.gl.enableVertexAttribArray(positionAttributeLocation);
                    this.gl.vertexAttribPointer(positionAttributeLocation, 2, this.gl.FLOAT, false, 0, 0);
                }
            } else if (item) {
                // This branch handles this.finalProgram when it's not null
                const program = item;
                const positionAttributeLocation = this.gl.getAttribLocation(program, "aVertexPosition");
                this.gl.enableVertexAttribArray(positionAttributeLocation);
                this.gl.vertexAttribPointer(positionAttributeLocation, 2, this.gl.FLOAT, false, 0, 0);
            }
        });
    }

    private resizeCanvas(): void {
        const canvas = this.gl.canvas as HTMLCanvasElement;
        const displayWidth = canvas.clientWidth;
        const displayHeight = canvas.clientHeight;
        if (canvas.width !== displayWidth || canvas.height !== displayHeight) {
            canvas.width = displayWidth;
            canvas.height = displayHeight;
            this.gl.viewport(0, 0, canvas.width, canvas.height);

            // Resize textures
            this.buffers.forEach(({ texture }) => {
                this.gl.bindTexture(this.gl.TEXTURE_2D, texture);
                this.gl.texImage2D(this.gl.TEXTURE_2D, 0, this.gl.RGBA, canvas.width, canvas.height, 0, this.gl.RGBA, this.gl.UNSIGNED_BYTE, null);
            });
        }
    }

    private render(): void {
        if (!this.finalProgram) {
            console.error("Final program not initialized");
            return;
        }


        // Render to buffers
        this.buffers.forEach((buffer, name) => {
            this.gl.bindFramebuffer(this.gl.FRAMEBUFFER, buffer.fbo);
            this.gl.useProgram(buffer.program);
            this.setUniforms(buffer.program, this.startTime, this.frame);

            // Bind textures from previous buffers
            let textureUnit = 0;
            this.buffers.forEach((prevBuffer, prevName) => {
                if (prevName !== name) {
                    this.gl.activeTexture(this.gl.TEXTURE0 + textureUnit);
                    this.gl.bindTexture(this.gl.TEXTURE_2D, prevBuffer.texture);
                    this.gl.uniform1i(this.gl.getUniformLocation(buffer.program, `buffer${prevName}`), textureUnit);
                    textureUnit++;
                }
            });

            this.gl.drawArrays(this.gl.TRIANGLE_STRIP, 0, 4);
        });

        // Render final pass to screen
        this.gl.bindFramebuffer(this.gl.FRAMEBUFFER, null);
        this.gl.useProgram(this.finalProgram);
        this.setUniforms(this.finalProgram, this.startTime, this.frame);

        let textureUnit = 0;
        this.buffers.forEach((buffer, name) => {
            this.gl.activeTexture(this.gl.TEXTURE0 + textureUnit);
            this.gl.bindTexture(this.gl.TEXTURE_2D, buffer.texture);
            if (!this.finalProgram) {
                throw new Error("Final program not initialized");
            }
            this.gl.uniform1i(this.gl.getUniformLocation(this.finalProgram, `buffer${name}`), textureUnit);
            textureUnit++;
        });

        this.gl.drawArrays(this.gl.TRIANGLE_STRIP, 0, 4);
        this.startTime += 1 / 60;
        this.frame++;
        this.log.textContent = `Time: ${this.startTime} Frame: ${this.frame}`;
        // if (this.startTime > 5) {
        //     return;
        // }

        requestAnimationFrame(() => this.render());
    }

    private setUniforms(program: WebGLProgram, time: number, frame: number): void {
        const timeLocation = this.gl.getUniformLocation(program, "time");
        const resolutionLocation = this.gl.getUniformLocation(program, "resolution");
        const frameLocation = this.gl.getUniformLocation(program, "frame");
        if (timeLocation) this.gl.uniform1f(timeLocation, time);
        if (resolutionLocation) this.gl.uniform2f(resolutionLocation, this.gl.canvas.width, this.gl.canvas.height);
        if (frameLocation) this.gl.uniform1i(frameLocation, frame);
    }
}

export default GFX;
