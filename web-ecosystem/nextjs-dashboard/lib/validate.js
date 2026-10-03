import { NextResponse } from 'next/server';

const USER_ID_PATTERN = /^[A-Za-z0-9-]{8,64}$/;
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const PAIRING_CODE_PATTERN = /^[A-F0-9]{8}$/;
const DOMAIN_PATTERN = /^(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$/;

export const MAX_BALANCE_SECONDS = 7 * 24 * 60 * 60;
export const MAX_STATS_BYTES = 64 * 1024;
export const MAX_BLOCKED_SITES = 200;

export function isValidUserId(value) {
  return typeof value === 'string' && USER_ID_PATTERN.test(value);
}

export function isValidProfileId(value) {
  return typeof value === 'string' && UUID_PATTERN.test(value);
}

export function isValidPairingCode(value) {
  return typeof value === 'string' && PAIRING_CODE_PATTERN.test(value);
}

export function normalizeDomain(raw) {
  if (typeof raw !== 'string') return null;
  const domain = raw
    .trim()
    .toLowerCase()
    .replace(/^[a-z]+:\/\//, '')
    .replace(/^www\./, '')
    .replace(/[/?#:].*$/, '');
  return DOMAIN_PATTERN.test(domain) ? domain : null;
}

export function isBoundedInteger(value, min, max) {
  return Number.isInteger(value) && value >= min && value <= max;
}

export async function readJson(request) {
  try {
    const body = await request.json();
    return body && typeof body === 'object' && !Array.isArray(body) ? body : null;
  } catch {
    return null;
  }
}

export function badRequest(message) {
  return NextResponse.json({ error: message }, { status: 400 });
}

export const INVALID_USER_ID = 'userId must be 8-64 letters, numbers or hyphens.';
