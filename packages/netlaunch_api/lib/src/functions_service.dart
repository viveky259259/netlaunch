import 'package:cloud_functions/cloud_functions.dart';
import 'package:netlaunch_core/netlaunch_core.dart';

class FunctionsService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<List<Deployment>> listDeployments(String apiKey, {int? limit}) async {
    try {
      final callable = _functions.httpsCallable('listDeploymentsFunction');
      final result = await callable.call({
        'apiKey': apiKey,
        if (limit != null) 'limit': limit,
      });

      final data = result.data as Map<String, dynamic>;
      final deployments = (data['deployments'] as List)
          .map((d) => Deployment.fromMap(d as Map<String, dynamic>, d['id'] as String))
          .toList();

      return deployments;
    } catch (e) {
      throw Exception('Failed to list deployments: $e');
    }
  }

  Future<void> deleteDeployment(String apiKey, String deploymentId) async {
    try {
      final callable = _functions.httpsCallable('deleteDeploymentFunction');
      await callable.call({
        'apiKey': apiKey,
        'deploymentId': deploymentId,
      });
    } catch (e) {
      throw Exception('Failed to delete deployment: $e');
    }
  }

  Future<Deployment> getDeploymentStatus(String apiKey, String deploymentId) async {
    try {
      final callable = _functions.httpsCallable('getDeploymentStatusFunction');
      final result = await callable.call({
        'apiKey': apiKey,
        'deploymentId': deploymentId,
      });

      final data = result.data as Map<String, dynamic>;
      return Deployment.fromMap(data, data['id'] as String);
    } catch (e) {
      throw Exception('Failed to get deployment status: $e');
    }
  }

  Future<String> generateApiKey() async {
    try {
      final callable = _functions.httpsCallable('generateApiKeyFunctionCallable');
      final result = await callable.call({});

      final data = result.data as Map<String, dynamic>;
      return data['apiKey'] as String;
    } catch (e) {
      throw Exception('Failed to generate API key: $e');
    }
  }

  /// List deployments for the authenticated user (requires login)
  Future<List<Deployment>> listUserDeployments({int? limit}) async {
    try {
      final callable = _functions.httpsCallable('listUserDeploymentsFunction');
      final result = await callable.call({
        if (limit != null) 'limit': limit,
      });

      final data = result.data as Map<String, dynamic>;
      final deployments = (data['deployments'] as List)
          .map((d) => Deployment.fromMap(d as Map<String, dynamic>, d['id'] as String))
          .toList();

      return deployments;
    } catch (e) {
      throw Exception('Failed to list deployments: $e');
    }
  }

  /// Fetch analytics for a deployment
  Future<DeploymentAnalytics> getDeploymentAnalytics(
    String deploymentId, {
    int days = 30,
  }) async {
    try {
      final callable =
          _functions.httpsCallable('getDeploymentAnalyticsFunction');
      final result = await callable.call({
        'deploymentId': deploymentId,
        'days': days,
      });

      final data = result.data as Map<String, dynamic>;
      return DeploymentAnalytics.fromMap(data);
    } catch (e) {
      throw Exception('Failed to get deployment analytics: $e');
    }
  }

  /// Save Firebase config for self-hosted deployments
  Future<Map<String, dynamic>> saveFirebaseConfig(String serviceAccountJson) async {
    try {
      final callable = _functions.httpsCallable('saveFirebaseConfigFunction');
      final result = await callable.call({
        'serviceAccountJson': serviceAccountJson,
      });
      return result.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to save Firebase config: $e');
    }
  }

  /// Get user's saved Firebase config (returns projectId, clientEmail — not the key)
  Future<Map<String, dynamic>> getFirebaseConfig() async {
    try {
      final callable = _functions.httpsCallable('getFirebaseConfigFunction');
      final result = await callable.call({});
      return result.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to get Firebase config: $e');
    }
  }

  /// Delete user's saved Firebase config
  Future<void> deleteFirebaseConfig() async {
    try {
      final callable = _functions.httpsCallable('deleteFirebaseConfigFunction');
      await callable.call({});
    } catch (e) {
      throw Exception('Failed to delete Firebase config: $e');
    }
  }

  /// Delete a deployment for the authenticated user (requires login)
  Future<void> deleteUserDeployment(String deploymentId) async {
    try {
      final callable = _functions.httpsCallable('deleteUserDeploymentFunction');
      await callable.call({
        'deploymentId': deploymentId,
      });
    } catch (e) {
      throw Exception('Failed to delete deployment: $e');
    }
  }
}

