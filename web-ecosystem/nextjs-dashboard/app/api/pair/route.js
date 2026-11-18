import { NextResponse } from 'next/server';
import { hashSecret, newSecret } from '../../../lib/auth';
import { supabaseAdmin } from '../../../lib/supabaseAdmin';

const PAIRING_TTL_MS = 10 * 60 * 1000;

async function removeExpiredSessions() {
  const { error } = await supabaseAdmin
    .from('pairing_sessions')
    .delete()
    .lt('expires_at', new Date().toISOString());
  if (error) console.error('Failed to clean up expired pairing sessions:', error);
}

export async function POST() {
  await removeExpiredSessions();

  const qrSecret = newSecret();
  const pollSecret = newSecret();

  const { data, error } = await supabaseAdmin
    .from('pairing_sessions')
    .insert({
      qr_secret_hash: hashSecret(qrSecret),
      poll_secret_hash: hashSecret(pollSecret),
      expires_at: new Date(Date.now() + PAIRING_TTL_MS).toISOString(),
    })
    .select('id, expires_at')
    .single();

  if (error) {
    console.error('Failed to create pairing session:', error);
    return NextResponse.json({ error: 'Could not start pairing.' }, { status: 500 });
  }

  return NextResponse.json({
    sessionId: data.id,
    qrSecret,
    pollSecret,
    expiresAt: data.expires_at,
  });
}
