import 'dotenv/config'
import { Client, Pool } from 'pg'
import Memcached from 'memcached'
import crypto from 'node:crypto'


const THREADS = 40
const FIXED_POOL = 5
const QUERY = 'SELECT * FROM usuario'

function pgCfg () {
  return { connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } }
}

// Ejecuta N tareas en lotes para no pasar el límite de conexiones
async function runInBatches (total, batchSize, taskFn) {
  let done = 0
  while (done < total) {
    const size = Math.min(batchSize, total - done)
    const batch = Array.from({ length: size }, taskFn)
    await Promise.all(batch)
    done += size
  }
}

// a) 40 conexiones independientes (por lotes)
async function ejecucionDirecta () {
  const cfg = pgCfg()
  const t0 = Date.now()
  const BATCH = 12 
  await runInBatches(THREADS, BATCH, async () => {
    const c = new Client(cfg)
    await c.connect()
    await c.query(QUERY)
    await c.end()
  })
  console.log(`Ejecución directa: ${Date.now() - t0} ms`)
}

// b) Pool fijo = 5
async function ejecucionPool (size = FIXED_POOL) {
  const pool = new Pool({ ...pgCfg(), max: size })
  const t0 = Date.now()
  await Promise.all(Array.from({ length: THREADS }, () => pool.query(QUERY)))
  console.log(`Fixed pool size (${size}): ${Date.now() - t0} ms`)
  await pool.end()
}

// c) Pool + Memcached
async function ejecucionPoolCache (size = FIXED_POOL) {
  const pool = new Pool({ ...pgCfg(), max: size })
  const mc = new Memcached(process.env.MEMCACHED_SERVERS || '127.0.0.1:11211', { retries: 0, timeout: 500 })
  const ttl = Number(process.env.MEMCACHED_TTL || 60)


  const rawKey = 'SELECT-ALL:usuario'; 
  const key = 'mc:' + crypto.createHash('sha1').update(rawKey).digest('hex');

  const mget = k => new Promise((res, rej) => mc.get(k, (e, d) => e ? rej(e) : res(d)))
  const mset = (k, v, t) => new Promise((res, rej) => mc.set(k, v, t, e => e ? rej(e) : res(true)))
  const mdel = k => new Promise(res => mc.del(k, () => res(true)))

  try {
    await mdel(key)
    const warm = await pool.query(QUERY)
    await mset(key, JSON.stringify(warm.rows), ttl)
  } catch (e) {
    console.warn('Memcached no disponible; pool sin caché →', e.code || e.message)
    const t0 = Date.now()
    await Promise.all(Array.from({ length: THREADS }, () => pool.query(QUERY)))
    console.log(`Pool (sin cache): ${Date.now() - t0} ms`)
    await pool.end(); mc.end()
    return
  }

  const t0 = Date.now()
  await Promise.all(Array.from({ length: THREADS }, async () => {
    let payload = await mget(key)
    if (!payload) { 
      const r = await pool.query(QUERY)
      payload = JSON.stringify(r.rows)
      await mset(key, payload, ttl)
    }
    JSON.parse(payload).length
  }))
  console.log(`Pool and cache (Memcached): ${Date.now() - t0} ms`)

  await pool.end()
  mc.end()
}

console.log('DB:', (process.env.DATABASE_URL || '').replace(/\/\/.*@/,'//***:***@'))
await ejecucionDirecta()
await ejecucionPool(FIXED_POOL)
await ejecucionPoolCache(FIXED_POOL)
