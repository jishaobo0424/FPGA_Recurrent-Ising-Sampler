`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/19/2019 03:17:21 AM
// Design Name: 
// Module Name: loop_matrix
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module loop_matrix
    # 
    (parameter integer URAM_LEN = 1600,
               integer mat1height = 100,
               integer mat1width = 100,
               integer DATABITS = 16,
               integer NOISE_START_ADDR = 257,
               integer TH_ADDR =256, 
               integer ADDR_BIT = 9,
               integer mat1binary=2**$clog2(mat1height),
               integer tree_depth = $clog2(mat1height), // the number of propagation to reach bottom
               integer num_of_bram = 5,
               integer num_of_lines_per_read = 2*num_of_bram,
               integer number_of_read = mat1height/num_of_lines_per_read,// need to be > 3 see line: "if(read_count==number_of_read-3)"
               integer rows_per_bram = mat1height/num_of_bram
    )
    (
    input clk,
    input wire [URAM_LEN-1:0] one_row_of_data_1,
    output wire [ADDR_BIT-1:0]addr_1,
    input wire [URAM_LEN-1:0] one_row_of_data_2,
    output wire [ADDR_BIT-1:0]addr_2,
    input wire [URAM_LEN-1:0] one_row_of_data_3,
    output wire [ADDR_BIT-1:0]addr_3,
    input wire [URAM_LEN-1:0] one_row_of_data_4,
    output wire [ADDR_BIT-1:0]addr_4,
    input wire [URAM_LEN-1:0] one_row_of_data_5,
    output wire [ADDR_BIT-1:0]addr_5,
    input wire [URAM_LEN-1:0] one_row_of_data_6,
    output wire [ADDR_BIT-1:0]addr_6,
    input wire [URAM_LEN-1:0] one_row_of_data_7,
    output wire [ADDR_BIT-1:0]addr_7,
    input wire [URAM_LEN-1:0] one_row_of_data_8,
    output wire [ADDR_BIT-1:0]addr_8,
    input wire [URAM_LEN-1:0] one_row_of_data_9,
    output wire [ADDR_BIT-1:0]addr_9,
    input wire [URAM_LEN-1:0] one_row_of_data_10,
    output wire [ADDR_BIT-1:0]addr_10,
    input wire start_computation, // 8+18+1 = 27
    output reg signed [31:0] matrix_output, // change the size of output if needed in the future
    input wire [31:0] result_select,
    input wire [31:0] loop_number,
    input wire [mat1height-1:0] init_state
    );
    reg [mat1height-1:0] state_vector=0;
    reg [mat1height*DATABITS-1:0] next_state_vector_before_th=0;
    // reg signed [DATABITS*mat1binary*2-1:0] bin1; // output
    reg [ADDR_BIT-1:0] addr_reg[num_of_lines_per_read-1:0];
    wire signed [URAM_LEN-1:0] data_wire[2*num_of_bram-1:0];
    
    // we need to manually change the assignment below
    assign data_wire[0] = one_row_of_data_1;
    assign data_wire[1] = one_row_of_data_2;
    assign data_wire[2] = one_row_of_data_3;
    assign data_wire[3] = one_row_of_data_4;
    assign data_wire[4] = one_row_of_data_5;
    assign data_wire[5] = one_row_of_data_6;
    assign data_wire[6] = one_row_of_data_7;
    assign data_wire[7] = one_row_of_data_8;
    assign data_wire[8] = one_row_of_data_9;
    assign data_wire[9] = one_row_of_data_10;
    
    
    reg [3:0] FSM_state = 0;
    assign addr_1 = addr_reg[0];
    assign addr_2 = addr_reg[1];
    assign addr_3 = addr_reg[2];
    assign addr_4 = addr_reg[3];
    assign addr_5 = addr_reg[4];
    assign addr_6 = addr_reg[5];
    assign addr_7 = addr_reg[6];
    assign addr_8 = addr_reg[7];
    assign addr_9 = addr_reg[8];
    assign addr_10 = addr_reg[9];
    
    integer  term_number;
    integer  k; // for counting 2*num_of_bram = num_of_lines_per_read
    integer  j; // for counting lines_per_read
    integer  m; // for counting to tree_depth, which is the depth of the tree
    integer  l;
    
    reg signed [DATABITS*mat1binary*2-1:0] binadd[num_of_lines_per_read-1:0];
    
    reg [7:0] read_count = 0; // for counting at the reading stage (state = 4'b4)
    reg [7:0] tree_depth_count = 0;
    reg [7:0] result_count = 0;
    reg [31:0] loop_counter = 0;
    reg [31:0] clock_counter = 1;
    reg [31:0] max_loop_num = 0;
    initial begin
        matrix_output = 0;
        for(k=0;k<=num_of_lines_per_read-1;k=k+1)begin
            binadd[k][DATABITS*mat1binary*2-1:0]<=0;
        end
        state_vector = 100'h0;
        addr_reg[0] = 0;
        addr_reg[1] = 0;
        addr_reg[2] = 0;
        addr_reg[3] = 0;
        addr_reg[4] = 0;
        addr_reg[5] = 0;
        addr_reg[6] = 0;
        addr_reg[7] = 0;
        addr_reg[8] = 0;
        addr_reg[9] = 0;
    end
    always @(posedge clk) begin
        if(loop_counter == max_loop_num && FSM_state != 4'h0) begin
            FSM_state<=4'h0;
//            loop_counter <= 0;
//            clock_counter <= 0;
//            matrix_output <= {clock_counter[15:0],state_vector[15:0]};
            result_count <= 0;
            read_count <= 0;
            tree_depth_count <= 0;
        end else 
        begin
            case(FSM_state)
                4'h0: // idle / finished last computing / reading results
                    begin
                        if(start_computation == 1'b1) begin
//                            clock_counter <= 1;
                            max_loop_num <= max_loop_num+loop_number;
                            FSM_state<=4'h1;
                            for(j=0;j<num_of_bram;j=j+1) begin
                                addr_reg[j*2] <= 0;
                                addr_reg[j*2+1] <= number_of_read;
                            end
                            if(loop_counter == 32'h0) begin
                                state_vector <= init_state;
                            end
                        end else begin
                            case(result_select)
                                32'h0:
                                    begin
                                        matrix_output <= state_vector[31:0];
                                    end
                                32'h1:
                                    begin
                                        matrix_output <= state_vector[63:32];
                                    end
                                32'h2:
                                    begin
                                        matrix_output <= state_vector[95:64];
                                    end
                                32'h3:
                                    begin
                                        matrix_output <= {clock_counter[27:0],state_vector[99:96]};
                                    end
                                32'h4:
                                    begin
                                        matrix_output <= loop_counter;
                                    end
                                default:
                                    begin
                                        matrix_output <= 0;
                                    end
                            endcase
                        end
                    end
                4'h1: // reading_bram 
                    begin
                        clock_counter <= clock_counter+1;
                        FSM_state<=4'h2;
                        for(j=0;j<num_of_bram;j=j+1) begin
                            addr_reg[j*2] <= 1;
                            addr_reg[j*2+1] <= number_of_read+1;
                        end
                    end
                4'h2: // read pipeline_1 
                    begin
                        clock_counter <= clock_counter+1;
                        FSM_state<=4'h3;
                        for(j=0;j<num_of_bram;j=j+1) begin
                            addr_reg[j*2] <= 2;
                            addr_reg[j*2+1] <= number_of_read+2;
                        end
                        read_count <= 4'h0; // next cycle is the 0th data coming in
                    end
                4'h3: // read data coming in
                    begin
                        clock_counter <= clock_counter+1;
                        tree_depth_count<= tree_depth_count+1;
                        read_count <= read_count +1;
                        if (read_count==number_of_read-4)
                        begin
                            FSM_state<=4'h4; 
                        end
                        for(j=0;j<num_of_bram;j=j+1) 
                        begin
                            // for this bram first assign two address to read next
                            addr_reg[j*2] <= read_count+3;
                            addr_reg[j*2+1] <= number_of_read+read_count+3;
                            
                            // for this bram we have two rows reading in
                            for (term_number = 0; term_number<= mat1width-1; term_number = term_number +1)
                            begin
                                // port A
                                if(state_vector[term_number] == 1'b1) begin
                                    binadd[2*j] [(term_number)*DATABITS +: DATABITS]<= data_wire[2*j][term_number*DATABITS +: DATABITS];
                                end
                                else begin
                                    binadd[2*j] [(term_number)*DATABITS +: DATABITS]<= 0;
                                end
                                
                                //port B
                                if(state_vector[term_number] == 1'b1) begin
                                    binadd[2*j+1] [(term_number)*DATABITS +: DATABITS]<= data_wire[2*j+1][term_number*DATABITS +: DATABITS];
                                end
                                else begin
                                    binadd[2*j+1] [(term_number)*DATABITS +: DATABITS]<= 0;
                                end
                            end
                            
                            for(m=0; m<tree_depth; m=m+1)
                                for(l=0; l<mat1binary>>(m+1); l=l+1)
                                begin
                                    binadd[2*j][2*mat1binary*DATABITS-(1<<(tree_depth-m))*DATABITS + l*DATABITS +: DATABITS] <= 
                                    $signed(binadd[2*j][2*mat1binary*DATABITS-(1<<(tree_depth-m+1))*DATABITS +2*l*DATABITS +: DATABITS]) +
                                    $signed(binadd[2*j][2*mat1binary*DATABITS-(1<<(tree_depth-m+1))*DATABITS +(2*l+1)*DATABITS +: DATABITS]);
                                end 
                                
                            for(m=0; m<tree_depth; m=m+1)
                                for(l=0; l<mat1binary>>(m+1); l=l+1)
                                begin
                                    binadd[2*j+1][2*mat1binary*DATABITS-(1<<(tree_depth-m))*DATABITS + l*DATABITS +: DATABITS] <= 
                                    $signed(binadd[2*j+1][2*mat1binary*DATABITS-(1<<(tree_depth-m+1))*DATABITS +2*l*DATABITS +: DATABITS]) +
                                    $signed(binadd[2*j+1][2*mat1binary*DATABITS-(1<<(tree_depth-m+1))*DATABITS +(2*l+1)*DATABITS +: DATABITS]);
                                end
                        
                            if(tree_depth_count >= tree_depth+1) // when read_count == tree_depth+1, result first time ready
                            begin
                                result_count <= result_count+1;
                                next_state_vector_before_th[(2*j    *number_of_read+result_count)*DATABITS+:DATABITS] <= binadd[2*j  ][2*mat1binary*DATABITS-2*DATABITS +: DATABITS];
                                next_state_vector_before_th[((2*j+1)*number_of_read+result_count)*DATABITS+:DATABITS] <= binadd[2*j+1][2*mat1binary*DATABITS-2*DATABITS +: DATABITS];
                            end
                        end
                        
                    end
                4'h4:
                    begin
                        clock_counter <= clock_counter+1;
                        if(result_count==number_of_read-3) 
                        begin
                            // only read th and noise using bram 1
                            addr_reg[0] <= TH_ADDR;
                            addr_reg[1] <= NOISE_START_ADDR+loop_counter;
                            read_count  <= 0;
                        end else if (result_count >= number_of_read-2) begin
                            for(j=0;j<num_of_bram;j=j+1) 
                            begin
                                addr_reg[j*2] <= read_count;
                                addr_reg[j*2+1] <= number_of_read+read_count;
                            end
                            read_count  <= read_count+1;
                        end 
    
                        if(result_count == number_of_read) 
                        begin
                            for (term_number = 0; term_number<= mat1width-1; term_number = term_number +1)
                            begin
                                if($signed(next_state_vector_before_th[term_number*DATABITS+:DATABITS]+data_wire[1][term_number*DATABITS +: DATABITS])>=$signed(data_wire[0][term_number*DATABITS +: DATABITS]))
                                begin
                                    state_vector[term_number]  <= 1;
                                end else 
                                begin
                                    state_vector[term_number]  <= 0;
                                end
                            end
                            FSM_state<=4'h3;
                            loop_counter <= loop_counter+1;
                            result_count <= 0;
                            tree_depth_count<=0;
                            read_count <= 0;
                            next_state_vector_before_th<= 0;
                        end else 
                        begin
                            tree_depth_count<= tree_depth_count+1;
                            for(j=0;j<num_of_bram;j=j+1) 
                            begin
                                // for this bram we have two rows reading in
                                for (term_number = 0; term_number<= mat1width-1; term_number = term_number +1)
                                begin
                                    // port A
                                    if(state_vector[term_number] == 1'b1) begin
                                        binadd[2*j] [(term_number)*DATABITS +: DATABITS]<= data_wire[2*j][term_number*DATABITS +: DATABITS];
                                    end
                                    else begin
                                        binadd[2*j] [(term_number)*DATABITS +: DATABITS]<= 0;
                                    end
                                    
                                    //port B
                                    if(state_vector[term_number] == 1'b1) begin
                                        binadd[2*j+1] [(term_number)*DATABITS +: DATABITS]<= data_wire[2*j+1][term_number*DATABITS +: DATABITS];
                                    end
                                    else begin
                                        binadd[2*j+1] [(term_number)*DATABITS +: DATABITS]<= 0;
                                    end
                                end
                                // continue propagating 
                                for(m=0; m<tree_depth; m=m+1)
                                    for(l=0; l<mat1binary>>(m+1); l=l+1)
                                    begin
                                        binadd[2*j][2*mat1binary*DATABITS-(1<<(tree_depth-m))*DATABITS + l*DATABITS +: DATABITS] <= 
                                        $signed(binadd[2*j][2*mat1binary*DATABITS-(1<<(tree_depth-m+1))*DATABITS +2*l*DATABITS +: DATABITS]) +
                                        $signed(binadd[2*j][2*mat1binary*DATABITS-(1<<(tree_depth-m+1))*DATABITS +(2*l+1)*DATABITS +: DATABITS]);
                                    end 
                                    
                                for(m=0; m<tree_depth; m=m+1)
                                    for(l=0; l<mat1binary>>(m+1); l=l+1)
                                    begin
                                        binadd[2*j+1][2*mat1binary*DATABITS-(1<<(tree_depth-m))*DATABITS + l*DATABITS +: DATABITS] <= 
                                        $signed(binadd[2*j+1][2*mat1binary*DATABITS-(1<<(tree_depth-m+1))*DATABITS +2*l*DATABITS +: DATABITS]) +
                                        $signed(binadd[2*j+1][2*mat1binary*DATABITS-(1<<(tree_depth-m+1))*DATABITS +(2*l+1)*DATABITS +: DATABITS]);
                                    end
                                if(tree_depth_count >= tree_depth+1) // when tree_depth_count == tree_depth+1, result first time ready
                                begin  
                                    result_count <= result_count+1;
                                    next_state_vector_before_th[(2*j    *number_of_read+result_count)*DATABITS+:DATABITS] <= binadd[2*j  ][2*mat1binary*DATABITS-2*DATABITS +: DATABITS];
                                    next_state_vector_before_th[((2*j+1)*number_of_read+result_count)*DATABITS+:DATABITS] <= binadd[2*j+1][2*mat1binary*DATABITS-2*DATABITS +: DATABITS];
                                end
                             end
                         end
                         
                    end
                      
                default: 
                    begin
                
                    end
            
            endcase 
        end
    end
endmodule
