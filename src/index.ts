/* import GFX from "./GFXold.ts";
const gfx = new GFX('glCanvas');
gfx.ready.then(() => {
    console.log("ShaderToy gfxironment is ready");
}).catch(error => {
    console.error("Failed to initialize ShaderToyEnvironment:", error);
}); */


import GFX from "./GFXNew.ts";

const gfx = new GFX('glCanvas');

gfx.addBuffer("bufferA", "path/To/bufferShader");
gfx.addBuffer("BufferB", "path/To/bufferShader");
gfx.addBuffer("final", "path/To/bufferShader");
gfx.addTexture("font1", "pathToTex");
gfx.addTexture("noise1", "noise.png");
gfx.setTarget("server");
gfx.setServer("http://localhost:3000/saveFrame");
gfx.stopAfter(3);

gfx.ready.then(() => {
    gfx.initialize();
    console.log("ShaderToy environment is ready");
}).catch(error => {
    console.error("Failed to initialize ShaderToyEnvironment:", error);
});
