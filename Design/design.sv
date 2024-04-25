
module asynchronous_fifo #(parameter DEPTH=333, A_SIZE=8, parameter D_SIZE = 8) (
  input w_clk, wrst_n,
  input r_clk, rrst_n,
  input w_enable, r_enable,
  input [A_SIZE-1:0] w_data,
  output reg [A_SIZE-1:0] r_data,
  output reg w_full, r_empty, write_error, read_error
);
 
  reg [D_SIZE:0] sync_w2r, sync_r2w;
  reg [D_SIZE:0] b_wptr, b_rptr;
  reg [D_SIZE:0] g_wptr, g_rptr;

  wire [D_SIZE-1:0] waddr, raddr;

  synchronizer #(D_SIZE) sync_wptr (r_clk, rrst_n, g_wptr, sync_w2r); //write pointer to read clock domain
  synchronizer #(D_SIZE) sync_rptr (w_clk, wrst_n, g_rptr, sync_r2w); //read pointer to write clock domain 
  
  wptr_handler #(D_SIZE) wptr_h(w_clk, wrst_n, w_enable,sync_r2w,b_wptr,g_wptr,w_full);
  rptr_handler #(D_SIZE) rptr_h(r_clk, rrst_n, r_enable,sync_w2r,b_rptr,g_rptr,r_empty);
  fifo_mem fifom(w_clk, w_enable, r_clk, r_enable,b_wptr, b_rptr, w_data,w_full,r_empty, r_data, write_error, read_error);

endmodule

module synchronizer #(parameter WIDTH=8) (input clk, rst_n, [WIDTH:0] d_in, output reg [WIDTH:0] d_out);
  reg [WIDTH:0] q1;
  always_ff @(posedge clk) begin
    if(!rst_n) begin
      q1 <= 0;
      d_out <= 0;
    end
    else begin
      q1 <= d_in;
      d_out <= q1;
    end
  end
endmodule

module wptr_handler #(parameter D_SIZE=8) (
  input w_clk, wrst_n, w_enable,
  input [D_SIZE:0] sync_r2w,
  output reg [D_SIZE:0] b_wptr, g_wptr,
  output reg w_full
);

  reg [D_SIZE:0] b_wptr_next;
  reg [D_SIZE:0] g_wptr_next;
   
  reg wrap_around;
  wire wfull;
  
  assign b_wptr_next = b_wptr+(w_enable & !w_full);
  assign g_wptr_next = (b_wptr_next >>1)^b_wptr_next;
  
  //updating the binary and gray pointers
  always@(posedge w_clk or negedge wrst_n) begin
    if(!wrst_n) begin
      b_wptr <= 0; // set default value
      g_wptr <= 0;
    end
    else begin
      b_wptr <= b_wptr_next; // incr binary write pointer
      g_wptr <= g_wptr_next; // incr gray write pointer
    end
  end
  
  //updating the w_full
  always@(posedge w_clk or negedge wrst_n) begin
    if(!wrst_n) w_full <= 0;
    else        w_full <= wfull;
  end

  assign wfull = (g_wptr_next == {~sync_r2w[D_SIZE:D_SIZE-1], sync_r2w[D_SIZE-2:0]});

endmodule

module rptr_handler #(parameter D_SIZE=8) (
  input r_clk, rrst_n, r_enable,
  input [D_SIZE:0] sync_w2r,
  output reg [D_SIZE:0] b_rptr, g_rptr,
  output reg r_empty
);

  reg [D_SIZE:0] b_rptr_next;
  reg [D_SIZE:0] g_rptr_next;
  reg rempty;
  
  assign b_rptr_next = b_rptr + (r_enable & !r_empty); // Update based on counter
  assign g_rptr_next = (b_rptr_next >> 1) ^ b_rptr_next;
  assign rempty = (sync_w2r == g_rptr_next);

  //updating the pointers
  always_ff @(posedge r_clk or negedge rrst_n) begin
    if (!rrst_n) begin
      b_rptr <= 0;
      g_rptr <= 0;
    end else begin
        b_rptr <= b_rptr_next;
        g_rptr <= g_rptr_next; 
      end
    end
   
    //Updating the r_empty condition
  always_ff @(posedge r_clk or negedge rrst_n) begin
    if (!rrst_n) r_empty <= 1;
    else r_empty <= rempty;
  end
endmodule



module fifo_mem #(parameter DEPTH=256, A_SIZE=8, D_SIZE=8) (
  input w_clk, w_enable, r_clk, r_enable,
  input [D_SIZE:0] b_wptr, b_rptr,
  input [A_SIZE-1:0] w_data,
  input w_full, r_empty,
  output reg [A_SIZE-1:0] r_data,
  output reg write_error, read_error
);
  reg [A_SIZE-1:0] fifo[0:DEPTH-1];
  
  //write block
  always_ff @(posedge w_clk) begin
    write_error = 0;
    if(w_enable) begin
      if(w_full) begin
       write_error  = 1;
      end 
      else if (!w_full) begin
       fifo[b_wptr[D_SIZE-1:0]] <= w_data;
      end
  end 
  end


   //Read block
  always_ff @(posedge r_clk) begin
    read_error = 0;
    if(r_enable) begin
     if(r_empty) begin
      read_error = 1;
     end
     else if (!r_empty) begin
      r_data <= fifo[b_rptr[D_SIZE-1:0]];
    end
    end
  end

endmodule