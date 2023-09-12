import HummingbirdCore
import NIOCore
import OpenAPIRuntime

/// Convert HBByteBufferStreamer to an AsyncSequence of HTTPBody.ByteChunks
struct AsyncStreamerToByteChunkSequence: AsyncSequence {
    typealias Element = HTTPBody.ByteChunk

    struct AsyncIterator: AsyncIteratorProtocol {
        let streamer: HBByteBufferStreamer
        
        mutating func next() async throws -> Element? {
            if case .byteBuffer(let buffer) = try await streamer.consume() {
                let byteChunk = [UInt8](buffer: buffer)[...]
                return byteChunk
            }
            return nil
        }
    }

    func makeAsyncIterator() -> AsyncIterator {
        .init(streamer: self.streamer)
    }

    let streamer: HBByteBufferStreamer
}