import { NextResponse } from 'next/server';
import { requireDevice } from '../../../lib/auth';
import { supabaseAdmin } from '../../../lib/supabaseAdmin';

export async function DELETE(request) {
  const { device, error: authError } = await requireDevice(request, 'account:delete');
  if (authError) return authError;

  const { error } = await supabaseAdmin.from('profiles').delete().eq('id', device.profileId);

  if (error) {
    console.error('Failed to delete account:', error);
    return NextResponse.json({ error: 'Could not delete account.' }, { status: 500 });
  }

  return NextResponse.json({ deleted: true });
}
