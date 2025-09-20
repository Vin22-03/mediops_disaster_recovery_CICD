import os
from flask import Flask, render_template, jsonify
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import text

app = Flask(__name__)

# ==============================
# 🔧 Database Config (from ENV)
# ==============================
DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT")
DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER")
DB_PASS = os.getenv("DB_PASSWORD")  # ✅ matches Secret key

# Fail fast if any env is missing
if not all([DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASS]):
    raise ValueError("❌ One or more DB environment variables are not set.")

print(f"🔌 Using DB connection -> host={DB_HOST}, port={DB_PORT}, db={DB_NAME}, user={DB_USER}")

app.config["SQLALCHEMY_DATABASE_URI"] = (
    f"postgresql://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
)
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

db = SQLAlchemy(app)

# ==============================
# 🗂️ Database Models
# ==============================
class Patient(db.Model):
    __tablename__ = "patients"
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(50))
    age = db.Column(db.Integer)
    diagnosis = db.Column(db.String(100))
    status = db.Column(db.String(20))

class Doctor(db.Model):   # ✅ Added Doctor model
    __tablename__ = "doctors"
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(50))
    specialization = db.Column(db.String(100))

class Appointment(db.Model):
    __tablename__ = "appointments"
    id = db.Column(db.Integer, primary_key=True)
    patient_id = db.Column(db.Integer)
    doctor_id = db.Column(db.Integer)
    date = db.Column(db.Date)
    status = db.Column(db.String(20))

class KPI(db.Model):
    __tablename__ = "kpi"
    id = db.Column(db.Integer, primary_key=True)
    total_patients = db.Column(db.Integer)
    active_doctors = db.Column(db.Integer)
    todays_appointments = db.Column(db.Integer)
    bed_occupancy = db.Column(db.Integer)

# ==============================
# 🌐 Routes
# ==============================
@app.route("/")
def landing():
    return render_template("landing.html")

@app.route("/dashboard")
def dashboard():
    try:
        patients = Patient.query.all()
        appointments = Appointment.query.all()
        kpi = KPI.query.first()
        return render_template(
            "dashboard.html",
            patients=patients,
            appointments=appointments,
            kpi={
                "total_patients": kpi.total_patients if kpi else 0,
                "active_doctors": kpi.active_doctors if kpi else 0,
                "todays_appointments": kpi.todays_appointments if kpi else 0,
                "bed_occupancy": kpi.bed_occupancy if kpi else 0,
            },
        )
    except Exception as e:
        return f"Database error on dashboard: {e}", 500

# --- ✅ New Pages ---
@app.route("/patients")
def patients_page():
    patients = Patient.query.all()
    return render_template("patients.html", patients=patients)

@app.route("/doctors")
def doctors_page():
    doctors = Doctor.query.all()
    return render_template("doctors.html", doctors=doctors)

@app.route("/appointments")
def appointments_page():
    appointments = Appointment.query.all()
    return render_template("appointments.html", appointments=appointments)

@app.route("/settings")
def settings_page():
    return render_template("settings.html")

# --- APIs ---
@app.route("/api/patients")
def api_patients():
    try:
        patients = Patient.query.all()
        return jsonify([{"name": p.name, "age": p.age, "diagnosis": p.diagnosis, "status": p.status} for p in patients])
    except Exception as e:
        return f"Database error: {e}", 500

@app.route("/api/kpi")
def api_kpi():
    try:
        kpi = KPI.query.first()
        return jsonify({
            "total_patients": kpi.total_patients if kpi else 0,
            "active_doctors": kpi.active_doctors if kpi else 0,
            "todays_appointments": kpi.todays_appointments if kpi else 0,
            "bed_occupancy": kpi.bed_occupancy if kpi else 0,
        })
    except Exception as e:
        return f"Database error: {e}", 500

@app.route("/patient-outcomes")
def patient_outcomes():
    PATIENT_KPI = {
        "avg_stay": {"value": "4.5 days", "change": -2.17, "prev": "4.6 days"},
        "readmission": {"value": "12%", "change": -7.69, "prev": "13%"},
        "satisfaction": {"value": "88", "change": +3.53, "prev": "85"},
        "mortality": {"value": "2.8%", "change": -3.45, "prev": "2.9%"},
    }
    return render_template("patient_outcomes.html", kpi=PATIENT_KPI)


@app.route("/version")
def version():
    version_tag = os.getenv("VERSION_TAG", "dev")
    deploy_color = os.getenv("DEPLOY_COLOR", "unknown")
    return render_template("version.html", version=version_tag, color=deploy_color)


# ==============================
# ❤️ Health Check
# ==============================
@app.route("/health")
def health():
    try:
        db.session.execute(text("SELECT 1"))
        return "Yeah am Healthy OK", 200
    except Exception as e:
        return f"Database connection failed: {e}", 500

# ==============================
# 🚀 App Runner
# ==============================
if __name__ == "__main__":
    try:
        with app.app_context():
            db.create_all()
    except Exception as e:
        print(f"⚠️ Failed to initialize database: {e}")
        # Do NOT raise — let pod start, readiness probe will keep it out of rotation

    app.run(host="0.0.0.0", port=8080)
