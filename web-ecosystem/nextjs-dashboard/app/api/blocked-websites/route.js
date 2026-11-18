import { NextResponse } from 'next/server';
import { requireDevice } from '../../../lib/auth';
import { supabaseAdmin } from '../../../lib/supabaseAdmin';
import { badRequest, INVALID_JSON, MAX_BLOCKED_SITES, normalizeDomain, readJson } from '../../../lib/validate';

async function readDomain(request) {
  const body = await readJson(request);
  if (!body) return { error: badRequest(INVALID_JSON) };
  const domain = normalizeDomain(body.domain);
  if (!domain) return { error: badRequest('domain must be a valid website domain, like youtube.com.') };
  return { domain };
}

export async function GET(request) {
  const { device, error: authError } = await requireDevice(request, 'status:read');
  if (authError) return authError;

  const { data: sites, error: sitesError } = await supabaseAdmin
    .from('blocked_websites')
    .select('id, domain')
    .eq('profile_id', device.profileId)
    .order('domain');

  if (sitesError) {
    console.error('Failed to list blocked websites:', sitesError);
    return NextResponse.json({ error: 'Could not load blocked websites.' }, { status: 500 });
  }

  return NextResponse.json({ blockedWebsites: sites });
}

export async function POST(request) {
  const { device, error: authError } = await requireDevice(request, 'sites:write');
  if (authError) return authError;

  const { error, domain } = await readDomain(request);
  if (error) return error;

  const { count, error: countError } = await supabaseAdmin
    .from('blocked_websites')
    .select('id', { count: 'exact', head: true })
    .eq('profile_id', device.profileId);

  if (countError) {
    console.error('Failed to count blocked websites:', countError);
    return NextResponse.json({ error: 'Could not add domain.' }, { status: 500 });
  }
  if (count >= MAX_BLOCKED_SITES) {
    return NextResponse.json({ error: `You can restrict up to ${MAX_BLOCKED_SITES} sites.` }, { status: 409 });
  }

  const { data: site, error: insertError } = await supabaseAdmin
    .from('blocked_websites')
    .upsert({ profile_id: device.profileId, domain }, { onConflict: 'profile_id,domain' })
    .select('id, domain')
    .single();

  if (insertError) {
    console.error('Failed to add blocked website:', insertError);
    return NextResponse.json({ error: 'Could not add domain.' }, { status: 500 });
  }

  return NextResponse.json({ blockedWebsite: site });
}

export async function DELETE(request) {
  const { device, error: authError } = await requireDevice(request, 'sites:write');
  if (authError) return authError;

  const { error, domain } = await readDomain(request);
  if (error) return error;

  const { error: deleteError } = await supabaseAdmin
    .from('blocked_websites')
    .delete()
    .eq('profile_id', device.profileId)
    .eq('domain', domain);

  if (deleteError) {
    console.error('Failed to remove blocked website:', deleteError);
    return NextResponse.json({ error: 'Could not remove domain.' }, { status: 500 });
  }

  return NextResponse.json({ removed: true });
}
