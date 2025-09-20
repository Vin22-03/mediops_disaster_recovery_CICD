import os
from flask import Flask, render_template, jsonify
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import text
from werkzeug.exceptions import InternalServerError

app = Flask(__name__)

# ==============================
# 🔧 Database Config (from ENV)
# ==============================
DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT")
DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER")
DB_PASS = os.getenv("DB_PASSWORD")  # Corrected to use DB_PASSWORD as per your YAML

# Strict environment variable check
if not all([DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASS]):
    # In a production environment, raise an error immediately on startup
    # to prevent a silent failure.
    raise ValueError("One or more database environment variables are not set. Exiting.")

app.config["SQLALCHEMY_DATABASE_URI"] = (
    f"postgresql://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
)
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

db = SQLAlchemy(app)

# ==============================
# 🗂️ Database Models
# ==============================
# All your model definitions are correct and remain unchanged.
class Patient(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(50))
    age = db.Column(db.Integer)
    diagnosis = db.Column(db.String(100))
    status = db.Column(db.String(20))

class Appointment(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    doctor = db.Column(db.String(50))
    status = db.Column(db.String(20))

class KPI(db.Model):
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
        # Wrap database access in a try/except block to fail gracefully.
        return f"Database error on dashboard route: {e}", 500

@app.route("/api/patients")
def api_patients():
    try:
        patients = Patient.query.all()
        return jsonify([
            {"name": p.name, "age": p.age, "diagnosis": p.diagnosis, "status": p.status}
            for p in patients
        ])
    except Exception as e:
        return f"Database error on API route: {e}", 500

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
        return f"Database error on KPI route: {e}", 500

@app.route("/patient-outcomes")
def patient_outcomes():
    PATIENT_KPI = {
        "avg_stay": {"value": "4.5 days", "change": -2.17, "prev": "4.6 days"},
        "readmission": {"value": "12%", "change": -7.69, "prev": "13%"},
        "satisfaction": {"value": "88", "change": +3.53, "prev": "85"},
        "mortality": {"value": "2.8%", "change": -3.45, "prev": "2.9%"},
    }
    return render_template("patient_outcomes.html", kpi=PATIENT_KPI)

# ==============================
# ❤️ Health Check
# ==============================
@app.route("/health")
def health():
    try:
        db.session.execute(text("SELECT 1"))
        return "OK", 200
    except Exception as e:
        return f"Database connection failed: {e}", 500

# ==============================
# 🚀 App Runner
# ==============================
if __name__ == "__main__":
    # The application context is necessary for creating the database schema.
    try:
        with app.app_context():
            db.create_all()
    except Exception as e:
        print(f"⚠️ Failed to initialize database: {e}")
        # Raising the exception will ensure the application exits if the database
        # cannot be initialized, preventing a crash loop.
        raise InternalServerError("Failed to initialize database.") from e

    # Ensure debug mode is turned off for production.
    # The `if __name__ == "__main__"` block is usually used for local development.
    # In a production container, you would use a WSGI server like Gunicorn.
    app.run(host="0.0.0.0", port=8080)
