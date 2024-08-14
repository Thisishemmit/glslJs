class GFX {
    private gl: WebGL2RenderingContext;
    private buffers: Map<string, { program: WebGLProgram, texture: WebGLTexture, fbo: WebGLFramebuffer }>;
    private textures: Map<string, WebGLTexture>;
    private finalProgram: WebGLProgram | null;
    private startTime: number;
    public ready: Promise<void>;
    public log: HTMLParagraphElement;
    private target: 'client' | 'server';
    private serverUrl: string | null;
    private stopTime: number | null;

    constructor(canvasId: string) {
        this.log = document.getElementById("log") as HTMLParagraphElement;
        const canvas = document.getElementById(canvasId) as HTMLCanvasElement;
        const gl = canvas.getContext('webgl2');
        if (!gl) {
            throw new Error("WebGL2 not supported");
        }
        this.gl = gl;

        this.buffers = new Map();
        this.textures = new Map();
        this.finalProgram = null;
        this.startTime = 0;
        this.target = 'client';
        this.serverUrl = null;
        this.stopTime = null;

        window.addEventListener("resize", () => this.resizeCanvas());
        this.resizeCanvas();

        this.ready = Promise.resolve();
    }

    public addBuffer(name: string, shaderPath: string): void {
        this.ready = this.ready.then(() => this.loadShaderFile(shaderPath)
            .then(fsShader => {
                const program = this.createProgram(this.getVertexShader(), fsShader);
                if (!program) {
                    throw new Error(`Failed to create program for buffer ${name}`);
                }
                const { texture, fbo } = this.createTextureAndFBO();
                this.buffers.set(name, { program, texture, fbo });
            }));
    }

    public addTexture(name: string, texturePath: string): void {
        this.ready = this.ready.then(() => {
            return new Promise<void>((resolve, reject) => {
                const texture = this.gl.createTexture();
                if (!texture) {
                    reject(new Error(`Failed to create texture for ${name}`));
                    return;
                }

                const image = new Image();
                image.onload = () => {
                    this.gl.bindTexture(this.gl.TEXTURE_2D, texture);
                    this.gl.texImage2D(this.gl.TEXTURE_2D, 0, this.gl.RGBA, this.gl.RGBA, this.gl.UNSIGNED_BYTE, image);
                    this.gl.generateMipmap(this.gl.TEXTURE_2D);
                    this.textures.set(name, texture);
                    resolve();
                };
                image.onerror = () => {
                    reject(new Error(`Failed to load texture from ${texturePath}`));
                };
                image.src = texturePath;
            });
        });
    }

    public setTarget(value: 'client' | 'server') {
        this.target = value;
    }

    public setServer(url: string): void {
        if (this.target !== 'server') {
            throw new Error("Server URL can only be set when target is 'server'");
        }
        this.serverUrl = url;
    }

    public stopAfter(seconds: number): void {
        this.stopTime = seconds;
    }

    public initialize(): void {
        this.ready = this.ready.then(() => {
            this.setupVertexBuffer();
            this.startTime = 0;
            requestAnimationFrame(() => this.render());
        });
    }

    private async loadShaderFile(url: string): Promise<string> {
        const response = await fetch(url);
        if (!response.ok) {
            throw new Error(`Failed to load shader file: ${url}`);
        }
        return response.text();
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
        if (this.stopTime !== null && this.startTime > this.stopTime) {
            console.log('Rendering stopped');
            return;
        }

        // ... (existing render logic)

        if (this.target === 'server') {
            this.sendFrameToServer();
        }

        this.startTime += 1 / 60;
        this.log.textContent = `Time: ${this.startTime}`;

        requestAnimationFrame(() => this.render());
    }

    private sendFrameToServer(): void {
        if (!this.serverUrl) {
            throw new Error("Server URL not set");
        }

        const frameData = (this.gl.canvas as HTMLCanvasElement).toDataURL('image/png');
        fetch(this.serverUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ frameData, frameNumber: Math.floor(this.startTime * 60) }),
        })
        .then(response => {
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            return response.text();
        })
        .then(result => console.log(result))
        .catch(error => console.error('Error:', error));
    }
}

export default GFX;
