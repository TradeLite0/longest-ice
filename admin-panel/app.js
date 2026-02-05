// Admin Panel JavaScript
const API_URL = window.location.origin + '/api';
let token = localStorage.getItem('adminToken');
let currentUser = null;
let map = null;
let driversMarkers = {};

// ==================== AUTH ====================

async function login() {
    const phone = document.getElementById('loginPhone').value;
    const password = document.getElementById('loginPassword').value;
    
    try {
        const res = await fetch(`${API_URL}/auth/login`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ phone, password })
        });
        
        const data = await res.json();
        
        if (data.success) {
            token = data.token;
            currentUser = data.user;
            localStorage.setItem('adminToken', token);
            
            if (!['admin', 'super_admin'].includes(data.user.type)) {
                alert('غير مصرح لك بالدخول');
                return;
            }
            
            document.getElementById('loginPage').classList.add('hidden');
            document.getElementById('mainApp').classList.remove('hidden');
            document.getElementById('userName').textContent = data.user.name;
            
            loadDashboard();
            initMap();
        } else {
            alert(data.message);
        }
    } catch (err) {
        console.error('Login error:', err);
        alert('خطأ في الاتصال');
    }
}

function logout() {
    localStorage.removeItem('adminToken');
    location.reload();
}

// ==================== NAVIGATION ====================

function showSection(sectionId) {
    // Hide all sections
    document.querySelectorAll('.section').forEach(s => s.classList.remove('active'));
    document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
    
    // Show selected
    document.getElementById(sectionId).classList.add('active');
    event.target.closest('.nav-item').classList.add('active');
    
    // Update title
    const titles = {
        dashboard: 'لوحة التحكم',
        drivers: 'إدارة السائقين',
        clients: 'إدارة العملاء',
        shipments: 'إدارة الشحنات',
        complaints: 'إدارة الشكاوى',
        liveMap: 'الخريطة الحية'
    };
    document.getElementById('pageTitle').textContent = titles[sectionId];
    
    // Load data
    if (sectionId === 'drivers') loadDrivers();
    if (sectionId === 'clients') loadClients();
    if (sectionId === 'shipments') loadShipments();
    if (sectionId === 'complaints') loadComplaints();
    if (sectionId === 'liveMap') refreshMap();
}

// ==================== DASHBOARD ====================

async function loadDashboard() {
    try {
        const res = await fetch(`${API_URL}/admin/dashboard`, {
            headers: { 'Authorization': `Bearer ${token}` }
        });
        const data = await res.json();
        
        if (data.success) {
            document.getElementById('statDrivers').textContent = data.stats.active_drivers;
            document.getElementById('statClients').textContent = data.stats.total_clients;
            document.getElementById('statShipments').textContent = data.stats.active_shipments;
            document.getElementById('statComplaints').textContent = data.stats.pending_complaints;
        }
    } catch (err) {
        console.error('Dashboard error:', err);
    }
}

// ==================== DRIVERS ====================

async function loadDrivers() {
    try {
        const res = await fetch(`${API_URL}/admin/users?type=driver`, {
            headers: { 'Authorization': `Bearer ${token}` }
        });
        const data = await res.json();
        
        const tbody = document.getElementById('driversTable');
        tbody.innerHTML = '';
        
        if (data.success) {
            data.users.forEach(driver => {
                const row = document.createElement('tr');
                row.innerHTML = `
                    <td>${driver.name}</td>
                    <td>${driver.phone}</td>
                    <td>
                        ${driver.is_approved 
                            ? '<span class="badge badge-success">نشط</span>' 
                            : '<span class="badge badge-warning">في الانتظار</span>'}
                    </td>
                    <td>-</td>
                    <td>
                        <button class="btn btn-primary" style="padding: 5px 10px; font-size: 12px;" 
                            onclick="trackDriver(${driver.id})">
                            <i class="fas fa-map-marker-alt"></i> تتبع
                        </button>
                    </td>
                `;
                tbody.appendChild(row);
            });
        }
    } catch (err) {
        console.error('Load drivers error:', err);
    }
}

async function addDriver() {
    const name = document.getElementById('newDriverName').value;
    const phone = document.getElementById('newDriverPhone').value;
    const password = document.getElementById('newDriverPassword').value;
    
    try {
        const res = await fetch(`${API_URL}/admin/create-user`, {
            method: 'POST',
            headers: { 
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${token}`
            },
            body: JSON.stringify({ name, phone, password, type: 'driver' })
        });
        
        const data = await res.json();
        
        if (data.success) {
            closeModal('addDriver');
            loadDrivers();
            alert('تم إضافة السائق بنجاح');
        } else {
            alert(data.message);
        }
    } catch (err) {
        console.error('Add driver error:', err);
    }
}

// ==================== CLIENTS ====================

async function loadClients() {
    try {
        const res = await fetch(`${API_URL}/admin/users?type=client`, {
            headers: { 'Authorization': `Bearer ${token}` }
        });
        const data = await res.json();
        
        const tbody = document.getElementById('clientsTable');
        tbody.innerHTML = '';
        
        if (data.success) {
            data.users.forEach(client => {
                const row = document.createElement('tr');
                row.innerHTML = `
                    <td>${client.name}</td>
                    <td>${client.phone}</td>
                    <td>${new Date(client.created_at).toLocaleDateString('ar-EG')}</td>
                    <td>-</td>
                `;
                tbody.appendChild(row);
            });
        }
    } catch (err) {
        console.error('Load clients error:', err);
    }
}

// ==================== SHIPMENTS ====================

async function loadShipments() {
    try {
        const res = await fetch(`${API_URL}/shipments`, {
            headers: { 'Authorization': `Bearer ${token}` }
        });
        const data = await res.json();
        
        const tbody = document.getElementById('shipmentsTable');
        tbody.innerHTML = '';
        
        if (data.success) {
            data.shipments.forEach(ship => {
                const statusBadge = {
                    pending: '<span class="badge badge-warning">معلقة</span>',
                    assigned: '<span class="badge badge-info">مخصصة</span>',
                    picked_up: '<span class="badge badge-info">تم الاستلام</span>',
                    in_transit: '<span class="badge badge-warning">في الطريق</span>',
                    delivered: '<span class="badge badge-success">تم التسليم</span>',
                    cancelled: '<span class="badge badge-danger">ملغية</span>'
                };
                
                const row = document.createElement('tr');
                row.innerHTML = `
                    <td>${ship.tracking_number}</td>
                    <td>${ship.customer_name}</td>
                    <td>${ship.driver_name || '-'}</td>
                    <td>${statusBadge[ship.status] || ship.status}</td>
                    <td>${new Date(ship.created_at).toLocaleDateString('ar-EG')}</td>
                `;
                tbody.appendChild(row);
            });
        }
    } catch (err) {
        console.error('Load shipments error:', err);
    }
}

// ==================== COMPLAINTS ====================

async function loadComplaints() {
    try {
        const res = await fetch(`${API_URL}/complaints`, {
            headers: { 'Authorization': `Bearer ${token}` }
        });
        const data = await res.json();
        
        const tbody = document.getElementById('complaintsTable');
        tbody.innerHTML = '';
        
        if (data.success) {
            data.complaints.forEach(comp => {
                const priorityBadge = {
                    urgent: '<span class="badge badge-danger">عاجل</span>',
                    high: '<span class="badge badge-warning">عالي</span>',
                    medium: '<span class="badge badge-info">متوسط</span>',
                    low: '<span class="badge">منخفض</span>'
                };
                
                const statusBadge = {
                    open: '<span class="badge badge-danger">مفتوحة</span>',
                    in_progress: '<span class="badge badge-warning">قيد المعالجة</span>',
                    resolved: '<span class="badge badge-success">محلولة</span>',
                    closed: '<span class="badge">مغلقة</span>'
                };
                
                const row = document.createElement('tr');
                row.innerHTML = `
                    <td>${comp.title}</td>
                    <td>${comp.complaint_type}</td>
                    <td>${priorityBadge[comp.priority]}</td>
                    <td>${statusBadge[comp.status]}</td>
                    <td>${new Date(comp.created_at).toLocaleDateString('ar-EG')}</td>
                    <td>
                        <button class="btn btn-primary" style="padding: 5px 10px; font-size: 12px;"
                            onclick="viewComplaint(${comp.id})">عرض</button>
                    </td>
                `;
                tbody.appendChild(row);
            });
        }
    } catch (err) {
        console.error('Load complaints error:', err);
    }
}

// ==================== LIVE MAP ====================

function initMap() {
    map = L.map('map').setView([30.0444, 31.2357], 12);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '© OpenStreetMap'
    }).addTo(map);
}

async function refreshMap() {
    if (!map) return;
    
    try {
        const res = await fetch(`${API_URL}/location/drivers`, {
            headers: { 'Authorization': `Bearer ${token}` }
        });
        const data = await res.json();
        
        if (data.success) {
            // Clear old markers
            Object.values(driversMarkers).forEach(m => map.removeLayer(m));
            driversMarkers = {};
            
            // Add new markers
            data.drivers.forEach(driver => {
                if (!driver.latitude || !driver.longitude) return;
                
                const color = driver.shipment_status ? 'orange' : 'green';
                const icon = L.divIcon({
                    className: 'custom-div-icon',
                    html: `<div style="background-color: ${color}; width: 15px; height: 15px; border-radius: 50%; border: 3px solid white; box-shadow: 0 2px 5px rgba(0,0,0,0.3);"></div>`,
                    iconSize: [20, 20],
                    iconAnchor: [10, 10]
                });
                
                const marker = L.marker([driver.latitude, driver.longitude], { icon })
                    .addTo(map)
                    .bindPopup(`
                        <b>${driver.name}</b><br>
                        ${driver.phone}<br>
                        <small>آخر تحديث: ${new Date(driver.timestamp).toLocaleTimeString('ar-EG')}</small>
                    `);
                
                driversMarkers[driver.driver_id] = marker;
            });
        }
    } catch (err) {
        console.error('Refresh map error:', err);
    }
}

// Auto refresh map every 30 seconds
setInterval(() => {
    if (document.getElementById('liveMap').classList.contains('active')) {
        refreshMap();
    }
}, 30000);

// ==================== MODALS ====================

function openModal(modalId) {
    document.getElementById(modalId + 'Modal').classList.add('active');
}

function closeModal(modalId) {
    document.getElementById(modalId + 'Modal').classList.remove('active');
}

// ==================== INIT ====================

// Check if already logged in
if (token) {
    fetch(`${API_URL}/auth/me`, {
        headers: { 'Authorization': `Bearer ${token}` }
    })
    .then(res => res.json())
    .then(data => {
        if (data.success && ['admin', 'super_admin'].includes(data.user.type)) {
            currentUser = data.user;
            document.getElementById('loginPage').classList.add('hidden');
            document.getElementById('mainApp').classList.remove('hidden');
            document.getElementById('userName').textContent = data.user.name;
            loadDashboard();
            initMap();
        } else {
            localStorage.removeItem('adminToken');
        }
    })
    .catch(() => {
        localStorage.removeItem('adminToken');
    });
}