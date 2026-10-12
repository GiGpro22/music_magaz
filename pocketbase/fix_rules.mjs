/**
 * Чинит API Rules и статусы заказов, пересоздаёт пароли пользователей.
 */
const BASE = process.env.PB_URL || 'http://127.0.0.1:8090';
const SUPER_EMAIL = process.env.PB_SUPER_EMAIL || 'super@music.local';
const SUPER_PASS = process.env.PB_SUPER_PASS || 'SuperPass12345';

let token = '';

async function req(method, path, body) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = token;
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
    throw new Error(`${method} ${path} → ${res.status}: ${text}`);
  }
  return data;
}

async function main() {
  const auth = await req('POST', '/api/collections/_superusers/auth-with-password', {
    identity: SUPER_EMAIL,
    password: SUPER_PASS,
  });
  token = auth.token;
  console.log('superuser ok');

  // promotions — покупатель должен читать акции для расчёта скидок
  const promotions = await req('GET', '/api/collections/promotions');
  await req('PATCH', `/api/collections/${promotions.id}`, {
    listRule: '@request.auth.id != ""',
    viewRule: '@request.auth.id != ""',
  });
  console.log('promotions rules: auth can list');

  // orders — упрощённые правила (без сравнения relation в listRule)
  const orders = await req('GET', '/api/collections/orders');
  const fields = (orders.fields || []).map((f) => {
    if (f.name === 'status' && f.type === 'select') {
      return {
        ...f,
        values: ['created', 'new', 'paid', 'shipped', 'cancelled', 'completed'],
      };
    }
    return f;
  });
  const fieldNames = new Set(fields.map((f) => f.name));
  if (!fieldNames.has('created')) {
    fields.push({
      name: 'created',
      type: 'autodate',
      onCreate: true,
      onUpdate: false,
    });
  }
  if (!fieldNames.has('updated')) {
    fields.push({
      name: 'updated',
      type: 'autodate',
      onCreate: true,
      onUpdate: true,
    });
  }
  await req('PATCH', `/api/collections/${orders.id}`, {
    fields,
    listRule: '@request.auth.id != ""',
    viewRule: '@request.auth.id != ""',
    createRule: '@request.auth.id != ""',
    updateRule: '@request.auth.role = "seller" || @request.auth.role = "admin"',
    deleteRule: '@request.auth.role = "admin"',
  });
  console.log('orders rules + status values + created/updated fixed');

  // products — покупатель может уменьшать остаток при заказе
  const products = await req('GET', '/api/collections/products');
  await req('PATCH', `/api/collections/${products.id}`, {
    updateRule:
      '@request.auth.role = "seller" || @request.auth.role = "admin" || @request.auth.role = "customer"',
  });
  console.log('products update: customer allowed');

  // loyalty_cards — чтение для авторизованных
  const cards = await req('GET', '/api/collections/loyalty_cards');
  await req('PATCH', `/api/collections/${cards.id}`, {
    listRule: '@request.auth.id != ""',
    viewRule: '@request.auth.id != ""',
  });

  // users — сброс паролей трёх учёток
  const users = await req(
    'GET',
    '/api/collections/users/records?perPage=100',
  );
  const customers = await req(
    'GET',
    '/api/collections/customers/records?perPage=10',
  );
  const firstCustomer = customers.items?.[0]?.id;

  const wanted = [
    {
      email: 'customer@music.ru',
      role: 'customer',
      name: 'Покупатель',
      customer: firstCustomer,
    },
    { email: 'seller@music.ru', role: 'seller', name: 'Продавец' },
    { email: 'admin@music.ru', role: 'admin', name: 'Администратор' },
  ];

  for (const w of wanted) {
    const existing = (users.items || []).find((u) => u.email === w.email);
    const payload = {
      email: w.email,
      emailVisibility: true,
      password: 'music12345',
      passwordConfirm: 'music12345',
      name: w.name,
      role: w.role,
      verified: true,
      ...(w.customer ? { customer: w.customer } : {}),
    };
    if (existing) {
      await req('PATCH', `/api/collections/users/records/${existing.id}`, payload);
      console.log('reset password:', w.email);
    } else {
      await req('POST', '/api/collections/users/records', payload);
      console.log('created:', w.email);
    }
  }

  // проверка входа
  for (const email of [
    'admin@music.ru',
    'seller@music.ru',
    'customer@music.ru',
  ]) {
    const r = await fetch(`${BASE}/api/collections/users/auth-with-password`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ identity: email, password: 'music12345' }),
    });
    console.log('login', email, r.status, r.ok ? 'OK' : await r.text());
  }

  console.log('\nDone. Passwords: music12345');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
