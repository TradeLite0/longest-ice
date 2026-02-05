/**
 * Backend Server للتطبيق اللوجستي - النسخة المتكاملة
 * مع PostgreSQL Database + Admin Panel + GPS Tracking + Complaint System
 */

const express = require('express');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const bodyParser = require('body-parser');
const { Pool } = require('pg');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 5000;
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-this-in-production';

// Middleware
app.use(cors());
app.use(bodyParser.json({ limit: '10mb' }));
app.use(bodyParser.urlencoded({ extended: true, limit: '10mb' }));

// 📦 إعداد PostgreSQL
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
});

// 🔁 Retry connection with exponential backoff
async function waitForDatabase(maxRetries = 30, delay = 2000) {
  for (let i = 0; i < maxRetries; i++) {
    try {
      await pool.query('SELECT 1');
      console.log('✅ Database connected successfully');
      return true;
    } catch (err) {
      console.log(`⏳ Waiting for database... attempt ${i + 1}/${maxRetries}`);
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }
  throw new Error('Could not connect to database after ' + maxRetries + ' attempts');
}

// 🚀 إنشاء الجداول لو مش موجودة
async function initDatabase() {
  try {
    // جدول المستخدمين (محدث مع صلاحيات)
    await pool.query(`
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        phone VARCHAR(20) UNIQUE NOT NULL,
        password VARCHAR(255) NOT NULL,
        name VARCHAR(100) NOT NULL,
        type VARCHAR(20) DEFAULT 'client' CHECK (type IN ('client', 'driver', 'admin', 'super_admin')),
        email VARCHAR(100),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        is_active BOOLEAN DEFAULT true,
        is_approved BOOLEAN DEFAULT false,
        last_login TIMESTAMP,
        created_by INTEGER REFERENCES users(id)
      )
    `);

    // جدول مواقع السائقين (GPS Tracking مباشر)
    await pool.query(`
      CREATE TABLE IF NOT EXISTS driver_locations (
        id SERIAL PRIMARY KEY,
        driver_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        latitude DECIMAL(10, 8) NOT NULL,
        longitude DECIMAL(11, 8) NOT NULL,
        accuracy DECIMAL(10, 2),
        speed DECIMAL(10, 2),
        heading DECIMAL(10, 2),
        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        is_gps_active BOOLEAN DEFAULT true,
        battery_level INTEGER,
        UNIQUE(driver_id)
      )
    `);

    // جدول الشحنات (محدث مع QR code وتتبع)
    await pool.query(`
      CREATE TABLE IF NOT EXISTS shipments (
        id SERIAL PRIMARY KEY,
        tracking_number VARCHAR(50) UNIQUE NOT NULL,
        qr_code VARCHAR(100) UNIQUE,
        customer_id INTEGER REFERENCES users(id),
        customer_name VARCHAR(100) NOT NULL,
        customer_phone VARCHAR(20),
        pickup_lat DECIMAL(10, 8),
        pickup_lng DECIMAL(11, 8),
        pickup_address TEXT,
        destination VARCHAR(100) NOT NULL,
        dest_lat DECIMAL(10, 8),
        dest_lng DECIMAL(11, 8),
        service_type VARCHAR(50),
        weight DECIMAL(10, 2),
        cost DECIMAL(10, 2),
        status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'assigned', 'picked_up', 'in_transit', 'out_for_delivery', 'delivered', 'cancelled')),
        driver_id INTEGER REFERENCES users(id),
        notes TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        delivered_at TIMESTAMP,
        delivered_lat DECIMAL(10, 8),
        delivered_lng DECIMAL(11, 8)
      )
    `);

    // جدول حالات الشحنات (History)
    await pool.query(`
      CREATE TABLE IF NOT EXISTS shipment_status_history (
        id SERIAL PRIMARY KEY,
        shipment_id INTEGER REFERENCES shipments(id) ON DELETE CASCADE,
        status VARCHAR(20) NOT NULL,
        location_lat DECIMAL(10, 8),
        location_lng DECIMAL(11, 8),
        notes TEXT,
        updated_by INTEGER REFERENCES users(id),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // جدول QR Scans مع GPS
    await pool.query(`
      CREATE TABLE IF NOT EXISTS qr_scans (
        id SERIAL PRIMARY KEY,
        shipment_id INTEGER REFERENCES shipments(id),
        driver_id INTEGER REFERENCES users(id),
        scan_type VARCHAR(20) CHECK (scan_type IN ('pickup', 'delivery', 'transfer')),
        qr_data TEXT,
        latitude DECIMAL(10, 8) NOT NULL,
        longitude DECIMAL(11, 8) NOT NULL,
        accuracy DECIMAL(10, 2),
        photo_url TEXT,
        notes TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // جدول الشكاوى
    await pool.query(`
      CREATE TABLE IF NOT EXISTS complaints (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id),
        user_type VARCHAR(20),
        shipment_id INTEGER REFERENCES shipments(id),
        title VARCHAR(200) NOT NULL,
        description TEXT NOT NULL,
        complaint_type VARCHAR(50) CHECK (complaint_type IN ('delay', 'damage', 'lost', 'behavior', 'other')),
        priority VARCHAR(20) DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
        status VARCHAR(20) DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'resolved', 'closed')),
        assigned_to INTEGER REFERENCES users(id),
        resolution_notes TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        resolved_at TIMESTAMP
      )
    `);

    // جدول الإشعارات
    await pool.query(`
      CREATE TABLE IF NOT EXISTS notifications (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        title VARCHAR(200) NOT NULL,
        message TEXT NOT NULL,
        type VARCHAR(50),
        is_read BOOLEAN DEFAULT false,
        data JSONB,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    console.log('✅ Database tables initialized');
  } catch (error) {
    console.error('❌ Database initialization error:', error);
    throw error;
  }
}

// ==================== AUTH MIDDLEWARE ====================

// التحقق من التوكن
function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ success: false, message: 'يجب تسجيل الدخول' });
  }

  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ success: false, message: 'توكن غير صالح' });
    }
    req.user = user;
    next();
  });
}

// التحقق من المشرف
function requireAdmin(req, res, next) {
  if (req.user.type !== 'admin' && req.user.type !== 'super_admin') {
    return res.status(403).json({ success: false, message: 'غير مصرح' });
  }
  next();
}

// التحقق من السائق
function requireDriver(req, res, next) {
  if (req.user.type !== 'driver') {
    return res.status(403).json({ success: false, message: 'للسائقين فقط' });
  }
  next();
}

// ==================== AUTH ROUTES ====================

/**
 * POST /api/auth/register
 * تسجيل مستخدم جديد (عميل أو سائق - يحتاج موافقة)
 */
app.post('/api/auth/register', async (req, res) => {
  try {
    const { phone, password, name, type = 'client', email } = req.body;

    // التحقق من البيانات
    if (!phone || !password || !name) {
      return res.status(400).json({ success: false, message: 'جميع الحقول مطلوبة' });
    }

    // التحقق من نوع المستخدم
    if (!['client', 'driver'].includes(type)) {
      return res.status(400).json({ success: false, message: 'نوع الحساب غير صالح' });
    }

    // التحقق من وجود المستخدم
    const existingUser = await pool.query('SELECT * FROM users WHERE phone = $1', [phone]);
    if (existingUser.rows.length > 0) {
      return res.status(409).json({ success: false, message: 'رقم الهاتف مسجل بالفعل' });
    }

    // تشفير كلمة المرور
    const hashedPassword = await bcrypt.hash(password, 10);

    // إنشاء المستخدم (غير مفعل لحد ما يوافق عليه المشرف)
    const result = await pool.query(
      'INSERT INTO users (phone, password, name, type, email, is_approved) VALUES ($1, $2, $3, $4, $5, $6) RETURNING *',
      [phone, hashedPassword, name, type, email, false]
    );

    res.status(201).json({
      success: true,
      message: 'تم إنشاء الحساب بنجاح، في انتظار موافقة المشرف',
      user: {
        id: result.rows[0].id,
        phone: result.rows[0].phone,
        name: result.rows[0].name,
        type: result.rows[0].type,
        is_approved: result.rows[0].is_approved
      }
    });
  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
});

/**
 * POST /api/auth/login
 * تسجيل الدخول
 */
app.post('/api/auth/login', async (req, res) => {
  try {
    const { phone, password } = req.body;

    if (!phone || !password) {
      return res.status(400).json({ success: false, message: 'رقم الهاتف وكلمة المرور مطلوبان' });
    }

    const result = await pool.query('SELECT * FROM users WHERE phone = $1', [phone]);

    if (result.rows.length === 0) {
      return res.status(401).json({ success: false, message: 'بيانات الدخول غير صحيحة' });
    }

    const user = result.rows[0];

    if (!user.is_active) {
      return res.status(403).json({ success: false, message: 'الحساب معطل' });
    }

    const validPassword = await bcrypt.compare(password, user.password);
    if (!validPassword) {
      return res.status(401).json({ success: false, message: 'بيانات الدخول غير صحيحة' });
    }

    // تحديث آخر دخول
    await pool.query('UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = $1', [user.id]);

    const token = jwt.sign(
      { userId: user.id, phone: user.phone, type: user.type, name: user.name },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.json({
      success: true,
      message: 'تم تسجيل الدخول بنجاح',
      token,
      user: {
        id: user.id,
        phone: user.phone,
        name: user.name,
        type: user.type,
        is_approved: user.is_approved
      }
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
});

/**
 * GET /api/auth/me
 * بيانات المستخدم الحالي
 */
app.get('/api/auth/me', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, phone, name, type, email, created_at, is_active, is_approved FROM users WHERE id = $1',
      [req.user.userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'المستخدم غير موجود' });
    }

    res.json({ success: true, user: result.rows[0] });
  } catch (error) {
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
});

// ==================== GPS TRACKING ROUTES ====================

/**
 * POST /api/location/update
 * تحديث موقع السائق (إجباري)
 */
app.post('/api/location/update', authenticateToken, requireDriver, async (req, res) => {
  try {
    const { latitude, longitude, accuracy, speed, heading, battery_level } = req.body;

    if (!latitude || !longitude) {
      return res.status(400).json({ success: false, message: 'الموقع مطلوب' });
    }

    // Upsert location
    await pool.query(`
      INSERT INTO driver_locations (driver_id, latitude, longitude, accuracy, speed, heading, battery_level, timestamp, is_gps_active)
      VALUES ($1, $2, $3, $4, $5, $6, $7, CURRENT_TIMESTAMP, true)
      ON CONFLICT (driver_id) 
      DO UPDATE SET 
        latitude = EXCLUDED.latitude,
        longitude = EXCLUDED.longitude,
        accuracy = EXCLUDED.accuracy,
        speed = EXCLUDED.speed,
        heading = EXCLUDED.heading,
        battery_level = EXCLUDED.battery_level,
        timestamp = CURRENT_TIMESTAMP,
        is_gps_active = true
    `, [req.user.userId, latitude, longitude, accuracy, speed, heading, battery_level]);

    res.json({ success: true, message: 'تم تحديث الموقع' });
  } catch (error) {
    console.error('Location update error:', error);
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
});

/**
 * GET /api/location/drivers
 * مواقع جميع السائقين (للأدمن فقط)
 */
app.get('/api/location/drivers', authenticateToken, requireAdmin, async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT 
        dl.driver_id,
        u.name,
        u.phone,
        dl.latitude,
        dl.longitude,
        dl.accuracy,
        dl.speed,
        dl.heading,
        dl.battery_level,
        dl.timestamp,
        dl.is_gps_active,
        s.id as current_shipment_id,
        s.status as shipment_status
      FROM driver_locations dl
      JOIN users u ON dl.driver_id = u.id
      LEFT JOIN shipments s ON dl.driver_id = s.driver_id AND s.status NOT IN ('delivered', 'cancelled')
      WHERE u.is_active = true
      ORDER BY dl.timestamp DESC
    `);

    res.json({ success: true, drivers: result.rows });
  } catch (error) {
    console.error('Get drivers location error:', error);
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
});

/**
 * GET /api/location/driver/:id
 * موقع سائق محدد
 */
app.get('/api/location/driver/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    
    // العميل يقدر يشوف موقع السائق اللي معاه الشحنة بس
    if (req.user.type === 'client') {
      const shipmentCheck = await pool.query(
        'SELECT * FROM shipments WHERE customer_id = $1 AND driver_id = $2 AND status NOT IN (\'delivered\', \'cancelled\')',
        [req.user.userId, id]
      );
      if (shipmentCheck.rows.length === 0) {
        return res.status(403).json({ success: false, message: 'غير مصرح' });
      }
    }

    const result = await pool.query(`
      SELECT dl.*, u.name, u.phone
      FROM driver_locations dl
      JOIN users u ON dl.driver_id = u.id
      WHERE dl.driver_id = $1
    `, [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'الموقع غير متوفر' });
    }

    res.json({ success: true, location: result.rows[0] });
  } catch (error) {
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
});

// ==================== SHIPMENT ROUTES ====================

/**
 * POST /api/shipments
 * إنشاء شحنة جديدة (للعملاء)
 */
app.post('/api/shipments', authenticateToken, async (req, res) => {
  try {
    const {
      customer_name, customer_phone, destination, service_type,
      weight, cost, notes, pickup_lat, pickup_lng, pickup_address
    } = req.body;

    // توليد رقم تتبع
    const tracking_number = 'TRK' + Date.now();
    const qr_code = 'QR' + Date.now();

    const result = await pool.query(`
      INSERT INTO shipments (
        tracking_number, qr_code, customer_id, customer_name, customer_phone,
        pickup_lat, pickup_lng, pickup_address, destination,
        service_type, weight, cost, notes, status
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, 'pending')
      RETURNING *
    `, [
      tracking_number, qr_code, req.user.userId, customer_name, customer_phone,
      pickup_lat, pickup_lng, pickup_address, destination,
      service_type, weight, cost, notes
    ]);

    res.status(201).json({ success: true, shipment: result.rows[0] });
  } catch (error) {
    console.error('Create shipment error:', error);
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
});

/**
 * GET /api/shipments
 * قائمة الشحنات
 */
app.get('/api/shipments', authenticateToken, async (req, res) => {
  try {
    let query = `
      SELECT s.*, 
        d.name as driver_name, d.phone as driver_phone,
        dl.latitude as driver_lat, dl.longitude as driver_lng
      FROM shipments s
      LEFT JOIN users d ON s.driver_id = d.id
      LEFT JOIN driver_locations dl ON s.driver_id = dl.driver_id
    `;
    let params = [];

    if (req.user.type === 'client') {
      query += ' WHERE s.customer_id = $1';
      params = [req.user.userId];
    } else if (req.user.type === 'driver') {
      query += ' WHERE s.driver_id = $1';
      params = [req.user.userId];
    }

    query += ' ORDER BY s.created_at DESC';

    const result = await pool.query(query, params);
    res.json({ success: true, shipments: result.rows });
  } catch (error) {
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
});

/**
 * GET /api/shipments/:id
 * تفاصيل شحنة مع موقع السائق
 */
app.get('/api/shipments/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;

    const result = await pool.query(`
      SELECT s.*,
        d.name as driver_name, d.phone as driver_phone,
        dl.latitude as driver_lat, dl.longitude as driver_lng,
        dl.timestamp as location_updated
      FROM shipments s
      LEFT JOIN users d ON s.driver_id = d.id
      LEFT JOIN driver_locations dl ON s.driver_id = dl.driver_id
      WHERE s.id = $1
    `, [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'الشحنة غير موجودة' });
    }

    const shipment = result.rows[0];

    // التحقق من الصلاحيات
    if (req.user.type === 'client' && shipment.customer_id !== req.user.userId) {
      return res.status(403).json({ success: false, message: 'غير مصرح' });
    }
    if (req.user.type === 'driver' && shipment.driver_id !== req.user.userId) {
      return res.status(403).json({ success: false, message: 'غير مصرح' });
    }

    res.json({ success: true, shipment });
  } catch (error) {
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
});

/**
 * PUT /api/shipments/:id/status
 * تحديث حالة الشحنة (للسائقين)
 */
app.put('/api/shipments/:id/status', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { status, lat, lng, notes } = req.body;

    // التحقق من الصلاحيات
    const shipmentCheck = await pool.query('SELECT * FROM shipments WHERE id = $1', [id]);
    if (shipmentCheck.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'الشحنة غير موجودة' });
    }

    const shipment = shipmentCheck.rows[0];

    if (req.user.type === 'driver' && shipment.driver_id !== req.user.userId) {
      return res.status(403).json({ success: false, message: 'غير مصرح' });
    }

    // تحديث الحالة
    let updateQuery = 'UPDATE shipments SET status = $1, updated_at = CURRENT_TIMESTAMP';
    let params = [status];

    if (status === 'delivered') {
      updateQuery += ', delivered_at = CURRENT_TIMESTAMP, delivered_lat = $2, delivered_lng = $3';
      params.push(lat, lng);
    }

    updateQuery += ' WHERE id = $' + (params.length + 1);
    params.push(id);

    await pool.query(updateQuery, params);

    // إضافة للتاريخ
    await pool.query(
      'INSERT INTO shipment_status_history (shipment_id, status, location_lat, location_lng, notes, updated_by) VALUES ($1, $2, $3, $4, $5, $6)',
      [id, status, lat, lng, notes, req.user.userId]
    );

    res.json({ success: true, message: 'تم تحديث الحالة' });
  } catch (error) {
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
});

// ==================== QR SCAN ROUTES ====================

/**
 * POST /api/qr/scan
 * مسح QR Code مع GPS (إجباري)
 */
app.post('/api/qr/scan', authenticateToken, requireDriver, async (req, res) => {
  try {
    const { shipment_id, scan_type, qr_data, latitude, longitude, accuracy, photo_url, notes } = req.body;

    // التحقق من وجود GPS
    if (!latitude || !longitude) {
      return res.status(400).json({ 
        success: false, 
        message: 'يجب تفعيل الموقع لمسح الكود',
        require_gps: true 
      });
    }

    // التحقق من الشحنة
    const shipmentCheck = await pool.query(
      'SELECT * FROM shipments WHERE id = $1 AND driver_id = $2',
      [shipment_id, req.user.userId]
    );

    if (shipmentCheck.rows.length === 0) {
      return res.status(403).json({ success: false, message: 'الشحنة غير مخصصة لك' });
    }

    // حفظ المسح
    await pool.query(`
      INSERT INTO qr_scans (shipment_id, driver_id, scan_type, qr_data, latitude, longitude, accuracy, photo_url, notes)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
    `, [shipment_id, req.user.userId, scan_type, qr_data, latitude, longitude, accuracy, photo_url, notes]);

    // تحديث حالة الشحنة
    let newStatus = 'in_transit';
    if (scan_type === 'pickup') newStatus = 'picked_up';
    if (scan_type === 'delivery') newStatus = 'delivered';

    await pool.query(
      'UPDATE shipments SET status = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2',
      [newStatus, shipment_id]
    );

    res.json({ success: true, message: 'تم المسح بنجاح', location: { lat: latitude, lng: longitude } });
  } catch (error) {
    console.error('QR scan error:', error);
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
});

// ==================== COMPLAINT ROUTES ====================

/**
 * POST /api/complaints
 * تقديم شكوى
 */
app.post('/api/complaints', authenticateToken, async (req, res) => {
  try {
    const { shipment_id, title, description, complaint_type, priority = 'medium' } = req.body;

    const result = await pool.query(`
      INSERT INTO complaints (user_id, user_type, shipment_id, title, description, complaint_type, priority)
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      RETURNING *
    `, [req.user.userId, req.user.type, shipment_id, title, description, complaint_type, priority]);

    res.status(201).json({ success: true, complaint: result.rows[0] });
  } catch (error) {
    console.error('Complaint creation error:', error);
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
});

/**
 * GET /api/complaints
 * قائمة الشكاوى (للأدمن فقط)
 */
app.get('/api/complaints', authenticateToken, requireAdmin, async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT c.*, 
        u.name as user_name, u.phone as user_phone,
        s.tracking_number,
        a.name as assigned_to_name
      FROM complaints c
      JOIN users u ON c.user_id = u.id
      LEFT JOIN shipments s ON c.shipment_id = s.id
      LEFT JOIN users a ON c.assigned_to = a.id
      ORDER BY 
        CASE c.priority 
          WHEN 'urgent' THEN 1 
          WHEN 'high' THEN 2 
          WHEN 'medium' THEN 3 
          ELSE 4 
        END,
        c.created_at DESC
    `);

    res.json({ success: true, complaints: result.rows });
  } catch (error) {
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
});

/**
 * PUT /api/complaints/:id
 * تحديث حالة الشكوى
 */
app.put('/api/complaints/:id', authenticateToken, requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const { status, assigned_to, resolution_notes } = req.body;

    let query = 'UPDATE complaints SET status = $1, updated_at = CURRENT_TIMESTAMP';
    let params = [status];
    let paramCount = 1;

    if (assigned_to) {
      paramCount++;
      query += `, assigned_to = $${paramCount}`;
      params.push(assigned_to);
    }

    if (resolution_notes) {
      paramCount++;
      query += `, resolution_notes = $${paramCount}`;
      params.push(resolution_notes);
    }

    if (status === 'resolved') {
      paramCount++;
      query += `, resolved_at = CURRENT_TIMESTAMP`;
    }

    paramCount++;
    query += ` WHERE id = $${paramCount} RETURNING *`;
    params.push(id);

    const result = await pool.query(query, params);

    res.json({ success: true, complaint: result.rows[0] });
  } catch (error) {
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
});

// ==================== ADMIN ROUTES ====================

/**
 * GET /api/admin/users
 * قائمة المستخدمين (للأدمن)
 */
app.get('/api/admin/users', authenticateToken, requireAdmin, async (req, res) => {
  try {
    const { type, is_approved } = req.query;
    
    let query = `
      SELECT u.id, u.phone, u.name, u.type, u.email, u.created_at, 
        u.is_active, u.is_approved, u.last_login,
        c.name as created_by_name
      FROM users u
      LEFT JOIN users c ON u.created_by = c.id
      WHERE 1=1
    `;
    let params = [];
    let paramCount = 0;

    if (type) {
      paramCount++;
      query += ` AND u.type = $${paramCount}`;
      params.push(type);
    }

    if (is_approved !== undefined) {
      paramCount++;
      query += ` AND u.is_approved = $${paramCount}`;
      params.push(is_approved === 'true');
    }

    query += ' ORDER BY u.created_at DESC';

    const result = await pool.query(query, params);
    res.json({ success: true, users: result.rows });
  } catch (error) {
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
});

/**
 * PUT /api/admin/users/:id/approve
 * الموافقة على مستخدم (تحويل من عميل لسائق أو العكس)
 */
app.put('/api/admin/users/:id/approve', authenticateToken, requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const { type, is_approved } = req.body;

    const result = await pool.query(
      'UPDATE users SET type = $1, is_approved = $2, updated_at = CURRENT_TIMESTAMP WHERE id = $3 RETURNING *',
      [type, is_approved, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'المستخدم غير موجود' });
    }

    res.json({ success: true, user: result.rows[0] });
  } catch (error) {
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
});

/**
 * POST /api/admin/create-user
 * إنشاء مستخدم من قبل الأدمن
 */
app.post('/api/admin/create-user', authenticateToken, requireAdmin, async (req, res) => {
  try {
    const { phone, password, name, type, email } = req.body;

    const hashedPassword = await bcrypt.hash(password, 10);

    const result = await pool.query(
      'INSERT INTO users (phone, password, name, type, email, is_approved, created_by) VALUES ($1, $2, $3, $4, $5, true, $6) RETURNING *',
      [phone, hashedPassword, name, type, email, req.user.userId]
    );

    res.status(201).json({ success: true, user: result.rows[0] });
  } catch (error) {
    if (error.code === '23505') {
      return res.status(409).json({ success: false, message: 'رقم الهاتف مسجل بالفعل' });
    }
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
});

/**
 * GET /api/admin/dashboard
 * بيانات لوحة التحكم
 */
app.get('/api/admin/dashboard', authenticateToken, requireAdmin, async (req, res) => {
  try {
    // إحصائيات
    const stats = await pool.query(`
      SELECT 
        (SELECT COUNT(*) FROM users WHERE type = 'driver' AND is_active = true) as active_drivers,
        (SELECT COUNT(*) FROM users WHERE type = 'client') as total_clients,
        (SELECT COUNT(*) FROM shipments WHERE status NOT IN ('delivered', 'cancelled')) as active_shipments,
        (SELECT COUNT(*) FROM complaints WHERE status = 'open') as pending_complaints,
        (SELECT COUNT(*) FROM users WHERE is_approved = false) as pending_approvals
    `);

    // آخر الشحنات
    const recentShipments = await pool.query(`
      SELECT s.*, d.name as driver_name
      FROM shipments s
      LEFT JOIN users d ON s.driver_id = d.id
      ORDER BY s.created_at DESC
      LIMIT 10
    `);

    // السائقين الأونلاين
    const onlineDrivers = await pool.query(`
      SELECT dl.driver_id, u.name, dl.latitude, dl.longitude, dl.timestamp
      FROM driver_locations dl
      JOIN users u ON dl.driver_id = u.id
      WHERE dl.timestamp > NOW() - INTERVAL '10 minutes'
    `);

    res.json({
      success: true,
      stats: stats.rows[0],
      recent_shipments: recentShipments.rows,
      online_drivers: onlineDrivers.rows
    });
  } catch (error) {
    console.error('Dashboard error:', error);
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
});

// ==================== NOTIFICATIONS ====================

/**
 * GET /api/notifications
 */
app.get('/api/notifications', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM notifications WHERE user_id = $1 ORDER BY created_at DESC LIMIT 20',
      [req.user.userId]
    );
    res.json({ success: true, notifications: result.rows });
  } catch (error) {
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
});

/**
 * PUT /api/notifications/:id/read
 */
app.put('/api/notifications/:id/read', authenticateToken, async (req, res) => {
  try {
    await pool.query('UPDATE notifications SET is_read = true WHERE id = $1 AND user_id = $2', 
      [req.params.id, req.user.userId]);
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
});

// ==================== WEB ADMIN PANEL ====================

// تقديم ملفات الـ Admin Panel
app.use('/admin-panel', express.static(path.join(__dirname, 'admin-panel')));
app.get('/admin', (req, res) => res.redirect('/admin-panel/index.html'));

// ==================== SETUP & HEALTH ====================

app.get('/setup', async (req, res) => {
  try {
    await initDatabase();
    
    const existing = await pool.query('SELECT * FROM users WHERE phone = $1', ['01017680036']);
    if (existing.rows.length > 0) {
      return res.json({ success: true, message: 'Admin already exists', user: existing.rows[0] });
    }
    
    const hashedPassword = await bcrypt.hash('01017680036aA@', 10);
    const result = await pool.query(
      'INSERT INTO users (phone, password, name, type, is_approved, is_active) VALUES ($1, $2, $3, $4, $5, $6) RETURNING *',
      ['01017680036', hashedPassword, 'Super Administrator', 'super_admin', true, true]
    );
    
    res.json({ success: true, message: 'Super admin created', user: result.rows[0] });
  } catch (error) {
    console.error('Setup error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'OK', database: 'connected', timestamp: new Date().toISOString() });
  } catch (error) {
    res.json({ status: 'OK', database: 'connecting', timestamp: new Date().toISOString() });
  }
});

// ==================== START SERVER ====================

const server = app.listen(PORT, '0.0.0.0', () => {
  console.log('🚀 ==========================================');
  console.log('🚀  Logistics Backend Server v2.0');
  console.log('🚀  GPS Tracking + Complaint System');
  console.log('🚀 ==========================================');
  console.log(`🚀  API: http://localhost:${PORT}/api`);
  console.log(`🚀  Admin: http://localhost:${PORT}/admin`);
  console.log('🚀 ==========================================');
});

// Initialize DB
(async () => {
  try {
    await waitForDatabase();
    await initDatabase();
    console.log('✅ Database ready');
  } catch (err) {
    console.error('❌ DB init failed:', err.message);
  }
})();