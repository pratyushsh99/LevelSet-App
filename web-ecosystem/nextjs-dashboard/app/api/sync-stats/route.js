import { NextResponse } from 'next/server';
import { supabaseAdmin } from '../../../lib/supabaseAdmin';
import { badRequest, INVALID_USER_ID, isBoundedInteger, isValidUserId, MAX_STATS_BYTES, readJson } from '../../../lib/validate';

export async function POST(request) {
  const body = await readJson(request);
  if (!body) return badRequest('Invalid JSON body.');

  const { userId, xp, currentStreak, progress, history } = body;
  if (!isValidUserId(userId)) return badRequest(INVALID_USER_ID);
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
    .ilike('user_id', userId)
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
