import PlaygroundSupport
import MetalKit

// MARK: - THE CODE IN THIS SECTION IS COMPUTATIONALLY EXPENSIVED AND SHOULD BE PERFORMED AS A ONE-TIME SETUP

guard let device = MTLCreateSystemDefaultDevice() else {
    fatalError("Your GPU sucks")
}
               
let frame = CGRect(x: 0, y: 0, width: 640, height: 480)
let view = MTKView(frame: frame, device: device)
view.clearColor = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)

// Manages memory for the mesh data
let allocator = MTKMeshBufferAllocator(device: device)

// Model I/O mesh
let primitive = MDLMesh(
    boxWithExtent: [0.75, 0.75, 0.75],
    segments: [100, 100, 100],
    inwardNormals: false,
    geometryType: .triangles,
    allocator: allocator
)

// MetalKit mesh
let mesh = try MTKMesh(mesh: primitive, device: device)

// Command queues organize command buffers. Command buffers organize command encoders.
guard let commandQueue = device.makeCommandQueue() else {
    fatalError("No Command Queue for YOU!")
}

let shader = """
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float4 position [[attribute(0)]];
};

vertex float4 vertex_main(const VertexIn vertex_in [[stage_in]]) {
    return vertex_in.position;
}

fragment float4 fragment_main() {
    return float4(0.75, 0.7, 0.7, 1);
}
"""

// Create the vertext and fragment functions
let library = try device.makeLibrary(source: shader, options: nil)
let vertextFunction = library.makeFunction(name: "vertex_main")
let fragmentFunction = library.makeFunction(name: "fragment_main")

// Create the pipeline state. This tells the GPU nothing will change.
let pipelineDescriptor = MTLRenderPipelineDescriptor()
pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm // 32-bit, pixel order blue, gree, red, alpha
pipelineDescriptor.vertexFunction = vertextFunction
pipelineDescriptor.fragmentFunction = fragmentFunction

// Use a vertex descriptor to tell the GPU how the vertices are laid out in memory
pipelineDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(mesh.vertexDescriptor)

// Create the pipeline state from the descriptor. This takes time, so it should be a one-time setup.
let pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)

// MARK: - THE CODE SHOULD BE PERFORMED EVERY FRAME

// The command buffer stores all the commands that we ask the GPU to run
guard let commandBuffer = commandQueue.makeCommandBuffer(),
      // The render pass descriptor is used to create the render pass encoder, which holds all the info the GPU need to draw the vertices
      let renderPassDescriptor = view.currentRenderPassDescriptor,
      let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
    fatalError() // Usually just return, but since we're only calling once in this example, we'll fatalError
}

renderEncoder.setRenderPipelineState(pipelineState)
renderEncoder.setVertexBuffer(mesh.vertexBuffers[0].buffer, offset: 0, index: 0)

// Models can contain multiple submeshes with different materials. This box only has one submesh.
guard let submesh = mesh.submeshes.first else {
    fatalError()
}

// Tell the GPU to render a vetext buffer using triangles. Drawing doesn't happen at this point.
renderEncoder.drawIndexedPrimitives(type: .triangle,
                                    indexCount: submesh.indexCount,
                                    indexType: submesh.indexType,
                                    indexBuffer: submesh.indexBuffer.buffer,
                                    indexBufferOffset: 0)

// You tell the render encoder that there are no more draw calls and end the render pass
renderEncoder.endEncoding()

// You get the drawable from the MTKView. The MTKView is backed by a Core Animation CAMetalLayer and the layer owns a drawable texture which Metal can read and write to.”
guard let drawable = view.currentDrawable else {
    fatalError()
}

// Ask the command buffer to present the MTKView’s drawable and commit to the GPU.
commandBuffer.present(drawable)

// Drawing happens at this point
commandBuffer.commit()

// View in the Assistant Editor
PlaygroundPage.current.liveView = view

