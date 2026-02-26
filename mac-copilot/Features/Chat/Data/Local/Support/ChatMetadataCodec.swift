import Foundation

enum ChatMetadataCodec {
    static func encode(_ metadata: ChatMessage.Metadata) throws -> String? {
        let data = try JSONEncoder().encode(metadata)
        return String(data: data, encoding: .utf8)
    }

    static func decode(from json: String) throws -> ChatMessage.Metadata {
        guard let data = json.data(using: .utf8) else {
            throw ChatMetadataCodecError.invalidUTF8
        }

        return try JSONDecoder().decode(ChatMessage.Metadata.self, from: data)
    }
}

enum ChatMetadataCodecError: Error {
    case invalidUTF8
}