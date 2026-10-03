import { NextResponse } from 'next/server';
import { supabaseAdmin } from '../../../../lib/supabaseAdmin';
import { badRequest, INVALID_USER_ID, isValidPairingCode, isValidUserId, readJson } from '../../../../lib/validate';

export async function POST(request) {
  const body = await readJson(request);
  if (!body) return badRequest('Invalid JSON body.');

  const { deviceUserId } = body;
  const pairingCode = typeof body.pairingCode === 'string' ? body.pairingCode.trim().toUpperCase() : null;
  if (!isValidPairingCode(pairingCode)) return badRequest('pairingCode must be an 8-character code.');
  if (!isValidUserId(deviceUserId)) return badRequest(INVALID_USER_ID.replace('userId', 'deviceUserId'));
  if (deviceUserId.toLowerCase().startsWith('pending-')) return badRequest('deviceUserId is reserved.');

  const { data: profile, error: fetchError } = await supabaseAdmin
    .from('profiles')
    .select('id, pairing_expires_at')
    .eq('pairing_code', pairingCode)
    .single();

  if (fetchError || !profile) {
    return NextResponse.json({ error: 'Pairing code not found.' }, { status: 404 });
  }

  if (!profile.pairing_expires_at || new Date(profile.pairing_expires_at) < new Date()) {
    return NextResponse.json({ error: 'Pairing code has expired.' }, { status: 410 });
  }

  const { data: existingProfile, error: existingError } = await supabaseAdmin
    .from('profiles')
    .select('id')
    .ilike('user_id', deviceUserId)
    .maybeSingle();

  if (existingError) {
    console.error('Failed to look up device profile:', existingError);
    return NextResponse.json({ error: 'Could not confirm pairing.' }, { status: 500 });
  }

  const update = existingProfile
    ? { pairing_code: null, pairing_expires_at: null, resolved_user_id: deviceUserId }
    : { user_id: deviceUserId, pairing_code: null, pairing_expires_at: null };

  const { data: claimed, error: updateError } = await supabaseAdmin
    .from('profiles')
    .update(update)
    .eq('id', profile.id)
    .eq('pairing_code', pairingCode)
    .select('id');

  if (updateError) {
    console.error('Failed to confirm pairing:', updateError);
    return NextResponse.json({ error: 'Could not confirm pairing.' }, { status: 500 });
  }
  if (!claimed || claimed.length === 0) {
    return NextResponse.json({ error: 'Pairing code has already been used.' }, { status: 409 });
  }

  return NextResponse.json(existingProfile ? { paired: true, alreadyPaired: true } : { paired: true });
}
