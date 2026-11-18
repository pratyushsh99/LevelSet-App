import { createHash, randomBytes } from 'crypto';
import { NextResponse } from 'next/server';
import { supabaseAdmin } from './supabaseAdmin';

const SECRET_PATTERN = /^[A-Za-z0-9_-]{43}$/;
const LAST_USED_REFRESH_MS = 60 * 60 * 1000;

const SCOPES = {
  ios: new Set(['pair:link', 'balance:write', 'stats:write', 'account:delete', 'token:revoke']),
  browser: new Set(['status:read', 'sites:write', 'time:deduct', 'token:revoke']),
};

export function newSecret() {
  return randomBytes(32).toString('base64url');
}

export function hashSecret(secret) {
  return createHash('sha256').update(secret).digest('hex');
}

export function isWellFormedSecret(value) {
  return typeof value === 'string' && SECRET_PATTERN.test(value);
}

export function bearerToken(request) {
  const match = /^Bearer ([A-Za-z0-9_-]{43})$/.exec(request.headers.get('authorization') || '');
  return match ? match[1] : null;
}

export async function issueDeviceToken(profileId, kind) {
  const token = newSecret();
  const { error } = await supabaseAdmin
    .from('device_tokens')
    .insert({ profile_id: profileId, token_hash: hashSecret(token), kind });
  if (error) throw error;
  return token;
}

function unauthorized() {
  return NextResponse.json(
    { error: 'Missing or invalid device token.' },
    { status: 401, headers: { 'WWW-Authenticate': 'Bearer' } }
  );
}

export async function requireDevice(request, scope) {
  const token = bearerToken(request);
  if (!token) return { error: unauthorized() };

  const { data, error } = await supabaseAdmin
    .from('device_tokens')
    .select('id, profile_id, kind, last_used_at')
    .eq('token_hash', hashSecret(token))
    .maybeSingle();

  if (error) {
    console.error('Failed to look up device token:', error);
    return { error: NextResponse.json({ error: 'Could not verify device.' }, { status: 500 }) };
  }
  if (!data) return { error: unauthorized() };
  if (!SCOPES[data.kind]?.has(scope)) {
    return { error: NextResponse.json({ error: 'This device is not allowed to do that.' }, { status: 403 }) };
  }

  const lastUsed = data.last_used_at ? Date.parse(data.last_used_at) : 0;
  if (Date.now() - lastUsed > LAST_USED_REFRESH_MS) {
    const { error: touchError } = await supabaseAdmin
      .from('device_tokens')
      .update({ last_used_at: new Date().toISOString() })
      .eq('id', data.id);
    if (touchError) console.error('Failed to record token use:', touchError);
  }

  return { device: { id: data.id, profileId: data.profile_id, kind: data.kind } };
}
