import { cert, initializeApp, type App } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import { logger } from './logger';

export interface PushPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
}

export interface PushResult {
  successCount: number;
  invalidTokens: string[];
}

let app: App | null | undefined;

/**
 * Lazily initializes the Firebase Admin app from FIREBASE_SERVICE_ACCOUNT_JSON.
 * Returns null (cached) when the env var is unset or unparsable, so callers
 * can fail soft — push notifications are a convenience, not a hard
 * dependency for using the app.
 */
function getApp(): App | null {
  if (app !== undefined) return app;

  const json = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!json) {
    logger.warn('FIREBASE_SERVICE_ACCOUNT_JSON not set — push notifications disabled');
    app = null;
    return app;
  }

  try {
    const serviceAccount = JSON.parse(json);
    app = initializeApp({ credential: cert(serviceAccount) });
  } catch (err) {
    logger.error({ err }, 'Failed to initialize Firebase Admin — push notifications disabled');
    app = null;
  }
  return app;
}

/**
 * Sends a push notification to up to 500 device tokens (FCM multicast limit).
 * Returns which tokens were rejected as invalid/unregistered so the caller
 * can prune them from the user's stored token list. No-ops (empty result)
 * when Firebase isn't configured or there are no tokens to send to.
 */
export async function sendPushNotification(
  tokens: string[],
  payload: PushPayload,
): Promise<PushResult> {
  if (tokens.length === 0) return { successCount: 0, invalidTokens: [] };

  const firebaseApp = getApp();
  if (!firebaseApp) return { successCount: 0, invalidTokens: [] };

  try {
    const response = await getMessaging(firebaseApp).sendEachForMulticast({
      tokens,
      notification: { title: payload.title, body: payload.body },
      data: payload.data,
    });

    const invalidTokens: string[] = [];
    response.responses.forEach((r, i) => {
      if (
        !r.success &&
        (r.error?.code === 'messaging/registration-token-not-registered' ||
          r.error?.code === 'messaging/invalid-registration-token')
      ) {
        invalidTokens.push(tokens[i]);
      }
    });

    return { successCount: response.successCount, invalidTokens };
  } catch (err) {
    logger.error({ err }, 'FCM push send failed');
    return { successCount: 0, invalidTokens: [] };
  }
}
