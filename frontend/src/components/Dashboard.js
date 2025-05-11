import React, { useState, useEffect, useCallback } from 'react';

function Dashboard() {
  const [balance, setBalance] = useState(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);
  const accountNumber = '12345678'; // Using the test account

  // Use useCallback to memoize the fetchBalance function
  const fetchBalance = useCallback(async () => {
    try {
      setLoading(true);
      const response = await fetch(`/api/balance/${accountNumber}`);
      
      if (!response.ok) {
        throw new Error('Failed to fetch balance');
      }
      
      const data = await response.json();
      setBalance(data.balance);
      setError('');
    } catch (err) {
      setError('Error fetching balance. Please try again later.');
      console.error(err);
    } finally {
      setLoading(false);
    }
  }, [accountNumber]);

  // Use the memoized fetchBalance in useEffect
  useEffect(() => {
    fetchBalance();
  }, [fetchBalance]);

  return (
    <div>
      <h2>Account Dashboard</h2>
      <div className="card">
        <h3>Current Balance</h3>
        {loading ? (
          <p>Loading balance...</p>
        ) : error ? (
          <p className="error">{error}</p>
        ) : (
          <div className="balance-display">
            ${parseFloat(balance).toFixed(2)}
          </div>
        )}
        <p>Account Number: {accountNumber}</p>
        <button onClick={fetchBalance}>Refresh Balance</button>
      </div>
    </div>
  );
}

export default Dashboard;