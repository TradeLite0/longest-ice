/**
 * Backend Server للتطبيق اللوجستي
 * مع PostgreSQL Database + Admin Panel APIs
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
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// 📦 إعداد PostgreSQL
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
});

// 🚀 إنشاء الجداول لو مش موجودة
async function initDatabase() {
  try {
    // جدول المستخدمين (محدث مع is_approved)
    await pool.query(`
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        phone VARCHAR(20) UNIQUE NOT NULL,
        password VARCHAR(255) NOT NULL,
        name VARCHAR(100) NOT NULL,
        type VARCHAR(20) DEFAULT 'client',
        email VARCHAR(100),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        is_active BOOLEAN DEFAULT true,
        is_approved BOOLEAN DEFAULT false,
        last_login TIMESTAMP
      )
    `);

    // جدول مواقع السائقين (GPS Tracking)
    await pool.query(`
      CREATE TABLE IF NOT EXISTS driver_locations (
        id SERIAL PRIMARY KEY,
        driver_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        latitude DECIMAL(10, 8) NOT NULL,
        longitude DECIMAL(11, 8) NOT NULL,
        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        is_gps_active BOOLEAN DEFAULT true
      )
    `);

    // جدول الشحنات (محدث مع QR code)
    await pool.query(`
      CREATE TABLE IF NOT EXISTS shipments (
        id SERIAL PRIMARY KEY,
        tracking_number VARCHAR(50) UNIQUE NOT NULL,
        qr_code VARCHAR(100) UNIQUE,
        customer_name VARCHAR(100) NOT NULL,
        customer_phone VARCHAR(20),
        origin VARCHAR(100),
        destination VARCHAR(100) NOT NULL,
        service_type VARCHAR(50),
        weight DECIMAL(10, 2),
        cost DECIMAL(10, 2),
        status VARCHAR(20) DEFAULT 'pending',
        driver_id INTEGER REFERENCES users(id),
        notes TEXT,
        scanned_at TIMESTAMP,
        scanned_by INTEGER REFERENCES users(id),
        scan_location_lat DECIMAL(10, 8),
        scan_location_lng DECIMAL(11, 8),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
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

    // جدول الإشعارات
    await pool.query(`
      CREATE TABLE IF NOT EXISTS notifications (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id),
        title VARCHAR(200) NOT NULL,
        message TEXT NOT NULL,
        is_read BOOLEAN DEFAULT false,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // جدول جلسات المستخدمين (للتحكم في الوصول)
    await pool.query(`
      CREATE TABLE IF NOT EXISTS user_sessions (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        token TEXT,
        device_info TEXT,
        ip_address VARCHAR(50),
        is_active BOOLEAN DEFAULT true,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        last_activity TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    console.log('✅ Database tables created successfully');
  } catch (error) {
    console.error('❌ Database initialization error:', error);
  }
}

// ==================== AUTH MIDDLEWARE ====================

function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];
  
  if (!token) {
    return res.status(401).json({ success: false, message: 'مطلوب توكن المصادقة' });
  }
  
  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ success: false, message: 'توكن غير صالح' });
    }
    req.user = user;
    next();
  });
}

function requireAdmin(req, res, next) {
  if (req.user.type !== 'admin') {
    return res.status(403).json({ success: false, message: 'غير مصرح - يتطلب صلاحية مشرف' });
  }
  next();
}

// ==================== AUTH ROUTES ====================

/**
 * POST /api/auth/register
 * تسجيل حساب جديد
 */
app.post('/api/auth/register', async (req, res) => {
  try {
    const { phone, password, name, type, email } = req.body;
    
    // التحقق من وجود المستخدم
    const existingUser = await pool.query('SELECT * FROM users WHERE phone = $1', [phone]);
    if (existingUser.rows.length > 0) {
      return res.status(400).json({
        success: false,
        message: 'رقم الموبايل مسجل بالفعل'
      });
    }
    
    // تشفير كلمة المرور
    const hashedPassword = await bcrypt.hash(password, 10);
    
    // السائقين يحتاجون موافقة
    const needsApproval = type === 'driver' || type === 'admin';
    
    // إنشاء مستخدم جديد
    const result = await pool.query(
      'INSERT INTO users (phone, password, name, type, email, is_approved) VALUES ($1, $2, $3, $4, $5, $6) RETURNING id, phone, name, type, is_approved',
      [phone, hashedPassword, name, type || 'client', email, !needsApproval]
    );
    
    const newUser = result.rows[0];
    
    res.status(201).json({
      success: true,
      message: needsApproval ? 'تم إرسال الطلب للمراجعة' : 'تم التسجيل بنجاح',
      user: newUser,
      needsApproval
    });
    
  } catch (error) {
    console.error('Register error:', error);
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
});

/**
 * POST /api/auth/login
 * تسجيل الدخول مع التحقق من الموافقة
 */
app.post('/api/auth/login', async (req, res) => {
  try {
    const { phone, password, fcm_token } = req.body;
    
    // البحث عن المستخدم
    const result = await pool.query('SELECT * FROM users WHERE phone = $1', [phone]);
    const user = result.rows[0];
    
    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'رقم الموبايل أو كلمة المرور غير صحيحة'
      });
    }
    
    // التحقق من أن الحساب مفعل
    if (!user.is_active) {
      return res.status(403).json({
        success: false,
        message: 'الحساب معطل - تواصل مع المشرف',
        accountDisabled: true
      });
    }
    
    // التحقق من الموافقة (للسائقين والمشرفين)
    if (!user.is_approved && (user.type === 'driver' || user.type === 'admin')) {
      return res.status(403).json({
        success: false,
        message: 'الحساب في انتظار موافقة المشرف',
        pendingApproval: true
      });
    }
    
    // التحقق من كلمة المرور
    const isValidPassword = await bcrypt.compare(password, user.password);
    if (!isValidPassword) {
      return res.status(401).json({
        success: false,
        message: 'رقم الموبايل أو كلمة المرور غير صحيحة'
      });
    }
    
    // تحديث آخر دخول
    await pool.query('UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = $1', [user.id]);
    
    // إنشاء JWT Token
    const token = jwt.sign(
      { userId: user.id, phone: user.phone, type: user.type },
      JWT_SECRET,
      { expiresIn: '7d' }
    );
    
    // تسجيل الجلسة
    await pool.query(
      'INSERT INTO user_sessions (user_id, token, created_at) VALUES ($1, $2, CURRENT_TIMESTAMP)',
      [user.id, token]
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
        email: user.email,
        is_approved: user.is_approved
      }
    });
    
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
});

/**
 * GET /api/auth/profile
 * بيانات المستخدم
 */
app.get('/api/auth/profile', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, phone, name, type, email, is_active, is_approved, last_login FROM users WHERE id = $1',
      [req.user.userId]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'المستخدم غير موجود' });
    }
    
    const user = result.rows[0];
    
    // التحقق من أن الحساب مفعل
    if (!user.is_active) {
      return res.status(403).json({
        success: false,
        message: 'الحساب معطل',
        accountDisabled: true
      });
    }
    
    res.json({ success: true, user });
  } catch (error) {
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
});

/**
 * POST /api/auth/check-access
 * فحص صلاحية الوصول (يتم استدعاؤه عند فتح التطبيق)
 */
app.post('/api/auth/check-access', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT is_active, is_approved, type FROM users WHERE id = $1',
      [req.user.userId]
    );
    
    if (result.rows.length === 0) {
      return res.json({ success: false, canAccess: false, message: 'المستخدم غير موجود' });
    }
    
    const user = result.rows[0];
    
    if (!user.is_active) {
      return res.json({ 
        success: false, 
        canAccess: false, 
        message: 'الحساب معطل',
        accountDisabled: true 
      });
    }
    
    if (!user.is_approved && (user.type === 'driver' || user.type === 'admin')) {
      return res.json({ 
        success: false, 
        canAccess: false, 
        message: 'الحساب في انتظار الموافقة',
        pendingApproval: true 
      });
    }
    
    res.json({ success: true, canAccess: true });
  } catch (error) {
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
});

// ==================== ADMIN ROUTES ====================

/**
 * GET /api/admin/pending-users
 * المستخدمين في انتظار الموافقة
 */
app.get('/api/admin/pending-users', authenticateToken, requireAdmin, async (req, res) => {
  try {
    const result = await pool.query(
      "SELECT id, phone, name, type, email, created_at FROM users WHERE is_approved = false AND type IN ('driver', 'admin') ORDER BY created_at DESC"
    );
    
    res.json({ success: true, users: result.rows });
  } catch (error) {
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
});

/**
 * GET /api/admin/users
 * جميع المستخدمين
 */
app.get('/api/admin/users', authenticateToken, requireAdmin, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, phone, name, type, email, is_active, is_approved, created_at, last_login FROM users ORDER BY created_at DESC'
    );
    
    res.json({ success: true, users: result.rows });
  } catch (error) {
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
});

/**
 * PUT /api/admin/users/:id/approve
 * موافقة على مستخدم
 */
app.put('/api/admin/users/:id/approve', authenticateToken, requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const { role } = req.body;
    
    await pool.query(
      'UPDATE users SET is_approved = true, type = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2',
      [role || 'driver', id]
    );
    
    res.json({ success: true, message: 'تم الموافقة على المستخدم' });
  } catch (error) {
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
});

/**
 * PUT /api/admin/users/:id/role
 * تغيير دور المستخدم
 */
app.put('/api/admin/users/:id/role', authenticateToken, requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const { role } = req.body;
    
    await pool.query(
      'UPDATE users SET type = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2',
      [role, id]
    );
    
    res.json({ success: true, message: 'تم تحديث الدور' });
  } catch (error) {
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
});

/**
 * PUT /api/admin/users/:id/disable
 * تعطيل/تفعيل المستخدم
 */
app.put('/api/admin/users/:id/disable', authenticateToken, requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const { is_active } = req.body;
    
    await pool.query(
      'UPDATE users SET is_active = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2',
      [is_active, id]
    );
    
    // إلغاء جميع جلسات المستخدم
    if (!is_active) {
      await pool.query('UPDATE user_sessions SET is_active = false WHERE user_id = $1', [id]);
    }
    
    res.json({ 
      success: true, 
      message: is_active ? 'تم تفعيل المستخدم' : 'تم تعطيل المستخدم' 
    });
  } catch (error) {
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
});

/**
 * DELETE /api/admin/users/:id
 * حذف مستخدم
 */
app.delete('/api/admin/users/:id', authenticateToken, requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    
    // إلغاء الجلسات أولاً
    await pool.query('DELETE FROM user_sessions WHERE user_id = $1', [id]);
    
    // حذف المستخدم
    await pool.query('DELETE FROM users WHERE id = $1', [id]);
    
    res.json({ success: true, message: 'تم حذف المستخدم' });
  } catch (error) {
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
});

// ==================== GPS TRACKING ROUTES ====================

/**
 * POST /api/drivers/location
 * تحديث موقع السائق
 */
app.post('/api/drivers/location', authenticateToken, async (req, res) => {
  try {
    const { latitude, longitude, is_gps_active } = req.body;
    const driverId = req.user.userId;
    
    // حذف الموقع القديم
    await pool.query('DELETE FROM driver_locations WHERE driver_id = $1', [driverId]);
    
    // إضافة الموقع الجديد
    await pool.query(
      'INSERT INTO driver_locations (driver_id, latitude, longitude, is_gps_active) VALUES ($1, $2, $3, $4)',
      [driverId, latitude, longitude, is_gps_active !== false]
    );
    
    res.json({ success: true, message: 'تم تحديث الموقع' });
  } catch (error) {
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
});

/**
 * POST /api/drivers/gps-disabled
 * إشعار عند إيقاف GPS
 */
app.post('/api/drivers/gps-disabled', authenticateToken, async (req, res) => {
  try {
    const { latitude, longitude, reason } = req.body;
    const driverId = req.user.userId;
    
    // تحديث حالة GPS
    await pool.query(
      'UPDATE driver_locations SET is_gps_active = false WHERE driver_id = $1',
      [driverId]
    );
    
    // إضافة إشعار للمشرف
    await pool.query(
      `INSERT INTO notifications (user_id, title, message) 
       VALUES ((SELECT id FROM users WHERE type = 'admin' LIMIT 1), $1, $2)`,
      ['GPS متوقف', `السائق ${driverId} قام بإيقاف GPS - الموقع الأخير: ${latitude}, ${longitude}`]
    );
    
    res.json({ success: true, message: 'تم إرسال الإشعار' });
  } catch (error) {
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
});

/**
 * GET /api/admin/drivers-locations
 * أماكن جميع السائقين (للمشرف)
 */
app.get('/api/admin/drivers-locations', authenticateToken, requireAdmin, async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT dl.driver_id, dl.latitude, dl.longitude, dl.timestamp, dl.is_gps_active,
             u.name as driver_name, u.phone as driver_phone
      FROM driver_locations dl
      JOIN users u ON dl.driver_id = u.id
      WHERE dl.timestamp > NOW() - INTERVAL '1 hour'
      ORDER BY dl.timestamp DESC
    `);
    
    res.json({ success: true, locations: result.rows });
  } catch (error) {
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
});

/**
 * GET /api/drivers/:id/location
 * موقع سائق محدد
 */
app.get('/api/drivers/:id/location', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    
    const result = await pool.query(
      'SELECT * FROM driver_locations WHERE driver_id = $1 ORDER BY timestamp DESC LIMIT 1',
      [id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'لا يوجد موقع' });
    }
    
    res.json({ success: true, location: result.rows[0] });
  } catch (error) {
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
});

// ==================== SHIPMENTS & QR SCANNER ROUTES ====================

/**
 * POST /api/shipments/scan
 * مسح QR Code
 */
app.post('/api/shipments/scan', authenticateToken, async (req, res) => {
  try {
    const { qr_code } = req.body;
    const userId = req.user.userId;
    
    // البحث عن الشحنة
    const result = await pool.query(
      'SELECT * FROM shipments WHERE qr_code = $1 OR tracking_number = $1',
      [qr_code]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'الشحنة غير موجودة' });
    }
    
    const shipment = result.rows[0];
    
    // تحديث بيانات المسح
    await pool.query(
      'UPDATE shipments SET scanned_at = CURRENT_TIMESTAMP, scanned_by = $1 WHERE id = $2',
      [userId, shipment.id]
    );
    
    res.json({ success: true, shipment });
  } catch (error) {
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
});

/**
 * PUT /api/shipments/scan/status
 * تحديث حالة الشحنة عبر QR
 */
app.put('/api/shipments/scan/status', authenticateToken, async (req, res) => {
  try {
    const { qr_code, status, location_lat, location_lng, notes } = req.body;
    const userId = req.user.userId;
    
    // البحث عن الشحنة
    const shipmentResult = await pool.query(
      'SELECT * FROM shipments WHERE qr_code = $1 OR tracking_number = $1',
      [qr_code]
    );
    
    if (shipmentResult.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'الشحنة غير موجودة' });
    }
    
    const shipment = shipmentResult.rows[0];
    
    // تحديث حالة الشحنة
    await pool.query(
      'UPDATE shipments SET status = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2',
      [status, shipment.id]
    );
    
    // إضافة للتاريخ
    await pool.query(
      'INSERT INTO shipment_status_history (shipment_id, status, location_lat, location_lng, notes, updated_by) VALUES ($1, $2, $3, $4, $5, $6)',
      [shipment.id, status, location_lat, location_lng, notes, userId]
    );
    
    res.json({ success: true, message: 'تم تحديث الحالة' });
  } catch (error) {
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
});

/**
 * GET /api/admin/shipments
 * جميع الشحنات (للمشرف)
 */
app.get('/api/admin/shipments', authenticateToken, requireAdmin, async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT s.*, u.name as driver_name 
      FROM shipments s 
      LEFT JOIN users u ON s.driver_id = u.id 
      ORDER BY s.created_at DESC
    `);
    
    res.json({ success: true, shipments: result.rows });
  } catch (error) {
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
});

/**
 * DELETE /api/admin/shipments/:id
 * حذف شحنة
 */
app.delete('/api/admin/shipments/:id', authenticateToken, requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    
    // حذف التاريخ أولاً
    await pool.query('DELETE FROM shipment_status_history WHERE shipment_id = $1', [id]);
    
    // حذف الشحنة
    await pool.query('DELETE FROM shipments WHERE id = $1', [id]);
    
    res.json({ success: true, message: 'تم حذف الشحنة' });
  } catch (error) {
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
});

// ==================== NOTIFICATIONS ROUTES ====================

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

// ==================== WEB ADMIN PANEL ====================

// تقديم ملفات الـ Admin Panel الثابتة
app.use('/admin-panel', express.static(path.join(__dirname, 'admin-panel')));

// صفحة Admin Panel الرئيسية
app.get('/admin', (req, res) => {
  res.redirect('/admin-panel/index.html');
});

// ==================== HEALTH CHECK ====================

app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'OK', database: 'connected', timestamp: new Date().toISOString() });
  } catch (error) {
    res.status(500).json({ status: 'ERROR', database: 'disconnected', error: error.message });
  }
});

// ==================== START SERVER ====================

initDatabase().then(() => {
  app.listen(PORT, '0.0.0.0', () => {
    console.log('🚀 ==========================================');
    console.log('🚀  Logistics Backend Server');
    console.log('🚀  PostgreSQL Database + Admin Panel');
    console.log('🚀 ==========================================');
    console.log(`🚀  API Server: http://localhost:${PORT}`);
    console.log(`🚀  Admin Panel: http://localhost:${PORT}/admin`);
    console.log('🚀 ==========================================');
  });
});
