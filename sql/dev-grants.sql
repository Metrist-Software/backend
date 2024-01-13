CREATE DATABASE develop_projections;
CREATE DATABASE develop_eventstore;

-- Set the passwords through pgAdmin4 and stash them into secrets manager
-- `mix phx.gen.secret` is a handy strong pw generator.
CREATE ROLE backend_projections WITH LOGIN;
CREATE ROLE backend_eventstore WITH LOGIN;

\c develop_eventstore;

GRANT CONNECT ON DATABASE develop_projections TO backend_eventstore;
GRANT CREATE ON SCHEMA public TO backend_eventstore;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO backend_eventstore;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO backend_eventstore;

CREATE SCHEMA migration;
GRANT CREATE ON SCHEMA migration TO backend_eventstore;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA migration TO backend_eventstore;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA migration TO backend_eventstore;

\c develop_projections;

GRANT CONNECT, CREATE ON DATABASE develop_projections TO backend_projections;
GRANT CREATE ON SCHEMA public TO backend_projections;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO backend_projections;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO backend_projections;
