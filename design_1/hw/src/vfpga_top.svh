import lynxTypes::*;

Byte_Stream_Decoder bsd_inst (
    .clk            (aclk),
    .reset          (!aresetn),

    .valid_in       (axis_host_recv[0].tvalid),
    .Stream_in      (axis_host_recv[0].tdata[31:0]),
    .rdy_out        (axis_host_recv[0].tready),

    .valid_out      (axis_host_send[0].tvalid),
    .Stream_out     (axis_host_send[0].tdata[31:0]),
    .rdy_in         (axis_host_send[0].tready),

    .par_valid_in   (axis_host_recv[1].tvalid),
    .par_Stream_in  (axis_host_recv[1].tdata[31:0]),
    .par_rdy_out    (axis_host_recv[1].tready)
);

// Tie-off unused signals to avoid synthesis problems
always_comb notify.tie_off_m();
always_comb sq_rd.tie_off_m();
always_comb sq_wr.tie_off_m();
always_comb cq_rd.tie_off_s();
always_comb cq_wr.tie_off_s();
always_comb axi_ctrl.tie_off_s();

ila_bsd ila_bsd_inst (
    .clk(aclk),
    .probe0(axis_host_recv[0].tvalid),  // 1 bit
    .probe1(axis_host_recv[0].tready),  // 1 bit
    .probe2(axis_host_recv[0].tlast),   // 1 bit
    .probe3(axis_host_recv[0].tdata),   // 512 bits
    .probe4(axis_host_send[0].tvalid),  // 1 bit
    .probe5(axis_host_send[0].tready),  // 1 bit
    .probe6(axis_host_send[0].tlast),   // 1 bit
    .probe7(axis_host_send[0].tdata)    // 512 bits
);
