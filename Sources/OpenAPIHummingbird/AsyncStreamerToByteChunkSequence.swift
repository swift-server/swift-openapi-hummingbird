//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import HummingbirdCore
import NIOCore
import OpenAPIRuntime

/// Convert HBByteBufferStreamer to an AsyncSequence of HTTPBody.ByteChunks
struct AsyncStreamerToByteChunkSequence: AsyncSequence {
    typealias Element = HTTPBody.ByteChunk

    struct AsyncIterator: AsyncIteratorProtocol {
        var streamer: HBStreamedRequestBody.AsyncIterator
        
        mutating func next() async throws -> Element? {
            if let buffer = try await streamer.next() {
                let byteChunk = [UInt8](buffer: buffer)[...]
                return byteChunk
            }
            return nil
        }
    }

    func makeAsyncIterator() -> AsyncIterator {
        .init(streamer: self.streamer.makeAsyncIterator())
    }

    let streamer: HBStreamedRequestBody
}
