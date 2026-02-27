import SwiftUI

struct GitPanelHeaderView: View {
    let totalAddedLines: Int
    let totalDeletedLines: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                    .font(.title3)
                Text("Git")
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            Spacer()
            HStack(spacing: 4) {
                Text("+\(totalAddedLines)")
                    .foregroundStyle(.green)
                Text("/")
                    .foregroundStyle(.secondary)
                Text("-\(totalDeletedLines)")
                    .foregroundStyle(.red)
            }
            .font(.subheadline)
            .fontWeight(.semibold)
        }
    }
}
