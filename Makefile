.PHONY: all dev server ui install install-ui install-server build clean help db-up db-down

# Default target
all: dev

# Install all dependencies
install: install-ui install-server

install-ui:
	@echo "Installing UI dependencies..."
	cd ui && npm install

install-server:
	@echo "Installing server dependencies..."
	cd server && go mod tidy && go mod download

# Development - run both servers
dev:
	@echo "Starting development servers..."
	@make -j2 server ui

# Run Go server
server:
	@echo "Starting Go server on :8080..."
	cd server && go run ./cmd/api/...

# Run React UI
ui:
	@echo "Starting React UI on :5173..."
	cd ui && npm run dev

# Build for production
build: build-server build-ui

build-server:
	@echo "Building Go server..."
	cd server && go build -o bin/api ./cmd/api/...

build-ui:
	@echo "Building React UI..."
	cd ui && npm run build

# Database commands (requires Docker)
db-up:
	@echo "Starting PostgreSQL..."
	docker run -d \
		--name sainath-postgres \
		-e POSTGRES_DB=sainath_society \
		-e POSTGRES_USER=postgres \
		-e POSTGRES_PASSWORD=postgres \
		-p 5432:5432 \
		postgres:16-alpine
	@echo "Waiting for PostgreSQL to be ready..."
	@sleep 3
	@echo "PostgreSQL is ready on port 5432"

db-down:
	@echo "Stopping PostgreSQL..."
	docker stop sainath-postgres && docker rm sainath-postgres

db-reset: db-down db-up

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf server/bin
	rm -rf ui/dist
	rm -rf ui/node_modules/.vite

# Help
help:
	@echo "Sainath Society Management - Development Commands"
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@echo "Targets:"
	@echo "  install        Install all dependencies (UI + Server)"
	@echo "  dev            Start both UI and Server for development"
	@echo "  server         Start Go server only"
	@echo "  ui             Start React UI only"
	@echo "  build          Build both for production"
	@echo "  db-up          Start PostgreSQL in Docker"
	@echo "  db-down        Stop PostgreSQL"
	@echo "  db-reset       Reset database"
	@echo "  clean          Clean build artifacts"
	@echo "  help           Show this help message"
	@echo ""
	@echo "Quick Start:"
	@echo "  1. make db-up      # Start PostgreSQL"
	@echo "  2. make install    # Install dependencies"
	@echo "  3. make dev        # Start development servers"
	@echo ""
	@echo "Default Credentials:"
	@echo "  Admin:  chairman@sainath.com / Admin@123"
	@echo "  Member: member1@sainath.com / Member@123"
