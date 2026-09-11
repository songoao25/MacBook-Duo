import SwiftUI
import MetalKit
import CoreVideo

// Independent implementation of eye -> hinged display -> fixed content plane.
// Reference model: https://github.com/Atomicx7/Duo-animation
// Adapted to a MacBook's horizontal bottom hinge. Shaders compile at runtime.
struct GlassSurface: NSViewRepresentable {
    let image: NSImage
    let tilt: Double
    let frost: Double
    let distance: Double

    func makeNSView(context: Context) -> GlassMetalView { GlassMetalView() }
    func updateNSView(_ view: GlassMetalView, context: Context) {
        view.configure(image: image, tilt: tilt, frost: frost, distance: distance)
    }
}

final class GlassMetalView: MTKView, MTKViewDelegate {
    private var queue: MTLCommandQueue?
    private var pipeline: MTLRenderPipelineState?
    private var texture: MTLTexture?
    private var sourceImage: NSImage?
    private var target: Float = 0
    private var displayed: Float = 0
    private var frost: Float = 0.09
    private var eyeDistance: Float = 2.4
    private var lastTime = CACurrentMediaTime()
    private var videoCache: CVMetalTextureCache?
    var readyForDisplay: Bool { texture != nil && pipeline != nil }
    var settled: Bool { abs(displayed - target) < 0.03 }

    func setLiveAngle(_ angle: Double) {
        target = Float(angle)
        isPaused = false
    }

    func receive(_ buffer: CVPixelBuffer) {
        guard let device, let queue, let cache = videoCache else { return }
        let width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer)
        var wrapped: CVMetalTexture?
        guard CVMetalTextureCacheCreateTextureFromImage(nil, cache, buffer, nil, .bgra8Unorm,
              width, height, 0, &wrapped) == kCVReturnSuccess,
              let wrapped, let source = CVMetalTextureGetTexture(wrapped) else { return }
        if texture?.width != width || texture?.height != height {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
                width: width, height: height, mipmapped: true)
            descriptor.usage = [.shaderRead]
            descriptor.storageMode = .private
            texture = device.makeTexture(descriptor: descriptor)
        }
        guard let texture, let command = queue.makeCommandBuffer(),
              let blit = command.makeBlitCommandEncoder() else { return }
        blit.copy(from: source, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(),
                  sourceSize: MTLSize(width: width, height: height, depth: 1),
                  to: texture, destinationSlice: 0, destinationLevel: 0, destinationOrigin: MTLOrigin())
        blit.generateMipmaps(for: texture)
        blit.endEncoding()
        command.addCompletedHandler { _ in _ = wrapped; _ = buffer }
        command.commit()
        isPaused = false
    }

    init() {
        super.init(frame: .zero, device: MTLCreateSystemDefaultDevice())
        colorPixelFormat = .bgra8Unorm
        framebufferOnly = true
        preferredFramesPerSecond = 60
        isPaused = true
        enableSetNeedsDisplay = false
        clearColor = MTLClearColorMake(0.015, 0.018, 0.025, 1)
        autoresizingMask = [.width, .height]
        guard let device else { return }
        queue = device.makeCommandQueue()
        CVMetalTextureCacheCreate(nil, nil, device, nil, &videoCache)
        do {
            let library = try device.makeLibrary(source: Self.shader, options: nil)
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "vertexMain")
            descriptor.fragmentFunction = library.makeFunction(name: "glassMain")
            descriptor.colorAttachments[0].pixelFormat = colorPixelFormat
            pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            NSLog("Hinge Glass renderer: %@", String(describing: error))
        }
        delegate = self
    }
    required init(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func configure(image: NSImage, tilt: Double, frost: Double, distance: Double) {
        if sourceImage !== image, let device,
           let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            do {
                texture = try MTKTextureLoader(device: device).newTexture(cgImage: cgImage,
                    options: [.SRGB: false, .generateMipmaps: true])
                sourceImage = image
            } catch { NSLog("Image texture failed: %@", String(describing: error)) }
        }
        target = Float(tilt)
        self.frost = Float(frost)
        eyeDistance = Float(distance)
        isPaused = false
    }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { isPaused = false }
    func draw(in view: MTKView) {
        guard let pipeline, let texture, let queue,
              let drawable = currentDrawable, let pass = currentRenderPassDescriptor,
              let command = queue.makeCommandBuffer(), let encoder = command.makeRenderCommandEncoder(descriptor: pass)
        else { return }
        let now = CACurrentMediaTime()
        let dt = min(max(now - lastTime, 1.0 / 120), 0.05)
        lastTime = now
        displayed += (target - displayed) * Float(1 - exp(-dt / 0.045))
        var parameters = [Float(drawableSize.width), Float(drawableSize.height),
                          displayed, frost, eyeDistance, Float(texture.width) / Float(texture.height), 0, 0]
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentBytes(&parameters, length: parameters.count * MemoryLayout<Float>.size, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        command.present(drawable)
        command.commit()
        if abs(target - displayed) < 0.005 { isPaused = true }
    }

    static let shader = """
    #include <metal_stdlib>
    using namespace metal;
    struct VertexOut { float4 position [[position]]; float2 uv; };
    struct Params { float2 size; float angle; float frost; float eye; float imageAspect; float2 pad; };
    vertex VertexOut vertexMain(uint id [[vertex_id]]) {
        float2 uv = float2((id << 1) & 2, id & 2);
        return {float4(uv.x * 2 - 1, 1 - uv.y * 2, 0, 1), uv};
    }
    float3 sampleScene(texture2d<float> tex, float2 point, constant Params& p, float lod) {
        // Aspect fill covers the display including the areas beside the notch.
        float screenAspect = p.size.x / p.size.y;
        float2 fit = screenAspect > p.imageAspect
            ? float2(1, screenAspect / p.imageAspect) : float2(p.imageAspect / screenAspect, 1);
        float2 uv = (point / p.size - 0.5) / fit + 0.5;
        if (any(uv < 0.0) || any(uv > 1.0)) return float3(0.015, 0.018, 0.025);
        constexpr sampler s(filter::linear, mip_filter::linear, address::clamp_to_edge);
        return tex.sample(s, uv, level(lod)).rgb;
    }
    fragment float4 glassMain(VertexOut in [[stage_in]], texture2d<float> tex [[texture(0)]], constant Params& p [[buffer(0)]]) {
        float2 pixel = in.uv * p.size;
        float angle = p.angle * M_PI_F / 180.0;
        float d = p.size.y - pixel.y;
        float gap = d * sin(angle);
        float2 glass = float2(pixel.x, p.size.y - d * cos(angle));
        float eye = p.size.y * p.eye;
        float2 center = p.size * 0.5;
        float2 hit = center + (glass - center) * eye / max(eye - gap, eye * 0.15);
        float radius = min(abs(gap) * p.frost, p.size.y * 0.055);
        float lod = max(0.0f, log2(max(1.0f, radius * 0.22)));
        float3 color = float3(0);
        // Mip-filtered disk sampling: soft spatially varying frost, no hard bands.
        for (int i = 0; i < 24; i++) {
            float r = sqrt((float(i) + 0.5) / 24.0) * radius;
            float a = float(i) * 2.39996323;
            color += sampleScene(tex, hit + float2(cos(a), sin(a)) * r, p, lod);
        }
        color /= 24.0;
        float depth = abs(gap) / p.size.y;
        color *= 1.0 - min(depth * 0.45, 0.35);
        // Grazing reflection remains screen-attached; the image moves behind it.
        float sheen = exp(-pow((in.uv.y - (0.25 + sin(angle) * 0.7)) / 0.19, 2.0));
        color += float3(0.78, 0.87, 1.0) * sheen * abs(sin(angle)) * 0.055;
        return float4(color, 1);
    }
    """
}
