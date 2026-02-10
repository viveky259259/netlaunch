import * as admin from 'firebase-admin';

const db = admin.firestore();

function classifyDevice(width: number): string {
  if (width < 768) return 'mobile';
  if (width < 1024) return 'tablet';
  return 'desktop';
}

export async function trackPageViewHandler(
  req: import('express').Request,
  res: import('express').Response
): Promise<void> {
  // CORS — allow deployed sites
  const origin = req.headers.origin || '';
  const allowed =
    origin.endsWith('.web.app') ||
    origin.endsWith('.firebaseapp.com') ||
    origin === '';

  if (!allowed) {
    res.status(403).end();
    return;
  }

  res.set('Access-Control-Allow-Origin', origin || '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).end();
    return;
  }

  // Parse URL-encoded body (sent as text/plain from sendBeacon)
  const body = typeof req.body === 'string' ? req.body : '';
  const params = new URLSearchParams(body);

  const siteId = params.get('d') || '';
  const pagePath = params.get('p') || '/';
  const viewportWidth = parseInt(params.get('w') || '0', 10);

  if (!siteId) {
    res.status(400).end();
    return;
  }

  const today = new Date().toISOString().slice(0, 10); // YYYY-MM-DD
  const device = classifyDevice(viewportWidth);
  const encodedPath = encodeURIComponent(pagePath).replace(/%/g, '_');

  const batch = db.batch();

  // 1. Site total
  const siteRef = db.collection('pageViews').doc(siteId);
  batch.set(
    siteRef,
    { totalViews: admin.firestore.FieldValue.increment(1) },
    { merge: true }
  );

  // 2. Daily counter
  const dailyRef = siteRef.collection('daily').doc(today);
  batch.set(
    dailyRef,
    {
      views: admin.firestore.FieldValue.increment(1),
      [`devices.${device}`]: admin.firestore.FieldValue.increment(1),
    },
    { merge: true }
  );

  // 3. Per-page counter
  const pageRef = siteRef.collection('pages').doc(encodedPath);
  batch.set(
    pageRef,
    {
      path: pagePath,
      views: admin.firestore.FieldValue.increment(1),
    },
    { merge: true }
  );

  try {
    await batch.commit();
  } catch (err) {
    console.error('trackPageView batch write failed:', err);
  }

  res.status(204).end();
}
