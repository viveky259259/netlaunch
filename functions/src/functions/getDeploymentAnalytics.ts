import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

const db = admin.firestore();

interface AnalyticsRequest {
  deploymentId: string;
  days?: number;
}

export const getDeploymentAnalytics = async (
  data: AnalyticsRequest,
  context: functions.https.CallableContext
): Promise<any> => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'You must be logged in to view analytics.'
    );
  }

  const { deploymentId, days: rawDays } = data;
  if (!deploymentId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'deploymentId is required.'
    );
  }

  const days = Math.min(Math.max(rawDays || 30, 1), 90);

  // Verify ownership
  const deploymentDoc = await db.collection('deployments').doc(deploymentId).get();
  if (!deploymentDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'Deployment not found.');
  }

  const deployment = deploymentDoc.data()!;
  if (deployment.userId !== context.auth.uid) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'You do not own this deployment.'
    );
  }

  const siteId = deployment.siteId;
  if (!siteId) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Deployment has no associated site.'
    );
  }

  // Date range
  const endDate = new Date();
  const startDate = new Date();
  startDate.setDate(startDate.getDate() - days);
  const startStr = startDate.toISOString().slice(0, 10);
  const endStr = endDate.toISOString().slice(0, 10);

  // Fetch in parallel: total, daily, top pages
  const [siteDoc, dailySnap, pagesSnap] = await Promise.all([
    db.collection('pageViews').doc(siteId).get(),
    db
      .collection('pageViews')
      .doc(siteId)
      .collection('daily')
      .where(admin.firestore.FieldPath.documentId(), '>=', startStr)
      .where(admin.firestore.FieldPath.documentId(), '<=', endStr)
      .orderBy(admin.firestore.FieldPath.documentId())
      .get(),
    db
      .collection('pageViews')
      .doc(siteId)
      .collection('pages')
      .orderBy('views', 'desc')
      .limit(10)
      .get(),
  ]);

  const totalViews = siteDoc.exists ? siteDoc.data()?.totalViews || 0 : 0;

  const dailyData = dailySnap.docs.map((doc) => ({
    date: doc.id,
    views: doc.data().views || 0,
    devices: doc.data().devices || {},
  }));

  const topPages = pagesSnap.docs.map((doc) => ({
    path: doc.data().path || decodeURIComponent(doc.id.replace(/_/g, '%')),
    views: doc.data().views || 0,
  }));

  return {
    siteId,
    totalViews,
    dailyData,
    topPages,
    period: { start: startStr, end: endStr, days },
  };
};
