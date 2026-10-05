-- ==============================================================================
-- FinanceTracker — Supabase Cloud Database Schema & Realtime Setup
-- ==============================================================================
-- Instructions:
-- 1. Open your Supabase Dashboard: https://supabase.com/dashboard
-- 2. Select your project (or create a new free project)
-- 3. Navigate to "SQL Editor" on the left sidebar
-- 4. Paste the entire content of this script and click "Run"
-- 5. Copy your Project URL & Anon Public Key from Settings -> API into the app!
-- ==============================================================================

-- 1. Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Auto-Update Timestamp Function
CREATE OR REPLACE FUNCTION set_updated_at_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Ledgers Table
CREATE TABLE IF NOT EXISTS public.ledgers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    currency TEXT NOT NULL DEFAULT 'MYR',
    color_hex TEXT NOT NULL DEFAULT '#1C1C1E',
    is_default BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

DROP TRIGGER IF EXISTS trigger_ledgers_updated_at ON public.ledgers;
CREATE TRIGGER trigger_ledgers_updated_at
BEFORE UPDATE ON public.ledgers
FOR EACH ROW EXECUTE FUNCTION set_updated_at_timestamp();

-- 4. Categories Table
CREATE TABLE IF NOT EXISTS public.categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    icon TEXT NOT NULL DEFAULT 'tag.fill',
    color_hex TEXT NOT NULL DEFAULT '#A0A0A0',
    type TEXT NOT NULL DEFAULT 'expense',
    is_system BOOLEAN NOT NULL DEFAULT false,
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

DROP TRIGGER IF EXISTS trigger_categories_updated_at ON public.categories;
CREATE TRIGGER trigger_categories_updated_at
BEFORE UPDATE ON public.categories
FOR EACH ROW EXECUTE FUNCTION set_updated_at_timestamp();

-- 5. Accounts Table (Bank Accounts, Wallets, Cards)
CREATE TABLE IF NOT EXISTS public.accounts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    institution TEXT NOT NULL DEFAULT '',
    account_type TEXT NOT NULL DEFAULT 'checking',
    last_four TEXT NOT NULL DEFAULT '',
    color_hex TEXT NOT NULL DEFAULT '#1C1C1E',
    icon TEXT NOT NULL DEFAULT 'building.columns.fill',
    starting_balance NUMERIC NOT NULL DEFAULT 0,
    credit_limit NUMERIC,
    ledger_id UUID REFERENCES public.ledgers(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

DROP TRIGGER IF EXISTS trigger_accounts_updated_at ON public.accounts;
CREATE TRIGGER trigger_accounts_updated_at
BEFORE UPDATE ON public.accounts
FOR EACH ROW EXECUTE FUNCTION set_updated_at_timestamp();

-- 6. Transactions Table
CREATE TABLE IF NOT EXISTS public.transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT,
    amount NUMERIC NOT NULL,
    type TEXT NOT NULL DEFAULT 'expense',
    date TIMESTAMPTZ NOT NULL DEFAULT now(),
    note TEXT NOT NULL DEFAULT '',
    receipt_image_base64 TEXT,
    ledger_id UUID REFERENCES public.ledgers(id) ON DELETE CASCADE,
    category_id UUID REFERENCES public.categories(id) ON DELETE SET NULL,
    account_id UUID REFERENCES public.accounts(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_transactions_date ON public.transactions(date DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_ledger ON public.transactions(ledger_id);
CREATE INDEX IF NOT EXISTS idx_transactions_updated_at ON public.transactions(updated_at DESC);

DROP TRIGGER IF EXISTS trigger_transactions_updated_at ON public.transactions;
CREATE TRIGGER trigger_transactions_updated_at
BEFORE UPDATE ON public.transactions
FOR EACH ROW EXECUTE FUNCTION set_updated_at_timestamp();

-- 7. Budgets Table
CREATE TABLE IF NOT EXISTS public.budgets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    amount NUMERIC NOT NULL,
    period TEXT NOT NULL DEFAULT 'monthly',
    alert_threshold NUMERIC NOT NULL DEFAULT 0.8,
    category_id UUID REFERENCES public.categories(id) ON DELETE CASCADE,
    ledger_id UUID REFERENCES public.ledgers(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

DROP TRIGGER IF EXISTS trigger_budgets_updated_at ON public.budgets;
CREATE TRIGGER trigger_budgets_updated_at
BEFORE UPDATE ON public.budgets
FOR EACH ROW EXECUTE FUNCTION set_updated_at_timestamp();

-- 8. Recurring Rules Table
CREATE TABLE IF NOT EXISTS public.recurring_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    amount NUMERIC NOT NULL,
    type TEXT NOT NULL DEFAULT 'expense',
    note TEXT NOT NULL DEFAULT '',
    frequency TEXT NOT NULL DEFAULT 'monthly',
    interval_value INT NOT NULL DEFAULT 1,
    next_due_date TIMESTAMPTZ NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    category_id UUID REFERENCES public.categories(id) ON DELETE SET NULL,
    ledger_id UUID REFERENCES public.ledgers(id) ON DELETE CASCADE,
    account_id UUID REFERENCES public.accounts(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

DROP TRIGGER IF EXISTS trigger_recurring_rules_updated_at ON public.recurring_rules;
CREATE TRIGGER trigger_recurring_rules_updated_at
BEFORE UPDATE ON public.recurring_rules
FOR EACH ROW EXECUTE FUNCTION set_updated_at_timestamp();

-- 9. Tags Table
CREATE TABLE IF NOT EXISTS public.tags (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    color_hex TEXT NOT NULL DEFAULT '#636366',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

DROP TRIGGER IF EXISTS trigger_tags_updated_at ON public.tags;
CREATE TRIGGER trigger_tags_updated_at
BEFORE UPDATE ON public.tags
FOR EACH ROW EXECUTE FUNCTION set_updated_at_timestamp();

-- 10. Transaction Tags Junction
CREATE TABLE IF NOT EXISTS public.transaction_tags (
    transaction_id UUID REFERENCES public.transactions(id) ON DELETE CASCADE,
    tag_id UUID REFERENCES public.tags(id) ON DELETE CASCADE,
    PRIMARY KEY (transaction_id, tag_id)
);

-- ==============================================================================
-- Row Level Security (RLS) & Policies
-- ==============================================================================
ALTER TABLE public.ledgers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.budgets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recurring_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transaction_tags ENABLE ROW LEVEL SECURITY;

-- Default open access policies for single-user / family device sync with anon key
DO $$ 
BEGIN
    DROP POLICY IF EXISTS "Allow all for anon on ledgers" ON public.ledgers;
    CREATE POLICY "Allow all for anon on ledgers" ON public.ledgers FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Allow all for anon on categories" ON public.categories;
    CREATE POLICY "Allow all for anon on categories" ON public.categories FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Allow all for anon on accounts" ON public.accounts;
    CREATE POLICY "Allow all for anon on accounts" ON public.accounts FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Allow all for anon on transactions" ON public.transactions;
    CREATE POLICY "Allow all for anon on transactions" ON public.transactions FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Allow all for anon on budgets" ON public.budgets;
    CREATE POLICY "Allow all for anon on budgets" ON public.budgets FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Allow all for anon on recurring_rules" ON public.recurring_rules;
    CREATE POLICY "Allow all for anon on recurring_rules" ON public.recurring_rules FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Allow all for anon on tags" ON public.tags;
    CREATE POLICY "Allow all for anon on tags" ON public.tags FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Allow all for anon on transaction_tags" ON public.transaction_tags;
    CREATE POLICY "Allow all for anon on transaction_tags" ON public.transaction_tags FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
END $$;

-- ==============================================================================
-- Realtime Replication Publication
-- ==============================================================================
-- Enable Realtime broadcast on tables for instant iPhone <-> iPad live sync
ALTER PUBLICATION supabase_realtime ADD TABLE public.ledgers;
ALTER PUBLICATION supabase_realtime ADD TABLE public.categories;
ALTER PUBLICATION supabase_realtime ADD TABLE public.accounts;
ALTER PUBLICATION supabase_realtime ADD TABLE public.transactions;
ALTER PUBLICATION supabase_realtime ADD TABLE public.budgets;
ALTER PUBLICATION supabase_realtime ADD TABLE public.recurring_rules;
ALTER PUBLICATION supabase_realtime ADD TABLE public.tags;
