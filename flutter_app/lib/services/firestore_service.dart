import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/deployment.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Listen to deployments for a specific user by userId
  Stream<List<Deployment>> listenToDeploymentsByUserId(String userId) {
    return _firestore
        .collection('deployments')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Deployment.fromMap(data, doc.id);
      }).toList();
    });
  }

  Future<Deployment?> getDeployment(String deploymentId) async {
    try {
      final doc = await _firestore.collection('deployments').doc(deploymentId).get();
      if (doc.exists) {
        return Deployment.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get deployment: $e');
    }
  }
}

