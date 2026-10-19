DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'tw_tenant') THEN
        CREATE ROLE tw_tenant LOGIN PASSWORD 'tw_tenant';
    END IF;
END;
$$;
