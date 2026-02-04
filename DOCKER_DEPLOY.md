# 🚀 Deploy with Docker Compose

## Quick Start

### 1. Clone and Navigate
```bash
cd logistics_app/server
```

### 2. Set Environment Variables
```bash
# Copy the example env file
cp .env.example .env

# Edit .env and change JWT_SECRET to something secure
nano .env
```

### 3. Deploy!
```bash
docker-compose up -d
```

### 4. Check Status
```bash
docker-compose ps
docker-compose logs -f app
```

---

## 🌐 Access Your API

| Endpoint | URL |
|----------|-----|
| Health Check | http://localhost:5000/health |
| Admin Panel | http://localhost:5000/admin |
| API | http://localhost:5000/api |

---

## 📋 Available Endpoints

### Auth
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - Login
- `GET /api/auth/me` - Get current user

### Shipments
- `GET /api/shipments` - List shipments
- `POST /api/shipments` - Create shipment
- `GET /api/shipments/:id` - Get shipment details
- `PUT /api/shipments/:id` - Update shipment
- `DELETE /api/shipments/:id` - Delete shipment

### Admin
- `GET /admin` - Admin panel
- `GET /api/admin/shipments` - All shipments (admin only)
- `GET /api/admin/users` - All users (admin only)

---

## 🛠️ Commands

```bash
# Start services
docker-compose up -d

# Stop services
docker-compose down

# View logs
docker-compose logs -f

# Restart
docker-compose restart

# Rebuild after code changes
docker-compose up -d --build

# Database shell
docker-compose exec db psql -U postgres -d logistics
```

---

## 🌍 Deploy to Production Server

### On a VPS (DigitalOcean, AWS, etc.)

1. **Install Docker & Docker Compose:**
```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
```

2. **Upload your code:**
```bash
scp -r server/ root@your-server-ip:/opt/logistics
cd /opt/logistics
```

3. **Run:**
```bash
docker-compose up -d
```

4. **Setup Nginx (optional, for custom domain):**
```bash
sudo apt install nginx
# Add config for reverse proxy
```

---

## ☁️ Deploy to Railway with Docker

1. Push code to GitHub
2. In Railway → New Project → Deploy from GitHub
3. Railway will detect `docker-compose.yml` automatically
4. Add environment variable: `JWT_SECRET`
5. Deploy! 🚀

---

## ☁️ Deploy to Render

1. Push code to GitHub
2. New Web Service → Connect repo
3. Select "Docker" environment
4. Set environment variables
5. Deploy!

---

Happy shipping! 📦🚚