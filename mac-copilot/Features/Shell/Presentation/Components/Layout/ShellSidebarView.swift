import SwiftUI

/// Shell sidebar host.
///
/// Iterates `AppFeatureRegistry` and renders each feature's sidebar section.
/// Uses a single `List(selection:)` with a unified `AnyHashable?` binding so
/// macOS handles row highlighting and keyboard navigation automatically.
///
/// Sync strategy:
/// - The per-feature `Binding<AnyHashable?>` (from `ShellViewModel.selectionBinding`)
///   is passed into each feature section so they can write directly into
///   `shellViewModel.selectionByFeature` when a row is tapped.
/// - A local `@State var listSelection` mirrors the active feature's selection
///   so the `List` knows which row to highlight. It is kept in sync via
///   `.onChange` observers in both directions.
/// - `onListSelectionChange` is called once per user tap (via `onChange(of: listSelection)`)
///   so the caller (ContentView) can sync feature VMs without relying on the
///   unreliable `$selectionByFeature` publisher which double-fires on Dictionary mutation.
struct ShellSidebarView: View {
    @ObservedObject var shellViewModel: ShellViewModel
    @ObservedObject var projectsViewModel: ProjectsViewModel
    let projectCreationService: ProjectCreationService
    @EnvironmentObject private var featureRegistry: AppFeatureRegistry
    let isAuthenticated: Bool
    let companionStatusLabel: String
    let isUpdateAvailable: Bool
    let onCheckForUpdates: () -> Void
    let onOpenProfile: () -> Void
    let onManageModels: () -> Void
    let onManageCompanion: () -> Void
    let onManageNativeTools: () -> Void
    let onSignOut: () -> Void

    /// Called exactly once per user-driven List selection change (including
    /// keyboard navigation). Provides the new `(featureID, selection?)` pair.
    /// Use this instead of observing `$selectionByFeature` to avoid the
    /// double-emission that Dictionary subscript-set triggers on `@Published`.
    var onListSelectionChange: ((_ featureID: String, _ newSelection: AnyHashable?) -> Void)?

    // MARK: - Unified List highlight selection

    /// Mirrors the active feature's selection for the `List(selection:)` highlight.
    /// Distinct from `shellViewModel.selectionByFeature` — the model is the source of
    /// truth; this is just the view-layer proxy for the List widget.
    @State private var listSelection: AnyHashable?

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            List(selection: $listSelection) {
                ForEach(featureRegistry.features) { feature in
                    Section(header: sidebarHeader(for: feature)) {
                        feature.sidebarSection(
                            // Per-feature binding: writes into shellViewModel.
                            // Wrapper intercepts the `set` to also update listSelection.
                            wrappedSelectionBinding(for: feature.id)
                        )
                    }
                }
            }
            // Programmatic selection changes (e.g. createChat, bootstrap) → sync to List.
            .onChange(of: shellViewModel.selectionByFeature) { _, newMap in
                guard let activeID = shellViewModel.activeFeatureID,
                      let sel = newMap[activeID]
                else { return }
                if listSelection != sel { listSelection = sel }
            }
            // User-driven tap (or keyboard nav) → fire the single, reliable callback.
            // `listSelection` changes exactly once per tap — unlike `$selectionByFeature`
            // which double-fires because Dictionary subscript-set uses two _modify cycles.
            .onChange(of: listSelection) { _, newSelection in
                guard let activeID = shellViewModel.activeFeatureID else { return }
                onListSelectionChange?(activeID, newSelection)
            }
            .safeAreaInset(edge: .bottom) {
                bottomBar(sidebarWidth: geometry.size.width)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
            }
        }
    }

    // MARK: - Selection binding wrapper

    @ViewBuilder
    private func sidebarHeader(for feature: FeatureModule) -> some View {
        HStack(spacing: 8) {
            Text(feature.sidebarTitle)
            Spacer(minLength: 8)

            if feature.id == ProjectsFeatureModule.featureID {
                ProjectsSectionActionMenuButton(
                    projectsViewModel: projectsViewModel,
                    projectCreationService: projectCreationService,
                    iconSystemName: "plus.circle"
                )
            }
        }
    }

    /// Creates a per-feature `Binding<AnyHashable?>` that mirrors writes into
    /// both `shellViewModel` and `listSelection` so the List highlight is instant.
    private func wrappedSelectionBinding(for featureID: String) -> Binding<AnyHashable?> {
        Binding(
            get: { shellViewModel.selectionByFeature[featureID] },
            set: { newValue in
                // Write into shellViewModel (this also sets activeFeatureID).
                shellViewModel.selectionBinding(for: featureID).wrappedValue = newValue
                // Immediately mirror to List highlight binding.
                listSelection = newValue
            }
        )
    }

    // MARK: - Bottom bar

    private func bottomBar(sidebarWidth: CGFloat) -> some View {
        ShellSidebarBottomBarView(
            isAuthenticated: isAuthenticated,
            sidebarWidth: sidebarWidth,
            onOpenProfile: onOpenProfile,
            companionStatusLabel: companionStatusLabel,
            isUpdateAvailable: isUpdateAvailable,
            onCheckForUpdates: onCheckForUpdates,
            onManageCompanion: onManageCompanion,
            onManageModels: onManageModels,
            onManageNativeTools: onManageNativeTools,
            onSignOut: onSignOut
        )
    }
}
