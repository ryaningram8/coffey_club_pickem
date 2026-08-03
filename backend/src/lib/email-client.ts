import { Resend } from 'resend';
import { logger } from './logger';

export interface EmailPayload {
  to: string;
  subject: string;
  html: string;
}

let client: Resend | null | undefined;

/**
 * Lazily builds the Resend client from RESEND_API_KEY. Returns null
 * (cached) when unset, so callers can fail soft — email is a convenience
 * channel, not a hard dependency for using the app.
 */
function getClient(): Resend | null {
  if (client !== undefined) return client;

  const apiKey = process.env.RESEND_API_KEY;
  if (!apiKey) {
    logger.warn('RESEND_API_KEY not set — email notifications disabled');
    client = null;
    return client;
  }

  client = new Resend(apiKey);
  return client;
}

/**
 * Sends a transactional email. No-ops when Resend isn't configured.
 * FROM_EMAIL defaults to Resend's shared sandbox sender, which works
 * without a verified domain for local/dev use.
 */
export async function sendEmail(payload: EmailPayload): Promise<void> {
  const resend = getClient();
  if (!resend) return;

  try {
    await resend.emails.send({
      from: process.env.EMAIL_FROM || 'Coffey Club Pickem <onboarding@resend.dev>',
      to: payload.to,
      subject: payload.subject,
      html: payload.html,
    });
  } catch (err) {
    logger.error({ err, to: payload.to }, 'Email send failed');
  }
}
