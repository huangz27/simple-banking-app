const express = require('express');
const { json } = require('express');
const { Pool } = require('pg');
const cors = require('cors');
const path = require('path');
const { SecretsManagerClient, GetSecretValueCommand } = require('@aws-sdk/client-secrets-manager');
const fs = require('fs/promises');
const { existsSync, mkdirSync, writeFileSync } = require('fs');

// Create Express application
const app = express();

// Enhanced logging middleware
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    console.log(`${req.method} ${req.originalUrl} ${res.statusCode} ${duration}ms`);
  });
  next();
});

// Middleware
app.use(json());
app.use(cors({
  origin: process.env.NODE_ENV === 'production' ? false : '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

// Check if frontend build directory exists
const frontendBuildPath = path.join(__dirname, '../frontend/build');
if (!existsSync(frontendBuildPath)) {
  console.warn(`Frontend build directory not found at ${frontendBuildPath}`);
  // Create directory if it doesn't exist
  try {
    mkdirSync(frontendBuildPath, { recursive: true });
    writeFileSync(
      path.join(frontendBuildPath, 'index.html'),
      '<html><body><h1>Banking App</h1><p>Application is still initializing...</p></body></html>'
    );
    console.log('Created placeholder index.html');
  } catch (err) {
    console.error('Error creating placeholder frontend:', err);
  }
}

// Serve static files from the React frontend app
app.use(express.static(frontendBuildPath));

// Load configuration
let config;
try {
  const configPath = path.join(__dirname, 'config.json');
  if (existsSync(configPath)) {
    const configData = require(configPath);
    config = configData;
  } else {
    config = {
      secretName: process.env.SECRETS_MANAGER_NAME,
      region: process.env.AWS_REGION || 'ap-southeast-1'
    };
  }
} catch (error) {
  console.error('Error loading config file:', error);
  config = {
    secretName: process.env.SECRETS_MANAGER_NAME,
    region: process.env.AWS_REGION || 'ap-southeast-1'
  };
}

// Secrets Manager configuration
const secretsManager = new SecretsManagerClient({
  region: config.region
});
const secretName = config.secretName;

// Function to get database credentials from Secrets Manager
async function getDatabaseConfig() {
  try {
    console.log(`Fetching database credentials from secret: ${secretName}`);
    const command = new GetSecretValueCommand({
      SecretId: secretName
    });
    
    const response = await secretsManager.send(command);
    const secretData = JSON.parse(response.SecretString);
    
    return {
      host: secretData.host,
      user: secretData.username,
      password: secretData.password,
      database: secretData.dbname,
      port: secretData.port || 5432,
      ssl: true
    };
    
  } catch (error) {
    console.error('Error retrieving database credentials:', error);
    throw error;
  }
}

// Database connection pool
let pool;

// Initialize database connection pool
async function initializeDbPool() {
  try {
    const dbConfig = await getDatabaseConfig();
    pool = new Pool({
      host: dbConfig.host,
      user: dbConfig.user,
      password: dbConfig.password,
      database: dbConfig.database,
      port: dbConfig.port,
      max: 10, // Maximum number of clients in the pool
      idleTimeoutMillis: 30000, // How long a client is allowed to remain idle before being closed
      connectionTimeoutMillis: 2000, // How long to wait for a connection
      ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
    });
    
    // Test the connection
    const client = await pool.connect();
    client.release();
    
    console.log('Database connection pool initialized');
    return pool;
  } catch (error) {
    console.error('Failed to initialize database connection pool:', error);
    throw error;
  }
}

// Error handling middleware
function errorHandler(err, req, res, next) {
  console.error('Unhandled error:', err);
  res.status(500).json({ 
    error: 'Internal server error',
    message: process.env.NODE_ENV === 'development' ? err.message : undefined
  });
}

// API Routes
const apiRouter = express.Router();

// GET - API Status
apiRouter.get('/status', (req, res) => {
  res.json({ 
    status: 'ok', 
    timestamp: new Date().toISOString(),
    version: '1.1.0',
    nodeVersion: process.version
  });
});

// GET - Check balance
apiRouter.get('/balance/:accountNumber', async (req, res, next) => {
  try {
    const client = await pool.connect();
    try {
      const result = await client.query(
        'SELECT balance FROM accounts WHERE account_number = $1',
        [req.params.accountNumber]
      );
      
      if (result.rows.length === 0) {
        return res.status(404).json({ error: 'Account not found' });
      }
      
      return res.json({ balance: result.rows[0].balance });
    } finally {
      client.release();
    }
  } catch (error) {
    next(error);
  }
});

// POST - Deposit
apiRouter.post('/deposit', async (req, res, next) => {
  const { accountNumber, amount } = req.body;
  
  if (!accountNumber || !amount || amount <= 0) {
    return res.status(400).json({ error: 'Invalid request parameters' });
  }
  
  try {
    const client = await pool.connect();
    try {
      // Start transaction
      await client.query('BEGIN');
      
      // Check if account exists
      const accountResult = await client.query(
        'SELECT id, balance FROM accounts WHERE account_number = $1',
        [accountNumber]
      );
      
      if (accountResult.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Account not found' });
      }
      
      const accountId = accountResult.rows[0].id;
      const newBalance = parseFloat(accountResult.rows[0].balance) + parseFloat(amount);
      
      // Update balance
      await client.query(
        'UPDATE accounts SET balance = $1 WHERE id = $2',
        [newBalance, accountId]
      );
      
      // Record transaction
      await client.query(
        'INSERT INTO transactions (account_id, type, amount) VALUES ($1, $2, $3)',
        [accountId, 'deposit', amount]
      );
      
      // Commit transaction
      await client.query('COMMIT');
      
      return res.json({ success: true, newBalance });
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  } catch (error) {
    next(error);
  }
});

// POST - Withdraw
apiRouter.post('/withdraw', async (req, res, next) => {
  const { accountNumber, amount } = req.body;
  
  if (!accountNumber || !amount || amount <= 0) {
    return res.status(400).json({ error: 'Invalid request parameters' });
  }
  
  try {
    const client = await pool.connect();
    try {
      // Start transaction
      await client.query('BEGIN');
      
      // Check if account exists and has sufficient funds
      const accountResult = await client.query(
        'SELECT id, balance FROM accounts WHERE account_number = $1',
        [accountNumber]
      );
      
      if (accountResult.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Account not found' });
      }
      
      const accountId = accountResult.rows[0].id;
      const currentBalance = parseFloat(accountResult.rows[0].balance);
      
      if (currentBalance < amount) {
        await client.query('ROLLBACK');
        return res.status(400).json({ error: 'Insufficient funds' });
      }
      
      const newBalance = currentBalance - parseFloat(amount);
      
      // Update balance
      await client.query(
        'UPDATE accounts SET balance = $1 WHERE id = $2',
        [newBalance, accountId]
      );
      
      // Record transaction
      await client.query(
        'INSERT INTO transactions (account_id, type, amount) VALUES ($1, $2, $3)',
        [accountId, 'withdrawal', amount]
      );
      
      // Commit transaction
      await client.query('COMMIT');
      
      return res.json({ success: true, newBalance });
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  } catch (error) {
    next(error);
  }
});

// GET - Transaction history
apiRouter.get('/transactions/:accountNumber', async (req, res, next) => {
  try {
    const client = await pool.connect();
    try {
      const accountResult = await client.query(
        'SELECT id FROM accounts WHERE account_number = $1',
        [req.params.accountNumber]
      );
      
      if (accountResult.rows.length === 0) {
        return res.status(404).json({ error: 'Account not found' });
      }
      
      const accountId = accountResult.rows[0].id;
      
      const transactionResult = await client.query(
        'SELECT type, amount, transaction_date FROM transactions WHERE account_id = $1 ORDER BY transaction_date DESC LIMIT 10',
        [accountId]
      );
      
      return res.json({ transactions: transactionResult.rows });
    } finally {
      client.release();
    }
  } catch (error) {
    next(error);
  }
});

// Mount API routes
app.use('/api', apiRouter);

// Create a test account if none exists
async function createTestAccountIfNeeded() {
  try {
    const client = await pool.connect();
    try {
      const result = await client.query('SELECT COUNT(*) as count FROM accounts');
      
      if (parseInt(result.rows[0].count) === 0) {
        await client.query(
          'INSERT INTO accounts (account_number, balance) VALUES ($1, $2)',
          ['12345678', 1000.00]
        );
        console.log('Created test account: 12345678 with $1000.00');
      }
    } finally {
      client.release();
    }
  } catch (error) {
    console.error('Error creating test account:', error);
  }
}

// Catch all other requests and return the React app
app.get('*', (req, res) => {
  res.sendFile(path.join(frontendBuildPath, 'index.html'));
});

// Add error handling middleware
app.use(errorHandler);

// Start server
async function startServer() {
  try {
    // Initialize database connection pool
    await initializeDbPool();
    
    const PORT = process.env.PORT || 3000;
    app.listen(PORT, () => {
      console.log(`Server running on port ${PORT}`);
      console.log(`Node.js version: ${process.version}`);
      console.log(`Using Secrets Manager secret: ${secretName} in region: ${config.region}`);
      
      // Try to connect to the database and create test account
      setTimeout(createTestAccountIfNeeded, 5000);
    });
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
}

// Start the server
startServer();