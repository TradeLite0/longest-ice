/**
 * Admin Panel JavaScript
 * Logistics Pro - لوحة تحكم المشرف
 */

// API Base URL
const API_URL = window.location.origin;

// Global State
let authToken = localStorage.getItem('admin_token');
let currentUser = null;
let map = null;
let mapLarge = null;
let driversMarkers = [];

// ==================== AUTH ====================

document.getElementById('login-form')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    
    const phone = document.getElementById('phone').value;
    const password = document.getElementById('password').value;
    
    try {
        const response = await fetch(`${API_URL}/api/auth/login`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ phone, password })
        });
        
        const data = await response.json();
        
        if (data.success && data.user.type === 'admin') {
            authToken = data.token;
            currentUser = data.user;
            localStorage.setItem('admin_token', authToken);
            showDashboard();
        } else {
            showError(data.message || 'غير مصرح - يجب أن تكون مشرف');
        }
    } catch (error) {
        showError('خطأ في الاتصال بالخادم');
    }
});

function showError(message) {
    const errorDiv = document.getElementById('login-error');
    errorDiv.textContent = message;
    errorDiv.style.display = 'block';
}

function logout() {
    authToken = null;
    currentUser = null;
    localStorage.removeItem('admin_token');
    document.getElementById('login-page').classList.remove('hidden');
    document.getElementById('dashboard').classList.add('hidden');
}

function showDashboard() {
    document.getElementById('login-page').classList.add('hidden');
    document.getElementById('dashboard').classList.remove('hidden');
    
    // Initialize map
    initMaps();
    
    // Load data
    loadStats();
    loadUsers();
    loadPendingUsers();
    loadShipments();
    loadDriversLocations();
    
    // Auto refresh every 10 seconds
    setInterval(() => {
        loadStats();
        loadDriversLocations();
    }, 10000);
}

// ==================== NAVIGATION ====================

document.querySelectorAll('.nav-item').forEach(item => {
    item.addEventListener('click', () => {
        // Update active nav
        document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
        item.classList.add('active');
        
        // Show section
        const section = item.dataset.section;
        document.querySelectorAll('.section').forEach(s => s.classList.remove('active'));
        document.getElementById(`section-${section}`).classList.add('active');
        
        // Update title
        const titles = {
            overview: 'لوحة التحكم',
            users: 'المستخدمين',
            pending: 'في انتظار الموافقة',
            shipments: 'الشحنات',
            map: 'خريطة السائقين'
        };
        document.getElementById('page-title').textContent = titles[section];
    });
});

// ==================== MAPS ====================

function initMaps() {
    // Small map in overview
    map = L.map('map').setView([26.8206, 30.8025], 6);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '© OpenStreetMap'
    }).addTo(map);
    
    // Large map
    mapLarge = L.map('map-large').setView([26.8206, 30.8025], 6);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '© OpenStreetMap'
    }).addTo(mapLarge);
}

function updateMaps(locations) {
    // Clear old markers
    driversMarkers.forEach(m => {
        map.removeLayer(m);
        mapLarge.removeLayer(m);
    });
    driversMarkers = [];
    
    // Add new markers
    locations.forEach(driver => {
        const markerHtml = `
            <div style="text-align: center;">
                <div style="background: #ff6b35; color: white; padding: 4px 8px; border-radius: 4px; font-size: 12px; font-weight: bold; margin-bottom: 2px;">
                    ${driver.driver_name}
                </div>
                <div style="color: #ff6b35; font-size: 24px;">📍</div>
            </div>
        `;
        
        const icon = L.divIcon({
            html: markerHtml,
            className: 'driver-marker',
            iconSize: [100, 50]
        });
        
        const marker = L.marker([driver.latitude, driver.longitude], { icon })
            .bindPopup(`
                <b>${driver.driver_name}</b><br>
                رقم: ${driver.driver_phone}<br>
                آخر تحديث: ${new Date(driver.timestamp).toLocaleString('ar-EG')}
            `);
        
        marker.addTo(map);
        const markerClone = L.marker([driver.latitude, driver.longitude], { icon })
            .bindPopup(`
                <b>${driver.driver_name}</b><br>
                رقم: ${driver.driver_phone}<br>
                آخر تحديث: ${new Date(driver.timestamp).toLocaleString('ar-EG')}
            `);
        markerClone.addTo(mapLarge);
        
        driversMarkers.push(marker, markerClone);
    });
}

// ==================== API CALLS ====================

async function apiCall(endpoint, options = {}) {
    const response = await fetch(`${API_URL}${endpoint}`, {
        ...options,
        headers: {
            'Authorization': `Bearer ${authToken}`,
            'Content-Type': 'application/json',
            ...options.headers
        }
    });
    return response.json();
}

// ==================== LOAD DATA ====================

async function loadStats() {
    try {
        const [usersRes, driversRes, shipmentsRes, pendingRes] = await Promise.all([
            apiCall('/api/admin/users'),
            apiCall('/api/admin/drivers-locations'),
            apiCall('/api/admin/shipments'),
            apiCall('/api/admin/pending-users')
        ]);
        
        if (usersRes.success) {
            document.getElementById('total-users').textContent = usersRes.users.length;
        }
        
        if (driversRes.success) {
            document.getElementById('active-drivers').textContent = driversRes.locations.length;
        }
        
        if (shipmentsRes.success) {
            document.getElementById('total-shipments').textContent = shipmentsRes.shipments.length;
        }
        
        if (pendingRes.success) {
            document.getElementById('pending-users-count').textContent = pendingRes.users.length;
            document.getElementById('pending-count').textContent = pendingRes.users.length;
        }
    } catch (error) {
        console.error('Error loading stats:', error);
    }
}

async function loadUsers() {
    try {
        const data = await apiCall('/api/admin/users');
        
        if (data.success) {
            const tbody = document.getElementById('users-table');
            tbody.innerHTML = data.users.map(user => `
                <tr>
                    <td>${user.name}</td>
                    <td>${user.phone}</td>
                    <td><span class="role-badge ${user.type}">${getRoleName(user.type)}</span></td>
                    <td><span class="status-badge ${user.is_active ? 'active' : 'disabled'}">${user.is_active ? 'مفعل' : 'معطل'}</span></td>
                    <td>${user.last_login ? new Date(user.last_login).toLocaleString('ar-EG') : '-'}</td>
                    <td>
                        <div class="action-btns">
                            ${user.is_active 
                                ? `<button class="btn btn-disable" onclick="toggleUser(${user.id}, false)"><i class="fas fa-ban"></i> تعطيل</button>`
                                : `<button class="btn btn-enable" onclick="toggleUser(${user.id}, true)"><i class="fas fa-check"></i> تفعيل</button>`
                            }
                            <button class="btn btn-delete" onclick="deleteUser(${user.id})"><i class="fas fa-trash"></i> حذف</button>
                        </div>
                    </td>
                </tr>
            `).join('');
        }
    } catch (error) {
        console.error('Error loading users:', error);
    }
}

async function loadPendingUsers() {
    try {
        const data = await apiCall('/api/admin/pending-users');
        
        if (data.success) {
            const tbody = document.getElementById('pending-table');
            tbody.innerHTML = data.users.map(user => `
                <tr>
                    <td>${user.name}</td>
                    <td>${user.phone}</td>
                    <td><span class="role-badge ${user.type}">${getRoleName(user.type)}</span></td>
                    <td>${new Date(user.created_at).toLocaleString('ar-EG')}</td>
                    <td>
                        <div class="action-btns">
                            <button class="btn btn-approve" onclick="approveUser(${user.id}, '${user.type}')"><i class="fas fa-check"></i> موافقة</button>
                            <button class="btn btn-reject" onclick="rejectUser(${user.id})"><i class="fas fa-times"></i> رفض</button>
                        </div>
                    </td>
                </tr>
            `).join('');
        }
    } catch (error) {
        console.error('Error loading pending users:', error);
    }
}

async function loadShipments() {
    try {
        const data = await apiCall('/api/admin/shipments');
        
        if (data.success) {
            const tbody = document.getElementById('shipments-table');
            tbody.innerHTML = data.shipments.map(shipment => `
                <tr>
                    <td>${shipment.tracking_number}</td>
                    <td>${shipment.customer_name}</td>
                    <td>${shipment.destination}</td>
                    <td><span class="status-badge ${getStatusClass(shipment.status)}">${getStatusName(shipment.status)}</span></td>
                    <td>${shipment.driver_name || '-'}</td>
                    <td>
                        <div class="action-btns">
                            <button class="btn btn-delete" onclick="deleteShipment(${shipment.id})"><i class="fas fa-trash"></i> حذف</button>
                        </div>
                    </td>
                </tr>
            `).join('');
        }
    } catch (error) {
        console.error('Error loading shipments:', error);
    }
}

async function loadDriversLocations() {
    try {
        const data = await apiCall('/api/admin/drivers-locations');
        
        if (data.success) {
            updateMaps(data.locations);
        }
    } catch (error) {
        console.error('Error loading drivers locations:', error);
    }
}

// ==================== ACTIONS ====================

async function approveUser(userId, role) {
    try {
        const data = await apiCall(`/api/admin/users/${userId}/approve`, {
            method: 'PUT',
            body: JSON.stringify({ role })
        });
        
        if (data.success) {
            alert('تم الموافقة على المستخدم');
            loadPendingUsers();
            loadUsers();
            loadStats();
        }
    } catch (error) {
        alert('خطأ في الموافقة');
    }
}

async function rejectUser(userId) {
    if (!confirm('هل أنت متأكد من رفض هذا المستخدم؟')) return;
    
    try {
        const data = await apiCall(`/api/admin/users/${userId}`, {
            method: 'DELETE'
        });
        
        if (data.success) {
            alert('تم رفض المستخدم');
            loadPendingUsers();
            loadStats();
        }
    } catch (error) {
        alert('خطأ في الرفض');
    }
}

async function toggleUser(userId, isActive) {
    try {
        const data = await apiCall(`/api/admin/users/${userId}/disable`, {
            method: 'PUT',
            body: JSON.stringify({ is_active: isActive })
        });
        
        if (data.success) {
            alert(isActive ? 'تم تفعيل المستخدم' : 'تم تعطيل المستخدم');
            loadUsers();
            loadStats();
        }
    } catch (error) {
        alert('خطأ في التحديث');
    }
}

async function deleteUser(userId) {
    if (!confirm('هل أنت متأكد من حذف هذا المستخدم؟ لا يمكن التراجع!')) return;
    
    try {
        const data = await apiCall(`/api/admin/users/${userId}`, {
            method: 'DELETE'
        });
        
        if (data.success) {
            alert('تم حذف المستخدم');
            loadUsers();
            loadStats();
        }
    } catch (error) {
        alert('خطأ في الحذف');
    }
}

async function deleteShipment(shipmentId) {
    if (!confirm('هل أنت متأكد من حذف هذه الشحنة؟')) return;
    
    try {
        const data = await apiCall(`/api/admin/shipments/${shipmentId}`, {
            method: 'DELETE'
        });
        
        if (data.success) {
            alert('تم حذف الشحنة');
            loadShipments();
            loadStats();
        }
    } catch (error) {
        alert('خطأ في الحذف');
    }
}

// ==================== HELPERS ====================

function getRoleName(role) {
    const names = {
        admin: 'مشرف',
        driver: 'سائق',
        client: 'عميل'
    };
    return names[role] || role;
}

function getStatusName(status) {
    const names = {
        pending: 'قيد الانتظار',
        loading: 'جاري التحميل',
        in_transit: 'في الطريق',
        delivered: 'تم التسليم',
        cancelled: 'ملغي'
    };
    return names[status] || status;
}

function getStatusClass(status) {
    const classes = {
        pending: 'pending',
        loading: 'active',
        in_transit: 'active',
        delivered: 'active',
        cancelled: 'disabled'
    };
    return classes[status] || 'pending';
}

// ==================== INIT ====================

// Check if already logged in
if (authToken) {
    showDashboard();
}
