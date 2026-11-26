// Copyright (C) 2019-2022, Université catholique de Louvain (UCLouvain, Belgium), University of Zürich (UZH, Switzerland),
//         Katholieke Universiteit Leuven (KU Leuven, Belgium), and Delft University of Technology (TU Delft, Netherlands).
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file except in compliance
// with the License, or, at your option, the Apache License version 2.0. You may obtain a copy of the License at
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the License is distributed on
// an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
//------------------------------------------------------------------------------
//
// "neuron_core.v" - File containing the time-multiplexed neuron array based on 12-bit leaky integrate-and-fire (LIF) neurons
//                   (as opposed to ODIN, which both 8-bit LIF and custom phenomenological Izhikevich neuron models)
// 
// Project: tinyODIN - A low-cost digital spiking neuromorphic processor adapted from ODIN.
//
// Author:  C. Frenkel, Delft University of Technology
//
// Cite/paper: C. Frenkel, M. Lefebvre, J.-D. Legat and D. Bol, "A 0.086-mm² 12.7-pJ/SOP 64k-Synapse 256-Neuron Online-Learning
//             Digital Spiking Neuromorphic Processor in 28-nm CMOS," IEEE Transactions on Biomedical Circuits and Systems,
//             vol. 13, no. 1, pp. 145-158, 2019.
//
//------------------------------------------------------------------------------


module neuron_core #(
    parameter N = 256,
    parameter M = 8
)(
    
    // Global inputs ------------------------------------------
    input  wire                 CLK,
    
    // Inputs from SPI configuration registers ----------------
    input  wire                 SPI_GATE_ACTIVITY_sync,
    
    // Synaptic inputs ----------------------------------------
    input  wire [         31:0] SYNARRAY_RDATA,
    
    // Inputs from controller ---------------------------------
    input  wire                 CTRL_NEUR_EVENT,
    input  wire                 CTRL_NEUR_TREF,
    input  wire [          3:0] CTRL_NEUR_VIRTS,
    input  wire                 CTRL_NEURMEM_CS,
    input  wire                 CTRL_NEURMEM_WE,
    input  wire [        M-1:0] CTRL_NEURMEM_ADDR,
    input  wire [      2*M-1:0] CTRL_PROG_DATA,
    input  wire [      2*M-1:0] CTRL_SPI_ADDR,
    
    // Outputs ------------------------------------------------
    output wire [         31:0] NEUR_STATE,
    output wire                 NEUR_EVENT_OUT
);
    
    // Internal regs and wires definitions

    wire [    3:0] syn_weight;
    wire [   31:0] syn_weight_int;
    wire           syn_event;
    wire           time_ref;
    
    wire           LIF_neuron_event_out;
    
    wire [   11:0] LIF_neuron_next_NEUR_STATE;
    
    wire [   31:0] neuron_data_int, neuron_data;
    
    genvar i;

    
    // Processing inputs from the synaptic array and the controller
    
    assign syn_weight_int  = SYNARRAY_RDATA >> ({2'b0,CTRL_NEURMEM_ADDR[2:0]} << 2);
    
    assign syn_weight      = |CTRL_NEUR_VIRTS ? CTRL_NEUR_VIRTS : syn_weight_int[3:0];
    assign syn_event       =  CTRL_NEUR_EVENT;
    assign time_ref        =  CTRL_NEUR_TREF;
    

    // Updated or configured neuron state to be written to the neuron memory

    assign neuron_data_int = {NEUR_STATE[31:12], LIF_neuron_next_NEUR_STATE};
    generate
        for (i=0; i<4; i=i+1) begin
        
            assign neuron_data[M*i+M-1:M*i] = SPI_GATE_ACTIVITY_sync
                                            ? ((i == CTRL_SPI_ADDR[2*M-1:M])
                                                     ? ((CTRL_PROG_DATA[M-1:0] & ~CTRL_PROG_DATA[2*M-1:M]) | (NEUR_STATE[M*i+M-1:M*i] & CTRL_PROG_DATA[2*M-1:M]))
                                                     : NEUR_STATE[M*i+M-1:M*i])
                                            : neuron_data_int[M*i+M-1:M*i];
            
        end
    endgenerate


    // Neuron output spike events

    assign NEUR_EVENT_OUT = NEUR_STATE[31] ? 1'b0 : ((CTRL_NEURMEM_CS && CTRL_NEURMEM_WE) ? LIF_neuron_event_out : 1'b0);
    
    
    // Neuron update logic for leaky integrate-and-fire (LIF) model
    
    lif_neuron lif_neuron_0 ( 
        .param_leak_str(                         NEUR_STATE[30:24]),
        .param_thr(                              NEUR_STATE[23:12]),
        
        .state_core(                             NEUR_STATE[11: 0]),
        .state_core_next(        LIF_neuron_next_NEUR_STATE[11: 0]),
        
        .syn_weight(syn_weight),
        .syn_event(syn_event),
        .time_ref(time_ref),
        
        .spike_out(LIF_neuron_event_out) 
    );


    // Neuron memory wrapper

    SRAM_256x32_wrapper neurarray_0 (       
        
        // Global inputs
        .CK         (CLK),
    
        // Control and data inputs
        .CS         (CTRL_NEURMEM_CS),
        .WE         (CTRL_NEURMEM_WE),
        .A          (CTRL_NEURMEM_ADDR),
        .D          (neuron_data),
        
        // Data output
        .Q          (NEUR_STATE)
    );
    

endmodule




module SRAM_256x32_wrapper (

    // Global inputs
    input          CK,                       // Clock (synchronous read/write)

    // Control and data inputs
    input          CS,                       // Chip select
    input          WE,                       // Write enable
    input  [  7:0] A,                        // Address bus 
    input  [ 31:0] D,                        // Data input bus (write)

    // Data output
    output [ 31:0] Q                         // Data output bus (read)   
);


    wire [31:0] sram_dout0;
    wire [31:0] unused_dout1;
    reg         cs_r;
    reg  [31:0] q_hold;

    always @(posedge CK) begin
        cs_r <= CS;
        if (cs_r) begin
            q_hold <= sram_dout0;
        end
    end

    assign Q = cs_r ? sram_dout0 : q_hold;

    sky130_sram_1kbyte_1rw1r_32x256_8 sram_inst (
        .clk0(CK),
        .csb0(~CS),
        .web0(~WE),
        .wmask0(4'b1111),
        .addr0(A),
        .din0(D),
        .dout0(sram_dout0),
        .clk1(1'b0),
        .csb1(1'b1),
        .addr1(8'b0),
        .dout1(unused_dout1)
    );

`ifndef VERILATOR
`ifndef SYNTHESIS
    wire [31:0] SRAM [255:0];
    genvar idx;
    generate
        for (idx=0; idx<256; idx=idx+1) begin : gen_sram_tb
            assign SRAM[idx] = sram_inst.mem[idx];
        end
    endgenerate
`endif
`endif


endmodule
