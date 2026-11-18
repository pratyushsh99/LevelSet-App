import { NextResponse } from 'next/server';
import { requireDevice } from '../../../lib/auth';
import { supabaseAdmin } from '../../../lib/supabaseAdmin';

export async function GET(request) {
  const { device, error: authError } = await requireDevice(request, 'status:read');
  if (authError) return authError;

  const { data: profile, error: profileError } = await supabaseAdmin
    .from('profiles')
    .select('remaining_seconds')
    .eq('id', device.profileId)
    .single();

  if (profileError || !profile) {
    return NextResponse.json({ error: 'Profile not found.' }, { status: 404 });
  }

  const { data: blockedSites, error: sitesError } = await supabaseAdmin
    .from('blocked_websites')
    .select('domain')
    .eq('profile_id', device.profileId);

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
