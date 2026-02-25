import Foundation

protocol ModelListingRepository {
    func fetchModels() async -> [String]
    func fetchModelCatalog() async -> [CopilotModelCatalogItem]
}