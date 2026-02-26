import Foundation

struct FetchModelCatalogUseCase {
    private let repository: ModelListingRepository

    init(repository: ModelListingRepository) {
        self.repository = repository
    }

    func execute() async throws -> [CopilotModelCatalogItem] {
        try await repository.fetchModelCatalog()
    }
}
