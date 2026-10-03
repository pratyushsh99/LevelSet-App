import { NextResponse } from 'next/server';
import { supabaseAdmin } from '../../../lib/supabaseAdmin';
import { badRequest, INVALID_USER_ID, isValidUserId } from '../../../lib/validate';

export async function GET(request) {
  const userId = new URL(request.url).searchParams.get('userId');
  if (!isValidUserId(userId)) return badRequest(INVALID_USER_ID);

  const { data: profile, error: profileError } = await supabaseAdmin
    .from('profiles')
    .select('id, remaining_seconds')
    .ilike('user_id', userId)
    .single();

  if (profileError || !profile) {
    return NextResponse.json({ error: 'Profile not found.' }, { status: 404 });
  }

  const { data: blockedSites, error: sitesError } = await supabaseAdmin
    .from('blocked_websites')
    .select('domain')
    .eq('profile_id', profile.id);

  if (sitesError) {
    console.error('Failed to load blocked websites:', sitesError);
    return NextResponse.json({ error: 'Could not load blocked websites.' }, { status: 500 });
  }

  return NextResponse.json({
    remainingSeconds: profile.remaining_seconds,
    locked: profile.remaining_seconds <= 0,
    blockedDomains: blockedSites.map((site) => site.domain),
  });
}
