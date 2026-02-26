$Title DSM_ALL_ELECTRIC_SMART_HOME (Energy Demand Optimization for Demand Side Management)
* Main.gms

$onText
 METHODOLOGY OVERVIEW
 This model implements an Implicit Demand Response (IDR) framework for Nordic households.
 It utilizes a sequential multi-objective optimization (Lexicographic) to resolve the
 trade-off between electricity costs and occupant comfort.The household is "fully electric,"
 integrating a Combined Heat Pump Water Heater (CHPWH), space heating, electric mobility
 (V2H/V2G), and solar PV.
$offText
* ------------------------------------------------------------------------------------------

* ==========================================================================================
* MODULE 1: DATA INPUTS AND CALIBRATION

* This module defines the Sets, loads, external weather and price data from Excel, and sets
* thermodynamic constants for the Nordic household case study.

$include 1_Data.gms
* ------------------------------------------------------------------------------------------

* ==========================================================================================
* MODULE 2: MATHEMATICAL FORMULATION

* This module contains the physics of the model. It declares the decision variables and
* formulates the constraints for energy balance, thermal dynamics of the water tanks/room,
* and EV battery logic.

$include 2_Model.gms
* ------------------------------------------------------------------------------------------

* ==========================================================================================
* MODULE 3: EXECUTION AND VISUALIZATION

* This module performs the sequential Lexicographic solve (Cost then Comfort).It then
* exports the results to GDX and generates 6 Python scripts to produce the result graphs.

$include 3_Results.gms
* ------------------------------------------------------------------------------------------

* End of Main Control File * ---------------------------------------------------------------
