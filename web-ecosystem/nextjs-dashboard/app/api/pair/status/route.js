import { NextResponse } from 'next/server';
import { bearerToken, hashSecret, issueDeviceToken } from '../../../../lib/auth';
import { supabaseAdmin } from '../../../../lib/supabaseAdmin';
import { badRequest, INVALID_JSON, isValidUuid, readJson } from '../../../../lib/validate';

export async function POST(request) {
  const body = await readJson(request);
  if (!body) return badRequest(INVALID_JSON);
  if (!isValidUuid(body.sessionId)) return badRequest('sessionId must be a valid id.');

  const pollSecret = bearerToken(request);
  if (!pollSecret) {
    return NextResponse.json({ error: 'Missing poll secret.' }, { status: 401 });
  }
  const pollSecretHash = hashSecret(pollSecret);

  const { data: session, error } = await supabaseAdmin
    .from('pairing_sessions')
    .select('profile_id, expires_at')
    .eq('id', body.sessionId)
    .eq('poll_secret_hash', pollSecretHash)
    .maybeSingle();

  if (error) {
    console.error('Failed to check pairing status:', error);
    return NextResponse.json({ error: 'Could not check pairing status.' }, { status: 500 });
  }
  if (!session) return NextResponse.json({ paired: false, gone: true }, { status: 404 });
  if (!session.profile_id) {
    const expired = new Date(session.expires_at) < new Date();
    return NextResponse.json(expired ? { paired: false, gone: true } : { paired: false });
  }

  const { data: collected, error: deleteError } = await supabaseAdmin
    .from('pairing_sessions')
    .delete()
    .eq('id', body.sessionId)
    .eq('poll_secret_hash', pollSecretHash)
    .not('profile_id', 'is', null)
    .select('profile_id');

  if (deleteError) {
    console.error('Failed to collect pairing session:', deleteError);
    return NextResponse.json({ error: 'Could not finish pairing.' }, { status: 500 });
  }
  if (!collected || collected.length === 0) {
    return NextResponse.json({ paired: false, gone: true }, { status: 404 });
  }

  try {
    const token = await issueDeviceToken(collected[0].profile_id, 'browser');
    return NextResponse.json({ paired: true, token });
  } catch (tokenError) {
    console.error('Failed to issue browser token:', tokenError);
    return NextResponse.json({ error: 'Could not finish pairing.' }, { status: 500 });
  }
}
