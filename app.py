from flask import Flask, render_template, jsonify


app = Flask(__name__)


# --- Demo data (replace with DB later) ---
PATIENTS = [
{"name": "John Doe", "age": 45, "diagnosis": "Hypertension", "status": "Admitted"},
{"name": "Jane Smith", "age": 56, "diagnosis": "Diabetes", "status": "Discharged"},
{"name": "Robert Brown", "age": 35, "diagnosis": "Back Pain", "status": "Admitted"},
{"name": "Mary Johnson", "age": 62, "diagnosis": "Flu", "status": "Discharged"}
]


APPOINTMENTS = [
{"doctor": "Dr. Williams", "status": "Completed"},
{"doctor": "Dr. Johnson", "status": "Pending"},
{"doctor": "Dr. Davis", "status": "Pending"}
]


KPI = {
"total_patients": 1250,
"active_doctors": 80,
"todays_appointments": 45,
"bed_occupancy": 85
}


@app.route("/")
def landing():
	return render_template("landing.html")


@app.route("/dashboard")
def dashboard():
	return render_template("dashboard.html", patients=PATIENTS, appointments=APPOINTMENTS, kpi=KPI)


# Optional JSON APIs (later for charts / React)
@app.route("/api/patients")
def api_patients():
	return jsonify(PATIENTS)


@app.route("/api/kpi")
def api_kpi():
	return jsonify(KPI)

@app.route("/patient-outcomes")
def patient_outcomes():
    PATIENT_KPI = {
        "avg_stay": {"value": "4.5 days", "change": -2.17, "prev": "4.6 days"},
        "readmission": {"value": "12%", "change": -7.69, "prev": "13%"},
        "satisfaction": {"value": "88", "change": +3.53, "prev": "85"},
        "mortality": {"value": "2.8%", "change": -3.45, "prev": "2.9%"}
    }
    return render_template("patient_outcomes.html", kpi=PATIENT_KPI)

if __name__ == "__main__":
	app.run(host="0.0.0.0", port=8080, debug=True)
