import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_apple_pay/flutter_apple_pay.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  Future<void> makePayment() async {
    PaymentItem paymentItems = PaymentItem(label: 'Label', amount: 51.0);
    const networks = [PaymentNetwork.visa, PaymentNetwork.mastercard];
    if(!await FlutterApplePay.canMakePayment(paymentNetworks: networks)) {
      print('Payment not supported.');
      return;
    }
    final payment = await FlutterApplePay.makePayment(
      countryCode: "US",
      currencyCode: "USD",
      paymentNetworks: networks,
      merchantIdentifier: "merchant.stripeApplePayTest",
      paymentItems: [paymentItems],
    );
    if(payment == null) {
      print('Payment cancelled.');
      return;
    }
    print(payment);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Apple Pay Test'),
        ),
        body: Center(
          child:
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
                Text('Waiting for Apple Pay modal.'),
                RaisedButton(
                  child: Text('Call payment'),
                  onPressed: () => makePayment(),
                )
            ],
          )
        ),
      ),
    );
  }
}
