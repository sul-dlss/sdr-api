#!/bin/sh

# Don't allow this command to fail
set -e

echo "HOST IS: $DATABASE_HOSTNAME"
until PGPASSWORD=$DATABASE_PASSWORD psql -h "$DATABASE_HOSTNAME" -U $DATABASE_USERNAME -c '\q'; do
    echo "Postgres is unavailable - sleeping"
    sleep 1
done

echo "Postgres is up - Setting up database"

# Allow this command to fail
set +e
echo "Creating DB."
SKIP_TEST_DATABASE=true bin/rails db:create

# Don't allow any following commands to fail
set -e
echo "Migrating db"
bin/rails db:migrate

echo "creating user"
bin/rails runner 'User.find_or_create_by(email: ENV["USER_EMAIL"]).update(password:  ENV["USER_PASSWORD"])'

echo "Running server"
exec bundle exec puma -C config/puma.rb config.ru
