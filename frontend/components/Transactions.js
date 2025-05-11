import React, { useState, useEffect, useCallback } from 'react';

function Transactions() {
  const [transactions, setTransactions] = useState([]);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);
  const accountNumber = '12345678'; // Using the test account

  // Use useCallback to memoize the fetchTransactions function
  const fetchTransactions = useCallback(async () => {
    try {
      setLoading(true);
      const response = await fetch(`/api/transactions/${accountNumber}`);
      
      if (!response.ok) {
        throw new Error('Failed to fetch transactions');
      }
      
      const data = await response.json();
      setTransactions(data.transactions || []);
      setError('');
    } catch (err) {
      setError('Error fetching transactions. Please try again later.');
      console.error(err);
    } finally {
      setLoading(false);
    }
  }, [accountNumber]);

  // Use the memoized fetchTransactions in useEffect
  useEffect(() => {
    fetchTransactions();
  }, [fetchTransactions]);

  const formatDate = (dateString) => {
    const date = new Date(dateString);
    return new Intl.DateTimeFormat('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    }).format(date);
  };

  return (
    <div>
      <h2>Transaction History</h2>
      <div className="card">
        {loading ? (
          <p>Loading transactions...</p>
        ) : error ? (
          <p className="error">{error}</p>
        ) : transactions.length === 0 ? (
          <p>No transactions found.</p>
        ) : (
          <ul className="transaction-list">
            {transactions.map((transaction, index) => (
              <li key={index} className="transaction-item">
                <span className={`transaction-type ${transaction.type}`}>
                  {transaction.type === 'deposit' ? 'Deposit' : 'Withdrawal'}
                </span>
                <span className={`transaction-amount ${transaction.type}`}>
                  {transaction.type === 'deposit' ? '+' : '-'}${parseFloat(transaction.amount).toFixed(2)}
                </span>
                <span className="transaction-date">
                  {formatDate(transaction.transaction_date)}
                </span>
              </li>
            ))}
          </ul>
        )}
        <button onClick={fetchTransactions} disabled={loading}>
          Refresh Transactions
        </button>
      </div>
    </div>
  );
}

export default Transactions;