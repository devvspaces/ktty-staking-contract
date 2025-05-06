-- Create tables for all your entities
CREATE TABLE tiers (
  id BIGINT PRIMARY KEY,
  name TEXT NOT NULL,
  min_stake NUMERIC NOT NULL,
  max_stake NUMERIC NOT NULL,
  lockup_period BIGINT NOT NULL,
  apy NUMERIC NOT NULL,
  is_active BOOLEAN NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE reward_tokens (
  address TEXT PRIMARY KEY,
  symbol TEXT NOT NULL,
  reward_rate NUMERIC NOT NULL,
  is_active BOOLEAN NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE tier_reward_tokens (
  tier_id BIGINT REFERENCES tiers(id),
  token_address TEXT REFERENCES reward_tokens(address),
  PRIMARY KEY (tier_id, token_address),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE stakes (
  id BIGINT PRIMARY KEY,
  owner TEXT NOT NULL,
  amount NUMERIC NOT NULL,
  tier_id BIGINT REFERENCES tiers(id),
  start_time BIGINT NOT NULL,
  end_time BIGINT NOT NULL, 
  has_withdrawn BOOLEAN DEFAULT FALSE,
  has_claimed_rewards BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE reward_claims (
  id SERIAL PRIMARY KEY,
  stake_id BIGINT REFERENCES stakes(id),
  owner TEXT NOT NULL,
  token_address TEXT NOT NULL,
  amount NUMERIC NOT NULL,
  block_timestamp BIGINT NOT NULL,
  transaction_hash TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);