import { NextResponse } from 'next/server';
import { requireDevice } from '../../../lib/auth';
import { supabaseAdmin } from '../../../lib/supabaseAdmin';

export async function DELETE(request) {
  const { device, error: authError } = await requireDevice(request, 'token:revoke');
  if (authError) return authError;

  const { error } = await supabaseAdmin.from('device_tokens').delete().eq('id', device.id);

  if (error) {
    console.error('Failed to revoke token:', error);
    return NextResponse.json({ error: 'Could not unlink device.' }, { status: 500 });
  }

  return NextResponse.json({ revoked: true });
}
