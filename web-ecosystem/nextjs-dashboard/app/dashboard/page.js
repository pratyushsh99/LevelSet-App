'use client';

import { useEffect, useState } from 'react';

const STORAGE_KEY = 'levelset_user_id';

export default function DashboardPage() {
  const [userId, setUserId] = useState(null);
  const [userIdInput, setUserIdInput] = useState('');
  const [status, setStatus] = useState(null);
  const [domainInput, setDomainInput] = useState('');
  const [error, setError] = useState(null);
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    const stored = window.localStorage.getItem(STORAGE_KEY);
    if (stored) setUserId(stored);
  }, []);

  useEffect(() => {
    if (!userId) return;
    refresh();

    const interval = setInterval(() => refresh({ silent: true }), 5000);
    return () => clearInterval(interval);
  }, [userId]);

  async function refresh({ silent = false } = {}) {
    if (!silent) {
      setIsLoading(true);
      setError(null);
    }
    try {
      const [statusRes, sitesRes] = await Promise.all([
        fetch(`/api/status?userId=${encodeURIComponent(userId)}`),
        fetch(`/api/blocked-websites?userId=${encodeURIComponent(userId)}`),
      ]);

      if (!statusRes.ok || !sitesRes.ok) {
        throw new Error('Profile not found.');
      }

      const statusData = await statusRes.json();
      const sitesData = await sitesRes.json();
      setStatus({ ...statusData, blockedWebsites: sitesData.blockedWebsites });
      if (!silent) setError(null);
    } catch (err) {

      if (!silent) {
        setError("Couldn't find a profile for that id. Check it and try again.");
        setStatus(null);
      }
    } finally {
      if (!silent) setIsLoading(false);
    }
  }

  function handleUseUserId(e) {
    e.preventDefault();
    const trimmed = userIdInput.trim();
    if (!trimmed) return;
    window.localStorage.setItem(STORAGE_KEY, trimmed);
    setUserId(trimmed);
  }

  function handleForget() {
    window.localStorage.removeItem(STORAGE_KEY);
    setUserId(null);
    setStatus(null);
  }

  async function handleAddDomain(e) {
    e.preventDefault();
    const domain = domainInput.trim();
    if (!domain) return;

    const res = await fetch('/api/blocked-websites', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ userId, domain }),
    });
    if (res.ok) {
      setDomainInput('');
      refresh();
    }
  }

  async function handleRemoveDomain(domain) {
    const res = await fetch('/api/blocked-websites', {
      method: 'DELETE',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ userId, domain }),
    });
    if (res.ok) refresh();
  }

  if (!userId) {
    return (
      <main style={styles.main}>
        <div style={styles.card}>
          <h1 style={styles.heading}>Dashboard</h1>
          <p style={styles.subheading}>
            Enter the device id from your phone (Profile → Link Desktop) or the
            one this browser got after scanning /pair.
          </p>
          <form onSubmit={handleUseUserId} style={styles.row}>
            <input
              style={styles.input}
              placeholder="Device id"
              value={userIdInput}
              onChange={(e) => setUserIdInput(e.target.value)}
            />
            <button style={styles.primaryButton} type="submit">
              Load
            </button>
          </form>
        </div>
      </main>
    );
  }

  return (
    <main style={styles.main}>
      <div style={styles.card}>
        <div style={styles.headerRow}>
          <h1 style={styles.heading}>Dashboard</h1>
          <button style={styles.textButton} onClick={handleForget}>
            Switch device
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
