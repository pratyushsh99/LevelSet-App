import { NextResponse } from 'next/server';
import { supabaseAdmin } from '../../../lib/supabaseAdmin';
import {
  badRequest,
  INVALID_USER_ID,
  isValidUserId,
  MAX_BLOCKED_SITES,
  normalizeDomain,
  readJson,
} from '../../../lib/validate';

async function findProfile(userId) {
  return supabaseAdmin.from('profiles').select('id').ilike('user_id', userId).single();
}

function profileNotFound() {
  return NextResponse.json({ error: 'Profile not found.' }, { status: 404 });
}

async function readMutation(request) {
  const body = await readJson(request);
  if (!body) return { error: badRequest('Invalid JSON body.') };
  if (!isValidUserId(body.userId)) return { error: badRequest(INVALID_USER_ID) };
  const domain = normalizeDomain(body.domain);
  if (!domain) return { error: badRequest('domain must be a valid website domain, like youtube.com.') };
  return { userId: body.userId, domain };
}

export async function GET(request) {
  const userId = new URL(request.url).searchParams.get('userId');
  if (!isValidUserId(userId)) return badRequest(INVALID_USER_ID);

  const { data: profile, error: profileError } = await findProfile(userId);
  if (profileError || !profile) return profileNotFound();

  const { data: sites, error: sitesError } = await supabaseAdmin
    .from('blocked_websites')
    .select('id, domain')
    .eq('profile_id', profile.id)
    .order('domain');

  if (sitesError) {
    console.error('Failed to list blocked websites:', sitesError);
    return NextResponse.json({ error: 'Could not load blocked websites.' }, { status: 500 });
  }

  return NextResponse.json({ blockedWebsites: sites });
}

export async function POST(request) {
  const { error, userId, domain } = await readMutation(request);
  if (error) return error;

  const { data: profile, error: profileError } = await findProfile(userId);
  if (profileError || !profile) return profileNotFound();

  const { count, error: countError } = await supabaseAdmin
    .from('blocked_websites')
    .select('id', { count: 'exact', head: true })
    .eq('profile_id', profile.id);

  if (countError) {
    console.error('Failed to count blocked websites:', countError);
    return NextResponse.json({ error: 'Could not add domain.' }, { status: 500 });
  }
  if (count >= MAX_BLOCKED_SITES) {
    return NextResponse.json({ error: `You can restrict up to ${MAX_BLOCKED_SITES} sites.` }, { status: 409 });
  }

  const { data: site, error: insertError } = await supabaseAdmin
    .from('blocked_websites')
    .upsert({ profile_id: profile.id, domain }, { onConflict: 'profile_id,domain' })
    .select('id, domain')
    .single();

  if (insertError) {
    console.error('Failed to add blocked website:', insertError);
    return NextResponse.json({ error: 'Could not add domain.' }, { status: 500 });
  }

  return NextResponse.json({ blockedWebsite: site });
}

export async function DELETE(request) {
  const { error, userId, domain } = await readMutation(request);
  if (error) return error;

  const { data: profile, error: profileError } = await findProfile(userId);
  if (profileError || !profile) return profileNotFound();

  const { error: deleteError } = await supabaseAdmin
    .from('blocked_websites')
    .delete()
    .eq('profile_id', profile.id)
    .eq('domain', domain);

  if (deleteError) {
    console.error('Failed to remove blocked website:', deleteError);
    return NextResponse.json({ error: 'Could not remove domain.' }, { status: 500 });
  }

  return NextResponse.json({ removed: true });
}
