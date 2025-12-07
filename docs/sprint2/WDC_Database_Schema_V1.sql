-- ============================================================================
-- WCD PLATFORM - DATABASE SCHEMA V1
-- ============================================================================
-- Author: Serhii Sokyrko
-- Date: October 2025
-- Sprint: 2
-- Database: PostgreSQL 15+ (Supabase)
-- Learning Outcome: LO7 (Distributed Data)
--
-- Purpose:
-- This schema defines the persistent data model for the WCD Platform,
-- supporting user accounts, competitions, chat, and GDPR compliance.
--
-- Design Principles:
-- 1. ACID Guarantees: Foreign keys, constraints, transactions
-- 2. GDPR Compliance: Soft deletes, audit trails, data retention policies
-- 3. Performance: Strategic indexes on high-query columns
-- 4. Scalability: UUID primary keys (distributed-friendly)
-- ============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";  -- For gen_random_uuid()

-- ============================================================================
-- TABLE: users
-- Purpose: User account authentication and authorization
-- ============================================================================
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255),  -- bcrypt hash (nullable for OAuth users)
    email_verified BOOLEAN DEFAULT FALSE,
    oauth_provider VARCHAR(50) CHECK (oauth_provider IN ('google', 'github', 'apple', NULL)),
    oauth_id VARCHAR(255),  -- External OAuth user ID
    role VARCHAR(20) DEFAULT 'user' CHECK (role IN ('user', 'admin', 'moderator')),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    deleted_at TIMESTAMP,  -- Soft delete (GDPR grace period)
    last_login_at TIMESTAMP,
    CONSTRAINT unique_oauth UNIQUE (oauth_provider, oauth_id)
);

-- Indexes for performance
CREATE INDEX idx_users_email ON users(email) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_oauth ON users(oauth_provider, oauth_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_deleted ON users(deleted_at) WHERE deleted_at IS NOT NULL;  -- Cleanup job

COMMENT ON TABLE users IS 'User accounts for authentication and authorization';
COMMENT ON COLUMN users.password_hash IS 'bcrypt hash (cost factor 12), nullable for OAuth-only users';
COMMENT ON COLUMN users.deleted_at IS 'Soft delete timestamp for GDPR 30-day grace period';

-- ============================================================================
-- TABLE: user_profiles
-- Purpose: User profile information (1:1 with users)
-- ============================================================================
CREATE TABLE user_profiles (
    id UUID PRIMARY KEY,  -- Same as users.id (1:1 relationship)
    user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    display_name VARCHAR(100) NOT NULL,
    avatar_url VARCHAR(500),  -- Cloudflare R2 URL
    bio TEXT CHECK (LENGTH(bio) <= 500),
    date_of_birth DATE NOT NULL,  -- Required for age verification (18+)
    country VARCHAR(2),  -- ISO 3166-1 alpha-2 code (e.g., 'NL', 'DE')
    verified BOOLEAN DEFAULT FALSE,  -- Veriff KYC verification status
    verified_at TIMESTAMP,
    verification_session_id VARCHAR(255),  -- Veriff session ID
    total_drinks INT DEFAULT 0 CHECK (total_drinks >= 0),  -- Cached from events (updated by Projector Service)
    total_points INT DEFAULT 0 CHECK (total_points >= 0),
    global_rank INT,  -- Global rank (updated daily by batch job)
    streak_days INT DEFAULT 0 CHECK (streak_days >= 0),  -- Consecutive days with activity
    last_activity_date DATE,  -- For streak calculation
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT age_check CHECK (EXTRACT(YEAR FROM AGE(date_of_birth)) >= 18)
);

-- Indexes
CREATE INDEX idx_profiles_user_id ON user_profiles(user_id);
CREATE INDEX idx_profiles_verified ON user_profiles(verified) WHERE verified = TRUE;
CREATE INDEX idx_profiles_rank ON user_profiles(global_rank) WHERE global_rank IS NOT NULL;
CREATE INDEX idx_profiles_total_drinks ON user_profiles(total_drinks DESC);  -- For leaderboard fallback

COMMENT ON TABLE user_profiles IS 'User profile information (1:1 with users)';
COMMENT ON COLUMN user_profiles.verified IS 'TRUE if user passed Veriff KYC (required for high-stakes competitions)';
COMMENT ON COLUMN user_profiles.total_drinks IS 'Cached value from events (updated by Projector Service, eventual consistency)';

-- ============================================================================
-- TABLE: competitions
-- Purpose: Competition metadata and configuration
-- ============================================================================
CREATE TABLE competitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(200) NOT NULL,
    description TEXT,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP NOT NULL,
    max_participants INT DEFAULT 1000 CHECK (max_participants > 0),
    entry_fee DECIMAL(10, 2) DEFAULT 0.00 CHECK (entry_fee >= 0),
    prize_pool DECIMAL(10, 2) DEFAULT 0.00 CHECK (prize_pool >= 0),
    verification_required BOOLEAN DEFAULT TRUE,  -- Require Veriff KYC to participate
    status VARCHAR(20) DEFAULT 'upcoming' CHECK (status IN ('upcoming', 'active', 'completed', 'cancelled')),
    visibility VARCHAR(20) DEFAULT 'public' CHECK (visibility IN ('public', 'private', 'invite_only')),
    rules TEXT,  -- Competition-specific rules (JSON or markdown)
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,  -- Competition creator
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT valid_time_range CHECK (end_time > start_time)
);

-- Indexes
CREATE INDEX idx_competitions_status ON competitions(status);
CREATE INDEX idx_competitions_time ON competitions(start_time, end_time);
CREATE INDEX idx_competitions_creator ON competitions(created_by);

COMMENT ON TABLE competitions IS 'Competition metadata and configuration';
COMMENT ON COLUMN competitions.verification_required IS 'If TRUE, only Veriff-verified users can participate';

-- ============================================================================
-- TABLE: competition_participants
-- Purpose: User participation in competitions (many-to-many relationship)
-- ============================================================================
CREATE TABLE competition_participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    competition_id UUID NOT NULL REFERENCES competitions(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    registered_at TIMESTAMP DEFAULT NOW(),
    final_rank INT CHECK (final_rank > 0),  -- Rank at competition end (NULL during active competition)
    final_score INT CHECK (final_score >= 0),  -- Total drinks during competition
    prize_amount DECIMAL(10, 2) DEFAULT 0.00 CHECK (prize_amount >= 0),  -- Prize won (if any)
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'disqualified', 'completed')),
    CONSTRAINT unique_participant UNIQUE (competition_id, user_id)
);

-- Indexes
CREATE INDEX idx_participants_competition ON competition_participants(competition_id);
CREATE INDEX idx_participants_user ON competition_participants(user_id);
CREATE INDEX idx_participants_rank ON competition_participants(competition_id, final_rank) WHERE final_rank IS NOT NULL;

COMMENT ON TABLE competition_participants IS 'User participation in competitions (many-to-many)';

-- ============================================================================
-- TABLE: events
-- Purpose: Event sourcing log for drink events (written by Projector Service)
-- Retention: 90 days (auto-deleted by cleanup job)
-- ============================================================================
CREATE TABLE events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    competition_id UUID REFERENCES competitions(id) ON DELETE SET NULL,
    event_type VARCHAR(50) DEFAULT 'drink_recorded' CHECK (event_type IN ('drink_recorded', 'badge_earned', 'streak_updated')),
    amount INT CHECK (amount > 0 AND amount <= 10),  -- Drinks recorded (1-10)
    points INT CHECK (points >= 0),  -- Points earned (calculated by Projector Service)
    metadata JSONB,  -- Additional event data (e.g., location, drink type)
    created_at TIMESTAMP DEFAULT NOW(),
    processed_at TIMESTAMP  -- When Projector Service processed this event
);

-- Indexes
CREATE INDEX idx_events_user_time ON events(user_id, created_at DESC);
CREATE INDEX idx_events_competition ON events(competition_id, created_at DESC);
CREATE INDEX idx_events_created ON events(created_at);  -- For retention policy cleanup

COMMENT ON TABLE events IS 'Event sourcing log for drink events (90-day retention)';
COMMENT ON COLUMN events.processed_at IS 'Timestamp when Projector Service processed this event (eventual consistency tracking)';

-- ============================================================================
-- TABLE: chat_rooms
-- Purpose: Chat room metadata (competitions, teams, direct messages)
-- ============================================================================
CREATE TABLE chat_rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(200),
    room_type VARCHAR(20) NOT NULL CHECK (room_type IN ('competition', 'team', 'direct')),
    competition_id UUID REFERENCES competitions(id) ON DELETE CASCADE,  -- NULL for non-competition chats
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_chat_rooms_type ON chat_rooms(room_type);
CREATE INDEX idx_chat_rooms_competition ON chat_rooms(competition_id) WHERE competition_id IS NOT NULL;

COMMENT ON TABLE chat_rooms IS 'Chat room metadata (competitions, teams, direct messages)';

-- ============================================================================
-- TABLE: chat_room_members
-- Purpose: Chat room membership (many-to-many relationship)
-- ============================================================================
CREATE TABLE chat_room_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chat_room_id UUID NOT NULL REFERENCES chat_rooms(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    joined_at TIMESTAMP DEFAULT NOW(),
    last_read_at TIMESTAMP,  -- For unread message count
    role VARCHAR(20) DEFAULT 'member' CHECK (role IN ('member', 'admin', 'moderator')),
    CONSTRAINT unique_membership UNIQUE (chat_room_id, user_id)
);

-- Indexes
CREATE INDEX idx_chat_members_room ON chat_room_members(chat_room_id);
CREATE INDEX idx_chat_members_user ON chat_room_members(user_id);

COMMENT ON TABLE chat_room_members IS 'Chat room membership (many-to-many)';

-- ============================================================================
-- TABLE: messages
-- Purpose: Chat messages (text, images, system notifications)
-- Retention: 30 days (auto-deleted by cleanup job)
-- ============================================================================
CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chat_room_id UUID NOT NULL REFERENCES chat_rooms(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,  -- NULL for system messages or deleted users
    message_type VARCHAR(20) DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'system')),
    content TEXT NOT NULL CHECK (LENGTH(content) <= 2000),  -- Max 2000 characters
    image_url VARCHAR(500),  -- Cloudflare R2 URL for image messages
    metadata JSONB,  -- Additional message data (e.g., mentions, reactions)
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    deleted_at TIMESTAMP  -- Soft delete (user can delete own messages)
);

-- Indexes
CREATE INDEX idx_messages_room_time ON messages(chat_room_id, created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_messages_user ON messages(user_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_messages_created ON messages(created_at);  -- For retention policy cleanup

COMMENT ON TABLE messages IS 'Chat messages (30-day retention)';
COMMENT ON COLUMN messages.deleted_at IS 'Soft delete for user-initiated message deletion';

-- ============================================================================
-- TABLE: badges
-- Purpose: Badge definitions (achievements)
-- ============================================================================
CREATE TABLE badges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT NOT NULL,
    icon_url VARCHAR(500),  -- Badge icon image URL
    criteria JSONB NOT NULL,  -- Badge earning criteria (e.g., {"total_drinks": 100})
    rarity VARCHAR(20) DEFAULT 'common' CHECK (rarity IN ('common', 'rare', 'epic', 'legendary')),
    created_at TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE badges IS 'Badge definitions (achievements)';
COMMENT ON COLUMN badges.criteria IS 'JSON criteria for earning badge (e.g., {"total_drinks": 100, "streak_days": 7})';

-- ============================================================================
-- TABLE: user_badges
-- Purpose: Badges earned by users (many-to-many relationship)
-- ============================================================================
CREATE TABLE user_badges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    badge_id UUID NOT NULL REFERENCES badges(id) ON DELETE CASCADE,
    earned_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT unique_user_badge UNIQUE (user_id, badge_id)
);

-- Indexes
CREATE INDEX idx_user_badges_user ON user_badges(user_id);
CREATE INDEX idx_user_badges_earned ON user_badges(earned_at DESC);

COMMENT ON TABLE user_badges IS 'Badges earned by users (many-to-many)';

-- ============================================================================
-- TABLE: friendships
-- Purpose: User friendship relationships (bidirectional)
-- ============================================================================
CREATE TABLE friendships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    friend_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'blocked')),
    created_at TIMESTAMP DEFAULT NOW(),
    accepted_at TIMESTAMP,
    CONSTRAINT no_self_friendship CHECK (user_id != friend_id),
    CONSTRAINT unique_friendship UNIQUE (user_id, friend_id)
);

-- Indexes
CREATE INDEX idx_friendships_user ON friendships(user_id);
CREATE INDEX idx_friendships_friend ON friendships(friend_id);
CREATE INDEX idx_friendships_status ON friendships(status);

COMMENT ON TABLE friendships IS 'User friendship relationships (bidirectional)';

-- ============================================================================
-- TABLE: user_consents
-- Purpose: GDPR consent records (consent management)
-- ============================================================================
CREATE TABLE user_consents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    consent_type VARCHAR(50) NOT NULL CHECK (consent_type IN ('marketing_emails', 'push_notifications', 'analytics', 'facial_biometrics')),
    granted BOOLEAN DEFAULT FALSE,
    granted_at TIMESTAMP,
    withdrawn_at TIMESTAMP,
    ip_address INET,  -- IP address when consent was given (audit trail)
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_consents_user ON user_consents(user_id);
CREATE INDEX idx_consents_type ON user_consents(consent_type);

COMMENT ON TABLE user_consents IS 'GDPR consent records (Article 7 - conditions for consent)';
COMMENT ON COLUMN user_consents.ip_address IS 'IP address when consent was granted (audit trail for GDPR compliance)';

-- ============================================================================
-- TABLE: audit_logs
-- Purpose: Audit trail for security and GDPR compliance
-- Retention: 90 days (legal requirement)
-- ============================================================================
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL,  -- e.g., 'user_login', 'profile_updated', 'account_deleted'
    resource_type VARCHAR(50),  -- e.g., 'user', 'competition', 'message'
    resource_id UUID,
    metadata JSONB,  -- Additional context (e.g., changed fields, IP address)
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_action ON audit_logs(action);
CREATE INDEX idx_audit_logs_created ON audit_logs(created_at);  -- For retention policy cleanup

COMMENT ON TABLE audit_logs IS 'Audit trail for security and GDPR compliance (90-day retention)';

-- ============================================================================
-- VIEWS
-- ============================================================================

-- View: Active competitions (upcoming or ongoing)
CREATE VIEW active_competitions AS
SELECT
    c.id,
    c.name,
    c.start_time,
    c.end_time,
    c.max_participants,
    c.entry_fee,
    c.prize_pool,
    COUNT(cp.id) AS current_participants
FROM competitions c
LEFT JOIN competition_participants cp ON c.id = cp.competition_id AND cp.status = 'active'
WHERE c.status IN ('upcoming', 'active')
GROUP BY c.id, c.name, c.start_time, c.end_time, c.max_participants, c.entry_fee, c.prize_pool;

COMMENT ON VIEW active_competitions IS 'Active competitions with participant counts';

-- View: User statistics (for profile display)
CREATE VIEW user_statistics AS
SELECT
    u.id AS user_id,
    up.display_name,
    up.total_drinks,
    up.total_points,
    up.global_rank,
    up.streak_days,
    COUNT(DISTINCT cp.competition_id) AS competitions_joined,
    COUNT(DISTINCT ub.badge_id) AS badges_earned,
    COUNT(DISTINCT f.friend_id) AS friend_count
FROM users u
JOIN user_profiles up ON u.id = up.user_id
LEFT JOIN competition_participants cp ON u.id = cp.user_id
LEFT JOIN user_badges ub ON u.id = ub.user_id
LEFT JOIN friendships f ON u.id = f.user_id AND f.status = 'accepted'
WHERE u.deleted_at IS NULL
GROUP BY u.id, up.display_name, up.total_drinks, up.total_points, up.global_rank, up.streak_days;

COMMENT ON VIEW user_statistics IS 'User statistics aggregated for profile display';

-- ============================================================================
-- FUNCTIONS & TRIGGERS
-- ============================================================================

-- Function: Update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to relevant tables
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_profiles_updated_at BEFORE UPDATE ON user_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_competitions_updated_at BEFORE UPDATE ON competitions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_chat_rooms_updated_at BEFORE UPDATE ON chat_rooms
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- DATA RETENTION CLEANUP FUNCTIONS
-- ============================================================================

-- Function: Delete old messages (30-day retention)
CREATE OR REPLACE FUNCTION cleanup_old_messages()
RETURNS void AS $$
BEGIN
    DELETE FROM messages
    WHERE created_at < NOW() - INTERVAL '30 days';
END;
$$ LANGUAGE plpgsql;

-- Function: Delete old events (90-day retention)
CREATE OR REPLACE FUNCTION cleanup_old_events()
RETURNS void AS $$
BEGIN
    DELETE FROM events
    WHERE created_at < NOW() - INTERVAL '90 days';
END;
$$ LANGUAGE plpgsql;

-- Function: Delete old audit logs (90-day retention)
CREATE OR REPLACE FUNCTION cleanup_old_audit_logs()
RETURNS void AS $$
BEGIN
    DELETE FROM audit_logs
    WHERE created_at < NOW() - INTERVAL '90 days';
END;
$$ LANGUAGE plpgsql;

-- Function: Hard delete soft-deleted users (30-day grace period)
CREATE OR REPLACE FUNCTION cleanup_deleted_users()
RETURNS void AS $$
BEGIN
    DELETE FROM users
    WHERE deleted_at IS NOT NULL
    AND deleted_at < NOW() - INTERVAL '30 days';
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION cleanup_old_messages IS 'Delete messages older than 30 days (run daily)';
COMMENT ON FUNCTION cleanup_old_events IS 'Delete events older than 90 days (run daily)';
COMMENT ON FUNCTION cleanup_old_audit_logs IS 'Delete audit logs older than 90 days (run daily)';
COMMENT ON FUNCTION cleanup_deleted_users IS 'Hard delete soft-deleted users after 30-day grace period (run weekly)';

-- ============================================================================
-- SEED DATA (Development/Testing)
-- ============================================================================

-- Insert sample badges
INSERT INTO badges (id, name, description, criteria, rarity) VALUES
(gen_random_uuid(), 'First Drink', 'Recorded your first drink', '{"total_drinks": 1}'::jsonb, 'common'),
(gen_random_uuid(), 'Century', 'Reached 100 total drinks', '{"total_drinks": 100}'::jsonb, 'rare'),
(gen_random_uuid(), 'Millennium', 'Reached 1000 total drinks', '{"total_drinks": 1000}'::jsonb, 'epic'),
(gen_random_uuid(), 'Week Streak', 'Maintained a 7-day streak', '{"streak_days": 7}'::jsonb, 'rare'),
(gen_random_uuid(), 'Month Streak', 'Maintained a 30-day streak', '{"streak_days": 30}'::jsonb, 'legendary'),
(gen_random_uuid(), 'Competition Winner', 'Won first place in a competition', '{"competition_wins": 1}'::jsonb, 'epic');

-- ============================================================================
-- DATABASE STATISTICS
-- ============================================================================

-- Show table sizes (for monitoring growth)
CREATE VIEW database_statistics AS
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
    pg_total_relation_size(schemaname||'.'||tablename) AS size_bytes
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

COMMENT ON VIEW database_statistics IS 'Table sizes for monitoring database growth';

-- ============================================================================
-- GRANTS (Security)
-- ============================================================================

-- Application user (used by microservices)
-- Assumes role 'wcd_app_user' exists
-- GRANT CONNECT ON DATABASE postgres TO wcd_app_user;
-- GRANT USAGE ON SCHEMA public TO wcd_app_user;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO wcd_app_user;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO wcd_app_user;

-- Read-only user (for analytics, reporting)
-- GRANT CONNECT ON DATABASE postgres TO wcd_readonly_user;
-- GRANT USAGE ON SCHEMA public TO wcd_readonly_user;
-- GRANT SELECT ON ALL TABLES IN SCHEMA public TO wcd_readonly_user;

-- ============================================================================
-- END OF SCHEMA
-- ============================================================================

-- Summary:
-- - 15 core tables (users, competitions, chat, events, badges, etc.)
-- - 2 views (active_competitions, user_statistics)
-- - 5 cleanup functions (GDPR data retention)
-- - Indexes for performance (20+ indexes)
-- - Triggers for updated_at timestamps
-- - Foreign keys for referential integrity
-- - CHECK constraints for data validation
-- - GDPR compliance (soft deletes, audit trails, consent records)
