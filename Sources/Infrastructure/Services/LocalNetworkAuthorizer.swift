import Foundation
import Network

final class LocalNetworkAuthorizer: NSObject {
    private let browserQueue = DispatchQueue(label: "com.ryankaya.signalboard.localnetwork.browser")

    private var browser: NWBrowser?
    private var service: NetService?
    private var completion: ((Result<Void, Error>) -> Void)?
    private var hasCompleted = false

    func requestAuthorization(serviceType: String, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.main.async {
            self.beginRequest(serviceType: serviceType, completion: completion)
        }
    }

    func cancel() {
        DispatchQueue.main.async {
            self.cleanup(resetState: true)
        }
    }

    private func beginRequest(serviceType: String, completion: @escaping (Result<Void, Error>) -> Void) {
        cleanup(resetState: true)

        self.completion = completion
        hasCompleted = false

        let bonjourType = "_\(serviceType)._tcp"

        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true

        let browser = NWBrowser(for: .bonjour(type: bonjourType, domain: nil), using: parameters)
        browser.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.complete(with: .success(()))
            case .failed(let error):
                self?.complete(with: .failure(error))
            case .waiting(let error):
                if Self.isPermissionDenied(error) {
                    self?.complete(with: .failure(error))
                }
            default:
                break
            }
        }
        browser.browseResultsChangedHandler = { _, _ in }
        browser.start(queue: browserQueue)
        self.browser = browser

        let service = NetService(
            domain: "local.",
            type: "\(bonjourType).",
            name: UUID().uuidString,
            port: 9
        )
        service.includesPeerToPeer = true
        service.delegate = self
        service.publish()
        self.service = service
    }

    private func complete(with result: Result<Void, Error>) {
        DispatchQueue.main.async {
            guard !self.hasCompleted else {
                return
            }

            self.hasCompleted = true
            let completion = self.completion
            self.cleanup(resetState: false)
            completion?(result)
        }
    }

    private func cleanup(resetState: Bool) {
        browser?.stateUpdateHandler = nil
        browser?.browseResultsChangedHandler = nil
        browser?.cancel()
        browser = nil

        service?.delegate = nil
        service?.stop()
        service = nil

        if resetState {
            completion = nil
            hasCompleted = false
        }
    }

    private static func isPermissionDenied(_ error: NWError) -> Bool {
        if case .dns(let dnsError) = error {
            return Self.localNetworkDNSFailureCodes.contains(Int(dnsError))
        }

        return false
    }

    private static let localNetworkDNSFailureCodes: Set<Int> = [
        -65555, // kDNSServiceErr_NoAuth
        -65570  // kDNSServiceErr_PolicyDenied
    ]
}

extension LocalNetworkAuthorizer: NetServiceDelegate {
    func netServiceDidPublish(_ sender: NetService) {
        complete(with: .success(()))
    }

    func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
        let code = errorDict[NetService.errorCode]?.intValue ?? -72000
        let error = NSError(domain: NetService.errorDomain, code: code, userInfo: nil)
        complete(with: .failure(error))
    }
}
