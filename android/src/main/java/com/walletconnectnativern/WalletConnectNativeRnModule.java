package com.walletconnectnativern;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.facebook.react.module.annotations.ReactModule;
import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import com.google.gson.reflect.TypeToken;
import com.walletconnect.web3.wallet.client.Wallet;
import com.walletconnect.web3.wallet.client.Web3Wallet;

import com.google.gson.Gson;

import java.lang.reflect.Type;
import java.util.List;
import java.util.Map;

import kotlin.Unit;
import kotlin.jvm.functions.Function2;

import com.walletconnect.android.Core;
import com.walletconnect.android.CoreClient;
import com.walletconnect.android.CoreInterface;
import com.walletconnect.android.relay.ConnectionType;
import java.util.ArrayList;
import java.util.Collections;

@ReactModule(name = WalletConnectNativeRnModule.NAME)
public class WalletConnectNativeRnModule extends ReactContextBaseJavaModule {
  public static final String NAME = "WalletConnectNativeRn";
  private final String WCMessageTag = "Wallet connect";
  Gson gson = new Gson();

  public WalletConnectNativeRnModule(ReactApplicationContext reactContext) {
    super(reactContext);
  }

  @Override
  @NonNull
  public String getName() {
    return NAME;
  }

  @ReactMethod
  public void getAllSessions(Promise promise){
    List<Wallet.Model.Session> sessions = Web3Wallet.getListOfActiveSessions();
    if (!sessions.isEmpty()) {
      promise.resolve(sessions);
    } else {
      promise.reject("No active sessions found.");
    }
  }

  @ReactMethod
  public void sendEvent(String eventName, Object data) {
    Gson eventData = gson.toJson(data);
    System.err.println(WCMessageTag + " " + eventName + ": " + data);
    ReactContext reactContext = getReactApplicationContext();
    reactContext.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
      .emit(eventName, eventData);
  }

  @ReactMethod
  public void sendEvent(String eventName, String message) {
    ReactContext reactContext = getReactApplicationContext();
    reactContext.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
      .emit(eventName, message);
  }

  Web3Wallet.WalletDelegate walletDelegate = new Web3Wallet.WalletDelegate() {
    public void onSessionExtend(@NonNull Wallet.Model.Session session) {
      sendEvent("session_extend", session);
    }

    public void onRequestExpired(@NonNull Wallet.Model.ExpiredRequest expiredRequest) {
      sendEvent("request_expired", expiredRequest);
    }

    public void onProposalExpired(@NonNull Wallet.Model.ExpiredProposal expiredProposal) {
      sendEvent("proposal_expired", expiredProposal);
    }

    public void onSessionProposal(@NonNull Wallet.Model.SessionProposal sessionProposal, @NonNull Wallet.Model.VerifyContext verifyContext) {
      sendEvent("session_proposal", sessionProposal);
    }


    public void onSessionAuthenticate(Wallet.Model.SessionAuthenticate sessionAuthenticate, Wallet.Model.VerifyContext verifyContext) {
      sendEvent("session_authenticate", sessionAuthenticate);
    }


    public void onSessionRequest(@NonNull Wallet.Model.SessionRequest sessionRequest, @NonNull Wallet.Model.VerifyContext verifyContext) {
      sendEvent("session_request", sessionRequest);
    }


    public void onAuthRequest(@NonNull Wallet.Model.AuthRequest authRequest, @NonNull Wallet.Model.VerifyContext verifyContext) {
      sendEvent("session_auth", authRequest);
    }


    public void onSessionDelete(@NonNull Wallet.Model.SessionDelete sessionDelete) {
      sendEvent("session_delete", sessionDelete);
    }


    public void onSessionSettleResponse(@NonNull Wallet.Model.SettledSessionResponse settleSessionResponse) {
      sendEvent("session_settled", settleSessionResponse);
    }


    public void onSessionUpdateResponse(@NonNull Wallet.Model.SessionUpdateResponse sessionUpdateResponse) {
      sendEvent("session_update", sessionUpdateResponse);
    }


    public void onConnectionStateChange(Wallet.Model.ConnectionState state) {
      sendEvent("state_changed", state.isAvailable);
    }


    public void onError(@NonNull Wallet.Model.Error error) {
      sendEvent("on_error", error);
    }
  };

  @ReactMethod
  public void initializeClient (Callback callback) {
    Web3Wallet walletInstance = MainApplication.getWeb3Wallet();
    walletInstance.setWalletDelegate(walletDelegate);
    callback.invoke();
  }

  @ReactMethod
  public void pair (String wcUrl, Promise promise) {
    Web3Wallet walletInstance = MainApplication.getWeb3Wallet();
    Wallet.Params.Pair pairData = new Wallet.Params.Pair(wcUrl) ;
    walletInstance.pair(pairData, (Wallet.Params.Pair pair) -> {
        String success = WCMessageTag + " paired successfully";
        System.out.println(success);
        promise.resolve(success);
        return null;
      },
      error -> {
        System.out.println(WCMessageTag + " error pair: " + error);
        promise.reject(error.toString());
        return kotlin.Unit.INSTANCE;
      });
  }

  @ReactMethod
  public void approveSession(
    String proposalData,
    String nameSpacesData,
    Promise promise
  ) throws Exception {
    Web3Wallet walletInstance = MainApplication.getWeb3Wallet();
    Wallet.Model.SessionProposal proposal = gson.fromJson(proposalData, Wallet.Model.SessionProposal.class);
    Type type = new TypeToken<Map<String,  Wallet.Model.Namespace.Session>>() {}.getType();
    Map<String, Wallet.Model.Namespace.Session> nameSpaces = gson.fromJson(nameSpacesData, type);
    Map<String, Wallet.Model.Namespace.Session> sessionNamespaces = walletInstance.generateApprovedNamespaces(proposal, nameSpaces);
    Wallet.Params.SessionApprove sessionApprovalData = new Wallet.Params.SessionApprove(proposal.proposerPublicKey, sessionNamespaces,proposal.relayProtocol);
    walletInstance.approveSession(sessionApprovalData, session -> {
        System.out.println(WCMessageTag + " session established");
        promise.resolve(gson.toJson(session));
        return null;
      },
      error -> {
        System.out.println(WCMessageTag + " error on session approval: " + error);
        promise.reject(error.toString());
        return kotlin.Unit.INSTANCE;
      });
  }

  @ReactMethod
  public void getActiveSessionByTopic(String topic, Promise promise){
    Web3Wallet walletInstance = MainApplication.getWeb3Wallet();
    Wallet.Model.Session session = walletInstance.getActiveSessionByTopic(topic);
    if(session != null){
      promise.resolve(gson.toJson(session));
    } else {
      promise.reject(WCMessageTag + " Session not exist");
    }
  }

  @ReactMethod
  public void respondSessionRequest(String sessionTopic, String respondParams, Promise promise) {
    try {
      Web3Wallet walletInstance = MainApplication.getWeb3Wallet();
      Wallet.Model.JsonRpcResponse.JsonRpcResult jsonRpcResponse = gson.fromJson(respondParams, Wallet.Model.JsonRpcResponse.JsonRpcResult.class) ;
      Wallet.Params.SessionRequestResponse params = new Wallet.Params.SessionRequestResponse(sessionTopic, jsonRpcResponse);

      walletInstance.respondSessionRequest(params, response -> {
        promise.resolve(gson.toJson(response));
        return null;
      }, error -> {
        promise.reject(gson.toJson(error));
        return null;
      });
    } catch (Exception e) {
      promise.reject(e);
    }
  }

  @ReactMethod
  public void rejectSessionRequest(String sessionTopic, String respondParams, Promise promise) {
    try {
      Web3Wallet walletInstance = MainApplication.getWeb3Wallet();
      Wallet.Model.JsonRpcResponse.JsonRpcError jsonRpcResponse = gson.fromJson(respondParams, Wallet.Model.JsonRpcResponse.JsonRpcError.class) ;
      Wallet.Params.SessionRequestResponse params = new Wallet.Params.SessionRequestResponse(sessionTopic, jsonRpcResponse);

      walletInstance.respondSessionRequest(params, response -> {
        promise.resolve(gson.toJson(response));
        return null;
      }, error -> {
        promise.reject(gson.toJson(error));
        return null;
      });
    } catch (Exception e) {
      promise.reject(e);
    }
  }

  @ReactMethod
  public void rejectSession(String rejectParams, Promise promise){
    Web3Wallet walletInstance = MainApplication.getWeb3Wallet();
    Wallet.Params.SessionReject params = gson.fromJson(rejectParams, Wallet.Params.SessionReject.class);
    walletInstance.rejectSession(params, response -> {
      promise.resolve(gson.toJson(response));
      return null;
    }, error -> {
      promise.reject(gson.toJson(error));
      return null;
    });
  }

  @ReactMethod
  public void deleteSession(String sessionTopic, Promise promise){
    Web3Wallet walletInstance = MainApplication.getWeb3Wallet();
    Wallet.Params.SessionDisconnect params = new Wallet.Params.SessionDisconnect(sessionTopic);
    walletInstance.disconnectSession(params, response -> {
      promise.resolve(gson.toJson(response));
      return null;
    }, error -> {
      promise.reject(gson.toJson(error));
      return null;
    });
  }

  @ReactMethod
  public void checkSessionExistence(String sessionTopic, Promise promise) {
    Web3Wallet walletInstance = MainApplication.getWeb3Wallet();
    Wallet.Params.SessionExtend eventData = new Wallet.Params.SessionExtend(sessionTopic);
    walletInstance.extendSession(eventData, response -> {
      System.out.println(WCMessageTag + " checkSessionExistence: " + response);
      promise.resolve(gson.toJson(response));
      return null;
    }, error -> {
      System.out.println(WCMessageTag + " checkSessionExistence error: " + error.toString());
      promise.reject(error.toString());
      return null;
    });
  }

  @ReactMethod
  public void checkSessionStatus(String sessionTopic, Promise promise) {
    Web3Wallet walletInstance = MainApplication.getWeb3Wallet();
    Wallet.Model.SessionEvent event = new Wallet.Model.SessionEvent("dummy", "message");
    Wallet.Params.SessionEmit eventData = new Wallet.Params.SessionEmit(sessionTopic, event, "eip155:1");
    walletInstance.emitSessionEvent(eventData, response -> {
      System.out.println(WCMessageTag + " checkSessionStatus: " + response);
      promise.resolve(gson.toJson(response));
      return null;
    }, error -> {
      System.out.println(WCMessageTag + " checkSessionStatus error: " + error.toString());
      promise.reject("Error", error.toString());
      return null;
    });
  }



}
