//
//  IdensicMobileSdkManager.swift
//  sumsub
//
//  Created by Vinod Sutar on 29/01/24.
//

import Foundation
import IdensicMobileSDK


@objc public protocol NativeServiceDelegate {
    @objc func onSuccess(_ jsCallback: String, data: [String : Any])
    @objc func onFailure(_ jsCallback: String, reasonCode: String, description: String)
}

@objc public class IdensicMobileSdkManager : NSObject {
    
    @objc static let shared = IdensicMobileSdkManager()
    
    private var currentToken : String?
    
    private var expiredToken : String?
    
    private var delegate : NativeServiceDelegate?
    
    private var actions : [String] = []
    
    public override init() {
        actions = [
            "SUMSUB_LAUNCH_SDK",
            "SUMSUB_NEW_TOKEN"
        ]
    }
    
    public func canPerformAction(jsonDict : [AnyHashable : Any]) -> Bool {
        
        
        if let action = jsonDict["action"] as? String {
            
            debugPrint("isIdensicMobileSDKAction:: \(action)")
            
            return actions.contains(action)
        }
        
        debugPrint("isIdensicMobileSDKAction:: err")
        
        return false
    }
    
    public func performAction(jsonDict : [AnyHashable : Any], viewController: UIViewController, delegate: NativeServiceDelegate) {
        
        self.delegate = delegate
        
        if let action = jsonDict["action"] as? String {
            
            debugPrint("action:: \(action)")
            
            if action == "SUMSUB_LAUNCH_SDK",
               let access_token = jsonDict["access_token"] as? String {
                
                currentToken = access_token
                
                let initialEmail = jsonDict["initial_email"] as? String
                let initialPhone = jsonDict["initial_phone"] as? String
                
                launchSdk(accessToken: access_token, vc: viewController, initialEmail: initialEmail, initialPhone: initialPhone)
                
            }
            else if (action == "SUMSUB_NEW_TOKEN") {
                
                if let access_token = jsonDict["access_token"] as? String {
                    
                    currentToken = access_token
                }
            }
            
        }
        
        
    }
    
    public func launchSdk( accessToken: String, vc: UIViewController,  initialEmail: String?,  initialPhone: String? )
    {
        let sdk = SNSMobileSDK(
            accessToken: accessToken
        )
        
        sdk.initialEmail = initialEmail ?? ""
        
        sdk.initialPhone = initialPhone ?? ""
        
        sdk.isAnalyticsEnabled = false
        
        sdk.locale = Locale.current.identifier
        
        sdk.tokenExpirationHandler { [self] (onComplete) in
            
            self.respondSuccess("LAUNCH_SDK", data: ["tokenExpired": "true"])
            
            Task {
                self.getToken { id, error in
                    
                    onComplete(self.currentToken)
                }
            }
        }
        
        sdk.onStatusDidChange { (sdk, prevStatus) in
            
            print("AAAAA ::: onStatusDidChange: [\(sdk.description(for: prevStatus))] -> [\(sdk.description(for: sdk.status))]")
            
            switch sdk.status {
                
            case .ready:
                // Technically .ready couldn't ever be passed here, since the callback has been set after `status` became .ready
               // self.sendStatus("ready")
                break
            case .failed:
               // self.sendStatus("failed_unknown")
                print("failReason: [\(sdk.description(for: sdk.failReason))] - \(sdk.verboseStatus)")
                break
            case .initial:
               // self.sendStatus("initial")
                print("No verification steps are passed yet")
                break
            case .incomplete:
                //self.sendStatus("incomplete")
                print("Some but not all of the verification steps have been passed over")
                break
            case .pending:
               // self.sendStatus("pending")
                print("Verification is pending")
                break
            case .temporarilyDeclined:
                //self.sendStatus("temporarily_declined")
                print("Applicant has been temporarily declined")
                break
            case .finallyRejected:
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    self.sendStatus("finally_rejected", approved: false)
                }
                print("Applicant has been finally rejected")
                break
            case .approved:
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    self.sendStatus("approved", approved: true)
                }
                print("Applicant has been approved")
                break
            case .actionCompleted:
                //self.sendStatus("action_completed")
                print("Applicant action has been completed")
                break
            }
        }
        
        //        sdk.present(from: vc)
        
        
        
        sdk.present()
    }
    
    private func sendStatus(_ idvStatus: String, approved: Bool? = nil) {
        
        var data = [
            "idvStatus": idvStatus,
        ]
        
        if let safeApproved = approved {
            data["approved"] = safeApproved ? "true" : "false"
        }
        
        self.respondSuccess("LAUNCH_SDK", data: data)
    }
    
    private func getToken(onComplete: @escaping (_ id: String?, _ error: Error?) -> ()) {
        
        
        print("AAAAA ::: sdk.tokenExpira67tionHandler")
        
        self.expiredToken = self.currentToken
        
        while self.expiredToken == self.currentToken {
            
            print("AAAAA ::: sdk.tokenExpira67tionHandler :::::  checking for new token")
            
            do {
                sleep(2)
            }
        }
        
        
        print("onComplete :: \(String(describing: self.currentToken))")
        
        self.expiredToken = nil
        
        onComplete(self.currentToken, nil)
    }
    
    private func respondSuccess(_ jsCallback: String, data: [String : Any]) {
                
        if let delegate = self.delegate {
            print("AAAA :::: Line 197")
            delegate.onSuccess("SUMSUB_\(jsCallback)_CB", data: data)
        }
    }
    
    private func respondFailure(_ jsCallback: String, reasonCode: String, description: String) {
        if let delegate = self.delegate {
            delegate.onFailure("SUMSUB_\(jsCallback)_CB", reasonCode: reasonCode, description: description)
        }
    }
    
}
