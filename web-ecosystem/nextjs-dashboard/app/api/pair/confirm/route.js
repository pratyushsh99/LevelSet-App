import { NextResponse } from 'next/server';
import { bearerToken, hashSecret, isWellFormedSecret, issueDeviceToken, requireDevice } from '../../../../lib/auth';
import { supabaseAdmin } from '../../../../lib/supabaseAdmin';
import { badRequest, INVALID_JSON, readJson } from '../../../../lib/validate';

export async function POST(request) {
  const body = await readJson(request);
  if (!body) return badRequest(INVALID_JSON);
  if (!isWellFormedSecret(body.secret)) return badRequest('secret must be the value from the pairing QR code.');

  let profileId = null;
  if (bearerToken(request)) {
    const { device, error } = await requireDevice(request, 'pair:link');
    if (error) return error;
    profileId = device.profileId;
  }

  const { data: session, error: fetchError } = await supabaseAdmin
    .from('pairing_sessions')
    .select('id, profile_id, expires_at')
    .eq('qr_secret_hash', hashSecret(body.secret))
    .maybeSingle();

  if (fetchError) {
    console.error('Failed to look up pairing session:', fetchError);
    return NextResponse.json({ error: 'Could not confirm pairing.' }, { status: 500 });
  }
  if (!session) return NextResponse.json({ error: 'Pairing code not found.' }, { status: 404 });
  if (new Date(session.expires_at) < new Date()) {
    return NextResponse.json({ error: 'Pairing code has expired.' }, { status: 410 });
  }
  if (session.profile_id) {
    return NextResponse.json({ error: 'Pairing code has already been used.' }, { status: 409 });
  }

  let deviceToken = null;
  let createdProfileId = null;
  if (!profileId) {
    const { data: profile, error: createError } = await supabaseAdmin
      .from('profiles')
      .insert({ remaining_seconds: 0 })
      .select('id')
      .single();
    if (createError) {
      console.error('Failed to create profile:', createError);
      return NextResponse.json({ error: 'Could not confirm pairing.' }, { status: 500 });
    }
    createdProfileId = profileId = profile.id;
  }

  const { data: claimed, error: claimError } = await supabaseAdmin
    .from('pairing_sessions')
    .update({ profile_id: profileId })
    .eq('id', session.id)
    .is('profile_id', null)
    .gt('expires_at', new Date().toISOString())
    .select('id');

  if (claimError || !claimed || claimed.length === 0) {
    if (createdProfileId) await supabaseAdmin.from('profiles').delete().eq('id', createdProfileId);
    if (claimError) {
      console.error('Failed to claim pairing session:', claimError);
      return NextResponse.json({ error: 'Could not confirm pairing.' }, { status: 500 });
    }
    return NextResponse.json({ error: 'Pairing code has already been used.' }, { status: 409 });
  }

  if (createdProfileId) {
    try {
      deviceToken = await issueDeviceToken(createdProfileId, 'ios');
    } catch (tokenError) {
      console.error('Failed to issue phone token:', tokenError);
      await supabaseAdmin.from('profiles').delete().eq('id', createdProfileId);
      return NextResponse.json({ error: 'Could not confirm pairing.' }, { status: 500 });
    }
  }

  return NextResponse.json(deviceToken ? { paired: true, deviceToken } : { paired: true });
}
