const express = require('express');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = 3000;
const DATA_DIR = path.join(__dirname, 'data');
const MENU_FILE = path.join(DATA_DIR, 'menu.json');
const ORDERS_FILE = path.join(DATA_DIR, 'orders.json');
const ADMIN_PASSWORD = 'infinity@2025';

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR);

if (!fs.existsSync(MENU_FILE)) {
  const defaultMenu = [
    { id: 1, name: 'ข้าวผัดกะเพราไก่', category: 'ข้าวผัด', price: 45, description: 'ข้าวผัดกะเพราไก่สูตรต้นตำรับ รสชาติกลมกล่อม', emoji: '🍚', available: true, updatedAt: new Date().toISOString() },
    { id: 2, name: 'ข้าวมันไก่', category: 'ข้าวมัน', price: 50, description: 'ข้าวมันไก่นุ่ม พร้อมน้ำจิ้มสูตรพิเศษ', emoji: '🍗', available: true, updatedAt: new Date().toISOString() },
    { id: 3, name: 'ผัดไทยกุ้ง', category: 'เส้น', price: 55, description: 'ผัดไทยกุ้งสด หอมอร่อยเส้นนุ่ม', emoji: '🍜', available: true, updatedAt: new Date().toISOString() },
    { id: 4, name: 'ต้มยำกุ้ง', category: 'ซุป', price: 65, description: 'ต้มยำกุ้งสูตรต้นตำรับ เผ็ดร้อนเต็มรส', emoji: '🍲', available: true, updatedAt: new Date().toISOString() },
    { id: 5, name: 'แกงเขียวหวานไก่', category: 'แกง', price: 55, description: 'แกงเขียวหวานไก่สูตรโบราณ หอมกะทิ', emoji: '🍛', available: true, updatedAt: new Date().toISOString() },
    { id: 6, name: 'ข้าวผัดปู', category: 'ข้าวผัด', price: 70, description: 'ข้าวผัดปูไข่เค็ม หอมมัน', emoji: '🦀', available: true, updatedAt: new Date().toISOString() },
    { id: 7, name: 'บะหมี่หมูแดง', category: 'เส้น', price: 50, description: 'บะหมี่หมูแดงน้ำแดง หวานกลมกล่อม', emoji: '🍝', available: true, updatedAt: new Date().toISOString() },
  ];
  fs.writeFileSync(MENU_FILE, JSON.stringify(defaultMenu, null, 2));
}

if (!fs.existsSync(ORDERS_FILE)) {
  fs.writeFileSync(ORDERS_FILE, JSON.stringify([], null, 2));
}

const readJSON = (file) => JSON.parse(fs.readFileSync(file, 'utf-8'));
const writeJSON = (file, data) => fs.writeFileSync(file, JSON.stringify(data, null, 2));

const adminAuth = (req, res, next) => {
  if (req.headers['x-admin-password'] !== ADMIN_PASSWORD) {
    return res.status(401).json({ success: false, message: 'รหัสผ่านไม่ถูกต้อง' });
  }
  next();
};

// ─── MENU ROUTES ────────────────────────────────────────────

app.get('/api/menu', (req, res) => {
  res.json(readJSON(MENU_FILE));
});

app.post('/api/menu', adminAuth, (req, res) => {
  const { name, category, price, description, emoji, available } = req.body;
  if (!name || !price) return res.status(400).json({ success: false, message: 'กรุณากรอกชื่อและราคา' });
  const menu = readJSON(MENU_FILE);
  const item = {
    id: Date.now(),
    name,
    category: category || 'ทั่วไป',
    price: Number(price),
    description: description || '',
    emoji: emoji || '🍱',
    available: available !== false,
    updatedAt: new Date().toISOString()
  };
  menu.push(item);
  writeJSON(MENU_FILE, menu);
  res.json({ success: true, data: item });
});

app.put('/api/menu/:id', adminAuth, (req, res) => {
  const id = Number(req.params.id);
  const menu = readJSON(MENU_FILE);
  const idx = menu.findIndex(m => m.id === id);
  if (idx === -1) return res.status(404).json({ success: false, message: 'ไม่พบเมนู' });
  menu[idx] = { ...menu[idx], ...req.body, id, updatedAt: new Date().toISOString() };
  writeJSON(MENU_FILE, menu);
  res.json({ success: true, data: menu[idx] });
});

app.delete('/api/menu/:id', adminAuth, (req, res) => {
  const id = Number(req.params.id);
  let menu = readJSON(MENU_FILE);
  const before = menu.length;
  menu = menu.filter(m => m.id !== id);
  if (menu.length === before) return res.status(404).json({ success: false, message: 'ไม่พบเมนู' });
  writeJSON(MENU_FILE, menu);
  res.json({ success: true });
});

// ─── ORDER ROUTES ────────────────────────────────────────────

app.post('/api/orders', (req, res) => {
  const { customerName, phone, address, items, note } = req.body;
  if (!customerName || !phone || !items || !items.length) {
    return res.status(400).json({ success: false, message: 'กรุณากรอกข้อมูลให้ครบ' });
  }
  if (!/^\d{9,10}$/.test(phone)) {
    return res.status(400).json({ success: false, message: 'เบอร์โทรต้องเป็นตัวเลข 9-10 หลัก' });
  }
  const menu = readJSON(MENU_FILE);
  let orderItems;
  try {
    orderItems = items.map(item => {
      const m = menu.find(m => m.id === item.id);
      if (!m) throw new Error('ไม่พบเมนู');
      return { menuId: item.id, name: m.name, emoji: m.emoji, price: m.price, qty: item.qty };
    });
  } catch (e) {
    return res.status(400).json({ success: false, message: e.message });
  }
  const total = orderItems.reduce((s, i) => s + i.price * i.qty, 0);
  const orders = readJSON(ORDERS_FILE);
  const order = {
    id: Date.now(),
    orderNumber: `INF${String(orders.length + 1).padStart(4, '0')}`,
    customerName,
    phone,
    address: address || '',
    items: orderItems,
    total,
    note: note || '',
    status: 'pending',
    orderedAt: new Date().toISOString()
  };
  orders.push(order);
  writeJSON(ORDERS_FILE, orders);
  res.json({ success: true, data: order });
});

app.get('/api/orders', adminAuth, (req, res) => {
  let orders = readJSON(ORDERS_FILE);
  const { status, search } = req.query;
  if (status && status !== 'all') orders = orders.filter(o => o.status === status);
  if (search) {
    const q = search.toLowerCase();
    orders = orders.filter(o =>
      o.customerName.toLowerCase().includes(q) ||
      o.phone.includes(q) ||
      o.orderNumber.toLowerCase().includes(q)
    );
  }
  res.json(orders.reverse());
});

app.put('/api/orders/:id/status', adminAuth, (req, res) => {
  const id = Number(req.params.id);
  const { status } = req.body;
  const valid = ['pending', 'confirmed', 'preparing', 'delivered', 'cancelled'];
  if (!valid.includes(status)) return res.status(400).json({ success: false, message: 'สถานะไม่ถูกต้อง' });
  const orders = readJSON(ORDERS_FILE);
  const idx = orders.findIndex(o => o.id === id);
  if (idx === -1) return res.status(404).json({ success: false, message: 'ไม่พบออเดอร์' });
  orders[idx].status = status;
  orders[idx].updatedAt = new Date().toISOString();
  writeJSON(ORDERS_FILE, orders);
  res.json({ success: true, data: orders[idx] });
});

app.delete('/api/orders/:id', adminAuth, (req, res) => {
  const id = Number(req.params.id);
  let orders = readJSON(ORDERS_FILE);
  const before = orders.length;
  orders = orders.filter(o => o.id !== id);
  if (orders.length === before) return res.status(404).json({ success: false, message: 'ไม่พบออเดอร์' });
  writeJSON(ORDERS_FILE, orders);
  res.json({ success: true });
});

app.get('/api/stats', adminAuth, (req, res) => {
  const orders = readJSON(ORDERS_FILE);
  const menu = readJSON(MENU_FILE);
  const today = new Date().toDateString();
  const todayOrders = orders.filter(o => new Date(o.orderedAt).toDateString() === today);
  res.json({
    totalOrders: orders.length,
    todayOrders: todayOrders.length,
    todayRevenue: todayOrders.filter(o => o.status !== 'cancelled').reduce((s, o) => s + o.total, 0),
    totalRevenue: orders.filter(o => o.status !== 'cancelled').reduce((s, o) => s + o.total, 0),
    pendingOrders: orders.filter(o => o.status === 'pending').length,
    menuCount: menu.length,
    availableMenu: menu.filter(m => m.available).length
  });
});

app.post('/api/admin/login', (req, res) => {
  if (req.body.password === ADMIN_PASSWORD) {
    res.json({ success: true });
  } else {
    res.status(401).json({ success: false, message: 'รหัสผ่านไม่ถูกต้อง' });
  }
});

app.get('/api/export/orders', adminAuth, (req, res) => {
  const orders = readJSON(ORDERS_FILE);
  const statusTH = { pending: 'รอยืนยัน', confirmed: 'ยืนยันแล้ว', preparing: 'กำลังเตรียม', delivered: 'ส่งแล้ว', cancelled: 'ยกเลิก' };
  const header = 'เลขออเดอร์,ชื่อลูกค้า,เบอร์โทร,ที่อยู่,รายการ,ยอดรวม,สถานะ,วันที่สั่ง\n';
  const rows = orders.map(o => {
    const items = o.items.map(i => `${i.name}x${i.qty}`).join(' | ');
    const date = new Date(o.orderedAt).toLocaleString('th-TH');
    return `"${o.orderNumber}","${o.customerName}","${o.phone}","${o.address}","${items}","${o.total}","${statusTH[o.status] || o.status}","${date}"`;
  }).join('\n');
  res.setHeader('Content-Type', 'text/csv; charset=utf-8');
  res.setHeader('Content-Disposition', 'attachment; filename="orders.csv"');
  res.send('﻿' + header + rows);
});

app.listen(PORT, () => {
  console.log('\n=================================');
  console.log('  🍱 Infinity Frozen Food');
  console.log('=================================');
  console.log(`  หน้าลูกค้า  : http://localhost:${PORT}`);
  console.log(`  หน้า Admin  : http://localhost:${PORT}/admin.html`);
  console.log(`  รหัส Admin  : infinity@2025`);
  console.log('=================================\n');
});
