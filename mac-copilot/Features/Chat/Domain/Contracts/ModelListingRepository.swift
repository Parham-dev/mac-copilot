import Foundation

protocol ModelListingRepository {
    func fetchModelCatalog() async throws -> [CopilotModelCatalogItem]
}