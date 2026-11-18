import { NextResponse } from 'next/server';
import { requireDevice } from '../../../lib/auth';
import { supabaseAdmin } from '../../../lib/supabaseAdmin';
import { badRequest, INVALID_JSON, isBoundedInteger, MAX_STATS_BYTES, readJson } from '../../../lib/validate';

export async function POST(request) {
  const { device, error: authError } = await requireDevice(request, 'stats:write');
  if (authError) return authError;

  const body = await readJson(request);
  if (!body) return badRequest(INVALID_JSON);

  const { xp, currentStreak, progress, history } = body;
  if (!isBoundedInteger(xp, 0, 1_000_000_000) || !isBoundedInteger(currentStreak, 0, 100_000)) {
    return badRequest('xp and currentStreak must be non-negative whole numbers.');
  }
  if (progress != null && (typeof progress !== 'object' || Array.isArray(progress))) {
    return badRequest('progress must be an object.');
  }
  if (history != null && !Array.isArray(history)) {
    return badRequest('history must be an array.');
  }

  const stats = { progress: progress ?? null, history: history ?? [] };
  if (JSON.stringify(stats).length > MAX_STATS_BYTES) {
    return NextResponse.json({ error: 'Stats payload is too large.' }, { status: 413 });
  }

  const { data, error } = await supabaseAdmin
    .from('profiles')
    .update({ xp, current_streak: currentStreak, stats })
    .eq('id', device.profileId)
    .select('id');

  if (error) {
    console.error('Failed to sync stats:', error);
    return NextResponse.json({ error: 'Could not sync stats.' }, { status: 500 });
  }
  if (!data || data.length === 0) {
    return NextResponse.json({ error: 'Profile not found.' }, { status: 404 });
  }

  return NextResponse.json({ synced: true });
}
