import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../services/functions_service.dart';
import '../models/deployment.dart';
import '../widgets/deployment_card.dart';

class DeploymentsScreen extends StatelessWidget {
  final String apiKey;

  const DeploymentsScreen({super.key, required this.apiKey});

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final functionsService = Provider.of<FunctionsService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Deployments'),
      ),
      body: StreamBuilder<List<Deployment>>(
        stream: firestoreService.listenToDeployments(apiKey),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final deployments = snapshot.data ?? [];

          if (deployments.isEmpty) {
            return const Center(
              child: Text('No deployments yet. Upload a file to get started!'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: deployments.length,
            itemBuilder: (context, index) {
              final deployment = deployments[index];
              return DeploymentCard(
                deployment: deployment,
                onDelete: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Deployment'),
                      content: const Text(
                        'Are you sure you want to delete this deployment?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    try {
                      await functionsService.deleteDeployment(
                        apiKey,
                        deployment.id,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Deployment deleted'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to delete: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

