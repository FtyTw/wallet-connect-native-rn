import Foundation
import UIKit
import AVFoundation
import WalletCore
import React
import WalletConnectSwiftV2
import Combine

struct RespondParams: Codable {
    let id: RPCID
    let response: RPCResult
}

struct ErrorRespondParams: Codable {
    let code: Int
    let message: String
    let id: RPCID
}

struct SuccessRespondParams:Codable {
    let id: RPCID
    let jsonrpc: String
    let result: String
}

struct WalletConnectMetadata: Codable {
    let projectId: String
    let relayUrl: String
    let icon: String
    let name: String
    let description: String
    let url: String
}




@objc(WalletConnectNativeRn)
class WalletConnectNativeRn: RCTEventEmitter {
    var WalletClient: Web3WalletClient?
    static var WalletClientStorage: Web3WalletClient?
    private var cancellables = Set<AnyCancellable>()
    private let WCPrefix: String = "WalletConnectNativeRn"
    public static var emitter: RCTEventEmitter!

    @objc override static func requiresMainQueueSetup() -> Bool {
        return false
    }
    override init() {
        super.init()
        WalletConnectNativeRn.emitter = self
    }

    override func supportedEvents() -> [String]! {
        return [
            "session_delete",
            "session_request",
            "session_proposal",
            "state_changed",
            "session_settled",
        ]
    }

    @objc func emitEvent(withName: String, body: Any) {
        WalletConnectNativeRn.emitter.sendEvent(withName: withName, body: body)
    }

    func convertToJSONString<T: Encodable>(_ value: T) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        do {
            let jsonData = try encoder.encode(value)
            return String(data: jsonData, encoding: .utf8)
        } catch {
            print("Failed to convert to JSON:", error.localizedDescription)
            return nil
        }
    }

    func convertToDictionary(_ text: String) -> [String: Any]? {
        let string = text as String
        if let data = string.data(using: .utf8) {
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: [])
                return json as? [String: Any]
            } catch {
                print("Error parsing JSON: \(error)")
            }
        }
        return nil
    }

    @objc static public func initializeWalletConnectCore(){
        print("\(WCPrefix) initializeWalletConnectCore")
        guard let filePath = Bundle.main.path(forResource: "wallet-connect-configs", ofType: "json") else {
            print("WALLET CONNECT configs file not found")
            return
        }
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: filePath))

            let configs = try JSONDecoder().decode(WalletConnectMetadata.self, from: data)
            print("WALLET CONNECT configs", configs)
            let metadata = AppMetadata(
                name: configs.name,
                description: configs.description,
                url: configs.url,
                icons: [configs.icon]
            )
            Networking.configure(projectId: configs.projectId, socketFactory: WalletConnectNativeRnSocketFactory())
            Web3Wallet.configure(
                metadata: metadata,
                crypto: WalletConnectNativeRnCryptoProvider()
            )
            NSLog("Wallet Connect initialized")
            WalletConnectNativeRn.WalletClientStorage = Web3Wallet.instance

        } catch {
            print("Ошибка при чтении файла: \(error.localizedDescription)")
        }
    }

    func initListeners(){
        WalletClient!.socketConnectionStatusPublisher
            .sink {status in
                self.emitEvent(withName: "state_changed", body: status)
            }
            .store(in: &cancellables)

        WalletClient?.sessionProposalPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] session in
                guard let self = self else { return }
                let proposal = session.proposal
                if let jsonString = convertToJSONString(proposal) {
                    self.emitEvent(withName: "session_proposal", body: jsonString)
                } else {
                    print("\(WCPrefix) Failed to convert session proposal(!) to JSON.")
                }
            }.store(in: &cancellables)

        WalletClient?.sessionRequestPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessionRequest in
                guard let self = self else { return }
                let request = sessionRequest.request
                if let jsonString = convertToJSONString(request) {
                    self.emitEvent(withName: "session_request", body: jsonString)
                } else {
                    print("\(WCPrefix) Failed to convert session request(!) to JSON.")
                }
            }.store(in: &cancellables)


        WalletClient?.sessionSettlePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] session in
                guard let self = self else { return }
                if let jsonString = convertToJSONString(session) {
                    self.emitEvent(withName: "session_settled", body: jsonString)
                } else {
                    print("\(WCPrefix) Failed to convert session settle(!) to JSON.")
                }
            }.store(in: &cancellables)

        WalletClient?.sessionDeletePublisher.receive(on: DispatchQueue.main)
            .sink { [weak self] session in
                guard let self = self else { return }
                // session.0 is session topic string
                self.emitEvent(withName: "session_delete", body: session.0)
            }.store(in: &cancellables)
    }

    func initializeClient(_ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
        guard let walletClient = WalletConnectNativeRn.WalletClientStorage else {
            print("\(WCPrefix) WalletClient is nil in initializeClient")
            let error = NSError(domain: "\(WCPrefix) WalletClient is nil in initializeClient", code: 200, userInfo: [NSLocalizedDescriptionKey: "WalletClient is nil in initializeClient"])
            reject("\(WCPrefix) WalletClient is nil in initializeClient", error.localizedDescription, error)
            return
        }

        if WalletClient == nil {
            WalletClient = walletClient as? Web3WalletClient
            initListeners()
            resolve("Wallet Connect listeners initialized")
        } else {
            print("\(WCPrefix) WalletClient is already initialized")
            let error = NSError(domain: "\(WCPrefix) Wallet Connect listeners already set", code: 200, userInfo: [NSLocalizedDescriptionKey: "WalletClient is nil in initializeClient"])
            reject("\(WCPrefix) Wallet Connect listeners already set", error.localizedDescription, error)
        }
    }

    func approveSessionAsync(_ proposalId: String, namespaces: [String: SessionNamespace]) async throws -> String {
        guard let walletClient = WalletClient else {
            throw NSError(domain: "Wallet Client not initialized", code: 401, userInfo: nil)
        }
        do {
            let session: ()? = try await walletClient.approve(proposalId: proposalId, namespaces: namespaces)
            return "WALLET CONNECT SESSION approval complete"
        } catch {
            throw error
        }
    }

    @objc
    func approveSession(_ proposalData: NSString, nameSpacesData: NSString, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
        let jsonString1 = proposalData as String
        let jsonString2 = nameSpacesData as String
        guard let jsonData1 = jsonString1.data(using: .utf8),
              let jsonData2 = jsonString2.data(using: .utf8) else {
            print("Error converting JSON strings to data.")
            return
        }
        Task {
            do {
                let proposal = try JSONDecoder().decode(Session.Proposal.self, from: jsonData1)
                let namespaces = try JSONDecoder().decode([String: SessionNamespace].self, from: jsonData2)
                let result = try await approveSessionAsync(
                    proposal.id,
                    namespaces:namespaces
                )
                resolve(result)
            } catch {
                let error = NSError(domain: "\(WCPrefix) approveSession error:", code: 200, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])
                reject("\(WCPrefix) session approval error", error.localizedDescription, error)
                print("\(WCPrefix) session approval error: \(error)")
            }
        }
    }

    func rejectSessionAsync(_ proposalId: String, reason: RejectionReason) async throws -> String{
        guard let walletClient = WalletClient else {
            throw NSError(domain: "Wallet Client not initialized", code: 401, userInfo: nil)
        }

        do {
            try await walletClient.reject(proposalId: proposalId, reason: reason)
            return "WALLET CONNECT session request rejected"
        } catch {
            throw error
        }

    }

    @objc func rejectSession(_ proposalId:NSString, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock){
        Task{
            do {
                let result = try await rejectSessionAsync(proposalId as String, reason: RejectionReason.userRejected)
                resolve(result)
            } catch {
                let error = NSError(domain: "\(WCPrefix) rejectSession error:", code: 200, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])
                reject("\(WCPrefix) pairing error", error.localizedDescription, error)
            }
        }
    }

    func respondSessionRequestAsync(_ topic:String, requestId:RPCID, response:RPCResult) async throws -> String{
        do{
            let result = try await WalletClient?.respond(topic:topic, requestId: requestId, response: response)
            switch response {
            case .response:
                print("\(WCPrefix) session request approve result: \(result)")
                return "WALLET CONNECT session request approved"
            case .error:
                print("\(WCPrefix) session request reject result: \(result)")
                return "WALLET CONNECT session request rejected"
            }
        } catch {
            throw error
        }
    }

    @objc func respondSessionRequest(_ sessionTopic:NSString, respondParams: NSString, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock){
        Task{
            do{
                guard let respondParamsString = respondParams as? String,
                      let respondParamsData = respondParamsString.data(using: .utf8) else {
                    let error = NSError(domain: "\(WCPrefix) respondSessionRequest Invalid data", code: 200, userInfo: nil)
                    reject("\(WCPrefix) respondSessionRequest Invalid data", error.localizedDescription, error)
                    print("\(WCPrefix) respondSessionRequest Invalid data: \(error)")
                    return
                }

                let respondParamsObject = try JSONDecoder().decode(SuccessRespondParams.self, from: respondParamsData)
                let responseValue = AnyCodable(respondParamsObject.result)
                let rpcResult = RPCResult.response(responseValue)
                let result = try await respondSessionRequestAsync(sessionTopic as String, requestId: respondParamsObject.id, response: rpcResult)
                resolve(result)
            } catch{
                let error = NSError(domain: "\(WCPrefix) respondSessionRequest error", code: 200, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])
                reject("\(WCPrefix) respondSessionRequest error", error.localizedDescription, error)
                print("\(WCPrefix) respondSessionRequest error: \(error)")

            }
        }
    }

    @objc func rejectSessionRequest(_ sessionTopic:NSString, respondParams: NSString, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock){
        Task{
            do{
                guard let respondParamsString = respondParams as? String,
                      let respondParamsData = respondParamsString.data(using: .utf8) else {
                    let error = NSError(domain: "\(WCPrefix) rejectSessionRequest Invalid data", code: 200, userInfo: nil)
                    reject("\(WCPrefix) rejectSessionRequest Invalid data", error.localizedDescription, error)
                    print("\(WCPrefix) rejectSessionRequest Invalid data: \(error)")
                    return
                }
                let respondParamsObject = try JSONDecoder().decode(ErrorRespondParams.self, from: respondParamsData)
                let rpcError = JSONRPCError(code: respondParamsObject.code, message: respondParamsObject.message)
                let rpcResult = RPCResult.error(rpcError)
                let result = try await respondSessionRequestAsync(sessionTopic as String, requestId: respondParamsObject.id, response: rpcResult)
                resolve(result)
            } catch{
                let error = NSError(domain: "\(WCPrefix) rejectSessionRequest error", code: 200, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])
                reject("\(WCPrefix) rejectSessionRequest error", error.localizedDescription, error)
                print("\(WCPrefix) rejectSessionRequest error: \(error)")
            }
        }
    }

    public func pairAsync(_ wcUrl: String) async throws -> String {
        guard let wcUrl = WalletConnectURI(string: wcUrl) else {
            throw NSError(domain: "Invalid URL", code: 400, userInfo: nil)
        }

        guard let walletClient = WalletClient else {
            throw NSError(domain: "Wallet Client not initialized", code: 401, userInfo: nil)
        }

        do {
            let pairing = try await walletClient.pair(uri: wcUrl)
            return "Pairing completed"
        } catch {
            throw error
        }
    }

    @objc func pair(_ wcUrl: NSString, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
        Task {
            do {
                let result = try await pairAsync(wcUrl as String)
                resolve(result)
            } catch {
                let error = NSError(domain: "\(WCPrefix) pairing error", code: 200, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])
                reject("\(WCPrefix) pairing error", error.localizedDescription, error)
                print("\(WCPrefix) pairing error: \(error)")
            }
        }
    }

    public func deleteSessionAsync(_ topic:String) async throws -> String {
        guard let walletClient = WalletClient else {
            throw NSError(domain: "Wallet Client not initialized", code: 401, userInfo: nil)
        }
        do{
            try await walletClient.disconnect(topic: topic)
            return topic
        } catch{
            throw error
        }

    }

    @objc
    func deleteSession(_ sessionTopic: String, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock){
        Task{
            do{
                let result = try await deleteSessionAsync(
                    sessionTopic as String
                )
                print("WALLET CONNECT session deleted")
                resolve(result)
            } catch {
                let error = NSError(domain: "\(WCPrefix) session deletion error:", code: 200, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])
                reject("\(WCPrefix) session deletion error:", error.localizedDescription, error)
                print("\(WCPrefix) session deletion error:: \(error)")
            }
        }
    }

    public func checkSessionAsync(_ topic: String) async throws -> String {
        guard let walletClient = WalletClient else {
            throw NSError(domain: "Wallet Client not initialized", code: 401, userInfo: nil)
        }
        print("Attempting to extend session with topic: \(topic)")

        let eventData: [String: Any] = ["dummy": true]
        let event = Session.Event(name: "message", data: AnyCodable(any: eventData))
        let chainId = Blockchain("eip155:1")!
        do {
            try await walletClient.emit(topic: topic,event: event, chainId:chainId)
            return "Session check emitted"
        } catch let error as NSError {
            throw error
        }
    }




}
