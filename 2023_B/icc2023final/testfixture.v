`timescale 1ns/10ps
`define SDFFILE     "./AFE_syn.sdf"    //Modify your sdf file name
`define CYCLE       10.0                //Modify your CYCLE (but dont over 20)

`define DEL_tb      1.0
`define PAT_NUM     1024
`define GOLD_NUM    1024

`define TIMEOUT 10000

`define PAT         "./PAT1.dat"
`ifdef  sim1
  `define GOLD      "./GOLD1.dat"
  `define SEL       1
`elsif  sim2
  `define GOLD      "./GOLD2.dat"
  `define SEL       2
`elsif  sim3
  `define GOLD      "./GOLD3.dat"
  `define SEL       3
`elsif  sim4
  `define GOLD      "./GOLD4.dat"
  `define SEL       4
`else //sim0
  `define GOLD      "./GOLD0.dat"
  `define SEL       0
`endif

module test;
reg          clk;
reg          rst;
reg  [2:0]   fn_sel;
reg  [31:0]  x;
wire         busy;
wire         done;



reg  [31:0]  PAT_mem   [0:`PAT_NUM-1];
reg  [31:0]  GOLD_mem  [0:`GOLD_NUM-1];
reg  [31:0]  fout;
reg  [31:0]  out_tmp;
integer      i, j, pass, err;
reg          over, over1, over2;
integer exp_sign1, exp_sign2, bits;
real    exp1, e1, m1, real1, exp2, e2, m2, real2, k, err_ratio, err_dist ;


//AFE CHIP
         AFE u_AFE( .clk        (clk     ),
                    .rst        (rst     ),
                    .fn_sel     (fn_sel  ),
                    .x          (x       ),
                    .busy       (busy    ),
                    .done       (done    )
                  );


`ifdef SDF
   initial       $sdf_annotate(`SDFFILE, u_AFE );
`endif

initial	 $readmemb (`PAT,  PAT_mem);
initial	 $readmemb (`GOLD, GOLD_mem);

initial begin
   clk           = 1'b0;
   rst           = 1'b0;
   fn_sel        = `SEL;
   x             = 'hz;
   i             = 0;
   j             = 0;
   pass          = 0;
   err           = 0;
   over          = 0;
   over1         = 0;
   over2         = 0;
end

always begin #(`CYCLE/2)  clk = ~clk; end

initial begin
	#(`CYCLE * `TIMEOUT);
	$display("ERROR: timeout\n");
	$finish;
end
initial begin
//$dumpfile("AFE.vcd");
//$dumpvars;

$fsdbDumpfile("AFE.fsdb");
$fsdbDumpvars;
$fsdbDumpMDA;

//$shm_open("AFE.shm ");
//$shm_probe;
end

initial begin
   @(posedge clk)  #`DEL_tb  rst = 1'b1;
   #`CYCLE                   rst = 1'b0;

    $display("-----------------------------------------------------\n");
    $display("Activation Functions Engine Simulation Begin ...");
    $display("----------------------------------------- \n");
    @(posedge clk);
    while (i <= `PAT_NUM-1) begin
       if(!busy)begin
          #`DEL_tb;
          x = PAT_mem[i];
          i=i+1;
       end
       else begin
          #`DEL_tb;
          x = 'hz;
       end
       @(posedge clk);
    end
    over1 = 1;
end


initial begin
   @(posedge done)   j=0;
   while (j<`GOLD_NUM)begin
      //Gold Comp
      fout=u_AFE.u_mem.mem[j];
      out_tmp=GOLD_mem[j];

      if(fout !== 'hX && fout !== 'hZ)begin
         //Output Real
         exp_sign1 = !(fout[30:23] >= 'd127);
         exp1=(exp_sign1)? ('d127-fout[30:23]) : (fout[30:23]-'d127) ;
         e1=(exp_sign1)?(1/(2**exp1)):(2**exp1);
         m1=1.0;
         for(k=0; k<=22; k=k+1)begin
            bits=k;
            if(fout[22-bits])  m1= m1 + 1/(2**(k+1));
         end
         real1= (fout[31])?(-m1 * e1):(m1 * e1) ;

         //Golden Real
         exp_sign2 = !(out_tmp[30:23] >= 'd127);
         exp2=(exp_sign2)? ('d127-out_tmp[30:23]) : (out_tmp[30:23]-'d127) ;
         e2=(exp_sign2)?(1/(2**exp2)):(2**exp2);
         m2=1.0;
         for(k=0; k<=22; k=k+1)begin
            bits=k;
            if(out_tmp[22-bits])  m2= m2 + 1/(2**(k+1));
         end
         real2 = (out_tmp[31])?(-m2 * e2):(m2 * e2) ;

         //Error Distance & Ratio
         err_dist  = ((real2-real1)*(real2-real1))**0.5;
         err_ratio = (err_dist/((real2*real2)**0.5))*100;

         if((err_dist > 0.002) && (err_ratio > 1.0))begin
            $display("Error:  Signal_%3d: %08h (Real=%.6f) != Expect %08h (Real=%.6f)  Error_Dist = %f(Error_Ratio = %f)\n", j, fout, real1, out_tmp, real2, err_dist, err_ratio);
            err  = err + 1;
         end
         else begin
            $display("Pass:   Signal_%3d: %08h (Real=%.6f) == Expect %08h (Real=%.6f)  Error_Dist = %f(Error_Ratio = %f)\n", j, fout, real1, out_tmp, real2, err_dist, err_ratio);
            pass = pass + 1;
          end
      end
      else begin
            $display("Error:  The SRAM_ADDR[%4d] is Unknow!!   \n", j);
      end

         j = j+1;

         $display("----------------------------------------- \n");

         if((pass+err) == `GOLD_NUM)  over2=1;
   end
end

always @(*)begin
   over = over1 & over2;
end

initial begin
      @(posedge over)
      if(over) begin
         $display("\n-----------------------------------------------------\n");
         if (err == 0)  begin
            $display("Congratulations! All data have been generated successfully!\n");
            $display("-------------------------PASS------------------------\n");
         end
         else begin
            $display("Final Simulation Result as below: \n");
            $display("-----------------------------------------------------\n");
            $display("Pass:   %d \n", pass);
            $display("Error:  %d \n", err);
            $display("-----------------------------------------------------\n");
         end
      end
      #(`CYCLE/2); $finish;
end



endmodule



