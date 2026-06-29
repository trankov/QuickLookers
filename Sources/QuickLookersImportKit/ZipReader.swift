import Foundation
import CLibArchive

public enum ZipError: Error { case open, read }

/// Читает записи ZIP (.vsix) из памяти через системную libarchive.
/// Память архива должна жить на время чтения, поэтому всё — внутри withUnsafeBytes.
public struct ZipReader {
    public init() {}

    public func entryNames(in data: Data) throws -> [String] {
        try read(data) { a in
            var names: [String] = []
            var entry: OpaquePointer?
            while archive_read_next_header(a, &entry) == 0 {
                if let e = entry, let p = archive_entry_pathname(e) {
                    names.append(String(cString: p))
                }
                archive_read_data_skip(a)
            }
            return names
        }
    }

    public func entry(_ name: String, in data: Data) throws -> Data? {
        try read(data) { a in
            var entry: OpaquePointer?
            while archive_read_next_header(a, &entry) == 0 {
                guard let e = entry, let p = archive_entry_pathname(e) else {
                    archive_read_data_skip(a); continue
                }
                if String(cString: p) == name {
                    return try readAll(a)
                }
                archive_read_data_skip(a)
            }
            return nil
        }
    }

    /// Открывает архив из памяти и выполняет body, гарантируя освобождение.
    private func read<T>(_ data: Data, _ body: (OpaquePointer) throws -> T) throws -> T {
        try data.withUnsafeBytes { (buf: UnsafeRawBufferPointer) -> T in
            guard let a = archive_read_new() else { throw ZipError.open }
            defer { archive_read_free(a) }
            archive_read_support_format_all(a)
            archive_read_support_filter_all(a)
            guard archive_read_open_memory(a, buf.baseAddress, buf.count) == 0 else { throw ZipError.open }
            return try body(a)
        }
    }

    /// Читает тело текущей записи целиком (размер может быть неизвестен — читаем до 0).
    private func readAll(_ a: OpaquePointer) throws -> Data {
        var out = Data()
        var chunk = [UInt8](repeating: 0, count: 64 * 1024)
        while true {
            let n = chunk.withUnsafeMutableBytes { archive_read_data(a, $0.baseAddress, $0.count) }
            if n == 0 { break }
            if n < 0 { throw ZipError.read }
            out.append(contentsOf: chunk[0..<n])
        }
        return out
    }
}
