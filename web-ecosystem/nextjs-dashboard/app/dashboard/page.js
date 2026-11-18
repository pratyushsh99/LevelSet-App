'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { authFetch, clearStoredToken, readStoredToken } from '../../lib/clientAuth';

export default function DashboardPage() {
  const [token, setToken] = useState(null);
  const [hasCheckedStorage, setHasCheckedStorage] = useState(false);
  const [status, setStatus] = useState(null);
  const [domainInput, setDomainInput] = useState('');
  const [error, setError] = useState(null);
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    setToken(readStoredToken());
    setHasCheckedStorage(true);
  }, []);

  useEffect(() => {
    if (!token) return;
    refresh();

    const interval = setInterval(() => refresh({ silent: true }), 5000);
    return () => clearInterval(interval);
  }, [token]);

  function signOutLocally() {
    clearStoredToken();
    setToken(null);
    setStatus(null);
  }

  async function refresh({ silent = false } = {}) {
    if (!silent) {
      setIsLoading(true);
      setError(null);
    }
    try {
      const [statusRes, sitesRes] = await Promise.all([
        authFetch(token, '/api/status'),
        authFetch(token, '/api/blocked-websites'),
      ]);

      if (statusRes.status === 401 || sitesRes.status === 401) {
        signOutLocally();
        return;
      }
      if (!statusRes.ok || !sitesRes.ok) {
        throw new Error('Request failed.');
      }

      const statusData = await statusRes.json();
      const sitesData = await sitesRes.json();
      setStatus({ ...statusData, blockedWebsites: sitesData.blockedWebsites });
      if (!silent) setError(null);
    } catch (err) {
      if (!silent) {
        setError("Couldn't load your balance. Try again in a moment.");
        setStatus(null);
      }
    } finally {
      if (!silent) setIsLoading(false);
    }
  }

  async function handleUnlink() {
    try {
      await authFetch(token, '/api/token', { method: 'DELETE' });
    } catch {
    }
    signOutLocally();
  }

  async function handleAddDomain(e) {
    e.preventDefault();
    const domain = domainInput.trim();
    if (!domain) return;

    const res = await authFetch(token, '/api/blocked-websites', {
      method: 'POST',
      body: { domain },
    });
    if (res.ok) {
      setDomainInput('');
      refresh();
    }
  }

  async function handleRemoveDomain(domain) {
    const res = await authFetch(token, '/api/blocked-websites', {
      method: 'DELETE',
      body: { domain },
    });
    if (res.ok) refresh();
  }

  if (!hasCheckedStorage) return null;

  if (!token) {
    return (
      <main style={styles.main}>
        <div style={styles.card}>
          <h1 style={styles.heading}>Dashboard</h1>
          <p style={styles.subheading}>
            This browser isn't linked yet. Open the pairing page and scan its QR
            code from the LevelSet app (Profile → Link Desktop).
          </p>
          <Link href="/pair" style={styles.primaryLink}>
            Link this browser
          </Link>
        </div>
      </main>
    );
  }

  return (
    <main style={styles.main}>
      <div style={styles.card}>
        <div style={styles.headerRow}>
          <h1 style={styles.heading}>Dashboard</h1>
          <button style={styles.textButton} onClick={handleUnlink}>
            Unlink this browser
          </button>
        </div>

        {error && <p style={styles.error}>{error}</p>}

        {status && (
          <>
            <div style={styles.balanceBox}>
              <span style={styles.balanceValue}>
                {formatSeconds(status.remainingSeconds)}
              </span>
              <span style={styles.balanceLabel}>
                {status.locked ? 'Locked — no time left' : 'remaining today'}
              </span>
            </div>

            <h2 style={styles.sectionTitle}>Blocked websites</h2>
            <form onSubmit={handleAddDomain} style={styles.row}>
              <input
                style={styles.input}
                placeholder="e.g. youtube.com"
                value={domainInput}
                onChange={(e) => setDomainInput(e.target.value)}
              />
              <button style={styles.primaryButton} type="submit">
                Add
              </button>
            </form>

            <ul style={styles.list}>
              {status.blockedWebsites?.length ? (
                status.blockedWebsites.map((site) => (
                  <li key={site.id} style={styles.listItem}>
                    <span>{site.domain}</span>
                    <button
                      style={styles.removeButton}
                      onClick={() => handleRemoveDomain(site.domain)}
                    >
                      Remove
                    </button>
                  </li>
                ))
              ) : (
                <li style={styles.emptyState}>No sites blocked yet.</li>
              )}
            </ul>
          </>
        )}

        {isLoading && !status && <p style={styles.subheading}>Loading…</p>}
      </div>
    </main>
  );
}

function formatSeconds(totalSeconds) {
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${minutes}:${seconds.toString().padStart(2, '0')}`;
}

const styles = {
  main: {
    minHeight: '100vh',
    display: 'flex',
    alignItems: 'flex-start',
    justifyContent: 'center',
    background: '#0b0c10',
    color: '#f5f5f5',
    fontFamily: 'system-ui, sans-serif',
    padding: '48px 24px',
  },
  card: {
    maxWidth: 480,
    width: '100%',
    background: '#16181d',
    borderRadius: 16,
    padding: '32px 28px',
    boxShadow: '0 8px 30px rgba(0,0,0,0.4)',
  },
  headerRow: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 8,
  },
  heading: { fontSize: 24, margin: 0 },
  subheading: { fontSize: 14, color: '#a3a7b0', marginBottom: 20, lineHeight: 1.5 },
  row: { display: 'flex', gap: 8, marginBottom: 16 },
  input: {
    flex: 1,
    padding: '10px 12px',
    borderRadius: 8,
    border: '1px solid #2a2d38',
    background: '#0f1116',
    color: '#f5f5f5',
    fontSize: 14,
  },
  primaryButton: {
    padding: '10px 18px',
    borderRadius: 8,
    border: 'none',
    background: '#6ea8fe',
    color: '#0b0c10',
    fontWeight: 600,
    fontSize: 14,
    cursor: 'pointer',
  },
  primaryLink: {
    display: 'inline-block',
    padding: '10px 18px',
    borderRadius: 8,
    background: '#6ea8fe',
    color: '#0b0c10',
    fontWeight: 600,
    fontSize: 14,
    textDecoration: 'none',
  },
  textButton: {
    background: 'none',
    border: 'none',
    color: '#6ea8fe',
    fontSize: 13,
    cursor: 'pointer',
  },
  balanceBox: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    padding: '20px 0',
    marginBottom: 8,
  },
  balanceValue: { fontSize: 40, fontWeight: 700, fontVariantNumeric: 'tabular-nums' },
  balanceLabel: { fontSize: 13, color: '#a3a7b0', marginTop: 4 },
  sectionTitle: { fontSize: 15, marginTop: 16, marginBottom: 12, color: '#e9e9ed' },
  list: { listStyle: 'none', padding: 0, margin: 0, display: 'flex', flexDirection: 'column', gap: 8 },
  listItem: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: '10px 12px',
    borderRadius: 8,
    background: '#0f1116',
    fontSize: 14,
  },
  removeButton: {
    background: 'none',
    border: 'none',
    color: '#e36b6b',
    fontSize: 13,
    cursor: 'pointer',
  },
  emptyState: { color: '#6b6f78', fontSize: 13, padding: '8px 0' },
  error: { color: '#ff6b6b', fontSize: 13, marginBottom: 12 },
};
