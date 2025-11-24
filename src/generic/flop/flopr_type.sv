module flopr_type #(parameter type T = logic [7:0],
                    parameter T RESET = '0) ( 

  input  logic             clk, reset,
  input  T d, 
  output T q);

  always_ff @(posedge clk)
    if (!reset) q <= RESET;
    else        q <= d;
endmodule
