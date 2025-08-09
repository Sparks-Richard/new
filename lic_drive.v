
`timescale 1ns / 1ps

module iic_drive(
	input						clk_8m,
	input 	      				clk_i, ///2xclk 400k*4 = 0.8Mhz
	input						rst_n,
	
	input 						wr_rd_flag,	//0 wr -- 1 rd
	input 						start_en,
	
	input		[ 7:0] 			i2c_device_addr,
	input		[15:0] 			register,
	input 		[ 7:0]			data_byte,
	
	output reg  				scl,
	inout 						sda,
	output reg 					busy,
	output reg 					err
		
    );
reg [  7:0]	nstate;
reg [  7:0]	cstate;	

localparam  idle        	=  8'b1111_1110; //fe
localparam  start_bit  	    =  8'b1111_1101; //fd
localparam  wr_dev_ctrl   	=  8'b1111_1011; //fb
localparam  wr_reg_high	    =  8'b1111_0111; //f7
localparam  wr_reg_low    	=  8'b1110_1111; //ef
localparam  wr_data_byte    =  8'b1101_1111; //df
localparam  i2c_over		=  8'b1011_1111; //bf
//localparam  i2c_ack    		=  8'b0111_1111;  //7f
reg [  7:0]	dev_r;
reg [  7:0]	reg_h;
reg [  7:0]	reg_l;
reg [  7:0] data_byte_r;

reg 		sda_o;
wire 		sda_i;
reg			sda_t;
reg			State_turn;
reg [ 15:0] Rec_count;

// ila_0 IIC_TEST (
	// .clk					(clk_8m), // input wire clk
	// .probe0					(sda_i), // input wire [0:0]  probe0  
	// .probe1					(sda_o), // input wire [0:0]  probe1 
	// .probe2					(sda_t), // input wire [7:0]  probe2 
	// .probe3					(scl), // input wire [7:0]  probe3
	// .probe4					(register[7:0])
// );

always @(*) begin
    case (cstate)
		idle:			nstate <=	(start_en)		? start_bit 	: idle;
		start_bit:		nstate <=	(State_turn)	? wr_dev_ctrl	: start_bit;
		wr_dev_ctrl:	nstate <=	(State_turn)	? wr_reg_high	: wr_dev_ctrl;
		wr_reg_high:	nstate <=	(State_turn)	? wr_reg_low	: wr_reg_high;
		wr_reg_low :	nstate <=	(State_turn)	? wr_data_byte	: wr_reg_low;
		// 
		wr_data_byte:	nstate <=	(State_turn)	? i2c_over		: wr_data_byte;
		i2c_over:		nstate <=	(State_turn)	? idle			: i2c_over;
		
	endcase
end
//scl
always @(posedge clk_i or negedge rst_n)
begin
	if(!rst_n) begin
		scl	<= 1'b1;
	end
	else begin
		case (nstate)
			idle:begin
				scl	<= 1'b1;
			end
			start_bit:begin
				if(Rec_count >= 16'd2)	scl	<= 1'b0;				
				else 					scl	<= 1'b1;
			end
			wr_dev_ctrl,wr_reg_high,wr_reg_low,wr_data_byte:	scl	<= ~scl;
			i2c_over:begin
				if(Rec_count == 16'd0)							scl	<= ~scl;
				else 											scl <= scl;
			end
		endcase 
	end
end
//sda_t
// always @(posedge clk_i or negedge rst_n)
// begin
	// if(!rst_n) 				sda_t	<= 1'b0;
	// else begin
		// case (nstate)
			// idle:			sda_t	<= 1'b0;
			// start_bit:		sda_t	<= 1'b1;	
			// wr_dev_ctrl,wr_reg_high,wr_reg_low,wr_data_byte:begin
				// if(Rec_count ==16'd15 || Rec_count == 16'd16)begin
					// sda_t	<= 1'b0;
				// end				
				// else begin
					// sda_t	<= 1'b1;
				// end		
			// end
			// i2c_over:		sda_t	<= 1'b0;
		// endcase
	// end
// end	
//sda_t
always @(posedge clk_i or negedge rst_n)
begin
	if(!rst_n) 				sda_t	<= 1'b1;
	else begin
		case (nstate)
			idle:			sda_t	<= 1'b1;
			start_bit:		sda_t	<= 1'b0;	
			wr_dev_ctrl,wr_reg_high,wr_reg_low,wr_data_byte:begin
				if(Rec_count ==16'd15 || Rec_count == 16'd16)begin
					sda_t	<= 1'b1;
				end				
				else begin
					sda_t	<= 1'b0;
				end		
			end
			i2c_over:		sda_t	<= 1'b0;
		endcase
	end
end		
//sda
always @(posedge clk_i or negedge rst_n)
begin
	if(!rst_n) begin
		sda_o		<= 1'b1;		
		dev_r 		<= 8'hff;
		reg_h 		<= 8'hff;
		reg_l 		<= 8'hff;
		data_byte_r	<= 8'hff;
	end
	else begin
		case (nstate)
			idle:begin
				sda_o	<= 1'b1;			
				dev_r 		<= dev_r;
				reg_h 		<= reg_h;
				reg_l 		<= reg_l;
				data_byte_r <= data_byte_r;
			end
			start_bit:begin		
				dev_r 		<= {i2c_device_addr[7:1] , wr_rd_flag};
				reg_h 		<= register[15:8];	
				reg_l 		<= register[ 7:0];	
				data_byte_r <= data_byte;	
				if(Rec_count >=16'd3)begin
					sda_o	<= dev_r[7];				
				end	
				else begin
					sda_o	<= 1'b0;
				end
			end
			wr_dev_ctrl:begin
				reg_h 		<= reg_h;
				reg_l 		<= reg_l;
				data_byte_r <= data_byte_r;			
				if(Rec_count ==16'd15 || Rec_count == 16'd16)begin
					sda_o	<= 1'b1;
				end		
				else if (Rec_count == 16'd17)begin
					sda_o	<= reg_h[7];
				end
				else begin
					sda_o	<= dev_r[7];
					if(!scl)begin
						dev_r <= {dev_r[6:0],dev_r[7]};
					end
				end				
			end		
			wr_reg_high:begin
				dev_r 		<= dev_r;
				reg_l 		<= reg_l;
				data_byte_r <= data_byte_r;			
				if(Rec_count ==16'd15 || Rec_count == 16'd16)begin
					sda_o	<= 1'b1;
				end		
				else if (Rec_count == 16'd17)begin
					sda_o	<= reg_l[7];
				end				
				else begin
					sda_o	<= reg_h[7];
					if(!scl)begin
						reg_h <= {reg_h[6:0],reg_h[7]};
					end
				end			
			end		
			wr_reg_low:begin
				dev_r 		<= dev_r;
				reg_h 		<= reg_h;
				data_byte_r <= data_byte_r;			
				if(Rec_count ==16'd15 || Rec_count == 16'd16)begin
					sda_o	<= 1'b1;
				end		
				else if (Rec_count == 16'd17)begin
					sda_o	<= data_byte_r[7];
				end				
				else begin
					sda_o	<= reg_l[7];
					if(!scl)begin
						reg_l <= {reg_l[6:0],reg_l[7]};
					end
				end			
			end
			wr_data_byte:begin
				dev_r 		<= dev_r;
				reg_h 		<= reg_h;
				reg_l 		<= reg_l;			
				if(Rec_count ==16'd15 || Rec_count == 16'd16)begin
					sda_o	<= 1'b1;
				end		
				else if (Rec_count == 16'd17)begin
					sda_o	<= 1'b0;
				end				
				else begin
					sda_o	<= data_byte_r[7];
					if(!scl)begin
						data_byte_r <= {data_byte_r[6:0],data_byte_r[7]};
					end
				end			
			end
			i2c_over:begin
				dev_r 		<= dev_r;
				reg_h 		<= reg_h;
				reg_l 		<= reg_l;
				data_byte_r <= data_byte_r;
				if(Rec_count <= 16'd1)begin
					sda_o	<= 1'b0;
				end
				else begin
					sda_o	<= 1'b1;
				end
			end
		endcase
	end
end

//count
always @(posedge clk_i or negedge rst_n)
begin
	if(!rst_n) begin
		Rec_count	<= 16'd0;
		State_turn  <=  1'b0;
	end
	else begin
		case (nstate)
			idle:begin
				Rec_count	<= 16'd0;
				State_turn 	<=  1'b0;
			end
			start_bit,i2c_over:begin
				if (Rec_count == 16'd4 - 1'b1) begin
					Rec_count  	<= 16'd0;
					State_turn  <=  1'b1;
				end
				else 							begin
					Rec_count  	<= Rec_count + 1'b1;
					State_turn  <= 1'b0;
				end				
			end
			wr_dev_ctrl,wr_reg_high,wr_reg_low,wr_data_byte:begin
				if (Rec_count == 16'd18 - 1'b1) begin
					Rec_count  	<= 16'd0;
					State_turn  <=  1'b1;
				end
				else 							begin
					Rec_count  	<= Rec_count + 1'b1;
					State_turn  <= 1'b0;
				end				
			end
		endcase
	end
end
//err
always @(posedge clk_i or negedge rst_n)
begin
	if(!rst_n) begin
		err	<= 1'b0;
	end
	else begin
		case (nstate)
			idle,i2c_over,start_bit:	begin
				err	<= err;
			end
			wr_dev_ctrl,wr_reg_high,wr_reg_low,wr_data_byte:begin
				if(Rec_count==16'd16) begin
					if(sda_i) 	err	<= 1'b1;
					else 		err	<= 1'b0;
				end
				else begin
					err	<= err;
				end
			end
		endcase 
	end

end
//busy
always @(posedge clk_i or negedge rst_n)
begin
	if(!rst_n) busy	<= 1'b1;
	else begin
		case (nstate)
			idle: busy	<= 1'b0;
			wr_dev_ctrl,wr_reg_high,wr_reg_low,wr_data_byte,i2c_over,start_bit: busy	<= 1'b1;
		endcase 
	end

end
always @(posedge clk_i or negedge rst_n) begin
    if(!rst_n)cstate <= idle;
    else cstate <= nstate;
end

IOBUF#(
		.DRIVE(12), // Specify the output drive strength
		.IBUF_LOW_PWR("TRUE"),  // Low Power - "TRUE", High Performance = "FALSE"
		.IOSTANDARD("DEFAULT"), // Specify the I/O standard
		.SLEW("SLOW") // Specify the output slew rate
)sda_iobuf
       (.I(sda_o),
        .IO(sda),
        .O(sda_i),
        .T(sda_t)   //1'b1 out 
);




endmodule
