export const metadata = {
  title: 'LevelSet — Screen Time Banking',
  description: 'Cross-device screen time banking for LevelSet.',
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body style={{ margin: 0 }}>{children}</body>
    </html>
  );
}
