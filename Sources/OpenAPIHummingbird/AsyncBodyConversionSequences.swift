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

/// Convert AsyncSequence of HTTPBody.ByteChunks to AsyncSequence of ByteBuffers
struct AsyncByteChunkToByteBufferSequence<BaseSequence: AsyncSequence>: AsyncSequence where BaseSequence.Element == HTTPBody.ByteChunk {
    typealias Element = ByteBuffer

    struct AsyncIterator: AsyncIteratorProtocol {
        var baseIterator: BaseSequence.AsyncIterator
        
        mutating func next() async throws -> Element? {
            if let byteChunk = try await baseIterator.next() {
                let buffer = ByteBuffer(bytes: byteChunk)
                return buffer
            }
            return nil
        }
    }

    func makeAsyncIterator() -> AsyncIterator {
        .init(baseIterator: base.makeAsyncIterator())
    }

    let base: BaseSequence
}

extension AsyncSequence where Element == HTTPBody.ByteChunk {
    var byteBufferSequence: AsyncByteChunkToByteBufferSequence<Self> { .init(base: self) }
}