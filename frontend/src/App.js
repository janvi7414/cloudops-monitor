import React, { useEffect, useState } from 'react';

function App() {
  const [backendMessage, setBackendMessage] = useState('Loading...');

  useEffect(() => {
    // Fetches status from backend API endpoint
    fetch('/api/data')
      .then((res) => res.json())
      .then((data) => setBackendMessage(data.message))
      .catch(() => setBackendMessage('Could not reach backend API'));
  }, []);

  return (
    <div style={{ padding: '2rem', fontFamily: 'sans-serif' }}>
      <h1>CloudOps Monitoring Application</h1>
      <p>Frontend: React SPA served via Nginx</p>
      <div style={{ marginTop: '1rem', padding: '1rem', background: '#f0f0f0', borderRadius: '4px' }}>
        <strong>Backend Response:</strong> {backendMessage}
      </div>
    </div>
  );
}

export default App;
