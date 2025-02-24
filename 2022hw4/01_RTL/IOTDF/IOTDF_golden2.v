`timescale 1ns/10ps
module IOTDF( clk, rst, in_en, iot_in, fn_sel, busy, valid, iot_out);
input          clk;
input          rst;
input          in_en;
input  [7:0]   iot_in;
input  [2:0]   fn_sel;
output         busy;
output         valid;
output [127:0] iot_out;


//****************************************	//
//	Step0:Readin			//
//****************************************	//
parameter FN_MAX = 1;
parameter FN_MIN = 2;
parameter FN_AVG = 3;
parameter FN_EXT = 4;
parameter FN_EXC = 5;
parameter FN_PMAX = 6;
parameter FN_PMIN = 7;

reg [2:0] fn;
reg [7:0] iot_data;

always@(posedge clk or posedge rst) begin
	if(rst) begin
		fn	<= 0;
		iot_data	<= 0;
	end
	else if(in_en)	begin
		fn	<= fn_sel;
		iot_data	<= iot_in;	
	end	
end


//****************************************	//					
//	Step1:Finite State Machine	//
//****************************************	// 
parameter S_IDLE		= 0;
parameter S_BUF1		= 1;
parameter S_GETD		= 2;

reg [6:0] counter_127;
reg       is_0th_round;
reg [2:0] state, state_next;
reg in_en_r;
always@(*) begin
	state_next = state;
	case(state)
		S_IDLE:	if(in_en)		state_next = S_BUF1;
		S_BUF1:	state_next = S_GETD;
		S_GETD:	state_next = S_GETD;
	endcase
end

always@(posedge clk or posedge rst) begin
	if(rst)	begin
		state 		<= S_IDLE;
		in_en_r 		<= 0;
		is_0th_round 	<= 1;
	end
	else	begin
		state 		<= state_next;
		in_en_r 		<= in_en;
		if(counter_127==127) is_0th_round <= 0;
	end
end

always@(posedge clk or posedge rst) begin
	if(rst)					counter_127 <= 0;
	else if(state==S_BUF1)			counter_127 <= 0;
	else					counter_127 <= counter_127+1;
end
// counter_127 =   0~  7 <-> 1st IOT data	//
// counter_127 =   8~ 15 <-> 2nd IOT data	//
// ...					//
// counter_127 = 120~127 <-> 16th IOT data	//


//****************************************	//
//	Step2:Operate function		//
//****************************************	//
reg [7:0] data_buf[0:15];
reg [7:0] max_buf[0:15];
reg [7:0] min_buf[0:15];
reg [7:0] sum_buf[0:15];   
reg [2:0] sum_carry;
reg       sum_buf_carry;
wire[8:0] sum_buf_result = (counter_127==0)? 
			  data_buf[0]:(data_buf[0] + sum_buf[15-counter_127[3:0]] + sum_buf_carry);   

wire[127:0] data = {	data_buf[00], data_buf[01], data_buf[02], data_buf[03],
			data_buf[04], data_buf[05], data_buf[06], data_buf[07],
			data_buf[08], data_buf[09], data_buf[10], data_buf[11],
			data_buf[12], data_buf[13], data_buf[14], data_buf[15]};

wire[127:0] max   =  {	max_buf[00], max_buf[01], max_buf[02], max_buf[03],
			max_buf[04], max_buf[05], max_buf[06], max_buf[07],
			max_buf[08], max_buf[09], max_buf[10], max_buf[11],
			max_buf[12], max_buf[13], max_buf[14], max_buf[15]};

wire[127:0] min   =  {	min_buf[00], min_buf[01], min_buf[02], min_buf[03],
			min_buf[04], min_buf[05], min_buf[06], min_buf[07],
			min_buf[08], min_buf[09], min_buf[10], min_buf[11],
			min_buf[12], min_buf[13], min_buf[14], min_buf[15]};

wire[127:0] sum   =  {	sum_carry,
			sum_buf[00], sum_buf[01], sum_buf[02], sum_buf[03],
			sum_buf[04], sum_buf[05], sum_buf[06], sum_buf[07],
			sum_buf[08], sum_buf[09], sum_buf[10], sum_buf[11],
			sum_buf[12], sum_buf[13], sum_buf[14], sum_buf[15][7:3]};

integer i;		
always@(posedge clk or posedge rst) begin
	if(rst) begin
		for(i=0; i<16; i=i+1)	data_buf[i] <= 0;
	end
	else	begin
		for(i=1; i<16; i=i+1)	data_buf[i] <= data_buf[i-1];
		data_buf[0] <= iot_data;	
	end
end

always@(posedge clk or posedge rst) begin
	if(rst) begin
		for(i=0; i<16; i=i+1)	begin
			max_buf[i]   <= 0;
			min_buf[i]   <= 8'hFF;
		end
	end
	else if(fn!=FN_PMAX && fn!=FN_PMIN && counter_127==1) begin
		for(i=0; i<16; i=i+1)	begin
			max_buf[i] <= 0;
			min_buf[i] <= 8'hFF;
		end
	end
	else if(counter_127[3:0]==15)	begin
		for(i=0; i<16; i=i+1)	begin
			max_buf[i] <= (data>max)? data_buf[i]:max_buf[i];
			min_buf[i] <= (data<min)? data_buf[i]:min_buf[i];
		end
	end
end

always@(posedge clk or posedge rst) begin
	if(rst) begin
		for(i=0; i<16; i=i+1)	sum_buf[i]  <= 0;
		sum_carry <= 0;
		sum_buf_carry <= 0;
	end
	else if(counter_127==0) begin
		for(i=0; i<15; i=i+1)	sum_buf[i] <= 0;
		sum_carry 	<= 0;
		sum_buf[15]	<= sum_buf_result[7:0];
		sum_buf_carry	<= sum_buf_result[8];
	end
	else if(counter_127[3:0]==15) begin
		sum_buf[0]	<= sum_buf_result[7:0];
		sum_carry	<= sum_carry+sum_buf_result[8];
		sum_buf_carry	<= 0;
	end
	else begin
		sum_buf[15-counter_127[3:0]]	<= sum_buf_result[7:0];
		sum_buf_carry			<= sum_buf_result[8];
	end
end


//****************************************	//
//	Step3:Output answer		//
//****************************************	//
wire[127:0] upper = 	(fn==FN_EXT)? 128'h AFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF:
		   	              128'h BFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
				 
wire[127:0] lower = 	(fn==FN_EXT)? 128'h 6FFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF:
		   	              128'h 7FFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
		
wire output_MAX = (fn==FN_MAX && counter_127==127); 
wire output_MIN = (fn==FN_MIN && counter_127==127); 
wire output_AVG = (fn==FN_AVG && counter_127==127);
wire output_EXT = (fn==FN_EXT && counter_127[3:0]==15 && (upper>data && data>lower));
wire output_EXC = (fn==FN_EXC && counter_127[3:0]==15 && (data>upper || lower>data));
wire output_PMAX= (fn==FN_PMAX && is_0th_round && counter_127==127 ||
		  fn==FN_PMAX && !is_0th_round && counter_127[3:0]==15 && data>max);
wire output_PMIN= (fn==FN_PMIN && is_0th_round && counter_127==127 ||
		  fn==FN_PMIN && !is_0th_round && counter_127[3:0]==15 && data<min); 

reg output_MAX_r, output_MIN_r, output_AVG_r, output_PMAX_r, output_PMIN_r;
always@(posedge clk or posedge rst) begin
	if(rst)	begin
		output_MAX_r <= 0;
		output_MIN_r <= 0;
		output_AVG_r <= 0;
		output_PMAX_r<= 0;
		output_PMIN_r<= 0;
	end
	else	begin
		output_MAX_r <= output_MAX;
		output_MIN_r <= output_MIN;
		output_AVG_r <= output_AVG;
		output_PMAX_r<= output_PMAX;
		output_PMIN_r<= output_PMIN;
	end
end

assign valid = output_MAX_r + output_MIN_r + output_AVG_r + 
	      output_EXT + output_EXC + output_PMAX_r + output_PMIN_r;
assign iot_out = (output_MAX_r)? max:
		(output_MIN_r)? min:
		(output_AVG_r)? sum:
		(output_EXT)? data:
		(output_EXC)? data:
		(output_PMAX_r)? max: min;
assign busy = 0;


endmodule
