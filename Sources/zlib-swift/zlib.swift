import Foundation
import zlib

public struct CompressionLevel: RawRepresentable {
    public let rawValue: Int32
    
    public static let noCompression = CompressionLevel(Z_NO_COMPRESSION)
    public static let bestSpeed = CompressionLevel(Z_BEST_SPEED)
    public static let bestCompression = CompressionLevel(Z_BEST_COMPRESSION)
    public static let defaultCompression = CompressionLevel(Z_DEFAULT_COMPRESSION)
    
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public init(_ rawValue: Int32) {
        self.rawValue = rawValue
    }
}

public struct GzipError: Error {
    public enum Kind: Equatable {
        case stream, data, memory, buffer, version, unknown(code: Int)
    }
    
    public let kind: Kind
    public let message: String
    
    internal init(code: Int32, msg: UnsafePointer<CChar>?) {
        self.message = {
            guard let msg = msg, let message = String(validatingUTF8: msg) else {
                return "Unknown gzip error"
            }
            return message
        }()
        
        self.kind = {
            switch code {
            case Z_STREAM_ERROR: return .stream
            case Z_DATA_ERROR: return .data
            case Z_MEM_ERROR: return .memory
            case Z_BUF_ERROR: return .buffer
            case Z_VERSION_ERROR: return .version
            default: return .unknown(code: Int(code))
            }
        }()
    }
    
    public var localizedDescription: String { self.message }
}


extension Data {
    public var zipped: Bool { self.starts(with: [0x1f, 0x8b]) }
    
    public func zipped(level: CompressionLevel = .defaultCompression) throws -> Data {
        guard !self.isEmpty else { return Data() }
        
        var stream = z_stream()
        var status: Int32
        
        status = deflateInit2_(&stream, level.rawValue, Z_DEFLATED, MAX_WBITS + 16, MAX_MEM_LEVEL, Z_DEFAULT_STRATEGY, ZLIB_VERSION, Int32(DataSize.stream))
        
        guard status == Z_OK else {
            // deflateInit2 returns:
            // Z_VERSION_ERROR  The zlib library version is incompatible with the version assumed by the caller.
            // Z_MEM_ERROR      There was not enough memory.
            // Z_STREAM_ERROR   A parameter is invalid.
            
            throw GzipError(code: status, msg: stream.msg)
        }
        
        var data = Data(capacity: DataSize.chunk)
        repeat {
            if Int(stream.total_out) >= data.count {
                data.count += DataSize.chunk
            }
            
            let inputCount = self.count
            let outputCount = data.count
            
            self.withUnsafeBytes { (inputPointer: UnsafeRawBufferPointer) in
                stream.next_in = UnsafeMutablePointer<Bytef>(mutating: inputPointer.bindMemory(to: Bytef.self).baseAddress!).advanced(by: Int(stream.total_in))
                stream.avail_in = uint(inputCount) - uInt(stream.total_in)
                
                data.withUnsafeMutableBytes { (outputPointer: UnsafeMutableRawBufferPointer) in
                    stream.next_out = outputPointer.bindMemory(to: Bytef.self).baseAddress!.advanced(by: Int(stream.total_out))
                    stream.avail_out = uInt(outputCount) - uInt(stream.total_out)
                    
                    status = deflate(&stream, Z_FINISH)
                    
                    stream.next_out = nil
                }
                
                stream.next_in = nil
            }
            
        } while stream.avail_out == 0
        
        guard deflateEnd(&stream) == Z_OK, status == Z_STREAM_END else {
            throw GzipError(code: status, msg: stream.msg)
        }
        
        data.count = Int(stream.total_out)
        
        return data
    }
    
    
    
    public func unzipped() throws -> Data {
        guard !self.isEmpty else { return Data() }

        var stream = z_stream()
        var status: Int32
        
        status = inflateInit2_(&stream, MAX_WBITS + 32, ZLIB_VERSION, Int32(DataSize.stream))
        
        guard status == Z_OK else {
            // inflateInit2 returns:
            // Z_VERSION_ERROR   The zlib library version is incompatible with the version assumed by the caller.
            // Z_MEM_ERROR       There was not enough memory.
            // Z_STREAM_ERROR    A parameters are invalid.
            
            throw GzipError(code: status, msg: stream.msg)
        }
        
        var data = Data(capacity: self.count * 2)
        repeat {
            if Int(stream.total_out) >= data.count {
                data.count += self.count / 2
            }
            
            let inputCount = self.count
            let outputCount = data.count
            
            self.withUnsafeBytes { (inputPointer: UnsafeRawBufferPointer) in
                stream.next_in = UnsafeMutablePointer<Bytef>(mutating: inputPointer.bindMemory(to: Bytef.self).baseAddress!).advanced(by: Int(stream.total_in))
                stream.avail_in = uint(inputCount) - uInt(stream.total_in)
                
                data.withUnsafeMutableBytes { (outputPointer: UnsafeMutableRawBufferPointer) in
                    stream.next_out = outputPointer.bindMemory(to: Bytef.self).baseAddress!.advanced(by: Int(stream.total_out))
                    stream.avail_out = uInt(outputCount) - uInt(stream.total_out)
                    
                    status = inflate(&stream, Z_SYNC_FLUSH)
                    
                    stream.next_out = nil
                }
                
                stream.next_in = nil
            }
            
        } while status == Z_OK
        
        guard inflateEnd(&stream) == Z_OK, status == Z_STREAM_END else {
            // inflate returns:
            // Z_DATA_ERROR   The input data was corrupted (input stream not conforming to the zlib format or incorrect check value).
            // Z_STREAM_ERROR The stream structure was inconsistent (for example if next_in or next_out was NULL).
            // Z_MEM_ERROR    There was not enough memory.
            // Z_BUF_ERROR    No progress is possible or there was not enough room in the output buffer when Z_FINISH is used.
            
            throw GzipError(code: status, msg: stream.msg)
        }
        
        data.count = Int(stream.total_out)
        
        return data
    }
    
}


private enum DataSize {
    static let chunk = 1 << 14
    static let stream = MemoryLayout<z_stream>.size
}
