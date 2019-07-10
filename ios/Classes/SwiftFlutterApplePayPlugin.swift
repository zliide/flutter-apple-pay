import Flutter
import UIKit
import Foundation
import PassKit

typealias AuthorizationCompletion = (_ payment: NSDictionary?) -> Void
typealias AuthorizationViewControllerDidFinish = (_ error : NSDictionary) -> Void

public class SwiftFlutterApplePayPlugin: NSObject, FlutterPlugin, PKPaymentAuthorizationViewControllerDelegate {
    var authorizationCompletion : AuthorizationCompletion!
    var authorizationViewControllerDidFinish : AuthorizationViewControllerDidFinish!
    var pkrequest = PKPaymentRequest()
    var flutterResult: FlutterResult?;
    
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_apple_pay", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(SwiftFlutterApplePayPlugin(), channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if #available(iOS 11, *) {
            handle11(_:call, result:result)
        } else {
            if call.method == "canMakePayment" {
                result(false)
            }
            else if call.method == "makePayment" {
                let error: NSDictionary = ["message": "User not added some cards", "code": "404"]
                result(error)
            }
        }
    }
    
    @available(iOS 11, *)
    public func handle11(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as! NSDictionary
        guard let paymentNeworks = arguments["paymentNetworks"] as? [String] else {return}
        var payments: [PKPaymentNetwork] = []

        paymentNeworks.forEach {
            
            guard let paymentType = PaymentSystem(rawValue: $0) else {
                assertionFailure("No payment type found")
                return
            }
            
            payments.append(paymentType.paymentNetwork)
        }

        if call.method == "canMakePayment" {
            result(PKPaymentAuthorizationViewController.canMakePayments(usingNetworks: payments))
        }
        else if call.method == "makePayment" {
            flutterResult = result;
            let parameters = NSMutableDictionary()
            var contactFields: Set<PKContactField> = []
            var items = [PKPaymentSummaryItem]()
            var totalPrice:Double = 0.0
            
            guard let countryCode = arguments["countryCode"] as? String else {return}
            guard let currencyCode = arguments["currencyCode"] as? String else {return}
            guard let fields = arguments["contactFields"] as? [String] else {return}

            guard let paymentItems = arguments["paymentItems"] as? [NSDictionary] else {return}
            guard let merchantIdentifier = arguments["merchantIdentifier"] as? String else {return}
            
            for dictionary in paymentItems {
                guard let label = dictionary["label"] as? String else {return}
                guard let price = dictionary["amount"] as? Double else {return}
                let type = PKPaymentSummaryItemType.final
                
                totalPrice += price
                
                items.append(PKPaymentSummaryItem(label: label, amount: NSDecimalNumber(floatLiteral: price), type: type))
            }
            
            let total = PKPaymentSummaryItem(label: "Total", amount: NSDecimalNumber(floatLiteral:totalPrice), type: .final)
            items.append(total)
            
            fields.forEach {
                
                guard let field = ContactField(rawValue: $0) else {
                    assertionFailure("No contact field found")
                    return
                }
                
                contactFields.insert(field.pkField)
            }

            parameters["paymentNetworks"] = payments
            parameters["requiredShippingContactFields"] = contactFields
            parameters["merchantCapabilities"] = PKMerchantCapability.capability3DS // optional
            
            parameters["merchantIdentifier"] = merchantIdentifier
            parameters["countryCode"] = countryCode
            parameters["currencyCode"] = currencyCode
            
            parameters["paymentSummaryItems"] = items
            
            makePaymentRequest(parameters: parameters,  authCompletion: authorizationCompletion, authControllerCompletion: authorizationViewControllerDidFinish)
        }
    }
    
    func authorizationCompletion(_ payment: NSDictionary?) {
        // success
//        var result: [String: Any] = [:]
//
//        result["token"] = payment.token.transactionIdentifier
//        result["billingContact"] = payment.billingContact?.emailAddress
//        result["shippingContact"] = payment.shippingContact?.emailAddress
//        result["shippingMethod"] = payment.shippingMethod?.detail
//
        if (flutterResult != nil) {
            flutterResult?(payment)
            flutterResult = nil
        }
    }
    
    func authorizationViewControllerDidFinish(_ error : NSDictionary) {
        if (flutterResult != nil) {
            //error
            flutterResult?(error)
            flutterResult = nil
        }
    }
    
    @available(iOS 11, *)
    enum PaymentSystem: String {
        case visa
        case mastercard
        case amex
        case quicPay
        case chinaUnionPay
        case discover
        case interac
        case privateLabel
        
        var paymentNetwork: PKPaymentNetwork {
            
            switch self {
            case .mastercard: return PKPaymentNetwork.masterCard
            case .visa: return PKPaymentNetwork.visa
            case .amex: return PKPaymentNetwork.amex
            case .quicPay: return PKPaymentNetwork.quicPay
            case .chinaUnionPay: return PKPaymentNetwork.chinaUnionPay
            case .discover: return PKPaymentNetwork.discover
            case .interac: return PKPaymentNetwork.interac
            case .privateLabel: return PKPaymentNetwork.privateLabel
            }
        }
    }

    @available(iOS 11, *)
    enum ContactField: String {
        case name
        case postalAddress
        case emailAddress
        case phoneNumber
        
        var pkField: PKContactField {
            
            switch self {
                case .name: return PKContactField.name
                case .postalAddress: return PKContactField.postalAddress
                case .emailAddress: return PKContactField.emailAddress
                case .phoneNumber: return PKContactField.phoneNumber
            }
        }
    }
    
    @available(iOS 11, *)
    func makePaymentRequest(parameters: NSDictionary, authCompletion: @escaping AuthorizationCompletion, authControllerCompletion: @escaping AuthorizationViewControllerDidFinish) {
        guard let paymentNetworks               = parameters["paymentNetworks"]                 as? [PKPaymentNetwork] else {return}
        guard let requiredShippingContactFields = parameters["requiredShippingContactFields"]   as? Set<PKContactField> else {return}
        let merchantCapabilities : PKMerchantCapability = parameters["merchantCapabilities"]    as? PKMerchantCapability ?? .capability3DS
        
        guard let merchantIdentifier            = parameters["merchantIdentifier"]              as? String else {return}
        guard let countryCode                   = parameters["countryCode"]                     as? String else {return}
        guard let currencyCode                  = parameters["currencyCode"]                    as? String else {return}
        
        guard let paymentSummaryItems           = parameters["paymentSummaryItems"]             as? [PKPaymentSummaryItem] else {return}
        
        authorizationCompletion = authCompletion
        authorizationViewControllerDidFinish = authControllerCompletion
        
        // Cards that should be accepted
        if PKPaymentAuthorizationViewController.canMakePayments(usingNetworks: paymentNetworks) {
            
            pkrequest.merchantIdentifier = merchantIdentifier
            pkrequest.countryCode = countryCode
            pkrequest.currencyCode = currencyCode
            pkrequest.supportedNetworks = paymentNetworks
            pkrequest.requiredShippingContactFields = requiredShippingContactFields
            pkrequest.merchantCapabilities = merchantCapabilities
            
            pkrequest.paymentSummaryItems = paymentSummaryItems
            
            let authorizationViewController = PKPaymentAuthorizationViewController(paymentRequest: pkrequest)
            
            if let viewController = authorizationViewController {
                viewController.delegate = self
                guard let currentViewController = UIApplication.shared.keyWindow?.topMostViewController() else {
                    return
                }
                currentViewController.present(viewController, animated: true)
            }
        } else {
            let error: NSDictionary = ["message": "User not added some cards", "code": "404"]
            authControllerCompletion(error)
         }

        return
    }
    
    @available(iOS 11, *)
    public func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment, handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        let paymentMethod: NSMutableDictionary = [
            "type": methodTypeToString(payment.token.paymentMethod.type),
        ]
        if let displayName = payment.token.paymentMethod.displayName {
            paymentMethod["displayName"] = displayName
        }
        if let network = networkToString(payment.token.paymentMethod.network) {
            paymentMethod["network"] = network
        }
        let token: NSDictionary = [
            "paymentMethod": paymentMethod,
            "transactionIdentifier": payment.token.transactionIdentifier,
            "paymentData": payment.token.paymentData.base64EncodedString(),
        ]
        let result: NSDictionary = [
            "token": token,
        ]
        authorizationCompletion(result)
        completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
    }
    
    @available(iOS 11, *)
    private func methodTypeToString(_ method: PKPaymentMethodType) -> String {
        switch method {
        case .debit: return "debit"
        case .credit: return "credit"
        case .prepaid: return "prepaid"
        case .store: return "store"
        case .unknown: return "unknown"
        }
    }
    @available(iOS 11, *)
    private func networkToString(_ network: PKPaymentNetwork?) -> String? {
        switch network {
        case PKPaymentNetwork.masterCard: return "masterCard"
        case PKPaymentNetwork.visa: return "visa"
        case PKPaymentNetwork.amex: return "amex"
        case PKPaymentNetwork.quicPay: return "quicPay"
        case PKPaymentNetwork.chinaUnionPay: return "chinaUnionPay"
        case PKPaymentNetwork.discover: return "discover"
        case PKPaymentNetwork.interac: return "interac"
        case PKPaymentNetwork.privateLabel: return "privateLabel"
        default: return nil
        }
    }
    

    public func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
        // Dismiss the Apple Pay UI
        guard let currentViewController = UIApplication.shared.keyWindow?.topMostViewController() else {
            return
        }
        currentViewController.dismiss(animated: true, completion: nil)
        authorizationCompletion(nil)
    }
    
    @available(iOS 11, *)
    func makePaymentSummaryItems(itemsParameters: Array<Dictionary <String, Any>>) -> [PKPaymentSummaryItem]? {
        var items = [PKPaymentSummaryItem]()
        var totalPrice:Decimal = 0.0
        
        for dictionary in itemsParameters {
            
            guard let label = dictionary["label"] as? String else {return nil}
            guard let amount = dictionary["amount"] as? NSDecimalNumber else {return nil}
            guard let type = dictionary["type"] as? PKPaymentSummaryItemType else {return nil}
            
            totalPrice += amount.decimalValue
            
            items.append(PKPaymentSummaryItem(label: label, amount: amount, type: type))
        }
        
        let total = PKPaymentSummaryItem(label: "Total", amount: NSDecimalNumber(decimal:totalPrice), type: .final)
        items.append(total)
        print(items)
        return items
    }
    
}

extension UIWindow {
    func topMostViewController() -> UIViewController? {
        guard let rootViewController = self.rootViewController else {
            return nil
        }
        return topViewController(for: rootViewController)
    }
    
    func topViewController(for rootViewController: UIViewController?) -> UIViewController? {
        guard let rootViewController = rootViewController else {
            return nil
        }
        guard let presentedViewController = rootViewController.presentedViewController else {
            return rootViewController
        }
        switch presentedViewController {
        case is UINavigationController:
            let navigationController = presentedViewController as! UINavigationController
            return topViewController(for: navigationController.viewControllers.last)
        case is UITabBarController:
            let tabBarController = presentedViewController as! UITabBarController
            return topViewController(for: tabBarController.selectedViewController)
        default:
            return topViewController(for: presentedViewController)
        }
    }
}
