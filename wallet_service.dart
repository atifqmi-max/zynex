import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WalletService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<double> getBalance() async {
    var doc = await _firestore.collection('wallets').doc(_auth.currentUser!.uid).get();
    if (doc.exists) return doc['balance']?.toDouble() ?? 0.0;
    return 0.0;
  }

  Future<void> sendMoney(String toUid, double amount) async {
    String fromUid = _auth.currentUser!.uid;
    var fromDoc = _firestore.collection('wallets').doc(fromUid);
    var toDoc = _firestore.collection('wallets').doc(toUid);

    await _firestore.runTransaction((transaction) async {
      var fSnap = await transaction.get(fromDoc);
      var tSnap = await transaction.get(toDoc);

      double fromBalance = fSnap['balance']?.toDouble() ?? 0.0;
      double toBalance = tSnap.exists ? tSnap['balance']?.toDouble() ?? 0.0 : 0.0;

      if (fromBalance < amount) throw Exception("Insufficient balance");

      transaction.update(fromDoc, {'balance': fromBalance - amount});
      transaction.set(toDoc, {'balance': toBalance + amount}, SetOptions(merge: true));

      // Transaction history
      transaction.set(_firestore.collection('transactions').doc(), {
        'from': fromUid,
        'to': toUid,
        'amount': amount,
        'timestamp': FieldValue.serverTimestamp()
      });
    });

    notifyListeners();
  }

  Stream<QuerySnapshot> getTransactions() {
    return _firestore.collection('transactions')
        .where('from', isEqualTo: _auth.currentUser!.uid)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
}
