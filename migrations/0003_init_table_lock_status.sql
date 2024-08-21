-- +goose Up
-- +goose StatementBegin
CREATE TABLE table_lock_status (
    table_name VARCHAR PRIMARY KEY,
    read_only BOOLEAN NOT NULL DEFAULT FALSE
);

INSERT INTO table_lock_status (table_name)
SELECT tablename
FROM pg_tables
WHERE schemaname = 'public' AND tablename NOT IN ('table_lock_status', 'goose_db_version');

CREATE OR REPLACE FUNCTION enforce_read_only() RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT read_only FROM table_lock_status WHERE table_name = TG_TABLE_NAME) THEN
        RAISE EXCEPTION 'table % is read-only', TG_TABLE_NAME;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION handle_read_only_change() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.read_only THEN
        EXECUTE format('
            CREATE OR REPLACE TRIGGER enforce_read_only_trigger
            BEFORE INSERT OR UPDATE OR DELETE ON %I
            FOR EACH STATEMENT
            EXECUTE FUNCTION enforce_read_only();
        ', NEW.table_name);
    ELSE
        EXECUTE format('
            DROP TRIGGER IF EXISTS enforce_read_only_trigger ON %I;
        ', NEW.table_name);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_on_read_only_change
AFTER INSERT OR UPDATE OF read_only ON table_lock_status
FOR EACH ROW
EXECUTE FUNCTION handle_read_only_change();
-- +goose StatementEnd


-- +goose Down
-- +goose StatementBegin
DROP TRIGGER IF EXISTS trigger_on_read_only_change ON table_lock_status;

DROP FUNCTION IF EXISTS handle_read_only_change();

DROP FUNCTION IF EXISTS enforce_read_only();

DROP TABLE IF EXISTS table_lock_status;
-- +goose StatementEnd
