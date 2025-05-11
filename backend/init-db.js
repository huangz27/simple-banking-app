const { Pool } = require('pg');
const { SecretsManagerClient, GetSecretValueCommand } = require('@aws-sdk/client-secrets-manager');

// Get AWS region from environment or use default
const region = process.env.AWS_REGION || 'ap-southeast-1';
const secretName = process.env.SECRETS_MANAGER_NAME;

// Create Secrets Manager client
const secretsManager = new SecretsManagerClient({ region });

async function initializeDatabase() {
  try {
    console.log('Initializing database...');
    
    // Get database credentials from Secrets Manager
    console.log(`Fetching database credentials from secret: ${secretName}`);
    const command = new GetSecretValueCommand({ SecretId: secretName });
    const response = await secretsManager.send(command);
    const secretData = JSON.parse(response.SecretString);
    
    // Create database connection
    const pool = new Pool({
      host: secretData.host,
      user: secretData.username,
      password: secretData.password,
      database: secretData.dbname,
      port: secretData.port || 5432,
      ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
    });
    
    // Connect to database
    const client = await pool.connect();
    
    try {
      // Create tables
      console.log('Creating tables...');
      
      // Create accounts table
      await client.query(`
        CREATE TABLE IF NOT EXISTS accounts (
          id SERIAL PRIMARY KEY,
          account_number VARCHAR(20) UNIQUE NOT NULL,
          balance DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);
      
      // Create updated_at trigger function
      await client.query(`
        CREATE OR REPLACE FUNCTION update_updated_at_column()
        RETURNS TRIGGER AS $$
        BEGIN
          NEW.updated_at = CURRENT_TIMESTAMP;
          RETURN NEW;
        END;
        $$ LANGUAGE plpgsql
      `);
      
      // Create trigger for accounts table
      await client.query(`
        DROP TRIGGER IF EXISTS update_accounts_updated_at ON accounts;
        CREATE TRIGGER update_accounts_updated_at
        BEFORE UPDATE ON accounts
        FOR EACH ROW
        EXECUTE FUNCTION update_updated_at_column()
      `);
      
      // Create transactions table
      await client.query(`
        CREATE TABLE IF NOT EXISTS transactions (
          id SERIAL PRIMARY KEY,
          account_id INTEGER NOT NULL,
          type VARCHAR(10) NOT NULL CHECK (type IN ('deposit', 'withdrawal')),
          amount DECIMAL(15, 2) NOT NULL,
          transaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (account_id) REFERENCES accounts(id)
        )
      `);
      
      // Create test account if none exists
      const accountResult = await client.query('SELECT COUNT(*) as count FROM accounts');
      
      if (parseInt(accountResult.rows[0].count) === 0) {
        console.log('Creating test account...');
        await client.query(
          'INSERT INTO accounts (account_number, balance) VALUES ($1, $2)',
          ['12345678', 1000.00]
        );
        console.log('Created test account: 12345678 with $1000.00');
      } else {
        console.log('Test account already exists, skipping creation.');
      }
      
      console.log('Database initialization completed successfully.');
    } finally {
      client.release();
      await pool.end();
    }
  } catch (error) {
    console.error('Error initializing database:', error);
    process.exit(1);
  }
}

// Run the initialization
initializeDatabase();