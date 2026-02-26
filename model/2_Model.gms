* ========================================================================================
* MODULE 2: MATHEMATICAL FORMULATION & PHYSICS

* This module defines the household energy system's decision variables and 
* constraints. It models the thermodynamic energy balance of the appliances, 
* Heat Pump Water Heater (HPWH) dynamics, and EV battery state-of-charge logic.
* -----------------------------------------------------------------------------------------

* 3. OPTIMIZATION MODEL VARIABLES AND EQUATIONS ===========================================

* MODEL VARIABLES
* All variables, positive, and binary and the intitral values.

VARIABLES
  cost_total           "Objective function1: Total combined energy cost"
  comfort_total        "Objective function2: Comfort indices"
  temp_low             "Temperature in the lower section"
  temp_up              "Temperature in the upper section"
  temp_room            "Temperature in the room (indoor space)"
  heat_in_low          "Energy injected in the lower section"
  heat_in_up           "Energy injected in the upper section"
  loss_low             "Heat transfer from the lower section"
  loss_up              "Heat transfer from the upper section"
  loss_room            "Heat transfer from Room to ambient environment"
  heat_low             "Internal energy in lower section"
  heat_up              "Internal energy in upper section"
  heat_room            "Internal energy in room (indoor space)"
  comf_ave_indx_room   "Average comfort index of indoor room temperature"
  comf_ave_indx_up     "Average comfort index of upper water tank temperature"
  comf_ave_indx_ev     "Average comfort index of EV state-of-charge (SOC) n"
;

POSITIVE VARIABLES
  peak                 "peak power during a day"
  fee_var              "Variable fee - Energy component"
  fee_fixed            "Power component (NOK/month)"
  p_total              "Overall hourly power consumption household energy profile"
  fee_grid_m           "Monthly Add-on for Grid Supplier; 125,200,325,.... (table) NOK/month"
  hp_low               "Energy consumed by lower section in each time interval"
  hp_up                "Energy consumed by upper section in each time interval"
  heat_in_room         "Energy injected in the room"
  p_imp                "Power imported from the grid"
  p_exp                "Power exported to the grid"
  p_self               "Produced solar energy that is consumed by the household"
  ev_energy            "Energy of the EV"
  soc
* Deviation variables for room temperature, upper temperature, and SOC in absolute function
  dev_room_pos(h), dev_room_neg(h)  
  dev_up_pos(h), dev_up_neg(h)  
  dev_soc_pos(h), dev_soc_neg(h)
;

BINARY VARIABLES
  sh_on(j,h)           "Allocated time for a shiftable appliance j"
  peak_on(h)           "Auxiliary binary variable for linearization"
  seg1                 "Auxiliary binary variables for linearization"
  seg2,seg3,seg4,seg5
  peak_active(h)       "Peak-demand activation status at time h for tariff segment determination"

  alpha_low(h)         "Controls On/Off variable for lower section- hp_lower_on"
  alpha_up(h)          "Controls On/Off variable for upper section- hp_upper_on"
  alpha_room(h)        "Controls On/Off setting for space heating system- heat_room_on"
  gama_ch(h)           "Charging state of the EV"
  gama_dch(h)          "Discharging state of the EV"
;

* Initial values at t1
  temp_low.l('h1')$(heat_space_on)     = (temp_lower_min_5 + temp_lower_max_5)/2;
  temp_low.fx('h1')$(heat_space_on)    = (temp_lower_min_5 + temp_lower_max_5)/2;
  temp_up.fx('h1')                     = (temp_up_min + temp_up_max)/2;
  temp_room.up('h1')$(heat_space_on)   = (temp_room_min  + temp_room_max)/2;
  alpha_room.fx(h)$(heat_space_on = 0) = 0;
  alpha_low.fx(h)$(heat_space_on = 0)  = 0;
  hp_low.fx(h)$(heat_space_on = 0)     = 0;
    
  ev_energy.up(h)     = ev_max;
  ev_energy.lo(h)     = ev_min;
  ev_energy.lo('h24') = (1.3)*ev_min;
  ev_energy.lo(h)$(ev_avail(h) eq 1 and ev_avail(h+1) eq 0) = (1.3)*ev_min;
    
  gama_ch.fx(h)$(ev_avail(h) = 0)  = 0;
  gama_dch.fx(h)$(ev_avail(h) = 0) = 0;
  gama_ch.l(h)$((ev_avail(h) = 1) and (pv_gen(h) > 0)) = 1;
  
* -----------------------------------------------------------------------------------------

* GENERAL OPTIMIZATION LOGIC
* The simulation employs Mixed-Integer Linear Programming (MILP). It linearizes absolute
* temperature deviations into comfort indicators as well as EV battery SOC deviations,
* ensuring a robust and computationally efficient solution for day-ahead scheduling.

* OPTIMIZATION STRATEGY: LEXICOGRAPHIC APPROACH
* The simulation uses sequential layers to ensure that higher-priority goals 
* (like cost) are not sacrificed when improving lower-priority goals (comfort).

EQUATIONS
   cost_def               "Objective Function for daily energy cost of household"
   comfort_def            "Objective Function for comfort indicators integration"
   power_balance_def      "Overall consumed power at each hour"
   export_def             "Exported power to the grid"
   selfcons_def           "Self-consumed solar energy by the household"
   peak_lb                "peak is at least the lower bound of each segment if active"
   peak_ub                "peak is at most the upper bound of each segment if active"
   peak_unique            "Only one segment is active at a time"
   tariff_def             "Fixed component of the energy consumption cost"
   seg_lo1                "peak falls within the segments for 0-2KW levels "
   seg_lo2,seg_lo3,seg_lo4,seg_lo5
   seg_up1                "peak falls within exactly one of segments for levels 2-5KW,5-10,10-15,15-20"
   seg_up2,seg_up3,seg_up4,seg_up5
   seg_one                "Only one segment is active at a time"
   power_balance          "Power balance at each interval"
   sh_duration            "Usage time limitation of shiftable appliances"
   grid_imp_cap           "peak load limitation for fuse and line connecting to the grid"
   grid_exp_cap           "peak load limitation for fuse and line connecting to the grid"
   start_time_pref        "Preferred starting time constraint of shiftable appliances"
   finish_time_pref       "Preferred finishing time constraint of shiftable appliances"
   
   max_hp_lower_c         "Operation status of HP in lower section"
   max_hp_upper_c         "Operation status of HP in upper section"
   one_mode_c             "NAND constraint to select only one of the two operating HP modes"
   max_heat_in_lower_c    "Transform of electrical energy to heat in lower section"
   max_heat_in_upper_c    "Transform of electrical energy to heat in upper section"
   usage_c                "Hot water usage for shower and faucet"
   heat_loss_lower_c      "Heat loss from lower section to outside environment"
   heat_loss_upper_c      "Heat loss from upper section to outside environment"
   heat_loss_room_c       "Heat loss from room to outside environment"
   energy_lower_c         "Lower section heat energy based on the temperature"
   energy_upper_c         "Upper section heat energy based on the temperature"
   energy_room_c          "Room heat energy based on the temperature"
   heatbalance_lower_c    "Heat energy balance for lower section"
   heatbalance_upper_c    "Heat energy balance for upper section"
   heatbalance_room_c     "Heat energy balance for room"
   temp_upper_slack_min   "Minimum allowed temp. in upper section to be below predefined limits"
   temp_upper_slack_max   "Maximum allowed temp. in upper section to be below predefined limits"
   temp_upper_slk_max_sol "Maximum allowed temp. in upper section while having solar in"
   temp_room_slack_min    "Minimum allowed temp. in room to be below predefined limits"
   temp_room_slack_max    "Maximum allowed temp. in room to be below predefined limits"
*  "The operating temperature limits in the Lower/upper section in 5 & 18.C"
   temp_lower_slack_min_5   , temp_lower_slack_max_5
   temp_lower_slack_min_5_18, temp_lower_slack_max_5_18
   temp_lower_slack_min_18  , temp_lower_slack_max_18
   temp_room_l            "Starting temperature of room"
   temp_limit             "Maximum temperature jump for the room"
   heat_in_room_max       "Control the room heating variable based on binary variable"
   heat_in_room_min       "Control the room heating variable based on binary variable"
   
   ev_balance             "Energy level constraint for EV"
   ev_charge_coord        "Constraint for charge or discharge status of EV"
   ev_dicharge_limt       "Constraint for max number of charge and discharge of EV per day"
*  coChrg3                "Constraint for min number of charge and discharge of EV per day"

   constraint_lexico      "Constraint for consideration of minimum cost in the second layer of optimization"
   soc_def                "Calculate State of Charge of the EV in percent"
   comfort_room           "Constraint for Average Comfort index for room temperature"
   comfort_up             "Constraint for Average Comfort index for hot water temperature"
   comfort_ev             "Constraint for Average Comfort index for EV level of battery"
   absolute_pos_room(h)   "Absolute Value Constraints for room temperature"
   absolute_neg_room(h)   "Absolute Value Constraints for room temperature"
   absolute_pos_up(h)     "Absolute Value Constraints for upper temperature"
   absolute_neg_up(h)     "Absolute Value Constraints for upper temperature"
   absolute_pos_soc(h)    "Absolute Value Constraints for SOC"
   absolute_neg_soc(h)    "Absolute Value Constraints for SOC"
;


cost_def       .. cost_total =e=
                  (  ( sum (h, p_imp(h)*( price_sub(h) + fee_energy + fee_grid_night$(ord(h) lt 7) + fee_grid_day$(ord(h) gt 8) )) + ((fee_energy_m + fee_grid_m)/30)) * (1+vat) )
                  - ( sum (h, p_exp(h)*( price_spot(h) - fee_grid_exp) )  );

power_balance_def(h)      .. p_total(h) =e=
                  sum(i, profile_nsh(i,h)*energy_nsh(i)/dur_nsh(i))/1000  +  sum(j, sh_on(j,h)*energy_sh(j)/dur_sh(j))/1000
                  +  (hp_low(h) + hp_up(h))/1000
                  +  (p_ev*gama_ch(h))$(ev_avail(h)=1) ;               

seg_lo1        .. peak =g= small_m*seg1;
seg_lo2        .. peak =g= 2*seg2;
seg_lo3        .. peak =g= 5*seg3;
seg_lo4        .. peak =g= 10*seg4;
seg_lo5        .. peak =g= 15*seg5;
seg_up1        .. peak =l= 2*seg1 + big_m*(1 - seg1);
seg_up2        .. peak =l= 5*seg2 + big_m*(1 - seg2);
seg_up3        .. peak =l= 10*seg3 + big_m*(1 - seg3);
seg_up4        .. peak =l= 15*seg4 + big_m*(1 - seg4);
seg_up5        .. peak =l= 20*seg5 + big_m*(1 - seg5);

seg_one        .. seg1 + seg2 + seg3 + seg4 + seg5 =e= 1;

tariff_def     .. fee_grid_m =e=  tariff_1*seg1 + tariff_2*seg2 + tariff_3*seg3 + tariff_4*seg4 + tariff_5*seg5;

peak_lb(h)     .. peak =g= p_imp(h);

peak_ub(h)     .. peak =l= p_imp(h) + big_m*(1 - peak_on(h));

peak_unique    .. sum(h, peak_on(h)) =e= 1;

power_balance(h) .. p_imp(h) + p_self(h) =e= p_total(h);

export_def(h)    .. p_exp(h) =e=  (pv_gen(h)/1000) + (p_ev*gama_dch(h))$(ev_avail(h)=1) - p_self(h);

selfcons_def(h)  .. p_self(h) =l=  (pv_gen(h)/1000) + (p_ev*gama_dch(h))$(ev_avail(h)=1);
* The balance is checked via results and it is working 
grid_imp_cap(h)  .. p_imp(h) =l= grid_cap ;
grid_exp_cap(h)  .. p_exp(h) =l= grid_cap ;

sh_duration(j)   .. sum(h, sh_on(j,h)) =e= dur_sh(j);

start_time_pref(j,h)$(ord(h) lt  start_pref(j))   ..  sh_on(j,h) =e= 0;

finish_time_pref(j,h)$(ord(h) gt  finish_pref(j)) ..  sh_on(j,h) =e= 0;

temp_room_l(h)$((ord(h) = 1) and (heat_space_on)) .. temp_room(h)  =e= (temp_room_min + temp_room_max)/2;

temp_upper_slack_min(h)$(ord(h) > 1)   .. temp_up(h) =G= temp_up_min ;

temp_upper_slack_max(h)$((ord(h)>1) and (pv_gen(h)<=0)).. temp_up(h) =L= temp_up_max;

temp_upper_slk_max_sol(h)$(pv_gen(h)>0).. temp_up(h) =L= temp_up_max_sol;

temp_room_slack_min(h)$((ord(h) > 1) and (heat_space_on)) .. temp_room(h) =G= temp_room_min;

temp_room_slack_max(h)$((ord(h) > 1) and (heat_space_on)) .. temp_room(h) =L= temp_room_max;

temp_lower_slack_min_5(h)$ ((temp_out(h) < -5) and (ord(h) > 1) and (heat_space_on))
                                       ..   temp_low(h) =G= temp_lower_min_5;

temp_lower_slack_min_5_18(h)$((temp_out(h) >=-5) and (temp_out(h) <=18) and (ord(h) > 1) and (heat_space_on))
                                       ..   temp_low(h)=G= temp_lower_min_5 - (15/23)*temp_out(h);

temp_lower_slack_min_18(h)$((temp_out(h) > 18) and (ord(h) > 1) and (heat_space_on))
                                       ..   temp_low(h) =G= temp_lower_min_18;

temp_lower_slack_max_5(h)$((temp_out(h) < -5) and (ord(h) > 1) and (heat_space_on))
                                       ..   temp_low(h) =L= temp_lower_max_5;

temp_lower_slack_max_5_18(h)$((temp_out(h) >=-5) and (temp_out(h) <=18) and (ord(h) > 1) and (heat_space_on))
                                       ..   temp_low(h) =L= temp_lower_max_5 - (15/23)*temp_out(h);

temp_lower_slack_max_18(h)$((temp_out(h) > 18) and (ord(h) > 1) and (heat_space_on))
                                       ..   temp_low(h) =L= temp_lower_max_18;

max_hp_lower_c(h)$(heat_space_on)      ..   hp_low(h) =e= alpha_low(h) * hp_low_max/dt;

max_hp_upper_c(h)                      ..   hp_up(h) =e= alpha_up(h) * hp_up_max/dt;
*t
one_mode_c(h)$(heat_space_on)          ..   alpha_low(h) + alpha_up(h) =l= 1;

max_heat_in_lower_c(h)$(heat_space_on) ..   heat_in_low(h) =e= cop_low(h) * hp_low(h);

max_heat_in_upper_c(h)                 ..   heat_in_up(h) =e= cop_up(h) * hp_up(h);

usage_c(h)$(hw_demand(h) > 0)          ..   heat_in_up(h) =e= 0;

heat_loss_lower_c(h)$(heat_space_on)   ..   loss_low(h) =e= u_low * area_low *(temp_low(h) - temp_amb);

heat_loss_upper_c(h)                   ..   loss_up(h) =e= u_up * area_up *(temp_up(h) - temp_amb);

heat_loss_room_c(h)$(heat_space_on)    ..   loss_room(h)  =e= 8 *(temp_room(h) - temp_out(h));
*                                                                                
energy_lower_c(h)$(heat_space_on)      ..   heat_low(h) =e= (temp_low(h)-temp_ref)*(mass_low * c_water);

energy_upper_c(h)                      ..   heat_up(h) =e= (temp_up(h)-temp_ref)*(mass_up * c_water);

energy_room_c(h)$(heat_space_on)       ..   heat_room(h)  =e= (temp_room(h))* 526;
*                                                                            (mass_room * c_air);                                                             
heatbalance_lower_c(h)$((ord(h) > 1) and (heat_space_on) ) ..
                      heat_low(h) =e= heat_low(h-1)+(heat_in_low(h)-loss_low(h)- 900/dt*alpha_room(h));

heatbalance_upper_c(h)$((ord(h) > 1)) ..
                     heat_up(h)  =e= heat_up(h-1)+ heat_in_up(h)- hw_demand(h)- loss_up(h);

heatbalance_room_c(h)$((ord(h) > 1) and (heat_space_on) )  ..
                     heat_room(h)   =e= heat_room(h-1) + (heat_in_room(h)) - loss_room(h);

temp_limit(h)$((ord(h) > 1) and (heat_space_on)) ..
                     temp_room(h)-temp_room(h-1) =l= 0.25;

heat_in_room_min(h)$(heat_space_on)  .. heat_in_room(h) =g= small_m *alpha_room(h);

heat_in_room_max(h)$(heat_space_on)  .. heat_in_room(h) =l= big_m * alpha_room(h);

ev_balance(h) .. ev_energy(h) =e=
                    ev_init$(ord(h)=1) + ev_energy(h-1)$(ord(h)>1) - ev_use$((ord(h)>1) and (ev_avail(h)=0) and (ev_avail(h+1)=1))
                    + (p_ev*(gama_ch(h)*eta_ev - gama_dch(h)/eta_ev ))$(ev_avail(h)=1);

ev_charge_coord(h)$(ev_avail(h) ne 0) .. gama_dch(h)+gama_ch(h) =l= 1;
ev_dicharge_limt .. sum(h$(ev_avail(h) ne 0), gama_dch(h))    =l= ev_discharge_cycle;

soc_def(h) .. soc(h) =e=  (ev_energy(h)/ev_cap)*100;


* -----------------------------------------------------------------------------------------
* ALGORITHMIC APPROACH: MILP & GLOBAL OPTIMALITY
* Based on the methodology, all thermal dynamics (HPWH and Building Envelope) are linearized.
* By using Mixed-Integer Linear Programming (MILP) with the CPLEX solver, we guarantee global
* optimality and computational efficiency required for real-time household dispatch, avoiding
* the local optima traps of Non-Linear (NLP) solvers.
* -----------------------------------------------------------------------------------------
