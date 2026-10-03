import Link from 'next/link';

export default function HomePage() {
  return (
    <main style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', background: '#0b0c10', color: '#f5f5f5', fontFamily: 'system-ui, sans-serif' }}>
      <div style={{ textAlign: 'center' }}>
        <h1>LevelSet Web Ecosystem</h1>
        <p style={{ color: '#a3a7b0' }}>
          <Link href="/pair" style={{ color: '#6ea8fe' }}>Pair a new device →</Link>
        </p>
        <p style={{ color: '#a3a7b0' }}>
          <Link href="/dashboard" style={{ color: '#6ea8fe' }}>Manage blocked sites →</Link>
        </p>
      </div>
    </main>
  );
}
