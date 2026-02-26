* ========================================================================================
* MODULE 1: DATA ACQUISITION & CALIBRATION

* This module initializes time sets, appliance categories, and loads external 
* Implicit Demand Response (IDR) signals including spot prices, outdoor 
* temperatures, and solar PV generation data from Excel.
* -----------------------------------------------------------------------------------------

* 1. SYSTEM SETS AND INITIALIZATION =======================================================

SETS
   h   "Set of hourly intervals"          / h1*h24 /
   i   "Set of non-shiftable appliances"  / Light,Fridge,Stove,TV,PC,Microw,Router,coffee /
   j   "Set of shiftable appliances"      / Dish,Lndry,vacuum /
;

* -----------------------------------------------------------------------------------------

* SEASONAL CONFIGURATION
* Space heating is automatically toggled based on the simulated months to reflect
* typical Nordic climate variations where heating is inactive during summer months.

$if not set month_name $setglobal month_name Dec

display "Selected sample day per of w the month:", "%month_name%";

SCALAR heat_space_on  "1 = Heating ON, 0 = Summer OFF";

heat_space_on = 1;

$ifThen %month_name% == "May" or %month_name% == "Jun" or %month_name% == "Jul" or %month_name% == "Aug" or %month_name% == "Sep"
   heat_space_on = 0;
$endIf


* 2. INPUT PARAMETERS AND DATA CALIBRATION ================================================

PARAMETERS
* EXTERNAL DATA LOADING (IDR SIGNALS)
* Weather (temp_out), Solar (pv_gen), and Spot Prices (price_spot) are 
* loaded from external sources to represent the Implicit Demand Response signals.

   temp_out(h)   "Outdoor temperature"
$call GDXXRW MonthsData.xlsx par=temp_out rng=%month_name%!B2:Y3 rdim=0 cdim=1
$GDXIN MonthsData.gdx
$load temp_out
$GDXIN

   pv_gen(h)     "Solar PV generation"
$call GDXXRW MonthsData.xlsx par=pv_gen rng=%month_name%!B4:Y5 rdim=0 cdim=1
$GDXIN MonthsData.gdx
$load pv_gen
$GDXIN

   price_spot(h) "Spot electricity price";
$call GDXXRW MonthsData.xlsx par=price_spot rng=%month_name%!B6:Y7 rdim=0 cdim=1
$GDXIN MonthsData.gdx
$load price_spot
$GDXIN
;

PARAMETERS
   price_sub(h)   "Subsidized spot price after governmental cap support"

   cop_up(h)      "Efficiency of electrical energy to thermal energy for upper section"
   cop_low(h)     "Efficiency of electrical energy to thermal energy for lower section"

   ev_avail(h)    "Connection status of EVs at time h"
                  /h1  1,h2  1,h3  1,h4  1,h5  1,h6  1,h7  1,h8  0,h9  0,h10 0,h11 0,h12
                  0,h13 0,h14 0,h15 1,h16 1,h17 1,h18 1,h19 1,h20 1,h21 1,h22 1,h23 1,h24 1/

   hw_demand(h)   "Total energy of hot water consumption from upper tank"
                  /h1  0, h2  0, h3  0, h4  0, h5  0, h6  0, h7  0, h8  6480, h9  1600, h10 0, h11 0, h12 0
                  ,h13 0, h14 0, h15 0, h16 0, h17 0, h18 1600, h19 3200, h20 2600, h21 0, h22 3200, h23 0, h24 0/

*  Appliances with district energy value and strict consumption scheduling in each household per day
   energy_nsh(i)  "Daily energy usage of non-shiftable appliances in Wh"
                  /Light 400,Fridge 4300,Stove 4500,TV 500,PC 200,Router 150,Microw 200, Coffee 80/

   dur_nsh(i)     "Daily time usage of non-shiftable appliances"
                  /Light 8,Fridge 24,Stove 3,TV 5,PC 2,Microw 1,Router 24,coffee 1/

*  Appliances with district energy value non-strict consumption scheduling in each household per day
   energy_sh(j)   "Daily energy usage of shiftable appliances in Wh"
                  /Dish 1440,Lndry 1940,Vacuum 420/

   dur_sh(j)      "Daily time usage of shiftable appliances"
                  /Dish 1,Lndry 2,Vacuum 1/

   start_pref(j)  "Preferred starting time of shiftable appliances"
                  /Dish 1,Lndry 1,Vacuum 17/

   finish_pref(j) "Preferred finishing time of shiftable appliances"
                  /Dish 16,Lndry 13,Vacuum 22/
;

    TABLE profile_nsh(i,h)   "Allocated time for a non-shiftable appliances at time h"       
$call=xls2gms i=MonthsData.xlsx r=NshAppliances!E3:AC11  o=profile_nsh.inc
$include profile_nsh.inc
;

* -----------------------------------------------------------------------------------------

* Input validation block (Data Integrity Tests)

scalar pv_sum, price_sum, h_count;

pv_sum    = sum(h, pv_gen(h));
price_sum = sum(h, price_spot(h));
h_count   = card(h);

display pv_sum, price_sum, h_count;

if (h_count ne 24,
   display "ERROR: Time set does not contain 24 hours.";
   display h_count;
   abort "Stopping execution: invalid time dimension.";
);

if (pv_sum < 0,
   display "ERROR: PV data contains negative values.";
   display pv_gen;
   abort "Stopping execution: invalid PV input.";
);

if (price_sum = 0,
   display "ERROR: Price data not loaded.";
   display price_spot;
   abort "Stopping execution: invalid price input.";
);

display "INPUT VALIDATION PASSED.";

* -----------------------------------------------------------------------------------------

* Custom ASCII Visualization in .lst File 
Scalar v_idx "Local loop counter for visualization";
Scalar v_max "Maximum stars allowed per line" / 50 /;
Scalar v_scale "Scaling factor";

File vis / '' /;  
put vis;
put / "__________________________________________________________";
put / "           INPUT DATA VISUAL PROFILES                     ";


* 1. TEMPERATURE PROFILE
put "--- TEMPERATURE PROFILE (temp_out) ---" /;
loop(h,
    put h.tl:4, " [", temp_out(h):5:1, " C] ";
    if(temp_out(h) > 0,
        for(v_idx = 1 to min(v_max, round(temp_out(h))), put "*");
    else
        put "minus";
    );
    put /;
);

* 2. SOLAR PV PROFILE
v_scale = smax(h, pv_gen(h)) / v_max;
if(v_scale = 0, v_scale = 1);
put / "--- SOLAR PV GENERATION (pv_gen) ---" /;
put " (Each * approx ", v_scale:0:2, " units)" /;
loop(h,
    put h.tl:4, " [", pv_gen(h):5:1, "] ";
    if(pv_gen(h) > 0,
        for(v_idx = 1 to round(pv_gen(h)/v_scale), put "*");
    );
    put /;
);

* 3. SPOT PRICE PROFILE
v_scale = smax(h, price_spot(h)) / v_max;
if(v_scale = 0, v_scale = 1);
put / "--- SPOT PRICE PROFILE (price_spot) ---" /;
put " (Each * approx ", v_scale:0:2, " units)" /;
loop(h,
    put h.tl:4, " [", price_spot(h):5:2, "] ";
    if(price_spot(h) > 0,
        for(v_idx = 1 to round(price_spot(h)/v_scale), put "*");
    );
    put /;
);

* 4. EV AVAILABILITY (Status 1 or 0)
put / "--- EV CONNECTION STATUS (ev_avail) ---" /;
loop(h,
    put h.tl:4, " [", ev_avail(h):1:0, "] ";
    if(ev_avail(h) > 0.5,
        put "CONNECTED [##########]";
    else
        put "AWAY      [          ]";
    );
    put /;
);

* 5. HOT WATER DEMAND PROFILE
v_scale = smax(h, hw_demand(h)) / v_max;
if(v_scale = 0, v_scale = 1);
put / "--- HOT WATER DEMAND (hw_demand) ---" /;
put " (Each * approx ", v_scale:0:2, " units)" /;
loop(h,
    put h.tl:4, " [", hw_demand(h):6:0, "] ";
    if(hw_demand(h) > 0,
        for(v_idx = 1 to round(hw_demand(h)/v_scale), put "*");
    );
    put /;
);

put / "____________________________________________________" /;
putclose;

* -----------------------------------------------------------------------------------------

* CASE STUDY PARAMETER SELECTION
* Values are calibrated based on a Norwegian pilot household (DESSI 108x living lab). 
* Thermal U-values follow Nordic building standards for high insulation.
* EV parameters reflect a typical commute for a standard 80kWh battery (Skoda Enyaq).

SCALARS
* Prices are used in  Øre
* Upper tank for hot water and Lower tank for space heating
 big_m             "Appropriately large value for linearization"       /1000000/
 small_m           "Appropriately small value for linearization"       /0.00001/
 grid_cap          "peak load index in kWh based on fuse limit (3*50A)"     /20/
 vat               "Value added Tax"                                      /0.25/
 vat_exp           "Value added Tax on production"                           /0/
 fee_energy        "Add-on for Energy Supplier ~ 0.02,..., 0.06 NOK/kWh"     /6/ 
 fee_energy_m      "Monthly Add-on for Energy Supplier ~ 19-50 NOK/month" /3900/
 fee_grid_day      "Add-on for Grid Supplier  gs = 0.43 (Weekday)"          /43/
 fee_grid_night    "Add-on for Grid Supplier  gs = 0.37 (Weekend/night)"    /37/
 fee_grid_exp      "Add-on for Grid Supplier  gs = 0.05 (PV Production)"     /5/
 tariff_1          "Fixed fee in level 1 based on daily cons. Øre/month" /12500/
 tariff_2          "Fixed fee in level 2 based on daily cons. Øre/month" /20000/
 tariff_3          "Fixed fee in level 3 based on daily cons. Øre/month" /32500/
 tariff_4          "Fixed fee in level 4 based on daily cons. Øre/month" /45000/
 tariff_5          "Fixed fee in level 5 based on daily cons. Øre/month" /57000/

 diameter          "Diameter of the tank"                               /595E-3/
 height            "Height of the tank in m"                           /2031E-3/
 volume_low        "Volume of lower section of tank in m3"                 /136/
 volume_up         "Volume of upper section of tank in m3 (224 - 350)"     /350/
 temp_amb          "Temperature of environment around tank"                 /18/
 temp_ref          "Cold water temperature of entering tank"                /10/
******             preference for water heater temp
 temp_hw_set       "Target temperature of upper section"                    /60/
******             preference for water heater temp
 temp_up_min       "Minimum temp. in upper section"                         /45/
 temp_up_max       "Maximum temp. in upper section"                         /75/
 temp_up_max_sol   "Maximum temp. in upper section with solar in"           /80/
 temp_lower_min_5  "Minimum temp. in lower section in 5 C out temp."        /35/
 temp_lower_max_5  "Maximum temp. in lower section in 5.C out temp."        /45/
 temp_lower_min_18 "Minimum temp. in lower section in 18 C out temp."       /20/
 temp_lower_max_18 "Maximum temp. in lower section in 18.C out temp."       /30/
******             preference for space heating temp
 temp_room_min     "Minimum preferred temperature indoor"                   /19/
 temp_room_max     "Maximum preferred temperature indoor"                   /24/
 temp_up_set       "Desired hot water temperature in the tank"              /60/
 temp_room_set     "Desired interior temperature"                         /21.5/
******             thermal-related specifications of house
 area_window       "Area of windows"                                         /2/
 u_walls           "Heat rate from walls"                                 /0.18/
 u_windows         "Heat rate from windows"                                /0.8/
 u_floor           "Heat rate from floor"                                  /0.1/
 u_roof            "Heat rate from roof"                                  /0.13/
 hp_up_max         "Energy consumption of upper section of HP (2.5 - 3)"   /3E3/
 hp_low_max        "Energy consumption of lower section of HP"             /2E3/
 c_water           "Heat capacity of water in Wh/kg.K"                   /1.162/
 c_air             "Heat capacity of air at 20.C & 1 atm in Wh/kg.K"     /0.279/
 rho_air           "Density of air in  kg/m^3"                           /1.225/
 u_low             "Heat rate from lower section of tank"                  /5.2/
 u_up              "Heat rate from upper section of tank"                  /1.1/
 comp_rate         "Compensation rate for prices above threshold"         /0.90/
 price_cap         "Threshold/cap price in  re/kWh"                         /73/
******             preference for EV battery level
 eta_ev            "Charging Discharging efficiency of a ES & EV"         /0.95/
 ev_min            "Minimum preferred energy of the EV"                     /30/
 ev_max            "Maximum energy of the EV"                               /70/
 ev_init           "Initial Energy of a EV at the start of the day"         /40/
 p_ev              "Power rate of the EV charger"                          /3.5/
 ev_use            "Average energy usage of the EV per a trip"               /7/
 ev_discharge_cycle"max interval for discharging per day  by manufactorer"   /4/
 ev_cap            "Battery capacity of the EV"                             /80/
 soc_set           "desired State-of-charge of the EV battery"              /60/
 
* Other required scalars:
 W /10/, S /15/, L /2.4/, dt /4/, q_loss /50/, k /2/, cap /1/

* Other parameters required for thermodynamic equations:
 area_front_back, area_side, area_floor, area_roof, volume, mass_room, mass_up, mass_low,
 height_low, height_up, area_low, area_up;

 mass_up          =    volume_up;
 mass_low         =    volume_low;
 area_front_back  =    (W * L - area_window) * 2;
 area_side        =    (S * L) * 2;
 area_floor       =    W * S;
 area_roof        =    area_floor;
 volume           =    W*S*L;
 mass_room        =    volume*rho_air;
 height_low       =    height*volume_low/(volume_low+volume_up);
 height_up        =    height*volume_up/(volume_low+volume_up);
 area_low         =    pi*diameter*height_low;
 area_up          =    pi*diameter*height_up;
 cop_up(h)        =    0.075 * temp_out(h) + 2.125;
 cop_low(h)       =    0.075 * temp_out(h) + 3.125;
 
* The Norwegian government provides a residential electricity subsidy for every hour that spot
* price exceeds 0.73 NOK/kWh (excl. VAT). Then government covers 90% of the additional cost.
 price_sub(h)     =    price_spot(h)$(price_spot(h) <= price_cap)
                       +(price_cap + (price_spot(h) - price_cap) * (1 - comp_rate))$(price_spot(h) > price_cap);

* 9. Appendix =============================================================================

*   - Appliances are divided into shiftable and non-shiftable plus power-controllable Heat Pump and Water Heater
*       Appliances Energy use data
*       Data Ref.: https://energyusecalculator.com/
*       EnLight   Daily usage of LED lightning           /8h/  /10W*5/      /0.05kW/  /0.4 kWh/
*       EnFridge  Daily usage of Refrigerator & freezer  /24h/ /100-400W/   /0.18kW/  /4.3 kWh/
*       EnStove   Daily usage of Electric stove & Oven   /3h/  /1000-3000W/ /1.5KW/   /4.5 kWh/
*       EnTV      Daily usage of TV                      /5h/  /80-120W/    /0.1kW/   /0.5 kWh/
*       EnPC      Daily usage of Computer                /2h/  /60-300W/    /0.1kW/   /0.2 kWh/
*       EnRouter  Daily usage of Router                  /24h/ /2-20W/      /0.006kW/ /0.15 kWh/
*       EnMicrow  Daily usage of Microwave               /10m/ /850-1800W/  /1.2kW/   /0.2 kWh/
*       EnCoffee  Daily usage of Coffee maker            /10m/ /300-600W/   /0.5kW/   /0.08 kWh/
*       EnDish    Daily usage of Dish Washer             /1h/  /1200-2400W/ /1.8kW/   /1.8 kWh/
*       EnLndry   Daily usage of Laundry                 /2h/  /400-1300W/  /0.6kW/   /1.2 kWh/
*       EnVacuum  Daily usage of Vacuum cleaner          /20m/ /500-30000W/ /1400kW/  /0.42 kWh/
*       EnEV      Daily usage of Slow EV charging (50%)  /6h/ /20-40kWh/    /30kWh/
*       EnPhone   Battery Capacity: 5,000 mAh  Daily required charge around 80% with a 25W charger,
*                 which takes almost one hour at average power consumption of 15-18,
*                 with the addition of other wearable devices it consumes around /0.02 kWh/ at the power of /0.02 kW/
*       Tesla Model3 has a range of 500 km and battery size of 75 kWh.
*                 It is assumed that EV is used after work for an afternoon ride after 5PM.
*                 Assumed daily usage is almost 45 km and 7 kWh/day.
*                 Standard charger home charging provides 7 kW and do the full charge of this car at 10 hours.
*                 Assumed 7 kWh takes almost 1 hours to charge.
*       Skoda Enyaq 80 (replaced EV in the new model) stats are different
*                 The battery for any EV is going to be happiest between 40 to 60% and that is the recommendation for when you're not going to be driving the car for a long period of time.14 Jun 2023

*   - Ref for other data:
*       Elec. price( re/kWh) and weather forecast( C) in East-Oslo on 17-02-2024
*       Meteorologisk institutt (MET)
*       ENTESOE electrifying europe for Day-ahead prices in NO1
*       Rooftop solar installation: 43 panels, each 380w and in total 17 kW of capacity

*   - Heat Transfer Mechanism:
*       The lower tank provides heat to the room when the heating system is active.
*       When  alpha_room(t) is active, heat is transferred from the lower tank to the room.

*   - Indoor temperature:
*       Ideal indoor temperature for a house during winter time generally falls
*       within the range of 68 F to 72 F (20 C to 22 C).

*    -Self-Consumption: The percentage of solar energy produced that is directly
*                       used by the household rather than being exported to the grid.
*    -Self-Sufficiency: The percentage of the household's total energy consumption
*                       that is met by solar energy produced onsite.
* =========================================================================================

