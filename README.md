
# Household Energy Management System (HEMS) – Optimization Model

## Overview

This repository contains a modular optimization model for a fully electric residential building under Nordic climate conditions.

The model determines the optimal hourly operation of:

* Heat pump water heater
* Space heating system
* Rooftop solar PV
* Electric vehicle (bidirectional charging)

The objective is formulated as a sequential (lexicographic) multi-objective problem, prioritizing:

1. Electricity cost minimization
2. Thermal comfort preservation

The optimization problem is formulated as a Mixed-Integer Linear Program (MILP) and solved using CPLEX in GAMS.

---

## Repository Structure

```
Residential-Energy-Optimization/
│
├── model/
│   ├── EMS_main.gms
│   ├── 1_Data.gms
│   ├── 2_Model.gms
│   └── 3_Results.gms
│
├── data/
│   └── MonthsData.xlsx
│
└── README.md
```

### File Description

**EMS_main.gms**
Controls execution and includes all model components.

**1_Data.gms**

* Imports hourly input data
* Handles month selection
* Defines seasonal parameters (e.g., space heating ON/OFF)

**2_Model.gms**

* Defines decision variables
* Implements thermal dynamics
* Implements EV battery constraints
* Enforces power balance
* Applies grid capacity limits

**3_Results.gms**

* Executes model solve
* Checks solver status
* Performs post-solve validation (energy balance, grid limits, temperature bounds)

---

## Model Characteristics

* Time resolution: 1 hour
* Horizon: 24-hour representative day
* Mathematical formulation: MILP
* Solver: CPLEX

The lexicographic structure ensures that electricity cost is minimized first, while maintaining feasibility with respect to thermal comfort constraints.

---

## Validation Procedure

The model includes internal validation steps:

* Solver optimality check (`modelstat`, `solvestat`)
* Grid capacity verification
* Energy balance verification
* Temperature safety bounds verification

Execution stops automatically if any violation occurs.

---

## Data Interface

Input data is currently read from:

```
data/MonthsData.xlsx
```

using GDXXRW.

The model structure is independent of the file format.
The data module can be adapted to read:

* CSV files
* GDX files
* Database exports

Only the import routine in `1_Data.gms` must be modified.
No changes are required in the optimization formulation.

---

## Running the Model

From the project root directory:

```
gams model/EMS_main.gms --month_name=Dec
```
## Analytics & Visualization

The model includes an automated GAMS-to-Python bridge for real-time post-processing:

* Automated Scripting & Visualization: GAMS dynamically generates and executes Python scripts upon solver completion to launch Matplotlib plots of dispatch trajectories.
* Data Storage & KPI Calculation: Optimization results are archived as GDX files for long-term storage, while the analytics wrapper calculates Cost-Savings, Comfort Enhancement, Self-Consumption, and Grid Trade.
```
Available month names must match the worksheet names in the input file.


