
import SwiftUI
import WebKit

struct ArtAppsAdView: View {
    let url: URL
    let onClose: () -> Void
    let onLoad: () -> Void
    
    let adDuration: TimeInterval = 30
    
    @Environment(\.colorScheme) var colorScheme
    
    @State private var progress: Double = 0.0
    @State private var isCloseButtonVisible = false
    @State private var isTimerActive = false
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    // ------ If need set app product, you must get data from server ------//
    @State var appProduct: ArtAppsProduct?
  
    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .bottom,spacing: 0) {
                if let appProduct {
                    ProductView(appProduct: appProduct)
                }
                
                if isCloseButtonVisible {
                    Spacer()
                    CloseButton
                }
                
                if !isCloseButtonVisible {
                    ProgressLine
                }
            }
            .frame(minHeight: 24)
            .padding(.horizontal, 10)
            
            ArtAppsWebViewWrapper(url: url, onLoad: {
                isTimerActive = true
                onLoad()
            })
            .edgesIgnoringSafeArea(.all)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .background(colorScheme == .dark ? Color.black.opacity(0.93) : Color.white)
        .edgesIgnoringSafeArea([.leading, .trailing, .bottom])
        .onReceive(timer) { _ in
            guard isTimerActive else { return }
            if progress < 1.0 {
                progress += 0.1 / adDuration
            } else {
                isTimerActive = false
                withAnimation(.linear(duration: 0.1)) {
                    isCloseButtonVisible = true
                }
            }
        }
    }
   
    //MARK: - Product View
    @ViewBuilder
    private func ProductView(appProduct: ArtAppsProduct) -> some View {
        Button(action: {
            if let url = URL(string: "https://apps.apple.com/app/\(appProduct.appID)") {
                UIApplication.shared.open(url)
            }
        }) {
            HStack {
                Image(appProduct.iconApp)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading) {
                    Text(appProduct.nameApp)
                        .foregroundColor(Color.primary)
                        .font(Font.system(size: 12, weight: .bold))
                        .multilineTextAlignment(.leading)
                    
                    Text("install")
                        .foregroundColor(Color.white)
                        .font(Font.system(size: 12, weight: .medium))
                        .padding(.vertical, 2)
                        .padding(.horizontal, 10)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
            }
            .frame(minWidth: 130, minHeight: 40, alignment: .leading)
        }
        Spacer(minLength: 0)
    }
    
    //MARK: - Close button
    @ViewBuilder
    private var CloseButton: some View {
        Button(action: onClose) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(Color.gray, lineWidth: 1)
                    )
                
                Image(systemName: "xmark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12, height: 12)
                    .font(Font.system(size: 12, weight: .bold))
                    .foregroundColor(Color.gray)
            }
        }
    }
    
    //MARK: - Progress view
    @ViewBuilder
    private var ProgressLine: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Color.white.opacity(0.5)
                
                Color.blue // Or any active color you prefer
                    .frame(width: geometry.size.width * CGFloat(min(progress, 1.0)))
            }
        }
        .frame(height: 4)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

#Preview {
    ArtAppsAdView(url: URL(string: "https://google.com")!, onClose: {}, onLoad: {})
}


