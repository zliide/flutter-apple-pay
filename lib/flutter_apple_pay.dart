import 'dart:async';

import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

class PaymentMethod {
  final String type;
  final String displayName;
  final String network;

  PaymentMethod(dynamic result)
      : type = result["type"],
        displayName = result["displayName"],
        network = result["network"];
}

class PaymentToken {
  final PaymentMethod paymentMethod;
  final String transactionIdentifier;
  final String paymentData;

  PaymentToken(dynamic result)
      : paymentMethod = PaymentMethod(result["paymentMethod"]),
        transactionIdentifier = result["transactionIdentifier"],
        paymentData = result["paymentData"];
}

class PaymentResult {
  final PaymentToken token;

  PaymentResult(dynamic result) : token = PaymentToken(result["token"]);
}

class FlutterApplePay {
  static const MethodChannel _channel =
      const MethodChannel('flutter_apple_pay');

  static Future<bool> canMakePayment({
    @required List<PaymentNetwork> paymentNetworks,
  }) async {
    final Map<String, Object> args = <String, dynamic>{
      'paymentNetworks':
          paymentNetworks.map((item) => item.toString().split('.')[1]).toList(),
    };
    try {
      return await _channel.invokeMethod('canMakePayment', args);
    } catch (e) {
      return false;
    }
  }

  static Future<PaymentResult> makePayment({
    @required String countryCode,
    @required String currencyCode,
    @required List<PaymentNetwork> paymentNetworks,
    @required String merchantIdentifier,
    @required List<PaymentItem> paymentItems,
    List<ContactField> contactFields,
  }) async {
    assert(countryCode != null);
    assert(currencyCode != null);
    assert(paymentNetworks != null);
    assert(merchantIdentifier != null);
    assert(paymentItems != null);

    final Map<String, Object> args = <String, dynamic>{
      'paymentNetworks':
          paymentNetworks.map((item) => item.toString().split('.')[1]).toList(),
      'countryCode': countryCode,
      'currencyCode': currencyCode,
      'paymentItems':
          paymentItems.map((PaymentItem item) => item._toMap()).toList(),
      'merchantIdentifier': merchantIdentifier,
      'contactFields': contactFields
              ?.map((item) => item.toString().split('.')[1])
              ?.toList() ??
          [],
    };
    final result = await _channel.invokeMethod('makePayment', args);
    if (result == null) {
      return null;
    }
    return PaymentResult(result);
  }
}

class PaymentItem {
  final String label;
  final double amount;

  PaymentItem({@required this.label, @required this.amount}) {
    assert(this.label != null);
    assert(this.amount != null);
  }

  Map<String, dynamic> _toMap() {
    Map<String, dynamic> map = new Map();
    map["label"] = this.label;
    map["amount"] = this.amount;
    return map;
  }
}

enum PaymentNetwork {
  visa,
  mastercard,
  amex,
  quicPay,
  chinaUnionPay,
  discover,
  interac,
  privateLabel
}

enum ContactField { name, postalAddress, emailAddress, phoneNumber }
