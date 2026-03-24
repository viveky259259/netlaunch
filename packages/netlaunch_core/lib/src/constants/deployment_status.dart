/// Deployment status values used across the system.
class DeploymentStatus {
  static const String pending = 'pending';
  static const String deploying = 'deploying';
  static const String success = 'success';
  static const String failed = 'failed';

  static bool isTerminal(String status) =>
      status == success || status == failed;
}
