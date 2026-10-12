/**
 * Полная настройка PocketBase: коллекции, правила, seed, 3 пользователя.
 *
 * Usage (из папки с pocketbase.exe, сервер уже запущен):
 *   node ..\setup_all.mjs
 * или из pocketbase/:
 *   node setup_all.mjs
 */
const BASE = process.env.PB_URL || 'http://127.0.0.1:8090';
const SUPER_EMAIL = process.env.PB_SUPER_EMAIL || 'super@music.local';
const SUPER_PASS = process.env.PB_SUPER_PASS || 'SuperPass12345';

let token = '';

async function req(method, path, body, auth = true) {
  const headers = { 'Content-Type': 'application/json' };
  if (auth && token) headers.Authorization = token;
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers,
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let data;
  try {
    data = JSON.parse(text);
  } catch {
    data = text;
  }
  if (!res.ok) {
    const msg = typeof data === 'object' ? JSON.stringify(data) : text;
    throw new Error(`${method} ${path} → ${res.status}: ${msg}`);
  }
  return data;
}

async function waitReady(retries = 40) {
  for (let i = 0; i < retries; i++) {
    try {
      const res = await fetch(`${BASE}/api/health`);
      if (res.ok) return;
    } catch (_) {}
    await new Promise((r) => setTimeout(r, 500));
  }
  throw new Error('PocketBase не отвечает на ' + BASE);
}

async function loginSuper() {
  const data = await req(
    'POST',
    '/api/collections/_superusers/auth-with-password',
    { identity: SUPER_EMAIL, password: SUPER_PASS },
    false,
  );
  token = data.token;
  console.log('OK superuser login');
}

async function getCollection(name) {
  try {
    return await req('GET', `/api/collections/${name}`);
  } catch {
    return null;
  }
}

async function ensureCollection(def) {
  const existing = await getCollection(def.name);
  if (existing) {
    console.log('  exists:', def.name);
    return existing;
  }
  const created = await req('POST', '/api/collections', def);
  console.log('  created:', def.name);
  return created;
}

function text(name, opts = {}) {
  return {
    name,
    type: 'text',
    required: !!opts.required,
    max: opts.max,
  };
}

function number(name, opts = {}) {
  return {
    name,
    type: 'number',
    required: !!opts.required,
    min: opts.min,
    max: opts.max,
  };
}

function bool(name, opts = {}) {
  return {
    name,
    type: 'bool',
    required: !!opts.required,
  };
}

function email(name, opts = {}) {
  return { name, type: 'email', required: !!opts.required };
}

function url(name, opts = {}) {
  return { name, type: 'url', required: !!opts.required };
}

function date(name, opts = {}) {
  return { name, type: 'date', required: !!opts.required };
}

function select(name, values, opts = {}) {
  return {
    name,
    type: 'select',
    required: !!opts.required,
    maxSelect: 1,
    values,
  };
}

function relation(name, collectionId, opts = {}) {
  return {
    name,
    type: 'relation',
    required: !!opts.required,
    collectionId,
    maxSelect: opts.maxSelect ?? 1,
    cascadeDelete: false,
  };
}

async function setupCollections() {
  console.log('Creating collections...');

  const brands = await ensureCollection({
    name: 'brands',
    type: 'base',
    listRule: '',
    viewRule: '',
    createRule: '@request.auth.role = "seller" || @request.auth.role = "admin"',
    updateRule: '@request.auth.role = "seller" || @request.auth.role = "admin"',
    deleteRule: '@request.auth.role = "admin"',
    fields: [
      text('name', { required: true }),
      text('country', { required: true }),
      url('website'),
      text('description'),
      bool('deleted'),
    ],
  });

  const categories = await ensureCollection({
    name: 'categories',
    type: 'base',
    listRule: '',
    viewRule: '',
    createRule: '@request.auth.role = "seller" || @request.auth.role = "admin"',
    updateRule: '@request.auth.role = "seller" || @request.auth.role = "admin"',
    deleteRule: '@request.auth.role = "admin"',
    fields: [
      text('name', { required: true }),
      text('slug', { required: true }),
      text('description'),
      bool('deleted'),
    ],
  });

  const suppliers = await ensureCollection({
    name: 'suppliers',
    type: 'base',
    listRule: '@request.auth.role = "seller" || @request.auth.role = "admin"',
    viewRule: '@request.auth.role = "seller" || @request.auth.role = "admin"',
    createRule: '@request.auth.role = "admin"',
    updateRule: '@request.auth.role = "admin"',
    deleteRule: '@request.auth.role = "admin"',
    fields: [
      text('name', { required: true }),
      email('email', { required: true }),
      text('phone'),
      text('city', { required: true }),
      bool('deleted'),
    ],
  });

  // Temporarily open create for seed, then we keep role rules (seed uses superuser token)
  const products = await ensureCollection({
    name: 'products',
    type: 'base',
    listRule: '',
    viewRule: '',
    createRule: '@request.auth.role = "seller" || @request.auth.role = "admin"',
    updateRule: '@request.auth.role = "seller" || @request.auth.role = "admin"',
    deleteRule: '@request.auth.role = "admin"',
    fields: [
      text('name', { required: true }),
      text('sku', { required: true }),
      number('price', { required: true, min: 0 }),
      number('stock', { required: true, min: 0 }),
      number('year'),
      relation('brand', brands.id, { required: true }),
      relation('supplier', suppliers.id, { required: true }),
      relation('categories', categories.id, { maxSelect: 20 }),
      text('description'),
      bool('deleted'),
    ],
  });

  const customers = await ensureCollection({
    name: 'customers',
    type: 'base',
    listRule: '@request.auth.id != ""',
    viewRule: '@request.auth.id != ""',
    createRule:
      '@request.auth.role = "seller" || @request.auth.role = "admin" || (@request.auth.role = "customer" && @request.auth.customer = "")',
    updateRule:
      '@request.auth.role = "seller" || @request.auth.role = "admin" || (@request.auth.role = "customer" && id = @request.auth.customer)',
    deleteRule: '@request.auth.role = "admin"',
    fields: [
      text('fullName', { required: true }),
      email('email', { required: true }),
      text('phone'),
      text('city'),
      bool('deleted'),
    ],
  });

  await ensureCollection({
    name: 'loyalty_cards',
    type: 'base',
    listRule: '@request.auth.id != ""',
    viewRule: '@request.auth.id != ""',
    createRule:
      '@request.auth.role = "seller" || @request.auth.role = "admin" || @request.auth.role = "customer"',
    updateRule:
      '@request.auth.role = "seller" || @request.auth.role = "admin"',
    deleteRule: '@request.auth.role = "admin"',
    fields: [
      relation('customer', customers.id, { required: true }),
      text('cardNumber', { required: true }),
      select('level', ['bronze', 'silver', 'gold'], { required: true }),
      number('points', { min: 0 }),
      bool('isActive'),
      date('issuedAt', { required: true }),
      bool('deleted'),
    ],
  });

  await ensureCollection({
    name: 'promotions',
    type: 'base',
    listRule: '@request.auth.role = "seller" || @request.auth.role = "admin"',
    viewRule: '@request.auth.role = "seller" || @request.auth.role = "admin"',
    createRule: '@request.auth.role = "admin"',
    updateRule: '@request.auth.role = "admin"',
    deleteRule: '@request.auth.role = "admin"',
    fields: [
      text('title', { required: true }),
      number('discountPercent', { required: true, min: 1, max: 90 }),
      relation('brand', brands.id, { maxSelect: 1 }),
      relation('categories', categories.id, { maxSelect: 20 }),
      date('startsAt', { required: true }),
      date('endsAt', { required: true }),
      bool('isActive'),
      bool('deleted'),
    ],
  });

  const orders = await ensureCollection({
    name: 'orders',
    type: 'base',
    listRule:
      '@request.auth.role = "seller" || @request.auth.role = "admin" || (@request.auth.role = "customer" && customer = @request.auth.customer)',
    viewRule:
      '@request.auth.role = "seller" || @request.auth.role = "admin" || (@request.auth.role = "customer" && customer = @request.auth.customer)',
    createRule: '@request.auth.id != ""',
    updateRule: '@request.auth.role = "seller" || @request.auth.role = "admin"',
    deleteRule: '@request.auth.role = "admin"',
    fields: [
      relation('customer', customers.id, { required: true }),
      select(
        'status',
        ['new', 'paid', 'shipped', 'cancelled', 'completed'],
        { required: true },
      ),
      number('subtotal', { required: true }),
      number('loyaltyDiscount'),
      number('promoDiscount'),
      number('total', { required: true }),
      text('note'),
      bool('deleted'),
    ],
  });

  await ensureCollection({
    name: 'order_items',
    type: 'base',
    listRule: '@request.auth.id != ""',
    viewRule: '@request.auth.id != ""',
    createRule: '@request.auth.id != ""',
    updateRule: '@request.auth.role = "seller" || @request.auth.role = "admin"',
    deleteRule: '@request.auth.role = "seller" || @request.auth.role = "admin"',
    fields: [
      relation('order', orders.id, { required: true }),
      relation('product', products.id, { required: true }),
      number('qty', { required: true, min: 1 }),
      number('unitPrice', { required: true }),
      number('lineTotal', { required: true }),
    ],
  });

  await ensureCollection({
    name: 'reviews',
    type: 'base',
    listRule: '@request.auth.id != ""',
    viewRule: '@request.auth.id != ""',
    createRule: '@request.auth.id != ""',
    updateRule: '@request.auth.role = "seller" || @request.auth.role = "admin"',
    deleteRule: '@request.auth.role = "seller" || @request.auth.role = "admin"',
    fields: [
      relation('product', products.id, { required: true }),
      relation('customer', customers.id, { required: true }),
      number('rating', { required: true, min: 1, max: 5 }),
      text('text', { required: true }),
      bool('deleted'),
    ],
  });

  // Extend users auth collection
  const users = await req('GET', '/api/collections/users');
  const fieldNames = new Set((users.fields || []).map((f) => f.name));
  const fields = [...(users.fields || [])];
  if (!fieldNames.has('role')) {
    fields.push(select('role', ['customer', 'seller', 'admin'], { required: true }));
  }
  if (!fieldNames.has('customer')) {
    fields.push(relation('customer', customers.id, { maxSelect: 1 }));
  }
  await req('PATCH', `/api/collections/${users.id}`, {
    fields,
    listRule: '@request.auth.role = "admin"',
    viewRule: '@request.auth.id != ""',
    createRule: '',
    updateRule: '@request.auth.role = "admin" || id = @request.auth.id',
    deleteRule: '@request.auth.role = "admin"',
  });
  console.log('  updated: users (+role, +customer)');

  return { customers };
}

async function createRecord(collection, body) {
  return req('POST', `/api/collections/${collection}/records`, body);
}

async function listAll(collection, filter = '') {
  const q = new URLSearchParams({
    page: '1',
    perPage: '200',
    ...(filter ? { filter } : {}),
  });
  const data = await req('GET', `/api/collections/${collection}/records?${q}`);
  return data.items || [];
}

async function seed() {
  console.log('Seeding data...');
  const existing = await listAll('brands');
  if (existing.length > 0) {
    console.log('  seed skipped (brands already exist)');
    return;
  }

  const brands = [];
  for (const b of [
    { name: 'Fender', country: 'USA', website: 'https://www.fender.com', description: 'Гитары и басы' },
    { name: 'Yamaha', country: 'Japan', website: 'https://www.yamaha.com', description: 'Клавиши и гитары' },
    { name: 'Gibson', country: 'USA', website: 'https://www.gibson.com', description: 'Электрогитары' },
    { name: 'Roland', country: 'Japan', website: 'https://www.roland.com', description: 'Синтезаторы и ударные' },
    { name: 'Shure', country: 'USA', website: 'https://www.shure.com', description: 'Микрофоны' },
  ]) {
    brands.push(await createRecord('brands', { ...b, deleted: false }));
  }

  const categories = [];
  for (const c of [
    { name: 'Электрогитары', slug: 'electric-guitars', description: '' },
    { name: 'Акустические гитары', slug: 'acoustic-guitars', description: '' },
    { name: 'Клавишные', slug: 'keyboards', description: '' },
    { name: 'Ударные', slug: 'drums', description: '' },
    { name: 'Микрофоны', slug: 'mics', description: '' },
    { name: 'Аксессуары', slug: 'accessories', description: '' },
  ]) {
    categories.push(await createRecord('categories', { ...c, deleted: false }));
  }

  const suppliers = [];
  for (const s of [
    { name: 'MusicTrade RU', email: 'trade@music.ru', phone: '+7-495-111-22-33', city: 'Москва' },
    { name: 'SoundImport', email: 'import@sound.ru', phone: '+7-812-222-33-44', city: 'Санкт-Петербург' },
    { name: 'GearHub', email: 'hub@gear.ru', phone: '+7-343-333-44-55', city: 'Екатеринбург' },
  ]) {
    suppliers.push(await createRecord('suppliers', { ...s, deleted: false }));
  }

  const productDefs = [
    ['Stratocaster Player', 'FND-STR-01', 89900, 12, 2022, 0, 0, [0, 5]],
    ['Telecaster Deluxe', 'FND-TEL-02', 105000, 8, 2021, 0, 0, [0]],
    ['Pacifica 112V', 'YAM-PAC-01', 42000, 20, 2023, 1, 1, [0]],
    ['PSR-E373', 'YAM-PSR-01', 28900, 15, 2023, 1, 1, [2]],
    ['Les Paul Standard', 'GIB-LP-01', 189000, 4, 2020, 2, 0, [0]],
    ['SG Special', 'GIB-SG-01', 125000, 6, 2019, 2, 0, [0]],
    ['FP-30X', 'ROL-FP-01', 65000, 10, 2022, 3, 1, [2]],
    ['TD-07KV', 'ROL-TD-01', 98000, 5, 2021, 3, 2, [3]],
    ['SM58', 'SHR-SM58', 12500, 40, 2020, 4, 2, [4]],
    ['SM7B', 'SHR-SM7B', 39900, 18, 2021, 4, 2, [4]],
    ['FG800', 'YAM-FG-01', 32000, 14, 2022, 1, 1, [1]],
    ['CD-60S', 'FND-CD-01', 28000, 11, 2023, 0, 0, [1]],
    ['Cable Jack 3m', 'ACC-CBL-01', 990, 100, 2024, 4, 2, [5]],
    ['Capo Universal', 'ACC-CAP-01', 1490, 80, 2024, 1, 1, [5]],
    ['Strings 09-42', 'ACC-STR-01', 790, 200, 2024, 0, 0, [5]],
    ['Amp Practice 15W', 'YAM-AMP-01', 15900, 9, 2023, 1, 1, [5]],
    ['Jazzmaster', 'FND-JM-01', 112000, 3, 2018, 0, 0, [0]],
    ['P-125', 'YAM-P125', 72000, 7, 2022, 1, 1, [2]],
    ['Thunderbird Bass', 'GIB-TB-01', 145000, 2, 2017, 2, 0, [0]],
    ['Beta 58A', 'SHR-B58', 18900, 22, 2020, 4, 2, [4]],
  ];

  for (const [name, sku, price, stock, year, bi, si, cats] of productDefs) {
    await createRecord('products', {
      name,
      sku,
      price,
      stock,
      year,
      brand: brands[bi].id,
      supplier: suppliers[si].id,
      categories: cats.map((i) => categories[i].id),
      description: `${name} — демо-товар`,
      deleted: false,
    });
  }

  const customers = [];
  for (const c of [
    { fullName: 'Иван Петров', email: 'ivan@mail.ru', phone: '+7-900-111-22-33', city: 'Москва' },
    { fullName: 'Анна Смирнова', email: 'anna@mail.ru', phone: '+7-900-222-33-44', city: 'Казань' },
    { fullName: 'Олег Кузнецов', email: 'oleg@mail.ru', phone: '+7-900-333-44-55', city: 'Новосибирск' },
    { fullName: 'Мария Волкова', email: 'maria@mail.ru', phone: '+7-900-444-55-66', city: 'Москва' },
  ]) {
    customers.push(await createRecord('customers', { ...c, deleted: false }));
  }

  const levels = ['bronze', 'silver', 'gold', 'silver'];
  for (let i = 0; i < customers.length; i++) {
    await createRecord('loyalty_cards', {
      customer: customers[i].id,
      cardNumber: `MC-100${i + 1}`,
      level: levels[i],
      points: (i + 1) * 150,
      isActive: true,
      issuedAt: new Date().toISOString().slice(0, 10),
      deleted: false,
    });
  }

  await createRecord('promotions', {
    title: 'Скидка на гитары Fender',
    discountPercent: 10,
    brand: brands[0].id,
    categories: [categories[0].id],
    startsAt: new Date(Date.now() - 86400000).toISOString().slice(0, 10),
    endsAt: new Date(Date.now() + 30 * 86400000).toISOString().slice(0, 10),
    isActive: true,
    deleted: false,
  });

  await createRecord('promotions', {
    title: 'Аксессуары −15%',
    discountPercent: 15,
    categories: [categories[5].id],
    startsAt: new Date(Date.now() - 86400000).toISOString().slice(0, 10),
    endsAt: new Date(Date.now() + 14 * 86400000).toISOString().slice(0, 10),
    isActive: true,
    deleted: false,
  });

  console.log('  seed OK');
}

async function ensureUser(email, password, name, role, customerId) {
  const found = await listAll('users', `email="${email}"`);
  if (found.length) {
    const u = found[0];
    await req('PATCH', `/api/collections/users/records/${u.id}`, {
      role,
      name,
      ...(customerId ? { customer: customerId } : {}),
    });
    console.log('  updated user:', email, role);
    return u;
  }
  const body = {
    email,
    emailVisibility: true,
    password,
    passwordConfirm: password,
    name,
    role,
    verified: true,
  };
  if (customerId) body.customer = customerId;
  const u = await createRecord('users', body);
  console.log('  created user:', email, role);
  return u;
}

async function setupUsers() {
  console.log('Creating app users...');
  const customers = await listAll('customers');
  const firstCustomer = customers[0]?.id;
  await ensureUser(
    'customer@music.ru',
    'music12345',
    'Покупатель',
    'customer',
    firstCustomer,
  );
  await ensureUser('seller@music.ru', 'music12345', 'Продавец', 'seller');
  await ensureUser('admin@music.ru', 'music12345', 'Администратор', 'admin');
}

async function exportSchema() {
  const cols = await req('GET', '/api/collections?perPage=100');
  const fs = await import('fs');
  const path = new URL('./pb_schema.json', import.meta.url);
  fs.writeFileSync(path, JSON.stringify(cols.items || cols, null, 2), 'utf8');
  console.log('Exported pb_schema.json');
}

async function main() {
  console.log('API:', BASE);
  await waitReady();
  await loginSuper();
  await setupCollections();
  await seed();
  await setupUsers();
  await exportSchema();
  console.log('\n=== ГОТОВО ===');
  console.log('Админка PocketBase: http://127.0.0.1:8090/_/');
  console.log(`Суперпользователь: ${SUPER_EMAIL} / ${SUPER_PASS}`);
  console.log('Приложение:');
  console.log('  customer@music.ru / music12345');
  console.log('  seller@music.ru / music12345');
  console.log('  admin@music.ru / music12345');
  console.log('\nЗапуск клиента:');
  console.log(
    '  flutter run -d chrome --web-port=5555 --dart-define=API_BASE_URL=http://127.0.0.1:8090',
  );
}

main().catch((e) => {
  console.error('\nОШИБКА:', e.message || e);
  process.exit(1);
});
