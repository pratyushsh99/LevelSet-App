
export const metadata = {
  title: 'Desktop Time Locked',
};

export default function LockedPage() {
  return (
    <main style={styles.main}>
      <div style={styles.card}>
        <div style={styles.icon}>⏳</div>
        <h1 style={styles.heading}>Desktop Time Locked!</h1>
        <p style={styles.body}>
          Open your iOS app and complete your exercises to unblock.
        </p>
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
    textAlign: 'center',
  },
  card: {
    maxWidth: 420,
  },
  icon: { fontSize: 56, marginBottom: 16 },
  heading: { fontSize: 28, marginBottom: 12 },
  body: { fontSize: 16, color: '#a3a7b0', lineHeight: 1.6 },
};
