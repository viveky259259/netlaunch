import 'package:cloud_functions/cloud_functions.dart';
import '../models/deployment.dart';

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
}

