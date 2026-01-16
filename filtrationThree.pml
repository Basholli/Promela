// always eventually full
// always eventually empty

mtype = {status_query, status_query_ack, req_filling, req_filling_ack, 
         filling, filling_ack, empty_state, ready, filled, open, close};

chan Vessel = [2] of { bit };      // Liquid flow (for demonstration)
chan blue = [10] of {mtype};        // Controller communication
chan red = [10] of {mtype};         // Status signals
chan in_to_valve = [1] of {mtype};  // In-valve control
chan out_to_valve = [1] of {mtype}; // Out-valve control
chan flag_chan = [1] of { bool };   // Process sync

bool in_valve_open = false;
bool out_valve_open = false;

proctype InValve(chan outflow, ctrl_cmd) {
    do
    :: ctrl_cmd?open ->
        in_valve_open = true;
        outflow!1;  // Liquid flow - shows valve readiness
       
        
    :: ctrl_cmd?close -> in_valve_open = false
    od
}

proctype OutValve(chan inflow, ctrl_cmd) {
    do
    :: ctrl_cmd?open ->
        out_valve_open = true;
        inflow?1;   // Consume liquid
        
    :: ctrl_cmd?close -> out_valve_open = false
    od
}

proctype InValveCtrl(chan ctrl_cmd, blue_line, red_line, flag_ch) {
    do
    ::  /* one full cycle in one branch */
        blue_line!status_query;
        blue_line?status_query_ack;
        red_line?empty_state;

        blue_line!req_filling;
        blue_line?req_filling_ack;   /* optional, if you want the ack */
        red_line?ready;

        ctrl_cmd!open;
        /* In-valve will set in_valve_open = true itself */
        blue_line!filling;

        blue_line?filling_ack;
        red_line?filled;

        ctrl_cmd!close;
        flag_ch!true;       /* tell OutValveCtrl we finished filling */
    od
}


proctype OutValveCtrl(chan ctrl_cmd, blue_line, red_line, flag_ch) {
    mtype msg;
    do
    :: blue_line?status_query ->
        blue_line!status_query_ack;
        red_line!empty_state

    :: blue_line?req_filling ->
        blue_line!req_filling_ack;
        ctrl_cmd!close;
        out_valve_open = 0;
        red_line!ready

    :: blue_line?filling ->
        blue_line!filling_ack;
        red_line!filled

    :: flag_ch?msg ->
        if
        :: msg == true ->
            ctrl_cmd!open;
            out_valve_open = 1;
            printf("1 process finished\n");
        fi
    od
}


never { 
    do
    :: (in_valve_open && out_valve_open) -> assert(false)
    :: else
    od
}

init {
    atomic {
        run InValve(Vessel, in_to_valve);
        run OutValve(Vessel, out_to_valve);
        run InValveCtrl(in_to_valve, blue, red, flag_chan);
        run OutValveCtrl(out_to_valve, blue, red, flag_chan);
        printf("Valve controllers + valves only - iSpin ready\n")
    }
}


//this code runs perfectly in ispin, does not have liveness property except for the never statement, filtrationFOur will try to have both the code and the ltl livesness prperrty