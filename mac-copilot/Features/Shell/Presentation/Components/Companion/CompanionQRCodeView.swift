import SwiftUI
import CoreImage.CIFilterBuiltins

struct CompanionQRCodeView: View {
    let payload: String?
    let size: CGFloat

    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    init(payload: String?, size: CGFloat = 120) {
        self.payload = payload
        self.size = size
    }

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
        .frame(width: size, height: size)
        .padding(18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    private func generateQRImage(from value: String?) -> NSImage? {
        guard let value, !value.isEmpty else {
            return nil
        }

        filter.message = Data(value.utf8)
        filter.correctionLevel = "H"

        guard let outputImage = filter.outputImage else {
            return nil
        }

        let moduleScale = max(8, floor(size / outputImage.extent.width))
        let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: moduleScale, y: moduleScale))
        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
    }
}
