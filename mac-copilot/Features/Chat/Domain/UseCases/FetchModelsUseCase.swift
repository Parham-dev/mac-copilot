import Foundation

struct FetchModelsUseCase {
    private let repository: ModelListingRepository

    init(repository: ModelListingRepository) {
        self.repository = repository
    }

    func execute() async -> [String] {
        await repository.fetchModels()
    }
}
