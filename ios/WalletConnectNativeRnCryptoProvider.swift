import Foundation
import WalletCore
import WalletConnectSwiftV2

struct WalletConnectNativeRnCryptoProvider: CryptoProvider {
  public func recoverPubKey(signature: EthereumSignature, message: Data) throws -> Data {
    var byteAddress: UnsafeRawPointer?
    var signatureAddress:UnsafeRawPointer?
    var publicKey:Data?
    signature.serialized.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> Void in
      signatureAddress = bytes.baseAddress
    }
    message.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> Void in
      byteAddress = bytes.baseAddress
    }
    if let byteAddress = byteAddress, let signatureAddress = signatureAddress {
      let pointer = TWPublicKeyRecover(signatureAddress ,byteAddress)
      let rawPointer = UnsafeRawPointer(pointer)
      publicKey = Data(bytes: rawPointer!, count: message.count)
    } else {
      print("WALLET CONNECT СRYPTO PROVIDER Failed to get one or both byte addresses")
    }
    return publicKey!
  }

  public func keccak256(_ data: Data) -> Data {
    let unsafePointer = UnsafeRawPointer((data as NSData).bytes)
    let resultPointer = TWHashKeccak256(unsafePointer)
    let hashData = Data(bytes: resultPointer, count: 32)
    return hashData
  }
}


