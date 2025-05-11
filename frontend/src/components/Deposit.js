import React, { useState, useCallback } from 'react';

function Deposit() {
  const [amount, setAmount] = useState('');
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const accountNumber = '12345678'; // Using the test account

  const handleSubmit = useCallback(async (e) => {
    e.preventDefault();
    
    if (!amount || isNaN(amount) || parseFloat(amount) <= 0) {
      setError('Please enter a valid amount');
      return;
    }
    
    try {
      setLoading(true);
      setError('');
      setMessage('');
      
      const response = await fetch('/api/deposit', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          accountNumber,
          amount: parseFloat(amount)
        }),
      });
      
      const data = await response.json();
      
      if (!response.ok) {
        throw new Error(data.error || 'Failed to process deposit');
      }
      
      setMessage(`Successfully deposited $${parseFloat(amount).toFixed(2)}. New balance: $${parseFloat(data.newBalance).toFixed(2)}`);
      setAmount('');
    } catch (err) {
      setError(err.message || 'Error processing deposit. Please try again.');
      console.error(err);
    } finally {
      setLoading(false);
    }
  }, [amount, accountNumber]);

  return (
    <div>
      <h2>Deposit Funds</h2>
      <div className="card">
        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label htmlFor="account">Account Number:</label>
            <input
              type="text"
              id="account"
              value={accountNumber}
              disabled
              aria-label="Account Number"
            />
          </div>
          <div className="form-group">
            <label htmlFor="amount">Amount to Deposit ($):</label>
            <input
              type="number"
              id="amount"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              step="0.01"
              min="0.01"
              placeholder="Enter amount"
              required
              aria-label="Deposit Amount"
            />
          </div>
          <button type="submit" disabled={loading}>
            {loading ? 'Processing...' : 'Deposit'}
          </button>
          
          {error && <p className="error" role="alert">{error}</p>}
          {message && <p className="success" role="status">{message}</p>}
        </form>
      </div>
    </div>
  );
}

export default Deposit;