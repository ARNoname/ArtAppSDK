
import UIKit
import SwiftUI

@MainActor
protocol ArtAppsWebViewControllerDelegate: AnyObject {
    func webViewControllerDidFinish(_ controller: ArtAppsWebViewController)
    func webViewControllerDidLoad(_ controller: ArtAppsWebViewController)
}

@MainActor
class ArtAppsWebViewController: UIViewController {
    
    weak var delegate: ArtAppsWebViewControllerDelegate?
    private let url: URL
    
    init(url: URL) {
        self.url = url
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .fullScreen
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        setupSwiftUI()
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    private func setupSwiftUI() {
        let adView = ArtAppsAdView(
            url: url,
            onClose: { [weak self] in
                self?.handleClose()
            },
            onLoad: { [weak self] in
                guard let self = self else { return }
                self.delegate?.webViewControllerDidLoad(self)
            }
        )
        
        let hostingController = UIHostingController(rootView: adView)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear
        
        addChild(hostingController)
        view.addSubview(hostingController.view)
        
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        hostingController.didMove(toParent: self)
    }
    
    private func handleClose() {
        dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            self.delegate?.webViewControllerDidFinish(self)
        }
    }
}
