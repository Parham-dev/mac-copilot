import Foundation

struct FetchModelCatalogUseCase {
    private let repository: ModelListingRepository

    init(repository: ModelListingRepository) {
        self.repository = repository
    }

    func execute() async -> [CopilotModelCatalogItem] {
        await repository.fetchModelCatalog()
    }
}
