import Foundation

enum ModelsDecodeError: Error {
    case unsupportedShape
}

enum ModelCatalogDecoder {
    static func decodeModelPayloads(from data: Data) throws -> [ModelPayload] {
        let decoder = JSONDecoder()

        if let wrapped = try? decoder.decode(ModelsResponse.self, from: data) {
            return wrapped.models
        }

        if let wrappedStrings = try? decoder.decode(ModelsStringResponse.self, from: data) {
            return wrappedStrings.models.map { ModelPayload(stringID: $0) }
        }

        if let direct = try? decoder.decode([ModelPayload].self, from: data) {
            return direct
        }

        if let directStrings = try? decoder.decode([String].self, from: data) {
            return directStrings.map { ModelPayload(stringID: $0) }
        }

        throw ModelsDecodeError.unsupportedShape
    }

    static func decodeErrorMessage(from data: Data) -> String? {
        guard let payload = try? JSONDecoder().decode(SidecarErrorResponse.self, from: data),
              let message = payload.error?.trimmingCharacters(in: .whitespacesAndNewlines),
              !message.isEmpty
        else {
            return nil
        }

        return message
    }
}

struct SidecarErrorResponse: Decodable {
    let ok: Bool?
    let error: String?
}

struct ModelsResponse: Decodable {
    let ok: Bool?
    let models: [ModelPayload]
}

struct ModelsStringResponse: Decodable {
    let ok: Bool?
    let models: [String]
}
