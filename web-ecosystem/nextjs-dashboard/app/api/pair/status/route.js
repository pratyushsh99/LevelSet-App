import { NextResponse } from 'next/server';
import { supabaseAdmin } from '../../../../lib/supabaseAdmin';
import { badRequest, isValidProfileId } from '../../../../lib/validate';

export async function GET(request) {
  const profileId = new URL(request.url).searchParams.get('profileId');
  if (!isValidProfileId(profileId)) return badRequest('profileId must be a valid id.');

  const { data: profile, error } = await supabaseAdmin
    .from('profiles')
    .select('user_id, resolved_user_id, pairing_code')
    .eq('id', profileId)
    .maybeSingle();

  if (error) {
    console.error('Failed to check pairing status:', error);
    return NextResponse.json({ error: 'Could not check pairing status.' }, { status: 500 });
  }

  if (!profile) {
    return NextResponse.json({ paired: false, gone: true });
  }

  const paired = !profile.pairing_code;
  return NextResponse.json({
    paired,
    userId: paired ? profile.resolved_user_id || profile.user_id : null,
  });
}
