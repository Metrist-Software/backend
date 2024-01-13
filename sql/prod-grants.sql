CREATE DATABASE production_projections;
CREATE DATABASE production_eventstore;

-- Set the passwords through pgAdmin4 and stash them into secrets manager
-- `mix phx.gen.secret` is a handy strong pw generator.
CREATE ROLE backend_projections WITH LOGIN;
CREATE ROLE backend_eventstore WITH LOGIN;

\c production_eventstore;

GRANT CONNECT ON DATABASE production_projections TO backend_eventstore;
GRANT CREATE ON SCHEMA public TO backend_eventstore;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO backend_eventstore;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO backend_eventstore;

CREATE SCHEMA migration;
GRANT CREATE ON SCHEMA migration TO backend_eventstore;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA migration TO backend_eventstore;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA migration TO backend_eventstore;

\c production_projections;

GRANT CONNECT, CREATE ON DATABASE production_projections TO backend_projections;
GRANT CREATE ON SCHEMA public TO backend_projections;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO backend_projections;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO backend_projections;
