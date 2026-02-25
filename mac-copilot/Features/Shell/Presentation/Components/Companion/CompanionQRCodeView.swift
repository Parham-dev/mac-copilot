import SwiftUI
import CoreImage.CIFilterBuiltins

struct CompanionQRCodeView: View {
    let payload: String?

    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    var body: some View {
        Group {
            if let image = generateQRImage(from: payload) {
                Image(nsImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "qrcode")
                    .font(.system(size: 72, weight: .regular))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 120, height: 120)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func generateQRImage(from value: String?) -> NSImage? {
        guard let value, !value.isEmpty else {
            return nil
        }

        filter.message = Data(value.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else {
            return nil
        }

        let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: 6, y: 6))
        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: 120, height: 120))
    }
}
