import Foundation

protocol ModelListingRepository {
    func fetchModelCatalog() async -> [CopilotModelCatalogItem]
}