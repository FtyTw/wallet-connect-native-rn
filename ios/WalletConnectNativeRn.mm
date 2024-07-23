#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(WalletConnectNativeRn, NSObject)

RCT_EXTERN_METHOD(initializeClient:(RCTResponseSenderBlock *)callback)
RCT_EXTERN_METHOD(pair:(NSString *)wcUrl resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(rejectSession:(NSString *)proposalId resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(addListener:(NSString *)eventName)
RCT_EXTERN_METHOD(removeListeners:(NSInteger *)count)
RCT_EXTERN_METHOD(approveSession:(NSString *)proposalData nameSpacesData:(NSString *)nameSpacesData resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(updateSession:(NSString *)topic nameSpacesData:(NSString *)nameSpacesData resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(emitSessionChanged:(NSString *)topic chainId:(NSString *)chainId resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(deleteSession:(NSString *)topic resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(getAllSessions:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(respondSessionRequest:(NSString *)sessionTopic respondParams:(NSString *)respondParams resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(rejectSessionRequest:(NSString *)sessionTopic respondParams:(NSString *)respondParams resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(removeAllListeners)
RCT_EXTERN_METHOD(checkSessionExistence:(NSString *)topic resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)


// + (BOOL)requiresMainQueueSetup
// {
//   return NO;
// }

@end
