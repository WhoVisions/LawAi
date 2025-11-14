#!/bin/bash
#
# LexiCore Development Environment Setup
#
# This script sets up the development environment for LexiCore.
# It installs dependencies, sets up databases, and runs initial migrations.
#
# Usage: ./scripts/setup.sh

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
info() {
    echo -e "${BLUE}ℹ ${NC}$1"
}

success() {
    echo -e "${GREEN}✅ ${NC}$1"
}

warn() {
    echo -e "${YELLOW}⚠️  ${NC}$1"
}

error() {
    echo -e "${RED}❌ ${NC}$1"
    exit 1
}

# Banner
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  LexiCore - Development Environment Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check prerequisites
info "Checking prerequisites..."

# Check Node.js
if ! command -v node &> /dev/null; then
    error "Node.js is not installed. Please install Node.js 20+ from https://nodejs.org/"
fi

NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 20 ]; then
    error "Node.js version 20+ is required. You have version $NODE_VERSION."
fi
success "Node.js $(node -v) found"

# Check npm
if ! command -v npm &> /dev/null; then
    error "npm is not installed."
fi
success "npm $(npm -v) found"

# Check Docker
if ! command -v docker &> /dev/null; then
    warn "Docker is not installed. You'll need Docker for local database."
    warn "Install from: https://www.docker.com/get-started"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    success "Docker $(docker --version | cut -d' ' -f3 | cut -d',' -f1) found"
fi

# Check Python (for image fetching script)
if ! command -v python3 &> /dev/null; then
    warn "Python 3 is not installed. Image fetching script won't work."
else
    success "Python $(python3 --version | cut -d' ' -f2) found"
fi

echo ""
info "Installing dependencies..."
npm install

success "Dependencies installed"

# Environment setup
echo ""
info "Setting up environment variables..."

if [ ! -f ".env.local" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example .env.local
        success "Created .env.local from .env.example"
        warn "Please edit .env.local and add your API keys:"
        warn "  - DATABASE_URL (if not using Docker)"
        warn "  - REDIS_URL (if not using Docker)"
        warn "  - OPENAI_API_KEY (required for AI features)"
        warn "  - CLERK_SECRET_KEY (required for auth)"
        echo ""
        read -p "Press Enter to continue after editing .env.local, or Ctrl+C to exit..."
    else
        warn "No .env.example found. Creating minimal .env.local..."
        cat > .env.local << 'EOF'
# Database
DATABASE_URL="postgresql://lexicore:dev_password@localhost:5432/lexicore_dev"
REDIS_URL="redis://localhost:6379"

# Auth (get from https://clerk.com)
CLERK_SECRET_KEY="sk_test_..."
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY="pk_test_..."

# OpenAI (get from https://platform.openai.com/api-keys)
OPENAI_API_KEY="sk-proj-..."

# JWT Secret (generated)
JWT_SECRET="$(openssl rand -base64 32)"

# Environment
NODE_ENV="development"
EOF
        success "Created .env.local"
        warn "Please edit .env.local and add your real API keys"
        echo ""
        read -p "Press Enter to continue after editing .env.local, or Ctrl+C to exit..."
    fi
else
    success ".env.local already exists"
fi

# Docker setup
echo ""
if command -v docker &> /dev/null; then
    info "Starting Docker containers..."

    if [ -f "docker-compose.yml" ]; then
        docker-compose up -d postgres redis
        success "Docker containers started"

        info "Waiting for PostgreSQL to be ready..."
        sleep 5

        # Check if PostgreSQL is ready
        until docker-compose exec -T postgres pg_isready -U lexicore > /dev/null 2>&1; do
            echo -n "."
            sleep 1
        done
        echo ""
        success "PostgreSQL is ready"

        # Enable pgvector extension
        info "Enabling pgvector extension..."
        docker-compose exec -T postgres psql -U lexicore -d lexicore_dev -c "CREATE EXTENSION IF NOT EXISTS vector;" > /dev/null 2>&1
        success "pgvector extension enabled"
    else
        warn "No docker-compose.yml found. Skipping Docker setup."
    fi
fi

# Database migrations
echo ""
info "Running database migrations..."

if command -v npx &> /dev/null; then
    # Generate Prisma client
    info "Generating Prisma client..."
    npx prisma generate

    # Run migrations
    info "Running migrations..."
    npx prisma migrate dev --name init

    success "Database migrations completed"

    # Seed database
    read -p "Do you want to seed the database with sample data? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        info "Seeding database..."
        npx prisma db seed
        success "Database seeded"
    fi
else
    warn "npx not found. Skipping database migrations."
fi

# TypeScript build check
echo ""
info "Checking TypeScript compilation..."
npm run type-check
success "TypeScript compilation successful"

# Optional: Fetch stock images
echo ""
read -p "Do you want to fetch stock images from Pexels? (requires PEXELS_API_KEY) (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -z "$PEXELS_API_KEY" ]; then
        warn "PEXELS_API_KEY not set in environment"
        read -p "Enter your Pexels API key (or press Enter to skip): " PEXELS_KEY
        if [ -n "$PEXELS_KEY" ]; then
            export PEXELS_API_KEY="$PEXELS_KEY"
            python3 scripts/fetch_images.py
        fi
    else
        python3 scripts/fetch_images.py
    fi
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Setup Complete! 🎉"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
success "LexiCore development environment is ready!"
echo ""
info "Next steps:"
echo ""
echo "  1. Start the development servers:"
echo "     ${GREEN}npm run dev${NC}"
echo ""
echo "  2. Open your browser:"
echo "     ${BLUE}http://localhost:3000${NC} (Web app)"
echo "     ${BLUE}http://localhost:3001${NC} (API server)"
echo ""
echo "  3. View database:"
echo "     ${GREEN}npx prisma studio${NC}"
echo ""
info "Useful commands:"
echo "  - Run tests:        ${GREEN}npm test${NC}"
echo "  - Type check:       ${GREEN}npm run type-check${NC}"
echo "  - Lint:             ${GREEN}npm run lint${NC}"
echo "  - Database migrate: ${GREEN}npx prisma migrate dev${NC}"
echo "  - View logs:        ${GREEN}docker-compose logs -f${NC}"
echo ""
info "Documentation:"
echo "  - README:       ${BLUE}./README.md${NC}"
echo "  - Architecture: ${BLUE}./docs/ARCHITECTURE.md${NC}"
echo "  - Database:     ${BLUE}./docs/DATABASE.md${NC}"
echo "  - API:          ${BLUE}./docs/API.md${NC}"
echo ""
warn "Remember to:"
echo "  - Add your real API keys to .env.local"
echo "  - Read docs/CLAUDE.md for working with Claude"
echo "  - Review docs/COMPLIANCE.md for legal requirements"
echo ""
