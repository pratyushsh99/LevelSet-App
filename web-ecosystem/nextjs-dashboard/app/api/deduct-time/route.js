import { NextResponse } from 'next/server';
import { requireDevice } from '../../../lib/auth';
import { supabaseAdmin } from '../../../lib/supabaseAdmin';
import { badRequest, INVALID_JSON, isBoundedInteger, readJson } from '../../../lib/validate';

export async function POST(request) {
  const { device, error: authError } = await requireDevice(request, 'time:deduct');
  if (authError) return authError;

  const body = await readJson(request);
  if (!body) return badRequest(INVALID_JSON);

  const { seconds = 5 } = body;
  if (!isBoundedInteger(seconds, 1, 60)) return badRequest('seconds must be a whole number between 1 and 60.');

  const { data: profile, error: fetchError } = await supabaseAdmin
    .from('profiles')
    .select('remaining_seconds')
    .eq('id', device.profileId)
    .single();

  if (fetchError || !profile) {
    return NextResponse.json({ error: 'Profile not found.' }, { status: 404 });
  }

  const newBalance = Math.max(0, profile.remaining_seconds - seconds);

  const { data: updated, error: updateError } = await supabaseAdmin
    .from('profiles')
    .update({ remaining_seconds: newBalance })
    .eq('id', device.profileId)
    .select('remaining_seconds')
    .single();

  if (updateError) {
    console.error('Failed to deduct time:', updateError);
    return NextResponse.json({ error: 'Could not update balance.' }, { status: 500 });
  }

  return NextResponse.json({
    remainingSeconds: updated.remaining_seconds,
    locked: updated.remaining_seconds <= 0,
  });
}
