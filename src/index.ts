import GFX from "./GFX";
const gfx = new GFX('glCanvas');
gfx.ready.then(() => {
    console.log("ShaderToy gfxironment is ready");
}).catch(error => {
    console.error("Failed to initialize ShaderToyEnvironment:", error);
});
