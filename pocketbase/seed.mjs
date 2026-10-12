/**
 * Seed тестовых данных в PocketBase.
 * Требует: node, запущенный pocketbase, открытые Create-правила коллекций
 * (или заголовок Authorization суперпользователя в ADMIN_TOKEN).
 *
 * Usage:
 *   node seed.mjs
 *   ADMIN_TOKEN=... node seed.mjs
 */
const BASE = process.env.PB_URL || 'http://127.0.0.1:8090';
const TOKEN = process.env.ADMIN_TOKEN || '';

async function req(method, path, body) {
  const headers = { 'Content-Type': 'application/json' };
  if (TOKEN) headers.Authorization = TOKEN;
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
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

async function create(collection, record) {
  return req('POST', `/api/collections/${collection}/records`, record);
}

async function main() {
  console.log('Seeding PocketBase at', BASE);

  const brands = [];
  for (const b of [
    { name: 'Fender', country: 'USA', website: 'https://www.fender.com', description: 'Гитары и басы' },
    { name: 'Yamaha', country: 'Japan', website: 'https://www.yamaha.com', description: 'Клавиши и гитары' },
    { name: 'Gibson', country: 'USA', website: 'https://www.gibson.com', description: 'Электрогитары' },
    { name: 'Roland', country: 'Japan', website: 'https://www.roland.com', description: 'Синтезаторы и ударные' },
    { name: 'Shure', country: 'USA', website: 'https://www.shure.com', description: 'Микрофоны' },
  ]) {
    brands.push(await create('brands', { ...b, deleted: false }));
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
    categories.push(await create('categories', { ...c, deleted: false }));
  }

  const suppliers = [];
  for (const s of [
    { name: 'MusicTrade RU', email: 'trade@music.ru', phone: '+7-495-111-22-33', city: 'Москва' },
    { name: 'SoundImport', email: 'import@sound.ru', phone: '+7-812-222-33-44', city: 'Санкт-Петербург' },
    { name: 'GearHub', email: 'hub@gear.ru', phone: '+7-343-333-44-55', city: 'Екатеринбург' },
  ]) {
    suppliers.push(await create('suppliers', { ...s, deleted: false }));
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

  const products = [];
  for (const [name, sku, price, stock, year, bi, si, cats] of productDefs) {
    products.push(
      await create('products', {
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
      }),
    );
  }

  const customers = [];
  for (const c of [
    { fullName: 'Иван Петров', email: 'ivan@mail.ru', phone: '+7-900-111-22-33', city: 'Москва' },
    { fullName: 'Анна Смирнова', email: 'anna@mail.ru', phone: '+7-900-222-33-44', city: 'Казань' },
    { fullName: 'Олег Кузнецов', email: 'oleg@mail.ru', phone: '+7-900-333-44-55', city: 'Новосибирск' },
    { fullName: 'Мария Волкова', email: 'maria@mail.ru', phone: '+7-900-444-55-66', city: 'Москва' },
  ]) {
    customers.push(await create('customers', { ...c, deleted: false }));
  }

  const levels = ['bronze', 'silver', 'gold', 'silver'];
  for (let i = 0; i < customers.length; i++) {
    await create('loyalty_cards', {
      customer: customers[i].id,
      cardNumber: `MC-100${i + 1}`,
      level: levels[i],
      points: (i + 1) * 150,
      isActive: true,
      issuedAt: new Date().toISOString(),
      deleted: false,
    });
  }

  await create('promotions', {
    title: 'Скидка на гитары Fender',
    discountPercent: 10,
    brand: brands[0].id,
    categories: [categories[0].id],
    startsAt: new Date(Date.now() - 86400000).toISOString(),
    endsAt: new Date(Date.now() + 30 * 86400000).toISOString(),
    isActive: true,
    deleted: false,
  });

  await create('promotions', {
    title: 'Аксессуары −15%',
    discountPercent: 15,
    categories: [categories[5].id],
    startsAt: new Date(Date.now() - 86400000).toISOString(),
    endsAt: new Date(Date.now() + 14 * 86400000).toISOString(),
    isActive: true,
    deleted: false,
  });

  console.log('Seed OK:', {
    brands: brands.length,
    categories: categories.length,
    suppliers: suppliers.length,
    products: products.length,
    customers: customers.length,
  });
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
