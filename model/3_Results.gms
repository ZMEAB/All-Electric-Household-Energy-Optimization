* ========================================================================================
* MODULE 3: EXECUTION, OPTIMIZATION & VISUALIZATION

* This module performs the sequential Lexicographic solve to balance cost and 
* comfort. It handles post-processing, GDX data export, and generates Python
* and GDX visualizations for the 6 core result categories.
* -----------------------------------------------------------------------------------------

* 4. SEQUENTIAL MULTI-OBJECTIVE OPTIMIZATION (LEXICOGRAPHIC LVL.1)=========================

* LEVEL 1: PRIMARY OBJECTIVE (COST MINIMIZATION)
* In this first stage, the model identifies the absolute minimum electricity bill 
* by shifting flexible loads to low-price periods and maximizing PV 
* self-consumption. Comfort is maintained within loose technical bounds.

Model      lexico_lv1 /cost_def,power_balance_def, export_def, selfcons_def, peak_lb, peak_ub, peak_unique, tariff_def, seg_lo1, seg_lo2, seg_lo3, seg_lo4, seg_lo5,
 seg_up1, seg_up2, seg_up3, seg_up4, seg_up5, seg_one, power_balance, sh_duration, grid_imp_cap, grid_exp_cap, start_time_pref, finish_time_pref, max_hp_lower_c,
 max_hp_upper_c, one_mode_c, max_heat_in_lower_c, max_heat_in_upper_c, usage_c, heat_loss_lower_c, heat_loss_upper_c, heat_loss_room_c, energy_lower_c,
 energy_upper_c, energy_room_c,heatbalance_lower_c,heatbalance_upper_c,heatbalance_room_c,temp_upper_slack_min,temp_upper_slack_max,temp_upper_slk_max_sol,
 temp_room_slack_min, temp_room_slack_max, temp_lower_slack_min_5, temp_lower_slack_max_5, temp_lower_slack_min_5_18, temp_lower_slack_max_5_18,
 temp_lower_slack_min_18, temp_lower_slack_max_18, temp_room_l, temp_limit, heat_in_room_max, heat_in_room_min, ev_balance, ev_charge_coord, ev_dicharge_limt, soc_def/;
 
Option     SYSOUT = ON;
Option     MIP=CPLEX;
Option     optca=0 , optcr=0;
Solve      lexico_lv1 using MIP minimizing cost_total;


* 5. POST-OPTIMIZATION ANALYSIS ===========================================================


* Performance Logging: Level 1 (Cost Optimization)
display "LEVEL 1: ECONOMIC OPTIMIZATION COMPLETE";
display "Execution Time (sec):", lexico_lv1.resusd;
display "Iteration Count:     ", lexico_lv1.iterusd;
display "Model Status (1=Opt):", lexico_lv1.modelstat;
display "Solver Status:       ", lexico_lv1.solvestat;

DISPLAY    cost_total.l, p_self.l,fee_grid_m.l,price_spot,pv_gen,p_total.l,p_imp.l,
p_exp.l,sh_on.l,profile_nsh,peak_on.l,seg1.l,seg2.l,seg3.l,seg4.l,seg5.l,hp_low.l, hp_up.l, temp_low.l,
temp_up.l, temp_room.l, loss_up.l ,loss_low.l,loss_room.l,
alpha_room.l, alpha_up.l, alpha_low.l, heat_in_room.l, gama_ch.l, gama_dch.l,soc.l,ev_energy.l, temp_out;

* -----------------------------------------------------------------------------------------
* Post-solve validation Lexicographic level 1

display Lexico_lv1.modelstat, Lexico_lv1.solvestat;

if (Lexico_lv1.modelstat ne 1,
   display "ERROR: Lexico1 not optimal.";
   abort "Stopping execution: Lexico1 failed.";
);

* Grid capacity validation

scalar grid_violation;

grid_violation = smax(h, p_imp.l(h) - grid_cap);

display grid_violation;

if (grid_violation > 1e-6,
   display "ERROR: Grid import exceeds maximum.";
   display p_imp.l;
   abort "Stopping execution: Grid constraint violated.";
);

* Power balance consistency check

parameter power_balance_check(h);

power_balance_check(h) =
      p_imp.l(h)
    + p_self.l(h)
    - p_total.l(h);

display power_balance_check;

scalar power_balance_max;

power_balance_max = smax(h, abs(power_balance_check(h)));

display power_balance_max;

if (power_balance_max > 1e-5,
   display "ERROR: Power balance not satisfied.";
   abort "Stopping execution: Power balance inconsistency detected.";
);

display "LEXICOGRAPHIC OPTIMIZATION LVL1 VALIDATION PASSED.";

* -----------------------------------------------------------------------------------------
* Measure comfort in first layer before optimizing it

Parameters
  Comf_ave_indx_room_L1  "Average room temperature comfort index at Lv1"
  Comf_ave_indx_up_L1    "Average upper tank temperature comfort index at Lv1"
  Comf_ave_indx_ev_L1    "Average EV SOC comfort index at Lv1"
  Comf_all_L1            "Aggregated overall comfort index at Lv1"
  Buy                    "Total energy purchased cost at Lv1"
  Sell                   "Total energy sold revenue at L1"         
;

  Comf_ave_indx_room_L1 = sum(h, ( 1- abs(temp_room.l(h) - temp_room_set) /(23 - 20) ))/24;
  Comf_ave_indx_up_L1   = sum(h, ( 1- abs(temp_up.l(h) - temp_up_set) /(70 - (50)) ))/24;    
  Comf_ave_indx_ev_L1   = sum(h, ( 1- abs(soc.l(h)-soc_set) /(80-20) ))/24;
  
  Comf_all_L1 = Comf_ave_indx_room_L1$(heat_space_on) + Comf_ave_indx_up_L1 + Comf_ave_indx_ev_L1;

  Buy   = (sum (h, p_imp.l(h)*( price_sub(h) + fee_energy + fee_grid_night$(ord(h) lt 7) + fee_grid_day$(ord(h) gt 8))) + ((fee_energy_m + fee_grid_m.l)/30)) * (1+vat);
  Sell =  sum (h, p_exp.l(h)*( price_spot(h) + fee_grid_exp) );

DISPLAY  '******',Buy,Sell, Comf_all_L1 ,Comf_ave_indx_room_L1, Comf_ave_indx_up_L1, Comf_ave_indx_ev_L1;


* * 6. SEQUENTIAL MULTI-OBJECTIVE OPTIMIZATION (LEXICOGRAPHIC LVL.2) ======================

Scalar cost_total_star "Saving the optimal value of first level objective function";
                       cost_total_star = cost_total.l;

* Resetting the variables to zero
temp_low.l(h) = 0;    temp_up.l(h) = 0;     temp_room.l(h) = 0;
loss_low.l(h) = 0;    loss_up.l(h) = 0;     loss_room.l(h) = 0;
heat_low.l(h) = 0;    heat_up.l(h) = 0;     heat_room.l(h) = 0;
alpha_low.l(h) = 0;   alpha_up.l(h) = 0;    alpha_room.l(h) = 0;
heat_in_low.l(h)= 0;  heat_in_up.l(h)= 0;   heat_in_room.l(h)= 0;
hp_low.l(h) = 0;      hp_up.l(h) = 0;       
peak.l = 0;           fee_var.l = 0;        fee_fixed.l = 0;    fee_grid_m.l = 0;
peak_active.l(h) = 0; seg1.l = 0; seg2.l = 0;  seg3.l = 0; seg4.l = 0; seg5.l = 0;
p_total.l(h) = 0;     p_imp.l(h) = 0;       p_exp.l(h) = 0;      p_self.l(h) = 0;
ev_energy.l(h) = 0;   soc.l(h) = 0;         gama_ch.l(h) = 0;    gama_dch.l(h) = 0;
sh_on.l(j,h) = 0;
;

* Sequential multi-objective optimization  
comfort_def       ..  comfort_total =e= Comf_ave_indx_room$(heat_space_on) + Comf_ave_indx_up + Comf_ave_indx_ev;

constraint_lexico ..  ((( sum (h, p_imp(h)*( price_sub(h) + fee_energy + fee_grid_night$(ord(h) lt 7) + fee_grid_day$(ord(h) gt 8) )) + ((fee_energy_m + fee_grid_m)/30)) * (1+vat))
                     -(sum (h, p_exp(h)*( price_spot(h) - fee_grid_exp) ) )) =l=  cost_total_star ;    
  
*                               Comf_ave_indx_room =e= sum(h, ( 1- abs(temp_room(h) - temp_room_set) /(23 - 20) ))/24;
comfort_room$(heat_space_on) .. Comf_ave_indx_room =e= sum(h, ( 1- (dev_room_pos(h) + dev_room_neg(h)) / (23 - 20))) / 24; 

*                        Comf_ave_indx_up =e= sum(h, ( 1- abs(temp_up(h) - temp_up_set) /(70 - (50)) ))/24;
comfort_up           ..  Comf_ave_indx_up =e= sum(h, ( 1- (dev_up_pos(h) + dev_up_neg(h)) / (70 - 50))) / 24;
    
*                        Comf_ave_indx_ev =e= sum(h, ( 1- abs(soc(h)-soc_set) /(80-20) ))/24;  
comfort_ev           ..  Comf_ave_indx_ev =e= sum(h$(ev_avail(h) ne 0), ( 1- (dev_soc_pos(h) + dev_soc_neg(h)) / (80 - 20))) / sum(h,ev_avail(h));

absolute_pos_room(h) ..  dev_room_pos(h)  =g= temp_room(h) - temp_room_set;
absolute_neg_room(h) ..  dev_room_neg(h)  =g= temp_room_set - temp_room(h);

absolute_pos_up(h)   ..  dev_up_pos(h)    =g= temp_up(h) - temp_up_set;
absolute_neg_up(h)   ..  dev_up_neg(h)    =g= temp_up_set - temp_up(h);

absolute_pos_soc(h)  ..  dev_soc_pos(h)   =g= soc(h) - soc_set;
absolute_neg_soc(h)  ..  dev_soc_neg(h)   =g= soc_set - soc(h);

* -----------------------------------------------------------------------------------------

* LEVEL 2: SECONDARY OBJECTIVE (COMFORT MAXIMIZATION)
* Keeping the cost at the previously found minimum, the model now adjusts the 
* thermal setpoints and EV charging schedules to maximize the 'Comfort Index.'
* This eliminates unnecessary discomfort caused by price-chasing.

Model      lexico_lv2 /comfort_def, constraint_lexico, comfort_room, comfort_up, comfort_ev, power_balance_def, export_def, selfcons_def, peak_lb, peak_ub, peak_unique, tariff_def,
 seg_lo1, seg_lo2, seg_lo3, seg_lo4, seg_lo5, seg_up1, seg_up2, seg_up3, seg_up4, seg_up5, seg_one, power_balance, sh_duration, grid_imp_cap, grid_exp_cap,
 start_time_pref, finish_time_pref, max_hp_lower_c, max_hp_upper_c, one_mode_c, max_heat_in_lower_c, max_heat_in_upper_c, usage_c, heat_loss_lower_c,
 heat_loss_upper_c, heat_loss_room_c, energy_lower_c, energy_upper_c, energy_room_c, heatbalance_lower_c, heatbalance_upper_c, heatbalance_room_c,
 temp_upper_slack_min, temp_upper_slack_max, temp_upper_slk_max_sol, temp_room_slack_min, temp_room_slack_max, temp_lower_slack_min_5,temp_lower_slack_max_5,
 temp_lower_slack_min_5_18, temp_lower_slack_max_5_18, temp_lower_slack_min_18, temp_lower_slack_max_18, temp_room_l, temp_limit, heat_in_room_max,
 heat_in_room_min, ev_balance, ev_charge_coord, ev_dicharge_limt, soc_def, absolute_pos_room,absolute_pos_up,absolute_pos_soc,absolute_neg_room,absolute_neg_up,absolute_neg_soc/;

Option     SYSOUT = ON;
Option     MIP=CPLEX;
Option     optca=0 , optcr=0;
Solve      lexico_lv2 using MIP maximizing comfort_total;

* 7. POST-OPTIMIZATION ANALYSIS ===========================================================



* Performance Logging: Level 2 (Comfort Optimization)
display "LEVEL 2: COMFORT OPTIMIZATION COMPLETE";
display "Execution Time (sec):", lexico_lv2.resusd;
display "Iteration Count:     ", lexico_lv2.iterusd;
display "Model Status (1=Opt):", lexico_lv2.modelstat;
display "Solver Status:       ", lexico_lv2.solvestat;

* -----------------------------------------------------------------------------------------
* Post-solve validation Lexicographic level 2

display lexico_lv2.modelstat, lexico_lv2.solvestat;

if (lexico_lv2.modelstat ne 1,
   display "ERROR: Lexico2 not optimal.";
   abort "Stopping execution: Lexico2 failed.";
);

scalar temp_violation;

temp_violation = smin(h, temp_up.l(h) - temp_up_min);

display temp_violation;

if (temp_violation < -0.5,
   display "ERROR: Upper tank temperature below minimum.";
   display temp_up.l;
   abort "Stopping execution: Temperature violation.";
);

display "LEXICOGRAPHIC OPTIMIZATION LVL2 VALIDATION PASSED.";

* -----------------------------------------------------------------------------------------

Parameter
  Solar_inc    "Pure revenue from solar generation"
  Solar_tot    "Total Solar generation over 24 hour in kWh"
  Solar_used   "Produced solar energy that is consumed by the household per hour"
  Buy_tot      "Total import over 24 hour in kWh"
  Sell_tot     "Total export over 24 hour in kWh"
  Demand_tot   "Total demand consumption over 24 hour in kWh"
  Self_Cons    "Self-consumption of solar installation over 24 hours in %"
  Self_Suff    "Self-sufficiency of solar installation over 24 hours in %"
;  
  Solar_inc     =  ((sum (h, pv_gen(h)/1000*(price_spot(h))+pv_gen(h)/1000*(fee_grid_exp))+(fee_energy_m/30)));

  Solar_tot    =  Sum(h, pv_gen(h)/1000 );
  
  Buy_tot      =  Sum(h, p_imp.l(h));
  
  Sell_tot     =  Sum(h, p_exp.l(h));

  Demand_tot   =  sum(h, p_total.l(h));

  Solar_used(h)=  min( p_total.l(h), (pv_gen(h)/1000) );

  Self_Cons    =  100 * ( sum(h, solar_used(h))) / solar_tot  ;

  Self_suff    =  100 * ( sum(h, solar_used(h))) / demand_tot ;
  
* -----------------------------------------------------------------------------------------

DISPLAY '***********************************************************************',
cost_total.l, comfort_total.l, Comf_ave_indx_room.l ,Comf_ave_indx_up.l, Comf_ave_indx_ev.l,
Solar_tot,Buy_tot, Sell_tot, Demand_tot,self_cons,Self_suff,
'-----------------------------------------------------------------------------',
p_self.l,Solar_inc, fee_grid_m.l,p_self.l,price_spot,pv_gen,p_total.l,p_imp.l, p_exp.l,sh_on.l,profile_nsh,peak_active.l,
seg1.l,seg2.l,seg3.l,seg4.l,seg5.l,hp_low.l, hp_up.l, temp_low.l,temp_up.l, temp_room.l, loss_up.l ,loss_low.l,loss_room.l,
cost_total_star, alpha_room.l, alpha_up.l, alpha_low.l, heat_in_room.l, gama_ch.l, gama_dch.l,soc.l,ev_energy.l, temp_out,
dev_room_pos.l,dev_room_neg.l,dev_up_pos.l,dev_up_neg.l,dev_soc_pos.l,dev_soc_neg.l;

* -----------------------------------------------------------------------------------------

*  Cumulative Performance Summary 
Scalar total_opt_time "Total time spent on both optimization layers (seconds)";
total_opt_time = lexico_lv1.resusd + lexico_lv2.resusd;

display "TOTAL OPTIMIZATION PERFORMANCE SUMMARY";
display "Total Combined Solve Time (sec):", total_opt_time;

* * 8. POST-OPTIMIZATION ANALYSIS ==========================================================

* DATA EXPORT: GDX GENERATION 
* Save full workspace and specific result sets
execute_unload "AllResults.gdx";
execute_unload "MainResults.gdx", 
    temp_out, pv_gen, price_spot, ev_avail, hw_demand, 
    temp_up, temp_low, temp_room, hp_up, hp_low, 
    ev_energy, P_total, P_imp, P_exp;

* Force GAMS Studio to open the GDX file as a new tab
execute 'shell execute MainResults.gdx';

* -----------------------------------------------------------------------------------------

* PYTHON link for drawing outputs

* FIGURE 1: INPUT PROFILES (Weather, Price, and PV)
File data_out / 'temp_plot_data.txt' /;
put data_out; loop(h, put h.tl, " ", temp_out(h), " ", pv_gen(h), " ", price_spot(h) /; );
putclose;

File py_plot / 'show_plot.py' /;
put py_plot;
put "import matplotlib.pyplot as plt" /;
put "hours, temps, pvs, prices = [], [], [], []" /;
put "with open('temp_plot_data.txt', 'r') as f:" /;
put "    for line in f:" /;
put "        parts = line.split(); hours.append(parts[0]); temps.append(float(parts[1])); pvs.append(float(parts[2])); prices.append(float(parts[3]))" /;
put "plt.rcParams['font.family'] = 'serif'" /;
put "fig, ax1 = plt.subplots(figsize=(12,7))" /;
put "ax1.set_xlabel('Time (Hour)', fontweight='bold'); ax1.set_ylabel('Temp (°C) & Price (øre/kWh)', fontweight='bold')" /;
put "ax1.bar(hours, temps, color='royalblue', alpha=0.8, label='Outdoor Temp (°C)')" /;
put "ax1.plot(hours, prices, 'g-o', linewidth=2, label='Spot Price (øre/kWh)')" /;
put "ax2 = ax1.twinx()" /;
put "ax2.set_ylabel('Solar PV Power (kW)', fontweight='bold', color='black')" /;
put "ax2.plot(hours, pvs, color='orange', linewidth=3, label='Solar PV (kW)')" /;
put "plt.title('Energy Management System: Input Profiles', fontweight='bold')" /;
put "plt.text(0.98, 0.95, 'Sample Day: %month_name%', transform=ax1.transAxes, ha='right', va='top', fontweight='bold', bbox=dict(facecolor='white', alpha=0.7))" /;
put "ax1.grid(True, which='both', linestyle=':', alpha=0.6); ax1.minorticks_on()" /;
put "fig.legend(loc='upper left', bbox_to_anchor=(0.02, 0.95), frameon=True)" /;
put "plt.tight_layout(); plt.show()" /;
putclose;

* FIGURE 2: THERMAL RESULTS (Water Tanks & Indoor Comfort)
File thermal_data /'thermal_res.txt'/;
put thermal_data; loop(h, put h.tl, " ", temp_up.l(h):0:2, " ", temp_low.l(h):0:2, " ", temp_room.l(h):0:2 /; );
putclose;

File py_thermal /'plot_thermal.py'/;
put py_thermal;
put "import matplotlib.pyplot as plt" /;
put "hours, tup, tlow, troom = [], [], [], []" /;
put "with open('thermal_res.txt', 'r') as f:" /;
put "    for line in f:" /;
put "        parts = line.split(); hours.append(parts[0]); tup.append(float(parts[1])); tlow.append(float(parts[2])); troom.append(float(parts[3]))" /;
put "plt.rcParams['font.family'] = 'serif'" /;
put "fig, ax1 = plt.subplots(figsize=(12,7))" /;
put "ax1.plot(hours, tup, 'r-', linewidth=2, label='Upper Tank Temp (°C)')" /;
put "ax1.plot(hours, tlow, 'b-', linewidth=2, label='Lower Tank Temp (°C)')" /;
put "ax1.set_ylabel('Water Tanks (°C)', fontweight='bold')" /;
put "ax2 = ax1.twinx()" /;
put "ax2.plot(hours, troom, 'k--', linewidth=3, label='Room Temp (°C)')" /;
put "ax2.set_ylabel('Indoor Room (°C)', fontweight='bold', color='black')" /;
put "plt.title('Thermal Results: Water Tank vs Indoor Temperature', fontweight='bold')" /;
put "ax1.grid(True, linestyle=':'); fig.legend(loc='upper center', ncol=3, frameon=True)" /;
put "plt.tight_layout(); plt.show()" /;
putclose;

* FIGURE 3: ENERGY DEMAND BREAKDOWN (Stacked Bars + Total Load Line)
File py_demand / 'res_appliances.py' /;
put py_demand;
put "import matplotlib.pyplot as plt; import numpy as np" /;
put "h = [f'h{i}' for i in range(1,25)]" /;
put "hp_u = np.array([" /; loop(h, put (hp_up.l(h)/1000):0:4, ","); put "])" /;
put "hp_l = np.array([" /; loop(h, put (hp_low.l(h)/1000):0:4, ","); put "])" /;
put "ev   = np.array([" /; loop(h, put (ev_energy.l(h)/1000):0:4, ","); put "])" /;
put "p_tot = np.array([" /; loop(h, put P_total.l(h):0:4, ","); put "])" /;
put "plt.rcParams['font.family'] = 'serif'" /;
put "fig, ax = plt.subplots(figsize=(12,7))" /;
put "ax.bar(h, hp_u, label='HP Upper (kW)', color='skyblue', edgecolor='white')" /;
put "ax.bar(h, hp_l, bottom=hp_u, label='HP Lower (kW)', color='steelblue', edgecolor='white')" /;
put "ax.bar(h, ev, bottom=hp_u+hp_l, label='EV Charging (kW)', color='lightgreen', edgecolor='white')" /;
put "ax.plot(h, p_tot, 'k-o', linewidth=2, markersize=4, label='Total Demand (P-total)')" /;
put "ax.set_ylabel('Power Demand (kW)', fontweight='bold')" /;
put "ax.set_xlabel('Time (Hour)', fontweight='bold')" /;
put "plt.title('Total Demand vs Thermal & E-mobility Breakdown', fontweight='bold')" /;
put "plt.legend(loc='upper right', frameon=True); plt.grid(axis='y', linestyle=':', alpha=0.7)" /;
put "plt.tight_layout(); plt.show()" /;
putclose;

* FIGURE 4: GRID INTERACTION (Import / Export Balance)
File py_grid / 'res_grid.py' /;
put py_grid;
put "import matplotlib.pyplot as plt" /;
put "h = [f'h{i}' for i in range(1,25)]" /;
put "p_tot = [" /; loop(h, put P_total.l(h):0:2, ","); put "]" /;
put "p_imp = [" /; loop(h, put P_imp.l(h):0:2, ","); put "]" /;
put "p_exp = [" /; loop(h, put P_exp.l(h):0:2, ","); put "]" /;
put "plt.rcParams['font.family'] = 'serif'" /;
put "plt.figure(figsize=(12,7))" /;
put "plt.plot(h, p_tot, 'k-', label='Total Load', linewidth=2)" /;
put "plt.step(h, p_imp, 'g-', where='mid', label='Grid Import')" /;
put "plt.step(h, p_exp, 'r-', where='mid', label='Grid Export')" /;
put "plt.axhline(0, color='black', linewidth=1)" /;
put "plt.ylabel('Power (kW)', fontweight='bold'); plt.xlabel('Time (Hour)', fontweight='bold')" /;
put "plt.title('Grid Interaction: Import vs Export', fontweight='bold')" /;
put "plt.legend(); plt.grid(True, linestyle=':'); plt.tight_layout(); plt.show()" /;
putclose;

* EXECUTION PHASE: LAUNCH SIMULTANEOUS POP-UPS
execute 'start /b python show_plot.py';
execute 'start /b python plot_thermal.py';
execute 'start /b python res_appliances.py';
execute 'start /b python res_grid.py';
