#!/bin/bash

set -e

# Function to wait for database
wait_for_db() {
    echo "Waiting for database to be ready..."
    while ! python manage.py check --database default; do
        echo "Database is unavailable - sleeping"
        sleep 1
    done
    echo "Database is ready!"
}

# Function to run migrations
run_migrations() {
    echo "Running database migrations..."
    python manage.py migrate --noinput
}

# Function to collect static files
collect_static() {
    echo "Collecting static files..."
    python manage.py collectstatic --noinput
}

# Function to create superuser if it doesn't exist
create_superuser() {
    if [ "$DJANGO_SUPERUSER_USERNAME" ] && [ "$DJANGO_SUPERUSER_PASSWORD" ] && [ "$DJANGO_SUPERUSER_EMAIL" ]; then
        echo "Creating superuser..."
        python manage.py shell << EOF
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='$DJANGO_SUPERUSER_USERNAME').exists():
    User.objects.create_superuser('$DJANGO_SUPERUSER_USERNAME', '$DJANGO_SUPERUSER_EMAIL', '$DJANGO_SUPERUSER_PASSWORD')
    print('Superuser created.')
else:
    print('Superuser already exists.')
EOF
    fi
}

# Main execution
if [ "$1" = "gunicorn" ]; then
    wait_for_db
    run_migrations
    collect_static
    create_superuser
    
    echo "Starting Gunicorn server..."
    exec "$@"
elif [ "$1" = "celery" ]; then
    if [ "$2" = "worker" ]; then
        echo "Starting Celery worker..."
        exec celery -A fleet worker -l info
    elif [ "$2" = "beat" ]; then
        echo "Starting Celery beat..."
        exec celery -A fleet beat -l info
    else
        echo "Starting Celery with command: $*"
        exec "$@"
    fi
elif [ "$1" = "manage.py" ]; then
    wait_for_db
    exec python "$@"
else
    exec "$@"
fi
