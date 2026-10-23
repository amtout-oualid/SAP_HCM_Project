import React from 'react';
import { Link } from 'react-router-dom';

const ComingSoon = () => {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', height: '100%', padding: '2rem' }}>
      <h1 style={{ fontSize: '2rem', fontWeight: 'bold', marginBottom: '1rem' }}>Page Not Built Yet</h1>
      <p style={{ color: 'var(--text-muted)', marginBottom: '2rem' }}>This feature is currently under construction.</p>
      <Link to="/" className="btn-primary">Return to Job Board</Link>
    </div>
  );
};

export default ComingSoon;
