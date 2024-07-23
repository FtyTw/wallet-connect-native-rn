import Foundation
import Starscream
import WalletConnectSwiftV2

class WalletConnectWebSocket: Starscream.WebSocket, WebSocketConnecting {
  private var _isConnected = true

  public var isConnected: Bool {
  _isConnected
  }

  var onConnect: (() -> Void)?

  var onDisconnect: ((Error?) -> Void)?

  var onText: ((String) -> Void)?

  convenience init(newRequest: URLRequest) {
    self.init(request: newRequest, useCustomEngine: false)

    onEvent = {
      [weak self] event in guard let self else { return }
      switch event {
        case .connected:
          _isConnected = true
          onConnect?()
          print("WALLET CONNECT WEBSOCKET CONNECTED")
        case .disconnected(let reason, let code):
          _isConnected = false
          onDisconnect?(NSError(domain: reason, code: Int(code), userInfo: nil))
          print("WALLET CONNECT WEBSOCKET DISCONNECTED")
        case .text(let text):
          onText?(text)
        case .binary:
          break
        case .pong:
          break
        case .ping:
          break
        case .error(let error):
          onDisconnect?(error)
          print("WALLET CONNECT WEBSOCKET ERROR", error as Any)
        case .viabilityChanged:
          break
        case .reconnectSuggested:
          break
        case .cancelled:
          _isConnected = false
          case .peerClosed:
          print("WALLET CONNECT PEER CLOSED")
          break
        @unknown default:
        break
      }
    }
  }
}

struct WalletConnectNativeRnSocketFactory: WebSocketFactory {
    func create(with url: URL) -> WebSocketConnecting {
        let urlRequest = URLRequest(url: url)
        return WalletConnectWebSocket(newRequest: urlRequest)

    }
}
