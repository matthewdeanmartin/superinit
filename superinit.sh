#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -eou pipefail

# Define variables
PROJECT_NAME="some_app"
DJANGO_PROJECT_NAME="some_app_host"
# Django app
APP_NAME="some_app"
PYTHON_VERSION="^3.11"
DJANGO_VERSION="^4.2"
POSTGRES_VERSION="psycopg2-binary" # To avoid having to build the binary from source

# Function to initialize Git repository
initialize_git() {
	if [ ! -d "$PROJECT_NAME/.git" ]; then
		echo "Initializing Git repository..."
		git init $PROJECT_NAME
		cd $PROJECT_NAME
	else
		echo "Git repository already initialized."
		cd $PROJECT_NAME
	fi
}

# Function to initialize Poetry and create Django project
initialize_poetry_django() {
	if [ ! -f "pyproject.toml" ]; then
		echo "Initializing Poetry..."
		poetry init --name $APP_NAME --directory=. --dependency "django$DJANGO_VERSION" --dependency "djangorestframework" --dependency $POSTGRES_VERSION --python $PYTHON_VERSION --no-interaction

		touch README.md

		echo "Installing dependencies..."
		poetry install

		echo "Creating Django project..."
		poetry run django-admin startproject $DJANGO_PROJECT_NAME .

		echo "Creating Django app: $APP_NAME..."
		poetry run python manage.py startapp $APP_NAME
	else
		echo "Poetry and Django project already initialized."
	fi
}

# Function to configure PostgreSQL database in Django settings
configure_postgresql() {
	SETTINGS_FILE="$DJANGO_PROJECT_NAME/settings.py"

	if ! grep -q "django.db.backends.postgresql_psycopg2" "$SETTINGS_FILE"; then
		echo "Configuring PostgreSQL database in Django settings..."
		python -c "
import re

settings_file = '$SETTINGS_FILE'

with open(settings_file, 'r+') as file:
    content = file.read()
    content = re.sub(r\"'ENGINE': 'django.db.backends.sqlite3'\", \"'ENGINE': 'django.db.backends.postgresql_psycopg2'\", content)
    content = re.sub(r\"'NAME': BASE_DIR \/ 'db.sqlite3',\", \"'NAME': 'postgres', 'USER': 'postgres', 'PASSWORD': 'postgres', 'HOST': 'localhost', 'PORT': '5432',\", content)
    file.seek(0)
    file.write(content)
    file.truncate()
"
	else
		echo "PostgreSQL already configured in Django settings."
	fi
}

add_rest_framework() {
	SETTINGS_FILE="$DJANGO_PROJECT_NAME/settings.py"
	echo $SETTINGS_FILE

	if ! grep -q "'rest_framework'," "$SETTINGS_FILE"; then
		echo "Adding Django REST Framework to installed apps..."
		python -c "
settings_file = '$SETTINGS_FILE'

with open(settings_file, 'r+') as file:
    lines = file.readlines()
    for i, line in enumerate(lines):
        if \"'django.contrib.staticfiles',\" in line:
            lines.insert(i + 1, \"    'rest_framework',\\n\")
            lines.insert(i + 2, f\"    '{os.environ.get('APP_NAME', '')}',\\n\")
            break
    file.seek(0)
    file.writelines(lines)
    file.truncate()
"
	else
		echo "Django REST Framework already added to installed apps."
	fi
}

# Function to create initial migrations and migrate the database
migrate_database() {
	if [ ! -d "$PROJECT_NAME/$DJANGO_PROJECT_NAME/migrations" ]; then
		echo "Creating initial migrations..."
		poetry run python manage.py makemigrations

		echo "Applying migrations..."
		poetry run python manage.py migrate
	else
		echo "Migrations already created and applied."
	fi
}

# Function to generate common Python configuration files
generate_config_files() {
	if [ ! -f ".gitignore" ]; then
		echo "Generating configuration files for Python tools..."

		cat <<EOL >.gitignore
# Python
*.pyc
__pycache__/
*.pyo
*.pyd
.Python
env/
venv/
ENV/
env.bak/
venv.bak/

# Django
*.log
*.pot
*.py[cod]
*.sqlite3
db.sqlite3

# macOS
.DS_Store

# VSCode
.vscode/

# Poetry
.poetry/
EOL

		# Generate pylint config
		echo "[MESSAGES CONTROL]
disable=missing-docstring" >.pylintrc

		# Generate black config
		cat <<EOL >>pyproject.toml

[tool.black]
line-length = 88
target-version = ['py311']
EOL

		# Generate isort config
		cat <<EOL >.isort.cfg
[settings]
profile = black
EOL

		# Generate .env file for environment variables
		cat <<EOL >.env
DEBUG=True
SECRET_KEY=your_secret_key_here
DATABASE_URL=postgres://postgres:postgres@localhost:5432/postgres
EOL

	else
		echo "Configuration files already generated."
	fi
}

# Function to set up pre-commit hooks with pylint, black, and isort
setup_pre_commit_hooks() {
	if [ ! -f ".pre-commit-config.yaml" ]; then
		echo "Setting up pre-commit hooks..."
		poetry add --dev pre-commit

		cat <<EOL >.pre-commit-config.yaml
repos:
  - repo: https://github.com/PyCQA/pylint
    rev: v2.16.0
    hooks:
      - id: pylint
  - repo: https://github.com/psf/black
    rev: 23.1.0
    hooks:
      - id: black
  - repo: https://github.com/pre-commit/mirrors-isort
    rev: v5.10.1
    hooks:
      - id: isort
EOL

		poetry run pre-commit install
		poetry run pre-commit autoupdate
		git add .pre-commit-config.yaml
		poetry run pre-commit run --all-files
	else
		echo "Pre-commit hooks already set up."
	fi
}

# Function to finalize Git configuration
finalize_git() {
	if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
		echo "Finalizing Git configuration..."
		git add .
		git commit -m "Initial commit: Set up Django REST API project with Poetry and common tools."
	else
		echo "Git already initialized with initial commit."
	fi
}

# Main function to execute all steps
main() {
	initialize_git
	initialize_poetry_django
	configure_postgresql
	add_rest_framework
	migrate_database
	generate_config_files
	setup_pre_commit_hooks
	finalize_git
	echo "All done! Your Django REST API project '$PROJECT_NAME' has been successfully set up."
}

# Execute the main function
main
