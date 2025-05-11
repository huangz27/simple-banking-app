import React from 'react';
import { BrowserRouter as Router, Routes, Route, Link } from 'react-router-dom';
import './App.css';
import Dashboard from './components/Dashboard';
import Deposit from './components/Deposit';
import Withdraw from './components/Withdraw';
import Transactions from './components/Transactions';

function App() {
  return (
    <Router>
      <div className="App">
        <header className="App-header">
          <h1>Simple Banking App</h1>
          <nav>
            <ul className="nav-links">
              <li><Link to="/">Dashboard</Link></li>
              <li><Link to="/deposit">Deposit</Link></li>
              <li><Link to="/withdraw">Withdraw</Link></li>
              <li><Link to="/transactions">Transactions</Link></li>
            </ul>
          </nav>
        </header>
        <main>
          <Routes>
            <Route path="/" element={<Dashboard />} />
            <Route path="/deposit" element={<Deposit />} />
            <Route path="/withdraw" element={<Withdraw />} />
            <Route path="/transactions" element={<Transactions />} />
          </Routes>
        </main>
        <footer>
          <p>&copy; {new Date().getFullYear()} Simple Banking App</p>
        </footer>
      </div>
    </Router>
  );
}

export default App;