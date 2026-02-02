/**
 * Backend Server للتطبيق اللوجستي
 * مع PostgreSQL Database
 */

const express = require('express');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const bodyParser = require('body-parser');
const { Pool } = require('pg');

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
    // جدول المستخدمين
    await pool.query(`
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        phone VARCHAR(20) UNIQUE NOT NULL,
        password VARCHAR(255) NOT NULL,
        name VARCHAR(100) NOT NULL,
        type VARCHAR(20) DEFAULT 'driver',
        email VARCHAR(100),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        is_active BOOLEAN DEFAULT true
      )
    `);

    // جدول الطلبات
    await pool.query(`
      CREATE TABLE IF NOT EXISTS orders (
        id SERIAL PRIMARY KEY,
        order_number VARCHAR(50) UNIQUE NOT NULL,
        customer_name VARCHAR(100) NOT NULL,
        customer_phone VARCHAR(20),
        address TEXT NOT NULL,
        amount DECIMAL(10,2) NOT NULL,
        status VARCHAR(20) DEFAULT 'pending',
        driver_id INTEGER REFERENCES users(id),
        notes TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
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

    console.log('✅ Database tables created successfully');
  } catch (error) {
    console.error('❌ Database initialization error:', error);
  }
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
    
    // إنشاء مستخدم جديد
    const result = await pool.query(
      'INSERT INTO users (phone, password, name, type, email) VALUES ($1, $2, $3, $4, $5) RETURNING id, phone, name, type',
      [phone, hashedPassword, name, type || 'driver', email]
    );
    
    const newUser = result.rows[0];
    
    // إنشاء JWT Token
    const token = jwt.sign(
      { userId: newUser.id, phone: newUser.phone, type: newUser.type },
      JWT_SECRET,
      { expiresIn: '7d' }
    );
    
    res.status(201).json({
      success: true,
      message: 'تم التسجيل بنجاح',
      token,
      user: newUser
    });
    
  } catch (error) {
    console.error('Register error:', error);
    res.status(500).json({
      success: false,
      message: 'خطأ في الخادم'
    });
  }
});

/**
 * POST /api/auth/login
 * تسجيل الدخول
 */
app.post('/api/auth/login', async (req, res) => {
  try {
    const { phone, password } = req.body;
    
    // البحث عن المستخدم
    const result = await pool.query('SELECT * FROM users WHERE phone = $1', [phone]);
    const user = result.rows[0];
    
    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'رقم الموبايل أو كلمة المرور غير صحيحة'
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
    
    // إنشاء JWT Token
    const token = jwt.sign(
      { userId: user.id, phone: user.phone, type: user.type },
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
        email: user.email
      },
      user_type: user.type
    });
    
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({
      success: false,
      message: 'خطأ في الخادم'
    });
  }
});

/**
 * POST /api/auth/reset-password
 * إعادة تعيين كلمة المرور
 */
app.post('/api/auth/reset-password', async (req, res) => {
  try {
    const { phone, new_password } = req.body;
    
    const result = await pool.query('SELECT * FROM users WHERE phone = $1', [phone]);
    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'المستخدم غير موجود'
      });
    }
    
    // تشفير كلمة المرور الجديدة
    const hashedPassword = await bcrypt.hash(new_password, 10);
    await pool.query('UPDATE users SET password = $1 WHERE phone = $2', [hashedPassword, phone]);
    
    res.json({
      success: true,
      message: 'تم تغيير كلمة المرور بنجاح'
    });
    
  } catch (error) {
    console.error('Reset password error:', error);
    res.status(500).json({
      success: false,
      message: 'خطأ في الخادم'
    });
  }
});

// ==================== ORDERS ROUTES ====================

/**
 * GET /api/orders/driver
 * جلب طلبات المندوب
 */
app.get('/api/orders/driver', async (req, res) => {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];
    
    if (!token) {
      return res.status(401).json({ success: false, message: 'مطلوب توكن' });
    }
    
    const decoded = jwt.verify(token, JWT_SECRET);
    
    const result = await pool.query(
      'SELECT * FROM orders WHERE driver_id = $1 ORDER BY created_at DESC',
      [decoded.userId]
    );
    
    res.json({ success: true, orders: result.rows });
  } catch (error) {
    console.error('Get orders error:', error);
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
});

/**
 * POST /api/orders
 * إنشاء طلب جديد
 */
app.post('/api/orders', async (req, res) => {
  try {
    const { order_number, customer_name, customer_phone, address, amount, driver_id, notes } = req.body;
    
    const result = await pool.query(
      'INSERT INTO orders (order_number, customer_name, customer_phone, address, amount, driver_id, notes) VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *',
      [order_number, customer_name, customer_phone, address, amount, driver_id, notes]
    );
    
    res.status(201).json({ success: true, order: result.rows[0] });
  } catch (error) {
    console.error('Create order error:', error);
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
});

/**
 * PUT /api/orders/:id/status
 * تحديث حالة الطلب
 */
app.put('/api/orders/:id/status', async (req, res) => {
  try {
    const { id } = req.params;
    const { status, notes } = req.body;
    
    const result = await pool.query(
      'UPDATE orders SET status = $1, notes = $2, updated_at = CURRENT_TIMESTAMP WHERE id = $3 RETURNING *',
      [status, notes, id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'الطلب غير موجود' });
    }
    
    res.json({ success: true, order: result.rows[0] });
  } catch (error) {
    console.error('Update order error:', error);
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
});

// ==================== WHATSAPP ROUTES ====================

app.post('/api/whatsapp/send', (req, res) => {
  try {
    const { phone, message } = req.body;
    console.log('📱 WhatsApp Message to:', phone);
    console.log('Message:', message);
    
    res.json({
      success: true,
      message: 'تم إرسال الرسالة',
      note: 'محاكاة - هنربط WhatsApp API قريباً'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: 'خطأ في إرسال الرسالة' });
  }
});

// ==================== PROTECTED ROUTES ====================

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

app.get('/api/user/profile', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query('SELECT id, phone, name, type, email FROM users WHERE id = $1', [req.user.userId]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'المستخدم غير موجود' });
    }
    
    res.json({ success: true, user: result.rows[0] });
  } catch (error) {
    res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
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
    console.log('🚀  PostgreSQL Database');
    console.log('🚀 ==========================================');
    console.log(`🚀  Running on: http://localhost:${PORT}`);
    console.log('🚀 ==========================================');
  });
});
