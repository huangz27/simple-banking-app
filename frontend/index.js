import React from 'react';
import { createRoot } from 'react-dom/client';
import './App.css';
import App from './App';

// React 18 uses createRoot instead of ReactDOM.render
const container = document.getElementById('root');
const root = createRoot(container);
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);