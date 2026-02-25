import Foundation

protocol ModelListingRepository {
    func fetchModels() async -> [String]
}