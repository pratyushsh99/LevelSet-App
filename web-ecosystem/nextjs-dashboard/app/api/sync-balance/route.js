import { NextResponse } from 'next/server';
import { requireDevice } from '../../../lib/auth';
import { supabaseAdmin } from '../../../lib/supabaseAdmin';
import { badRequest, INVALID_JSON, MAX_BALANCE_SECONDS, readJson } from '../../../lib/validate';

export async function POST(request) {
  const { device, error: authError } = await requireDevice(request, 'balance:write');
  if (authError) return authError;

  const body = await readJson(request);
  if (!body) return badRequest(INVALID_JSON);

  const { remainingSeconds } = body;
  if (typeof remainingSeconds !== 'number' || !Number.isFinite(remainingSeconds) || remainingSeconds < 0) {
    return badRequest('remainingSeconds must be a non-negative number.');
  }

  const { data, error } = await supabaseAdmin
    .from('profiles')
    .update({ remaining_seconds: Math.min(MAX_BALANCE_SECONDS, Math.floor(remainingSeconds)) })
    .eq('id', device.profileId)
    .select('id');

  if (error) {
    console.error('Failed to sync balance:', error);
    return NextResponse.json({ error: 'Could not sync balance.' }, { status: 500 });
  }
  if (!data || data.length === 0) {
    return NextResponse.json({ error: 'Profile not found.' }, { status: 404 });
  }

  return NextResponse.json({ synced: true });
}
