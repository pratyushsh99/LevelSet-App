import { NextResponse } from 'next/server';
import { randomBytes, randomUUID } from 'crypto';
import { supabaseAdmin } from '../../../lib/supabaseAdmin';

const PAIRING_TTL_MS = 10 * 60 * 1000;
const ABANDONED_AFTER_MS = 60 * 60 * 1000;

function generatePairingCode() {
  return randomBytes(4).toString('hex').toUpperCase();
}

async function removeAbandonedPairings() {
  const cutoff = new Date(Date.now() - ABANDONED_AFTER_MS).toISOString();
  const { error } = await supabaseAdmin
    .from('profiles')
    .delete()
    .like('user_id', 'pending-%')
    .is('resolved_user_id', null)
    .lt('pairing_expires_at', cutoff);
  if (error) console.error('Failed to clean up abandoned pairings:', error);
}

export async function POST() {
  await removeAbandonedPairings();

  const pairingExpiresAt = new Date(Date.now() + PAIRING_TTL_MS).toISOString();

  const { data, error } = await supabaseAdmin
    .from('profiles')
    .insert({
      user_id: `pending-${randomUUID()}`,
      remaining_seconds: 0,
      pairing_code: generatePairingCode(),
      pairing_expires_at: pairingExpiresAt,
    })
    .select('id, pairing_code, pairing_expires_at')
    .single();

  if (error) {
    console.error('Failed to create pairing code:', error);
    return NextResponse.json({ error: 'Could not create pairing code.' }, { status: 500 });
  }

  return NextResponse.json({
    profileId: data.id,
    pairingCode: data.pairing_code,
    expiresAt: data.pairing_expires_at,
  });
}
