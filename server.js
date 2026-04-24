require('dotenv').config();
const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ limit: '50mb', extended: true }));

console.log("File is running...");

// 🔹 PostgreSQL connection
const DB_NAME = process.env.DB_NAME || "fleet_dev";
console.log("Using DB:", DB_NAME);
console.log("USER:", process.env.DB_USER);
console.log("PASSWORD:", process.env.DB_PASSWORD);
const pool = new Pool({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT,
  ssl: {
    rejectUnauthorized: false
  }
});

// ✅ Test API
app.get('/', (req, res) => {
  res.send('Backend running 🚀 - Version: 2026-04-22-14-35');
});

// ─────────────────────────────────────────────
// AUTH
// ─────────────────────────────────────────────
app.post("/login", async (req, res) => {
  const { emp_id, password, role } = req.body;
  console.log("LOGIN ATTEMPT - INPUT:", { emp_id, password, role });
  try {
    const result = await pool.query(
      "SELECT * FROM users WHERE employee_id=$1 AND password=$2 AND role=$3",
      [emp_id, password, role]
    );
    console.log("DB RESULT COUNT:", result.rows.length);
    if (result.rows.length > 0) {
      console.log("LOGIN SUCCESS for:", emp_id);
      res.json({ success: true, user: result.rows[0] });
    } else {
      console.log("LOGIN FAILED - No match found in DB");
      res.json({ success: false });
    }
  } catch (err) {
    console.error("LOGIN ERROR:", err);
    res.status(500).send("Server error");
  }
});

// ─────────────────────────────────────────────
// STATS (for admin dashboard green card)
// ─────────────────────────────────────────────
app.get('/stats', async (req, res) => {
  try {
    const drivers = await pool.query("SELECT COUNT(*) FROM users WHERE role='driver' AND active=true");
    const admins = await pool.query("SELECT COUNT(*) FROM users WHERE role='admin'");
    const vehicles = await pool.query("SELECT COUNT(*) FROM vehicles WHERE active=true");
    const routes = await pool.query("SELECT COUNT(*) FROM routes WHERE active=true");
    const activeTrips = await pool.query("SELECT COUNT(*) FROM trips WHERE trip_status='STARTED'");
    const allocations = await pool.query("SELECT COUNT(*) FROM trip_allocations");

    res.json({
      active_drivers: parseInt(drivers.rows[0].count),
      active_admins: parseInt(admins.rows[0].count),
      active_vehicles: parseInt(vehicles.rows[0].count),
      active_routes: parseInt(routes.rows[0].count),
      active_trips: parseInt(activeTrips.rows[0].count),
      trip_allocations: parseInt(allocations.rows[0].count),
    });
  } catch (err) {
    console.error(err);
    res.status(500).send('Error');
  }
});

// ─────────────────────────────────────────────
// VEHICLES dropdown (for driver app)
// ─────────────────────────────────────────────
app.get('/vehicles', async (req, res) => {
  const result = await pool.query('SELECT id, vin FROM vehicles WHERE active = true');
  res.json(result.rows);
});

// ─────────────────────────────────────────────
// VEHICLES CRUD (for admin)
// ─────────────────────────────────────────────
app.get('/vehicles/all', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM vehicles ORDER BY id');
    res.json(result.rows);
  } catch (err) { res.status(500).send('Error'); }
});

app.post('/vehicles', async (req, res) => {
  const { vin, brand, variant, engine_type, gearbox_type, project_code, batch, sv_number, powertrain_type } = req.body;
  try {
    const result = await pool.query(
      `INSERT INTO vehicles (vin, brand, variant, engine_type, gearbox_type, active, project_code, batch, sv_number, powertrain_type)
       VALUES ($1,$2,$3,$4,$5,true,$6,$7,$8,$9) RETURNING *`,
      [vin, brand, variant, engine_type, gearbox_type, project_code, batch, sv_number, powertrain_type]
    );
    res.json(result.rows[0]);
  } catch (err) { 
    console.error("ADD VEHICLE ERROR:", err);
    res.status(500).json({ error: err.message }); 
  }
});

app.put('/vehicles/:id', async (req, res) => {
  const { vin, brand, variant, engine_type, gearbox_type, active = true, project_code, batch, sv_number, powertrain_type } = req.body;
  try {
    const result = await pool.query(
      `UPDATE vehicles SET vin=$1, brand=$2, variant=$3, engine_type=$4, gearbox_type=$5, active=$6, project_code=$7, batch=$8, sv_number=$9, powertrain_type=$10
       WHERE id=$11 RETURNING *`,
      [vin, brand, variant, engine_type, gearbox_type, active, project_code, batch, sv_number, powertrain_type, req.params.id]
    );
    res.json(result.rows[0]);
  } catch (err) { 
    console.error("UPDATE VEHICLE ERROR:", err);
    res.status(500).json({ error: err.message }); 
  }
});

app.delete('/vehicles/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM vehicles WHERE id=$1', [req.params.id]);
    res.json({ success: true });
  } catch (err) { 
    console.error("DELETE VEHICLE ERROR:", err);
    res.status(500).json({ error: err.message }); 
  }
});

// ─────────────────────────────────────────────
// ROUTES dropdown (for driver app)
// ─────────────────────────────────────────────
app.get('/routes', async (req, res) => {
  const result = await pool.query('SELECT id, route_name FROM routes WHERE active = true');
  res.json(result.rows);
});

// ─────────────────────────────────────────────
// ROUTES CRUD (for admin)
// ─────────────────────────────────────────────
app.get('/routes/all', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM routes ORDER BY id');
    res.json(result.rows);
  } catch (err) { res.status(500).send('Error'); }
});

app.post('/routes', async (req, res) => {
  const { route_name, circuit_type, kms_coverage } = req.body;
  try {
    const result = await pool.query(
      `INSERT INTO routes (route_name, circuit_type, kms_coverage, active)
       VALUES ($1,$2,$3,true) RETURNING *`,
      [route_name, circuit_type, kms_coverage]
    );
    res.json(result.rows[0]);
  } catch (err) { 
    console.error("ADD ROUTE ERROR:", err);
    res.status(500).json({ error: err.message }); 
  }
});

app.put('/routes/:id', async (req, res) => {
  const { route_name, circuit_type, kms_coverage, active } = req.body;
  try {
    const result = await pool.query(
      `UPDATE routes SET route_name=$1, circuit_type=$2, kms_coverage=$3, active=$4
       WHERE id=$5 RETURNING *`,
      [route_name, circuit_type, kms_coverage, active, req.params.id]
    );
    res.json(result.rows[0]);
  } catch (err) { res.status(500).send('Error'); }
});

app.delete('/routes/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM routes WHERE id=$1', [req.params.id]);
    res.json({ success: true });
  } catch (err) { res.status(500).send('Error'); }
});

// ─────────────────────────────────────────────
// USERS (admins + drivers)
// ─────────────────────────────────────────────
app.get('/users/admins', async (req, res) => {
  try {
    const result = await pool.query("SELECT * FROM users WHERE role='admin' ORDER BY id");
    res.json(result.rows);
  } catch (err) { res.status(500).send('Error'); }
});

app.get('/users/drivers', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT u.*, 
        EXISTS (SELECT 1 FROM trips WHERE driver_id = u.id AND trip_status = 'STARTED') AS in_active_trip
      FROM users u 
      WHERE u.role='driver' 
      ORDER BY u.id
    `);
    res.json(result.rows);
  } catch (err) { res.status(500).send('Error'); }
});

app.post('/users', async (req, res) => {
  const { employee_id, name, password, role } = req.body;
  try {
    const result = await pool.query(
      `INSERT INTO users (employee_id, name, password, role) VALUES ($1,$2,$3,$4) RETURNING *`,
      [employee_id, name, password, role]
    );
    res.json(result.rows[0]);
  } catch (err) { 
    console.error("ADD USER ERROR:", err);
    res.status(500).json({ error: err.message }); 
  }
});

app.put('/users/:id', async (req, res) => {
  const { employee_id, name, password, role } = req.body;
  try {
    const result = await pool.query(
      `UPDATE users SET employee_id=$1, name=$2, password=$3, role=$4 WHERE id=$5 RETURNING *`,
      [employee_id, name, password, role, req.params.id]
    );
    res.json(result.rows[0]);
  } catch (err) { res.status(500).send('Error'); }
});

app.delete('/users/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM users WHERE id=$1', [req.params.id]);
    res.json({ success: true });
  } catch (err) { res.status(500).send('Error'); }
});

// Driver-specific add/update (with experience, dl_number, dl_expiry, joining_date)
app.post('/drivers', async (req, res) => {
  const { employee_id, name, password, experience, dl_number, dl_expiry, joining_date } = req.body;
  try {
    const result = await pool.query(
      `INSERT INTO users (employee_id, name, password, role, experience, dl_number, dl_expiry, joining_date)
       VALUES ($1,$2,$3,'driver',$4,$5,$6,$7) RETURNING *`,
      [employee_id, name, password, experience, dl_number, dl_expiry || null, joining_date || null]
    );
    res.json(result.rows[0]);
  } catch (err) { 
    console.error("ADD DRIVER ERROR:", err);
    res.status(500).json({ error: err.message }); 
  }
});

app.put('/drivers/:id', async (req, res) => {
  const { employee_id, name, password, experience, dl_number, dl_expiry, active, joining_date } = req.body;
  try {
    const result = await pool.query(
      `UPDATE users SET employee_id=$1, name=$2, password=$3, experience=$4,
       dl_number=$5, dl_expiry=$6, active=$7, joining_date=$8 WHERE id=$9 RETURNING *`,
      [employee_id, name, password, experience, dl_number, dl_expiry || null, active, joining_date || null, req.params.id]
    );
    res.json(result.rows[0]);
  } catch (err) { 
    console.error("UPDATE DRIVER ERROR:", err);
    res.status(500).json({ error: err.message }); 
  }
});

// ─────────────────────────────────────────────
// FUEL CARDS CRUD
// ─────────────────────────────────────────────
app.get('/fuel-cards', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT fc.*, v.vin FROM fuel_cards fc
       LEFT JOIN vehicles v ON fc.vehicle_id = v.id
       ORDER BY fc.id`
    );
    res.json(result.rows);
  } catch (err) { res.status(500).send('Error'); }
});

app.post('/fuel-cards', async (req, res) => {
  const { fc_number, vehicle_id } = req.body;
  try {
    const result = await pool.query(
      `INSERT INTO fuel_cards (fc_number, vehicle_id, active) VALUES ($1,$2,true) RETURNING *`,
      [fc_number, vehicle_id || null]
    );
    res.json(result.rows[0]);
  } catch (err) { 
    console.error("ADD FUEL CARD ERROR:", err);
    res.status(500).json({ error: err.message }); 
  }
});

app.put('/fuel-cards/:id', async (req, res) => {
  const { fc_number, vehicle_id, active } = req.body;
  try {
    const result = await pool.query(
      `UPDATE fuel_cards SET fc_number=$1, vehicle_id=$2, active=$3 WHERE id=$4 RETURNING *`,
      [fc_number, vehicle_id || null, active, req.params.id]
    );
    res.json(result.rows[0]);
  } catch (err) { 
    console.error("UPDATE FUEL CARD ERROR:", err);
    res.status(500).json({ error: err.message }); 
  }
});

app.delete('/fuel-cards/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM fuel_cards WHERE id=$1', [req.params.id]);
    res.json({ success: true });
  } catch (err) { res.status(500).send('Error'); }
});

// Fuel card assigned to a vehicle (for driver app)
app.get('/fuel-cards/by-vehicle/:vehicle_id', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT fc_number FROM fuel_cards WHERE vehicle_id=$1 AND active=true LIMIT 1`,
      [req.params.vehicle_id]
    );
    res.json(result.rows[0] || null);
  } catch (err) { res.status(500).send('Error'); }
});

// ─────────────────────────────────────────────
// TRIP ALLOCATION
// ─────────────────────────────────────────────
app.get('/trip-allocations', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT ta.*, 
         u1.name AS driver_name, u1.employee_id AS emp_id_1,
         u2.name AS driver_name_2, u2.employee_id AS emp_id_2,
         u3.name AS driver_name_3, u3.employee_id AS emp_id_3,
         v.vin, r.route_name
       FROM trip_allocations ta
       JOIN users u1 ON ta.driver_id = u1.id
       LEFT JOIN users u2 ON ta.driver_id_2 = u2.id
       LEFT JOIN users u3 ON ta.driver_id_3 = u3.id
       JOIN vehicles v ON ta.vehicle_id = v.id
       JOIN routes r ON ta.route_id = r.id
       ORDER BY ta.id DESC`
    );
    res.json(result.rows);
  } catch (err) { 
    console.error("GET TRIP ALLOCATIONS ERROR:", err);
    res.status(500).json({ error: err.message }); 
  }
});

app.post('/trip-allocations', async (req, res) => {
  const { driver_id, driver_id_2, driver_id_3, vehicle_id, route_id, shift } = req.body;
  try {
    const drivers = [driver_id, driver_id_2, driver_id_3].filter(id => id != null);
    
    // Check if any of the drivers are in an active trip
    const activeTrips = await pool.query(
      "SELECT driver_id FROM trips WHERE driver_id = ANY($1) AND trip_status = 'STARTED'",
      [drivers]
    );

    if (activeTrips.rows.length > 0) {
      const busyIds = activeTrips.rows.map(r => r.driver_id).join(', ');
      return res.status(400).json({ error: `Driver(s) ${busyIds} are already in an active trip!` });
    }

    const result = await pool.query(
      `INSERT INTO trip_allocations (driver_id, driver_id_2, driver_id_3, vehicle_id, route_id, shift, date, status)
       VALUES ($1,$2,$3,$4,$5,$6,NOW(), 'PENDING') RETURNING *`,
      [driver_id, driver_id_2, driver_id_3, vehicle_id, route_id, shift]
    );
    res.json(result.rows[0]);
  } catch (err) {
    console.error("ADD ALLOCATION ERROR:", err);
    res.status(500).json({ error: err.message });
  }
});

app.put('/trip-allocations/:id/status', async (req, res) => {
  const { status } = req.body;
  try {
    const result = await pool.query(
      "UPDATE trip_allocations SET status = $1 WHERE id = $2 RETURNING *",
      [status, req.params.id]
    );
    res.json(result.rows[0]);
  } catch (err) {
    console.error("UPDATE STATUS ERROR:", err);
    res.status(500).json({ error: err.message });
  }
});

app.delete('/trip-allocations/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM trip_allocations WHERE id=$1', [req.params.id]);
    res.json({ success: true });
  } catch (err) { res.status(500).send('Error'); }
});

// Trip allocation by driver (for driver app - to show their assigned trip)
app.get('/trip-allocations/by-driver/:driver_id', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT ta.*, v.vin, r.route_name FROM trip_allocations ta
       JOIN vehicles v ON ta.vehicle_id = v.id
       JOIN routes r ON ta.route_id = r.id
       WHERE (ta.driver_id = $1 OR ta.driver_id_2 = $1 OR ta.driver_id_3 = $1)
       AND ta.status != 'CANCELLED'
       ORDER BY ta.id DESC LIMIT 1`,
      [req.params.driver_id]
    );
    res.json(result.rows[0] || null);
  } catch (err) { 
    console.error("GET BY DRIVER ERROR:", err);
    res.status(500).json({ error: err.message }); 
  }
});

// ─────────────────────────────────────────────
// TRIPS
// ─────────────────────────────────────────────
app.post('/start-trip', async (req, res) => {
  const { driver_id, vehicle_id, route_id, start_odo, shift } = req.body;
  try {
    const result = await pool.query(
      `INSERT INTO trips (driver_id, vehicle_id, route_id, start_odo, shift, start_time, trip_status)
       VALUES ($1,$2,$3,$4,$5,NOW(),'STARTED') RETURNING id`,
      [driver_id, vehicle_id, route_id, start_odo, shift]
    );
    res.json({ success: true, trip_id: result.rows[0].id });
  } catch (err) {
    console.error(err);
    res.status(500).send('Error');
  }
});

// WIPE ALL TRIPS (requested by admin)
app.delete('/trips/all/wipe', async (req, res) => {
  try {
    await pool.query('DELETE FROM trips');
    res.json({ success: true, message: 'All trips deleted' });
  } catch (err) {
    console.error(err);
    res.status(500).send('Error');
  }
});

app.post('/end-trip', async (req, res) => {
  const { trip_id, end_odo } = req.body;
  try {
    await pool.query(
      `UPDATE trips SET end_odo=$1, end_time=NOW(), trip_status='ENDED' WHERE id=$2`,
      [end_odo, trip_id]
    );
    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).send('Error');
  }
});

// All trips for reports
app.get('/trips/all', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT t.*, u.name AS driver_name, u.employee_id, v.vin, r.route_name,
       COALESCE(t.start_time::date::text, '—') as report_date
       FROM trips t
       LEFT JOIN users u ON t.driver_id = u.id
       LEFT JOIN vehicles v ON t.vehicle_id = v.id
       LEFT JOIN routes r ON t.route_id = r.id
       ORDER BY t.id DESC`
    );
    res.json(result.rows);
  } catch (err) { res.status(500).send('Error'); }
});

// ─────────────────────────────────────────────
// FUEL ENTRIES (for reports)
// ─────────────────────────────────────────────
app.get('/fuel/all', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT fe.*, u.name AS driver_name, u.employee_id, v.vin,
       COALESCE(fe.created_at::date::text, '—') as report_date
       FROM fuel_entries fe
       LEFT JOIN users u ON fe.driver_id = u.id
       LEFT JOIN vehicles v ON fe.vehicle_id = v.id
       ORDER BY fe.id DESC`
    );
    res.json(result.rows);
  } catch (err) { console.error(err); res.status(500).send('Error'); }
});

// ─────────────────────────────────────────────
// ISSUES (for reports)
// ─────────────────────────────────────────────
app.get('/issues/all', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT i.*, u.name AS driver_name, u.employee_id,
       COALESCE(i.issue_date::date::text, i.created_at::date::text, '—') as report_date
       FROM issues i
       LEFT JOIN users u ON i.driver_id = u.id
       ORDER BY i.id DESC`
    );
    res.json(result.rows);
  } catch (err) { console.error(err); res.status(500).send('Error'); }
});

// ─────────────────────────────────────────────
// REPAIRS (for reports)
// ─────────────────────────────────────────────
app.get('/repairs/all', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT r.*, v.vin, u.name AS driver_name,
       COALESCE(r.service_date::date::text, '—') as report_date
       FROM repair_history r
       LEFT JOIN vehicles v ON r.vehicle_id = v.id
       LEFT JOIN users u ON r.driver_id = u.id
       ORDER BY r.id DESC`
    );
    res.json(result.rows);
  } catch (err) { console.error(err); res.status(500).send('Error'); }
});

// ─────────────────────────────────────────────
// ASSETS (for asset tracking + reports)
// ─────────────────────────────────────────────
app.get('/assets', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT a.*, v.vin,
       COALESCE(a.installation_date::date::text, a.created_at::date::text, '—') as report_date
       FROM asset_tracking a
       LEFT JOIN vehicles v ON a.vehicle_id = v.id
       ORDER BY a.id DESC`
    );
    res.json(result.rows);
  } catch (err) { console.error(err); res.status(500).send('Error'); }
});

app.post('/assets', async (req, res) => {
  const { category, vehicle_id, asset_number, requested_by, fitted_by, installation_date, odo_reading } = req.body;
  try {
    const result = await pool.query(
      `INSERT INTO asset_tracking (category, vehicle_id, asset_number, requested_by, fitted_by, installation_date, odo_reading)
       VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
      [category, vehicle_id, asset_number, requested_by, fitted_by, installation_date, odo_reading]
    );
    res.json(result.rows[0]);
  } catch (err) { res.status(500).send('Error'); }
});

app.delete('/assets/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM asset_tracking WHERE id=$1', [req.params.id]);
    res.json({ success: true });
  } catch (err) { res.status(500).send('Error'); }
});

// ─────────────────────────────────────────────
// FUEL ENTRIES POST (driver logs fuel)
// ─────────────────────────────────────────────
app.post('/fuel-entries', async (req, res) => {
  const { trip_id, driver_id, vehicle_id, litres, amount, fuel_type, fuel_card_number, bill_image, odo_reading } = req.body;
  try {
    const result = await pool.query(
      `INSERT INTO fuel_entries (trip_id, driver_id, vehicle_id, litres, amount, fuel_type, fuel_card_number, bill_image, odo_reading, created_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,NOW()) RETURNING *`,
      [trip_id, driver_id, vehicle_id, litres, amount, fuel_type, fuel_card_number, bill_image, odo_reading || null]
    );
    res.json(result.rows[0]);
  } catch (err) { console.error(err); res.status(500).send('Error'); }
});

// ─────────────────────────────────────────────
// ISSUES POST (driver reports issue)
// ─────────────────────────────────────────────
app.post('/issues', async (req, res) => {
  const { driver_id, vehicle_vin, description, odo_entry, date } = req.body;
  try {
    const result = await pool.query(
      `INSERT INTO issues (driver_id, vehicle_vin, description, odo_entry, issue_date, created_at)
       VALUES ($1,$2,$3,$4,$5,NOW()) RETURNING *`,
      [driver_id, vehicle_vin, description, odo_entry, date]
    );
    res.json(result.rows[0]);
  } catch (err) { console.error(err); res.status(500).send('Error'); }
});

// ─────────────────────────────────────────────
// REPAIRS POST (admin logs repair)
// ─────────────────────────────────────────────
app.post('/repairs', async (req, res) => {
  const { driver_id, vehicle_id, service_date, requested_by, performed_by,
    odo_reading, repair_details, notes,
    part_replacement, part_removal_refit, software_flashing } = req.body;
  try {
    const result = await pool.query(
      `INSERT INTO repair_history (driver_id, vehicle_id, service_date, requested_by, performed_by,
        odo_reading, repair_details, notes, part_replacement, part_removal_refit, software_flashing)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) RETURNING *`,
      [driver_id, vehicle_id, service_date, requested_by, performed_by,
        odo_reading, repair_details, notes,
        part_replacement, part_removal_refit, software_flashing]
    );
    res.json(result.rows[0]);
  } catch (err) { console.error(err); res.status(500).send('Error'); }
});

// ─────────────────────────────────────────────
// ATTENDANCE (Punch-In / Punch-Out)
// ─────────────────────────────────────────────

// Create attendance table if not exists (run once on start)
pool.query(`
  CREATE TABLE IF NOT EXISTS attendance (
    id SERIAL PRIMARY KEY,
    driver_id INTEGER NOT NULL REFERENCES users(id),
    attendance_date DATE NOT NULL DEFAULT CURRENT_DATE,
    punch_in TIMESTAMPTZ,
    punch_out TIMESTAMPTZ,
    UNIQUE(driver_id, attendance_date)
  )
`).catch(err => console.error('attendance table error:', err));

// Get today's attendance for a driver
app.get('/attendance/today/:driver_id', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT * FROM attendance WHERE driver_id=$1 AND attendance_date=CURRENT_DATE`,
      [req.params.driver_id]
    );
    res.json(result.rows[0] || null);
  } catch (err) { console.error(err); res.status(500).send('Error'); }
});

// Punch In
app.post('/attendance/punch-in', async (req, res) => {
  const { driver_id } = req.body;
  try {
    const result = await pool.query(
      `INSERT INTO attendance (driver_id, attendance_date, punch_in)
       VALUES ($1, CURRENT_DATE, NOW())
       ON CONFLICT (driver_id, attendance_date) DO UPDATE SET punch_in = NOW()
       RETURNING *`,
      [driver_id]
    );
    res.json(result.rows[0]);
  } catch (err) { console.error(err); res.status(500).send('Error'); }
});

// Punch Out
app.post('/attendance/punch-out', async (req, res) => {
  const { driver_id } = req.body;
  try {
    const result = await pool.query(
      `UPDATE attendance SET punch_out=NOW()
       WHERE driver_id=$1 AND attendance_date=CURRENT_DATE
       RETURNING *`,
      [driver_id]
    );
    if (result.rows.length === 0) return res.status(400).json({ error: 'Not punched in today' });
    res.json(result.rows[0]);
  } catch (err) { console.error(err); res.status(500).send('Error'); }
});

// Admin: get all attendance records (optionally filtered by date)
app.get('/attendance/all', async (req, res) => {
  try {
    const { date } = req.query; // optional YYYY-MM-DD
    let query = `
      SELECT a.*, u.name AS driver_name, u.employee_id
      FROM attendance a
      JOIN users u ON a.driver_id = u.id
    `;
    const params = [];
    if (date) {
      query += ` WHERE a.attendance_date = $1`;
      params.push(date);
    }
    query += ` ORDER BY a.attendance_date DESC, u.name ASC`;
    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) { console.error(err); res.status(500).send('Error'); }
});

// ─────────────────────────────────────────────
// START SERVER
// ─────────────────────────────────────────────
app.listen(3000, () => {
  console.log('Server running on port 3000 🚀');
});