'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import { QRCodeSVG } from 'qrcode.react';
import { TOKEN_STORAGE_KEY } from '../../lib/clientAuth';

const POLL_INTERVAL_MS = 2000;

export default function PairPage() {
  const router = useRouter();
  const [session, setSession] = useState(null);
  const [error, setError] = useState(null);
  const [linkedToken, setLinkedToken] = useState(null);
  const [copied, setCopied] = useState(false);
  const pollTimer = useRef(null);

  const generateCode = useCallback(async () => {
    setError(null);
    setLinkedToken(null);
    setSession(null);
    try {
      const res = await fetch('/api/pair', { method: 'POST' });
      if (!res.ok) throw new Error('Request failed');
      setSession(await res.json());
    } catch (err) {
      setError('Could not generate a pairing code. Please try again.');
    }
  }, []);

  useEffect(() => {
    generateCode();
  }, [generateCode]);

  useEffect(() => {
    if (!session) return undefined;

    async function poll() {
      try {
        const res = await fetch('/api/pair/status', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${session.pollSecret}`,
          },
          body: JSON.stringify({ sessionId: session.sessionId }),
        });
        const data = await res.json();
        if (data.paired && data.token) {
          clearInterval(pollTimer.current);
          window.localStorage.setItem(TOKEN_STORAGE_KEY, data.token);
          window.localStorage.removeItem('levelset_user_id');
          setLinkedToken(data.token);
        } else if (data.gone) {
          clearInterval(pollTimer.current);
          setSession(null);
          setError('This pairing code expired. Generate a new one.');
        }
      } catch {
      }
    }

    pollTimer.current = setInterval(poll, POLL_INTERVAL_MS);
    return () => clearInterval(pollTimer.current);
  }, [session]);

  const qrValue = session
    ? JSON.stringify({ type: 'levelset-pairing', v: 2, secret: session.qrSecret })
    : '';

  async function copyExtensionKey() {
    await navigator.clipboard.writeText(linkedToken);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  }

  if (linkedToken) {
    return (
      <main style={styles.main}>
        <div style={styles.card}>
          <div style={{ fontSize: 40, marginBottom: 8 }}>✅</div>
          <h1 style={styles.heading}>Linked!</h1>
          <p style={styles.subheading}>
            This browser is now connected to your LevelSet screen-time balance.
          </p>

          <button style={styles.primaryButton} onClick={() => router.push('/dashboard')}>
            Go to Dashboard
          </button>

          <div style={styles.deviceIdBox}>
            <p style={styles.codeLabel}>
              Using the browser extension? Copy this browser's key and paste it
              into the extension's options page. Keep it private: it can spend
              your earned time and edit your blocked sites, but it can't add
              time.
            </p>
            <button style={styles.deviceIdButton} onClick={copyExtensionKey}>
              Copy extension key
            </button>
            {copied && <p style={styles.copiedNote}>Copied!</p>}
          </div>
        </div>
      </main>
    );
  }

  return (
    <main style={styles.main}>
      <div style={styles.card}>
        <h1 style={styles.heading}>Link this computer</h1>
        <p style={styles.subheading}>
          Open the LevelSet iOS app, go to Profile → Link Desktop, and scan
          this code to connect your screen-time balance to this browser.
        </p>

        <div style={styles.qrBox}>
          {session ? (
            <QRCodeSVG value={qrValue} size={220} includeMargin />
          ) : error ? (
            <p style={styles.error}>{error}</p>
          ) : (
            <p>Generating pairing code…</p>
          )}
        </div>

        {session && (
          <>
            <p style={styles.expiry}>
              Expires at {new Date(session.expiresAt).toLocaleTimeString()}
            </p>
            <p style={styles.waiting}>Waiting for your phone to scan…</p>
          </>
        )}

        <button style={styles.secondaryButton} onClick={generateCode}>
          Generate new code
        </button>
      </div>
    </main>
  );
}

const styles = {
  main: {
    minHeight: '100vh',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    background: '#0b0c10',
    color: '#f5f5f5',
    fontFamily: 'system-ui, sans-serif',
    padding: '24px',
  },
  card: {
    maxWidth: 420,
    width: '100%',
    background: '#16181d',
    borderRadius: 16,
    padding: '32px 28px',
    textAlign: 'center',
    boxShadow: '0 8px 30px rgba(0,0,0,0.4)',
  },
  heading: { fontSize: 24, marginBottom: 8 },
  subheading: { fontSize: 14, color: '#a3a7b0', marginBottom: 24, lineHeight: 1.5 },
  qrBox: {
    background: '#fff',
    borderRadius: 12,
    padding: 20,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: 260,
  },
  codeLabel: { marginTop: 20, fontSize: 13, color: '#a3a7b0' },
  expiry: { marginTop: 16, fontSize: 12, color: '#6b6f78' },
  waiting: { fontSize: 13, color: '#8a8fa3', marginTop: 16 },
  error: { color: '#ff6b6b' },
  primaryButton: {
    marginTop: 8,
    padding: '12px 24px',
    borderRadius: 10,
    border: 'none',
    background: '#6ea8fe',
    color: '#0b0c10',
    fontWeight: 600,
    fontSize: 15,
    cursor: 'pointer',
  },
  secondaryButton: {
    marginTop: 20,
    padding: '10px 18px',
    borderRadius: 10,
    border: '1px solid #2a2d38',
    background: 'transparent',
    color: '#a3a7b0',
    fontSize: 13,
    cursor: 'pointer',
  },
  deviceIdBox: { marginTop: 24, textAlign: 'left' },
  deviceIdButton: {
    width: '100%',
    padding: '10px 12px',
    borderRadius: 8,
    border: '1px solid #2a2d38',
    background: '#0f1116',
    color: '#6ea8fe',
    fontSize: 13,
    textAlign: 'center',
    cursor: 'pointer',
    overflowWrap: 'anywhere',
  },
  copiedNote: { fontSize: 12, color: '#4ade80', marginTop: 6 },
};
