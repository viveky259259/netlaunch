import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutterkit/kit/kit.dart';
import '../services/firestore_service.dart';
import '../services/functions_service.dart';
import '../models/deployment.dart';
import '../widgets/deployment_card.dart';

class DeploymentsScreen extends StatelessWidget {
  final String userId;
  final String apiKey;

  const DeploymentsScreen(
      {super.key, required this.userId, required this.apiKey});

  @override
  Widget build(BuildContext context) {
    final firestoreService =
        Provider.of<FirestoreService>(context, listen: false);
    final functionsService =
        Provider.of<FunctionsService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Deployments'),
      ),
      body: StreamBuilder<List<Deployment>>(
        stream: firestoreService.listenToDeploymentsByUserId(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: UkSpinner());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: UkAlert(
                  message: 'Error: ${snapshot.error}',
                  type: UkAlertType.danger,
                  dismissible: false,
                ),
              ),
            );
          }

          final deployments = snapshot.data ?? [];

          if (deployments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.web_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  UkHeading('No deployments yet',
                      level: 5, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    'Upload a file to get started!',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
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
                        UkButton(
                          label: 'Cancel',
                          variant: UkButtonVariant.text,
                          onPressed: () => Navigator.pop(context, false),
                        ),
                        UkButton(
                          label: 'Delete',
                          variant: UkButtonVariant.primary,
                          icon: Icons.delete,
                          onPressed: () => Navigator.pop(context, true),
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
