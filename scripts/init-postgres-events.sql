-- EMS Events Database Initialization Script
-- Compatible with plain PostgreSQL (no PostGIS required)

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "plpgsql";

-- Trigger function for updated_at
CREATE OR REPLACE FUNCTION insert_updated_at() RETURNS trigger AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    display_name VARCHAR(255),
    bio TEXT,
    avatar TEXT,
    status VARCHAR(50) DEFAULT 'active',
    role VARCHAR(50) DEFAULT 'user',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Events table
CREATE TABLE IF NOT EXISTS events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(500) NOT NULL,
    description TEXT,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP NOT NULL,
    location VARCHAR(500),
    venue VARCHAR(255),
    city VARCHAR(255),
    max_attendees INTEGER DEFAULT 0,
    current_attendees INTEGER DEFAULT 0,
    price DECIMAL(10, 2) DEFAULT 0,
    currency VARCHAR(10) DEFAULT 'USD',
    image_url TEXT,
    status VARCHAR(50) DEFAULT 'draft',
    category VARCHAR(100),
    organizer_id UUID REFERENCES users(id),
    tags TEXT[],
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Tickets table
CREATE TABLE IF NOT EXISTS tickets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    ticket_type VARCHAR(100) NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    status VARCHAR(50) DEFAULT 'active',
    qr_code TEXT,
    purchase_date TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Speakers table
CREATE TABLE IF NOT EXISTS speakers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    bio TEXT,
    title VARCHAR(255),
    company VARCHAR(255),
    avatar TEXT,
    social_links JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Event speakers junction
CREATE TABLE IF NOT EXISTS event_speakers (
    event_id UUID REFERENCES events(id) ON DELETE CASCADE,
    speaker_id UUID REFERENCES speakers(id) ON DELETE CASCADE,
    PRIMARY KEY (event_id, speaker_id)
);

-- Registrations table
CREATE TABLE IF NOT EXISTS registrations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(50) DEFAULT 'pending',
    registered_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(event_id, user_id)
);

-- Sessions table
CREATE TABLE IF NOT EXISTS sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_events_status ON events(status);
CREATE INDEX IF NOT EXISTS idx_events_start_time ON events(start_time);
CREATE INDEX IF NOT EXISTS idx_events_organizer ON events(organizer_id);
CREATE INDEX IF NOT EXISTS idx_tickets_user ON tickets(user_id);
CREATE INDEX IF NOT EXISTS idx_tickets_event ON tickets(event_id);
CREATE INDEX IF NOT EXISTS idx_registrations_user ON registrations(user_id);
CREATE INDEX IF NOT EXISTS idx_registrations_event ON registrations(event_id);
CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id);

-- Insert sample data
INSERT INTO users (id, username, email, password_hash, display_name, role, status)
VALUES
    ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'admin', 'admin@ems.local', '$2a$10$placeholder', 'Admin User', 'admin', 'active'),
    ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a12', 'organizer1', 'organizer@ems.local', '$2a$10$placeholder', 'John Doe', 'organizer', 'active'),
    ('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a13', 'attendee1', 'attendee@ems.local', '$2a$10$placeholder', 'Jane Smith', 'user', 'active')
ON CONFLICT (username) DO NOTHING;

INSERT INTO events (id, title, description, start_time, end_time, location, venue, city, max_attendees, current_attendees, price, status, category, organizer_id)
VALUES
    ('e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a01', 'Tech Conference 2024', 'Annual technology conference featuring AI and cloud innovations', '2024-12-15 09:00:00', '2024-12-15 18:00:00', 'San Francisco, CA', 'Moscone Center', 'San Francisco', 500, 0, 299.00, 'published', 'Technology', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a12'),
    ('e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a02', 'Music Festival', 'Outdoor music festival with top artists', '2024-11-20 14:00:00', '2024-11-20 23:00:00', 'Austin, TX', 'Zilker Park', 'Austin', 1000, 0, 150.00, 'published', 'Music', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a12'),
    ('e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a03', 'Startup Workshop', 'Hands-on workshop for startup founders', '2024-10-25 10:00:00', '2024-10-25 16:00:00', 'New York, NY', 'WeWork Hudson Yards', 'New York', 50, 0, 49.00, 'published', 'Business', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a12')
ON CONFLICT DO NOTHING;

INSERT INTO speakers (id, name, bio, title, company, social_links)
VALUES
    ('50eebc99-9c0b-4ef8-bb6d-6bb9bd380a01', 'Dr. Emily Watson', 'AI researcher with 15+ years experience', 'Chief AI Scientist', 'DeepMind', '{"twitter": "emilywatson", "linkedin": "emilywatson"}'),
    ('50eebc99-9c0b-4ef8-bb6d-6bb9bd380a02', 'Michael Chen', 'Serial entrepreneur and VC investor', 'General Partner', 'Sequoia Capital', '{"twitter": "mchen", "linkedin": "michaelchen"}')
ON CONFLICT DO NOTHING;

INSERT INTO event_speakers (event_id, speaker_id)
VALUES
    ('e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a01', '50eebc99-9c0b-4ef8-bb6d-6bb9bd380a01'),
    ('e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a01', '50eebc99-9c0b-4ef8-bb6d-6bb9bd380a02')
ON CONFLICT DO NOTHING;
