//btn7 播放歌曲 同时led闪烁   					 ---->pin124  ---->play
//btn0 切换工作模式 在DISP0上显示当前模式   	 ---->pin61   ---->mode
//btn2 选择乐曲编号 在DISP2上显示当前乐曲编号 ---->pin89   ---->music
//btn6 暂停播放音乐      						 ---->pin123  ---->rst

module ElecDoorBell(clk_1mhz, rst, rst2, play, beep, btn0, btn2, led, seg, loc, lcd_en, lcd_data, lcd_rw, lcd_rs );

input clk_1mhz, rst;		//clk_1mhz 系统时钟 ---->pin18   rst  重置 btn6 ---->pin123
input play; 				//btn7 播放歌曲 	 ---->pin124
input btn2;
input btn0;
input rst2;

output [15:0] led;
output beep;				//pin60 无源蜂鸣器
output [7:0] seg, loc;	//seg单个数码管 loc为数码管DISP位置

output lcd_en, lcd_rw, lcd_rs;   //lcd_en:液晶_使能,lcd_rw:液晶_读,lcd_rs:液晶_写																	
output [7:0]  lcd_data;				//lcd_data:液晶_数据,rst2:液晶_复位	
reg [7:0] lcd_data=0;
reg lcd_rs=0;
reg[5:0]c_state=0,n_state=0;
reg[127:0]row_1=0,row_2=0;
wire lcd_en,lcd_rw,rst2,rst2in;

wire btn0_debounce,btn2_debounce,play_1;


reg [7:0] seg=0, loc=0;
reg beep_flag=0;									

reg clk_1khz=0, clk_8hz=0, clk_500hz=0;

reg [19:0] cnt=0;       //led模块计数器
reg [15:0] cnt1=0;      //8hz的分频计数器
reg [8:0] cnt2=0;			//1khz的分频计数器
reg [7:0] cnt3=0;			//2khz的分频计数器

reg [3:0] high=0, mid=0, low=0;

reg [3:0] stime=4'b0;	//led闪烁时间控制计数器

reg [1:0] m_rst=0;       	//rst信号,复位时m=0
reg [2:0] music=3'b1;     	//五首音乐
reg [2:0] mode=3'b011;    	//四种工作状态

reg [10:0] divider=0, origin=0;   //origin 预置音调  divider 音调值
reg [9:0] counter = 0;

reg [4:0] counter6=0;
reg [4:0] counter7=0;
reg [7:0] cnt6=0;
reg [7:0] cnt7=0;

assign rst2in=~rst2;    //把按下时的上升沿变成下降沿


wire rin;					//执行代码时的复位信号
assign rin = ~rst;		//把按下时的上升沿变为下降沿,用于执行代码
wire carry;					//预置计数上限(数值由预置计数器上限决定)
assign carry=(divider==0);	//2^13-1=8191,carry只能取0或1


reg [2:0] play_mode=3'b011;
always@(posedge play_1)
begin
	play_mode<=mode;
end

//-----------------------工作模式转换----------------------
reg [5:0] turn=0;

always@(posedge btn0_debounce or posedge play_1)
	begin
		if(btn0_debounce)
			turn<=turn+1'b1;
		else if(play_1)
			turn<=6'b0;
	end

always@(posedge btn0_debounce)
	begin
		if(mode<4)
				mode<=mode+1'b1;
		else
				mode<=1;
	end
	
//-----------------------歌曲选择--------------------------

always@(posedge btn2_debounce)
	begin
		if(music<5)
			music<=music+1'b1;
		else
			music<=1;
	end

//-----------------------按键消抖-------------------------

key_debounce   u1 (clk_1mhz,play,play_1);    //播放键play消抖
key_debounce   u2 (clk_1mhz,btn0,btn0_debounce);
key_debounce   u3 (clk_1mhz,btn2,btn2_debounce);


//----------------------分频代码--------------------------

always@(posedge clk_1mhz)     //分频8hz
	begin
		if(cnt1<62499)				//1mhz/8hz = 125000 cnt1<[125000/2-1]=62499
			cnt1<=cnt1+1'b1;
		else
			begin
				cnt1<=0;
				clk_8hz=!clk_8hz;
			end
	end
	
always@(posedge clk_1mhz)		//分频1khz
	begin
		if(cnt2<499)				//1mhz/1khz = 1000 cnt2<[1000/2-1]=499
			cnt2<=cnt2+1'b1;
		else
			begin
				cnt2<=0;
				clk_1khz=!clk_1khz;
			end
	end

always@(posedge clk_1mhz)    //预置计数
	begin
		if(carry)            //如果divider=8191
			divider<=origin;     //返回到预置值
		else
			divider<=divider-1;  //迅速从预置值增加到8191
	end

	
always@(posedge carry)     //频率=2*音调频率的方波,产生振荡
	begin
		beep_flag<=~beep_flag;
	end

assign beep=beep_flag?1'b1:1'b0;
	
//------------------------led功能实现代码块--------------------------
reg [15:0]led=0;//16位LED状态寄存器
//assign led = led;

always@(posedge clk_1mhz or posedge play_1)
	begin
		if(play_1)
			begin
				cnt<=20'b0;
				stime<=4'b0;
			end
		else if (play_mode==1 || play_mode == 4 || mode==1 || mode==4 )
			begin
				cnt<=20'b0;
				stime<=4'b0;
			end
		else if(cnt==20'd1000000)
			begin
			cnt<=20'd0;
			if(play_mode==2)
				if(stime<=4'b0101)
					stime<=stime+1'b1;
				else
					stime<=4'b0101;
			else if(play_mode==3)
				if(play_mode == 2)
					stime<=4'b0101;
				else
					if(stime<=4'b1011)
						if(stime<=4'b0101)
							stime<=4'b0110;
						else
							stime<=stime+1'b1;
					else
						stime<=4'b1011;
			end
		else
			cnt<=cnt+1'b1;
	end
			
always@(posedge clk_1mhz )
	begin
			  if((play_mode==2 || play_mode==3))
					begin
					   if(mode==4 || mode==1 || turn>=1)
								led<=16'b0000000000000000;
						
						else if(stime==4'b000)
							led<=16'b1111111111110000;
						
						else if(cnt == 20'd1000000 & stime!=4'b0101 & stime!=4'b1011) //判断计数值是否达到50M（1s）
							led <= {led[3:0],led[15:4]}; //如果计数值达到50M（1s），LED状态寄存器移位
						else if(stime==4'b0101 || stime==4'b1011 )     //计数达到5s，LED关闭
							if(play_mode==3 && mode==3)
								led<={high,mid,low};
							else
								led <= 16'b0;
						else if(stime==4'b0110 & play_mode==3)
							led<=16'b1111111111110000;
					end
				else if(play_mode==1 || play_mode==4 || mode==1 || mode==4)
					if(play_mode==1 && mode==1)
						led<={high,mid,low};
					else
						led<=16'b0000000000000000;
	end


	
//--------------------------------音调设置---------------------------------	
always@(posedge clk_8hz)     //音调预置,原理是改变蜂鸣器振荡频率
	begin
		case({high,mid,low})
			'b000000000001:origin<=1911;//低音1(001)
			'b000000000010:origin<=1703;//2
			'b000000000011:origin<=1517;//3
			'b000000000100:origin<=1432;//4
			'b000000000101:origin<=1261;//5
			'b000000000110:origin<=1136;//6
			'b000000000111:origin<=1012;//7
			'b000000010000:origin<=956;//中音1(010)
			'b000000100000:origin<=851;//2
			'b000000110000:origin<=758;//3
			'b000001000000:origin<=716;//4
			'b000001010000:origin<=638;//5
			'b000001100000:origin<=568;//6
			'b000001110000:origin<=506;//7
			'b000100000000:origin<=478;//高音1(100)
			'b001000000000:origin<=426;//2
			'b001100000000:origin<=379;//3
			'b010000000000:origin<=358;//4
			'b010100000000:origin<=319;//5
			'b011000000000:origin<=284;//6
			'b011100000000:origin<=253;//7
			'b000000000000:origin<=0;//休止符
		endcase
	end
	
//--------------------------------功能设置----------------------------
always@(posedge play_1 or negedge rin)  //play_1是消抖后的play;模式计数
	begin
		if(!rin)    //按下rst复位
				m_rst<=0;   //复位信号
		else
				m_rst<=1;   //没有复位
	end
	
	
	//---------------------------------音乐---------------------------------

always@(posedge clk_8hz or posedge play_1 or posedge btn0_debounce or posedge btn2_debounce )             //音乐
begin       //1
if(play_1 )
	if(m_rst==0)
		{high,mid,low}<='b000000000000;   //蜂鸣器静默
	else
		counter<=0;
else if(btn0_debounce || btn2_debounce)
	counter<=500;
else if(m_rst==0)
begin       //2
                //数码管不显示
{high,mid,low}<='b000000000000;   //蜂鸣器静默
end         //2
else
begin       //2
if(music==1 && (mode==1 || mode==3))    //生日快乐歌
begin       //3
if(counter>122)
	{high,mid,low}<='b000000000000;   //蜂鸣器静默
else
counter<=counter+1;
case(counter)
0: {high,mid,low}<='b000001010000;//050
1: {high,mid,low}<='b000001010000;
2: {high,mid,low}<='b000001010000;//050
3: {high,mid,low}<='b000001010000;
4: {high,mid,low}<='b000001100000;//060
5: {high,mid,low}<='b000001100000;
6: {high,mid,low}<='b000001100000;
7: {high,mid,low}<='b000001100000;
8: {high,mid,low}<='b000001010000;//050
9: {high,mid,low}<='b000001010000;
10: {high,mid,low}<='b000001010000;
11: {high,mid,low}<='b000001010000;
12: {high,mid,low}<='b000100000000;//100
13: {high,mid,low}<='b000100000000;
14: {high,mid,low}<='b000100000000;
15: {high,mid,low}<='b000100000000;
16: {high,mid,low}<='b000001110000;//070
17: {high,mid,low}<='b000001110000;
18: {high,mid,low}<='b000001110000;
19: {high,mid,low}<='b000001110000;
20: {high,mid,low}<='b000001110000;
21: {high,mid,low}<='b000001110000;
22: {high,mid,low}<='b000001110000;
23: {high,mid,low}<='b000001110000;
24: {high,mid,low}<='b000001010000;//050
25: {high,mid,low}<='b000001010000;
26: {high,mid,low}<='b000001010000;//050
27: {high,mid,low}<='b000001010000;
28: {high,mid,low}<='b000001100000;//060
29: {high,mid,low}<='b000001100000;
30: {high,mid,low}<='b000001100000;
31: {high,mid,low}<='b000001100000;
32: {high,mid,low}<='b000001010000;//050
33: {high,mid,low}<='b000001010000;
34: {high,mid,low}<='b000001010000;
35: {high,mid,low}<='b000001010000;
36: {high,mid,low}<='b001000000000;//200
37: {high,mid,low}<='b001000000000;
38: {high,mid,low}<='b001000000000;
39: {high,mid,low}<='b001000000000;
40: {high,mid,low}<='b000100000000;//100
41: {high,mid,low}<='b000100000000;
42: {high,mid,low}<='b000100000000;
43: {high,mid,low}<='b000100000000;
44: {high,mid,low}<='b000100000000;
45: {high,mid,low}<='b000100000000;
46: {high,mid,low}<='b000100000000;
47: {high,mid,low}<='b000100000000;
48: {high,mid,low}<='b000001010000;//050
49: {high,mid,low}<='b000001010000;
50: {high,mid,low}<='b000001010000;//050
51: {high,mid,low}<='b000001010000;
52: {high,mid,low}<='b010100000000;//500
53: {high,mid,low}<='b010100000000;
54: {high,mid,low}<='b010100000000;
55: {high,mid,low}<='b010100000000;
56: {high,mid,low}<='b001100000000;//300
57: {high,mid,low}<='b001100000000;
58: {high,mid,low}<='b001100000000;
59: {high,mid,low}<='b001100000000;
60: {high,mid,low}<='b000100000000;//100
61: {high,mid,low}<='b000100000000;
62: {high,mid,low}<='b000100000000;
63: {high,mid,low}<='b000100000000;
64: {high,mid,low}<='b000001110000;//070
65: {high,mid,low}<='b000001110000;
66: {high,mid,low}<='b000001110000;
67: {high,mid,low}<='b000001110000;
68: {high,mid,low}<='b000001100000;//060
69: {high,mid,low}<='b000001100000;
70: {high,mid,low}<='b000001100000;
71: {high,mid,low}<='b000001100000;
72: {high,mid,low}<='b000001100000;
73: {high,mid,low}<='b000001100000;
74: {high,mid,low}<='b000001100000;
75: {high,mid,low}<='b000001100000;
76: {high,mid,low}<='b000000000000;//000
77: {high,mid,low}<='b000000000000;
78: {high,mid,low}<='b000000000000;
79: {high,mid,low}<='b000000000000;
80: {high,mid,low}<='b000000000000;//000
81: {high,mid,low}<='b000000000000;
82: {high,mid,low}<='b000000000000;
83: {high,mid,low}<='b000000000000;
84: {high,mid,low}<='b010000000000;//400
85: {high,mid,low}<='b010000000000;
86: {high,mid,low}<='b010000000000;//400
87: {high,mid,low}<='b010000000000;
88: {high,mid,low}<='b001100000000;//300
89: {high,mid,low}<='b001100000000;
90: {high,mid,low}<='b001100000000;
91: {high,mid,low}<='b001100000000;
92: {high,mid,low}<='b000100000000;//100
93: {high,mid,low}<='b000100000000;
94: {high,mid,low}<='b000100000000;
95: {high,mid,low}<='b000100000000;
96: {high,mid,low}<='b001000000000;//200
97: {high,mid,low}<='b001000000000;
98: {high,mid,low}<='b001000000000;
99: {high,mid,low}<='b001000000000;
100: {high,mid,low}<='b000100000000;//100
101: {high,mid,low}<='b000100000000;
102: {high,mid,low}<='b000100000000;
103: {high,mid,low}<='b000100000000;
104: {high,mid,low}<='b000100000000;
105: {high,mid,low}<='b000100000000;
106: {high,mid,low}<='b000100000000;
107: {high,mid,low}<='b000100000000;
108: {high,mid,low}<='b000100000000;
109: {high,mid,low}<='b000100000000;
110: {high,mid,low}<='b000100000000;
111: {high,mid,low}<='b000100000000;
112: {high,mid,low}<='b000100000000;
113: {high,mid,low}<='b000100000000;
114: {high,mid,low}<='b000100000000;
115: {high,mid,low}<='b000100000000;
116: {high,mid,low}<='b000100000000;
117: {high,mid,low}<='b000100000000;
118: {high,mid,low}<='b000100000000;
119: {high,mid,low}<='b000100000000;
120: {high,mid,low}<='b000000000000;//000
121: {high,mid,low}<='b000000000000;
122: {high,mid,low}<='b000000000000;
123: {high,mid,low}<='b000000000000;
endcase
end       //3
else if(music==2 && (mode==1 || mode==3))  //春节序曲
begin     //3
if(counter>100)
	{high,mid,low}<='b000000000000;   //蜂鸣器静默
else
counter<=counter+1;
case(counter)
0: {high,mid,low}<='b001100000000;//300  开头
1: {high,mid,low}<='b001100000000;
2: {high,mid,low}<='b001100000000;//300
3: {high,mid,low}<='b001000000000;//200
4: {high,mid,low}<='b000100000000;//100
5: {high,mid,low}<='b000100000000;
6: {high,mid,low}<='b000100000000;
7: {high,mid,low}<='b000100000000;
8: {high,mid,low}<='b001100000000;//300
9: {high,mid,low}<='b001100000000;
10: {high,mid,low}<='b001100000000;//300
11: {high,mid,low}<='b001000000000;//200
12: {high,mid,low}<='b000100000000;//100
13: {high,mid,low}<='b000100000000;
14: {high,mid,low}<='b000100000000;
15: {high,mid,low}<='b000100000000;
16: {high,mid,low}<='b001100000000;//300
17: {high,mid,low}<='b001100000000;
18: {high,mid,low}<='b001100000000;//300
19: {high,mid,low}<='b001000000000;//200
20: {high,mid,low}<='b000100000000;//100
21: {high,mid,low}<='b000100000000;
22: {high,mid,low}<='b000001010000;//050
23: {high,mid,low}<='b000001010000;
24: {high,mid,low}<='b000000110000;//030
25: {high,mid,low}<='b000000110000;
26: {high,mid,low}<='b000001100000;//060
27: {high,mid,low}<='b000001100000;
28: {high,mid,low}<='b000001010000;//050
29: {high,mid,low}<='b000001010000;
30: {high,mid,low}<='b000001010000;
31: {high,mid,low}<='b000001100000;//060
32: {high,mid,low}<='b000001010000;//050
33: {high,mid,low}<='b000001010000;
34: {high,mid,low}<='b000001100000;//060
35: {high,mid,low}<='b000001100000;
36: {high,mid,low}<='b000001010000;//050
37: {high,mid,low}<='b000001010000;
38: {high,mid,low}<='b000001010000;
39: {high,mid,low}<='b000001100000;//060
40: {high,mid,low}<='b000001010000;//050
41: {high,mid,low}<='b000001010000;
42: {high,mid,low}<='b000001100000;//060
43: {high,mid,low}<='b000001100000;
44: {high,mid,low}<='b000001010000;//050
45: {high,mid,low}<='b000001010000;
46: {high,mid,low}<='b000001110000;//070
47: {high,mid,low}<='b000001100000;//060
48: {high,mid,low}<='b000001010000;//050
49: {high,mid,low}<='b000001010000;
50: {high,mid,low}<='b000001110000;//070
51: {high,mid,low}<='b000001100000;//060
52: {high,mid,low}<='b000001010000;//050
53: {high,mid,low}<='b000001010000;
54: {high,mid,low}<='b000001110000;//070
55: {high,mid,low}<='b000001100000;//060
56: {high,mid,low}<='b000001010000;//050
57: {high,mid,low}<='b000001010000;
58: {high,mid,low}<='b000001110000;//070
59: {high,mid,low}<='b000001100000;//060
60: {high,mid,low}<='b000001010000;//050
61: {high,mid,low}<='b000001100000;//060
62: {high,mid,low}<='b000001110000;//070
63: {high,mid,low}<='b000001100000;//060
64: {high,mid,low}<='b000001010000;//050
65: {high,mid,low}<='b000001100000;//060
66: {high,mid,low}<='b000001110000;//070
67: {high,mid,low}<='b000001100000;//060
68: {high,mid,low}<='b000001010000;//050
69: {high,mid,low}<='b000001100000;//060
70: {high,mid,low}<='b000001110000;//070
71: {high,mid,low}<='b000001100000;//060
72: {high,mid,low}<='b000001010000;//050
73: {high,mid,low}<='b000001100000;//060
74: {high,mid,low}<='b000001110000;//070
75: {high,mid,low}<='b000001100000;//060
76: {high,mid,low}<='b000001010000;//050
77: {high,mid,low}<='b000001010000;
78: {high,mid,low}<='b000001010000;
79: {high,mid,low}<='b000000000000;//000
80: {high,mid,low}<='b000001010000;//050
81: {high,mid,low}<='b000001010000;
82: {high,mid,low}<='b000001010000;
83: {high,mid,low}<='b000000000000;//000
84: {high,mid,low}<='b000001010000;//050
85: {high,mid,low}<='b000001010000;
86: {high,mid,low}<='b000001010000;
87: {high,mid,low}<='b000001010000;
88: {high,mid,low}<='b000001010000;
89: {high,mid,low}<='b000001010000;
90: {high,mid,low}<='b000001010000;
91: {high,mid,low}<='b000000000000;//000
92: {high,mid,low}<='b000001010000;//050  引子
93: {high,mid,low}<='b000001010000;
94: {high,mid,low}<='b000001010000;//050
95: {high,mid,low}<='b000001100000;//060
96: {high,mid,low}<='b000001010000;//050
97: {high,mid,low}<='b000001010000;
98: {high,mid,low}<='b000000000000;//050
99: {high,mid,low}<='b000000000000;//060
100: {high,mid,low}<='b000000000000;//100
101: {high,mid,low}<='b000000000000;
endcase
end       //3
else if(music==3 && (mode==1 || mode==3))
begin
if(counter>90)
	{high,mid,low}<='b000000000000;   //蜂鸣器静默
else
counter<=counter+1;
case(counter)
0: {high,mid,low}<='b000001010000;//060  开头
1: {high,mid,low}<='b000001010000;
2: {high,mid,low}<='b000001010000;
3: {high,mid,low}<='b000001010000;
4: {high,mid,low}<='b000001110000;//070
5: {high,mid,low}<='b000001110000;
6: {high,mid,low}<='b000001110000;
7: {high,mid,low}<='b000001110000;
8: {high,mid,low}<='b000001110000;//070
9: {high,mid,low}<='b000001110000;
10: {high,mid,low}<='b000001110000;//070
11: {high,mid,low}<='b000001110000;
12: {high,mid,low}<='b000100000000;//100
13: {high,mid,low}<='b000100000000;
14: {high,mid,low}<='b000100000000;//100
15: {high,mid,low}<='b000100000000;
16: {high,mid,low}<='b000100000000;//100
17: {high,mid,low}<='b000100000000;
18: {high,mid,low}<='b000001110000;//070
19: {high,mid,low}<='b000001110000;
20: {high,mid,low}<='b000001110000;
21: {high,mid,low}<='b000001110000;
22: {high,mid,low}<='b000001110000;//700
23: {high,mid,low}<='b000001110000;
24: {high,mid,low}<='b001000000000;//070
25: {high,mid,low}<='b000001110000;
26: {high,mid,low}<='b000001010000;//060
27: {high,mid,low}<='b000001010000;
28: {high,mid,low}<='b000001010000;
29: {high,mid,low}<='b000001010000;
30: {high,mid,low}<='b000000110000;//030
31: {high,mid,low}<='b000000110000;
32: {high,mid,low}<='b000000110000;
33: {high,mid,low}<='b000000110000;
34: {high,mid,low}<='b000000110000;
35: {high,mid,low}<='b000000110000;
36: {high,mid,low}<='b000000110000;
37: {high,mid,low}<='b000000110000;
38: {high,mid,low}<='b000000110000;
39: {high,mid,low}<='b000000110000;
40: {high,mid,low}<='b000000110000;
41: {high,mid,low}<='b000000110000;
42: {high,mid,low}<='b000000110000;//030
43: {high,mid,low}<='b000000110000;
44: {high,mid,low}<='b000001010000;//060  开头
45: {high,mid,low}<='b000001010000;
46: {high,mid,low}<='b000001010000;
47: {high,mid,low}<='b000001010000;
48: {high,mid,low}<='b000001110000;//070
49: {high,mid,low}<='b000001110000;
50: {high,mid,low}<='b000001110000;
51: {high,mid,low}<='b000001110000;
52: {high,mid,low}<='b000001110000;//070
53: {high,mid,low}<='b000001110000;
54: {high,mid,low}<='b000001110000;//070
55: {high,mid,low}<='b000001110000;
56: {high,mid,low}<='b000100000000;//100
57: {high,mid,low}<='b000100000000;
58: {high,mid,low}<='b000100000000;//100
59: {high,mid,low}<='b000100000000;
60: {high,mid,low}<='b000100000000;//100
61: {high,mid,low}<='b000100000000;
62: {high,mid,low}<='b000001110000;//070
63: {high,mid,low}<='b000001110000;
64: {high,mid,low}<='b000001110000;
65: {high,mid,low}<='b000001110000;
66: {high,mid,low}<='b000001110000;//700
67: {high,mid,low}<='b000001110000;
68: {high,mid,low}<='b001000000000;//070
69: {high,mid,low}<='b000001110000;
70: {high,mid,low}<='b000001010000;//060
71: {high,mid,low}<='b000001010000;
72: {high,mid,low}<='b000001010000;
73: {high,mid,low}<='b000001010000;
74: {high,mid,low}<='b000000110000;//030
75: {high,mid,low}<='b000000110000;
76: {high,mid,low}<='b000000110000;
77: {high,mid,low}<='b000000110000;
78: {high,mid,low}<='b000000110000;
79: {high,mid,low}<='b000000110000;
80: {high,mid,low}<='b000000110000;
81: {high,mid,low}<='b000000110000;
82: {high,mid,low}<='b000000110000;
83: {high,mid,low}<='b000000110000;
84: {high,mid,low}<='b000000110000;
85: {high,mid,low}<='b000000110000;
86: {high,mid,low}<='b000000110000;//030
87: {high,mid,low}<='b000000110000;
88: {high,mid,low}<='b000000000000;//050
89: {high,mid,low}<='b000000000000;
90: {high,mid,low}<='b000000000000;
91: {high,mid,low}<='b000000000000;
endcase
end
else if(music==4 && (mode==1 || mode==3))   //彩云追月
begin     //3
if(counter>100)
	{high,mid,low}<='b000000000000;  //蜂鸣器静默
else
counter<=counter+1;
case(counter)
0: {high,mid,low}<='b000000000101;//005
1: {high,mid,low}<='b000000000101;
2: {high,mid,low}<='b000000000101;
3: {high,mid,low}<='b000000000101;
4: {high,mid,low}<='b000000000101;
5: {high,mid,low}<='b000000000101;
6: {high,mid,low}<='b000000000110;//006
7: {high,mid,low}<='b000000000110;
8: {high,mid,low}<='b000000010000;//010
9: {high,mid,low}<='b000000010000;
10: {high,mid,low}<='b000000100000;//020
11: {high,mid,low}<='b000000100000;
12: {high,mid,low}<='b000000110000;//030
13: {high,mid,low}<='b000000110000;
14: {high,mid,low}<='b000001010000;//050
15: {high,mid,low}<='b000001010000;
16: {high,mid,low}<='b000001100000;//060
17: {high,mid,low}<='b000001100000;
18: {high,mid,low}<='b000001100000;
19: {high,mid,low}<='b000001100000;
20: {high,mid,low}<='b000001100000;
21: {high,mid,low}<='b000001100000;
22: {high,mid,low}<='b000001100000;
23: {high,mid,low}<='b000001100000;
24: {high,mid,low}<='b000001100000;
25: {high,mid,low}<='b000001100000;
26: {high,mid,low}<='b000001100000;
27: {high,mid,low}<='b000001100000;
28: {high,mid,low}<='b000001100000;
29: {high,mid,low}<='b000001100000;
30: {high,mid,low}<='b000000000000;//000
31: {high,mid,low}<='b000000000000;
32: {high,mid,low}<='b000001100000;//060
33: {high,mid,low}<='b000001100000;
34: {high,mid,low}<='b000100000000;//100
35: {high,mid,low}<='b000100000000;
36: {high,mid,low}<='b000100000000;
37: {high,mid,low}<='b000100000000;
38: {high,mid,low}<='b000001100000;//060
39: {high,mid,low}<='b000001100000;
40: {high,mid,low}<='b000001010000;//050
41: {high,mid,low}<='b000001010000;
42: {high,mid,low}<='b000000110000;//030
43: {high,mid,low}<='b000000110000;
44: {high,mid,low}<='b000001010000;//050
45: {high,mid,low}<='b000001010000;
46: {high,mid,low}<='b000001010000;
47: {high,mid,low}<='b000001010000;
48: {high,mid,low}<='b000001100000;//060
49: {high,mid,low}<='b000001100000;
50: {high,mid,low}<='b000100000000;//100
51: {high,mid,low}<='b000100000000;
52: {high,mid,low}<='b000100000000;
53: {high,mid,low}<='b000100000000;
54: {high,mid,low}<='b000001100000;//060
55: {high,mid,low}<='b000001100000;
56: {high,mid,low}<='b000001010000;//050
57: {high,mid,low}<='b000001010000;
58: {high,mid,low}<='b000000110000;//030
59: {high,mid,low}<='b000000110000;
60: {high,mid,low}<='b000001010000;//050
61: {high,mid,low}<='b000001010000;
62: {high,mid,low}<='b000001010000;
63: {high,mid,low}<='b000001010000;
64: {high,mid,low}<='b000001100000;//060
65: {high,mid,low}<='b000001100000;
66: {high,mid,low}<='b000100000000;//100
67: {high,mid,low}<='b000100000000;
68: {high,mid,low}<='b000100000000;
69: {high,mid,low}<='b000100000000;
70: {high,mid,low}<='b000001100000;//060
71: {high,mid,low}<='b000001100000;
72: {high,mid,low}<='b000001010000;//050
73: {high,mid,low}<='b000001010000;
74: {high,mid,low}<='b000000110000;//030
75: {high,mid,low}<='b000000110000;
76: {high,mid,low}<='b000001010000;//050
77: {high,mid,low}<='b000001010000;
78: {high,mid,low}<='b000001100000;//060
79: {high,mid,low}<='b000001100000;
80: {high,mid,low}<='b000001010000;//050
81: {high,mid,low}<='b000001010000;//030
82: {high,mid,low}<='b000000110000;
83: {high,mid,low}<='b000000110000;
84: {high,mid,low}<='b000000110000;
85: {high,mid,low}<='b000000110000;
86: {high,mid,low}<='b000000110000;
87: {high,mid,low}<='b000000110000;
88: {high,mid,low}<='b000000110000;
89: {high,mid,low}<='b000000110000;
90: {high,mid,low}<='b000000110000;
91: {high,mid,low}<='b000000110000;
92: {high,mid,low}<='b000000110000;
93: {high,mid,low}<='b000000110000;
94: {high,mid,low}<='b000000000000;//000
95: {high,mid,low}<='b000000000000;
96: {high,mid,low}<='b000000110000;//030
97: {high,mid,low}<='b000000110000;
98: {high,mid,low}<='b000000000000;//050
99: {high,mid,low}<='b000000000000;
100: {high,mid,low}<='b000000000000;
101: {high,mid,low}<='b000000000000;

endcase
end      //3
else if(music==5 && (mode==1 || mode==3))  //祝你圣诞快乐
begin    //3
if(counter>194)
	{high,mid,low}<='b000000000000; //蜂鸣器静默
else
counter<=counter+1;
case(counter)
0: {high,mid,low}<='b000001010000;//050
1: {high,mid,low}<='b000001010000;
2: {high,mid,low}<='b000001010000;
3: {high,mid,low}<='b000001010000;
4: {high,mid,low}<='b000100000000;//100
5: {high,mid,low}<='b000100000000;
6: {high,mid,low}<='b000100000000;
7: {high,mid,low}<='b000100000000;
8: {high,mid,low}<='b000100000000;//100
9: {high,mid,low}<='b000100000000;
10: {high,mid,low}<='b001000000000;//200
11: {high,mid,low}<='b001000000000;
12: {high,mid,low}<='b000100000000;//100
13: {high,mid,low}<='b000100000000;
14: {high,mid,low}<='b000001110000;//070
15: {high,mid,low}<='b000001110000;
16: {high,mid,low}<='b000001100000;//060
17: {high,mid,low}<='b000001100000;
18: {high,mid,low}<='b000001100000;
19: {high,mid,low}<='b000001100000;
20: {high,mid,low}<='b000001100000;//060
21: {high,mid,low}<='b000001100000;
22: {high,mid,low}<='b000001100000;
23: {high,mid,low}<='b000000000000;//000
24: {high,mid,low}<='b000001100000;//060
25: {high,mid,low}<='b000001100000;
26: {high,mid,low}<='b000001100000;
27: {high,mid,low}<='b000001100000;
28: {high,mid,low}<='b001000000000;//200
29: {high,mid,low}<='b001000000000;
30: {high,mid,low}<='b001000000000;
31: {high,mid,low}<='b001000000000;
32: {high,mid,low}<='b001000000000;//200
33: {high,mid,low}<='b001000000000;
34: {high,mid,low}<='b001100000000;//300
35: {high,mid,low}<='b001100000000;
36: {high,mid,low}<='b001000000000;//200
37: {high,mid,low}<='b001000000000;
38: {high,mid,low}<='b000100000000;//100
39: {high,mid,low}<='b000100000000;
40: {high,mid,low}<='b000001110000;//070
41: {high,mid,low}<='b000001110000;
42: {high,mid,low}<='b000001110000;
43: {high,mid,low}<='b000001110000;
44: {high,mid,low}<='b000001010000;//050
45: {high,mid,low}<='b000001010000;
46: {high,mid,low}<='b000001010000;
47: {high,mid,low}<='b000000000000;//000
48: {high,mid,low}<='b000001010000;//050
49: {high,mid,low}<='b000001010000;
50: {high,mid,low}<='b000001010000;
51: {high,mid,low}<='b000001010000;
52: {high,mid,low}<='b001100000000;//300
53: {high,mid,low}<='b001100000000;
54: {high,mid,low}<='b001100000000;
55: {high,mid,low}<='b001100000000;
56: {high,mid,low}<='b001100000000;//300
57: {high,mid,low}<='b001100000000;
58: {high,mid,low}<='b010000000000;//400
59: {high,mid,low}<='b010000000000;
60: {high,mid,low}<='b001100000000;//300
61: {high,mid,low}<='b001100000000;
62: {high,mid,low}<='b001000000000;//200
63: {high,mid,low}<='b001000000000;
64: {high,mid,low}<='b000100000000;//100
65: {high,mid,low}<='b000100000000;
66: {high,mid,low}<='b000100000000;
67: {high,mid,low}<='b000100000000;
68: {high,mid,low}<='b000001100000;//060
69: {high,mid,low}<='b000001100000;
70: {high,mid,low}<='b000001100000;
71: {high,mid,low}<='b000001100000;
72: {high,mid,low}<='b000001010000;//050
73: {high,mid,low}<='b000001010000;
74: {high,mid,low}<='b000001010000;//050
75: {high,mid,low}<='b000001010000;
76: {high,mid,low}<='b000001100000;//060
77: {high,mid,low}<='b000001100000;
78: {high,mid,low}<='b000001100000;
79: {high,mid,low}<='b000001100000;
80: {high,mid,low}<='b001000000000;//200
81: {high,mid,low}<='b001000000000;
82: {high,mid,low}<='b001000000000;
83: {high,mid,low}<='b001000000000;
84: {high,mid,low}<='b000001110000;//070
85: {high,mid,low}<='b000001110000;
86: {high,mid,low}<='b000001110000;
87: {high,mid,low}<='b000001110000;
88: {high,mid,low}<='b000100000000;//100
89: {high,mid,low}<='b000100000000;
90: {high,mid,low}<='b000100000000;
91: {high,mid,low}<='b000100000000;
92: {high,mid,low}<='b000100000000;
93: {high,mid,low}<='b000100000000;
94: {high,mid,low}<='b000100000000;
95: {high,mid,low}<='b000000000000;//000
96: {high,mid,low}<='b000001010000;//050
97: {high,mid,low}<='b000001010000;
98: {high,mid,low}<='b000001010000;
99: {high,mid,low}<='b000001010000;
100: {high,mid,low}<='b000100000000;//100
101: {high,mid,low}<='b000100000000;
102: {high,mid,low}<='b000100000000;
103: {high,mid,low}<='b000100000000;
104: {high,mid,low}<='b000100000000;//100
105: {high,mid,low}<='b000100000000;
106: {high,mid,low}<='b000100000000;
107: {high,mid,low}<='b000100000000;
108: {high,mid,low}<='b000100000000;//100
109: {high,mid,low}<='b000100000000;
110: {high,mid,low}<='b000100000000;
111: {high,mid,low}<='b000100000000;
112: {high,mid,low}<='b000001110000;//070
113: {high,mid,low}<='b000001110000;
114: {high,mid,low}<='b000001110000;
115: {high,mid,low}<='b000001110000;
116: {high,mid,low}<='b000001110000;
117: {high,mid,low}<='b000001110000;
118: {high,mid,low}<='b000001110000;
119: {high,mid,low}<='b000000000000;//000
120: {high,mid,low}<='b000001110000;//070
121: {high,mid,low}<='b000001110000;
122: {high,mid,low}<='b000001110000;
123: {high,mid,low}<='b000001110000;
124: {high,mid,low}<='b000100000000;//100
125: {high,mid,low}<='b000100000000;
126: {high,mid,low}<='b000100000000;
127: {high,mid,low}<='b000100000000;
128: {high,mid,low}<='b000001110000;//070
129: {high,mid,low}<='b000001110000;
130: {high,mid,low}<='b000001110000;
131: {high,mid,low}<='b000001110000;
132: {high,mid,low}<='b000001100000;//060
133: {high,mid,low}<='b000001100000;
134: {high,mid,low}<='b000001100000;
135: {high,mid,low}<='b000001100000;
136: {high,mid,low}<='b000001010000;//050
137: {high,mid,low}<='b000001010000;
138: {high,mid,low}<='b000001010000;
139: {high,mid,low}<='b000001010000;
140: {high,mid,low}<='b000001010000;
141: {high,mid,low}<='b000001010000;
142: {high,mid,low}<='b000001010000;
143: {high,mid,low}<='b000000000000;//000
144: {high,mid,low}<='b001000000000;//200
145: {high,mid,low}<='b001000000000;
146: {high,mid,low}<='b001000000000;
147: {high,mid,low}<='b001000000000;
148: {high,mid,low}<='b001100000000;//300
149: {high,mid,low}<='b001100000000;
150: {high,mid,low}<='b001100000000;
151: {high,mid,low}<='b001100000000;
152: {high,mid,low}<='b001000000000;//200
153: {high,mid,low}<='b001000000000;
154: {high,mid,low}<='b001000000000;
155: {high,mid,low}<='b001000000000;
156: {high,mid,low}<='b000100000000;//100
157: {high,mid,low}<='b000100000000;
158: {high,mid,low}<='b000100000000;
159: {high,mid,low}<='b000100000000;
160: {high,mid,low}<='b000001010000;//500
161: {high,mid,low}<='b000001010000;
162: {high,mid,low}<='b000001010000;
163: {high,mid,low}<='b000001010000;
164: {high,mid,low}<='b000001010000;//050
165: {high,mid,low}<='b000001010000;
166: {high,mid,low}<='b000001010000;
167: {high,mid,low}<='b000001010000;
168: {high,mid,low}<='b000001010000;//050
169: {high,mid,low}<='b000001010000;
170: {high,mid,low}<='b000001010000;//050
171: {high,mid,low}<='b000001010000;
172: {high,mid,low}<='b000001100000;//060
173: {high,mid,low}<='b000001100000;
174: {high,mid,low}<='b000001100000;
175: {high,mid,low}<='b000001100000;
176: {high,mid,low}<='b001000000000;//200
177: {high,mid,low}<='b001000000000;
178: {high,mid,low}<='b001000000000;
179: {high,mid,low}<='b001000000000;
180: {high,mid,low}<='b000001110000;//070
181: {high,mid,low}<='b000001110000;
182: {high,mid,low}<='b000001110000;
183: {high,mid,low}<='b000001110000;
184: {high,mid,low}<='b000100000000;//100
185: {high,mid,low}<='b000100000000;
186: {high,mid,low}<='b000100000000;
187: {high,mid,low}<='b000100000000;
188: {high,mid,low}<='b000100000000;
189: {high,mid,low}<='b000100000000;
190: {high,mid,low}<='b000100000000;
191: {high,mid,low}<='b000100000000;
192: {high,mid,low}<='b000000000000;
193: {high,mid,low}<='b000000000000;
194: {high,mid,low}<='b000000000000;//000
195: {high,mid,low}<='b000000000000;
endcase
			end       //3
	else
	{high,mid,low}<='b000000000000;
		end       //2
	end       //1


	
	
//———————————————————————————————数码管准备———————————————————----———————
//数码管准备
//loc[0]---->pin63    ---->DISP0
//loc[2]---->pin67    ---->DISP2
always@(posedge clk_1khz)   //数码管准备
	begin
		case(cnt6)
			//需要写5个部分，每部分1个begin;
			//rst:不亮
			8'b10000000:   //rst:100_00xxx;mode0,1,2,3:0xx_00xxx(xxx为loc编码)
				begin 
					seg<=8'b00000000;    //并联(两管同时显示不同数字需分频
					loc<=8'b11111111;    //seg:1=亮;loc:0=亮
				end
			//mode1:bc=1
			8'b01000011:
				begin 
					seg<=8'b00000110;   //seg[0]->seg[7] 为 abcdefg
					loc<=8'b11111110;	  //loc[0]->loc[7] 为 DISP7->DISP0;
				end
			//mode2:abdeg=1
			8'b01100011:
				begin 
					seg<=8'b01011011;
					loc<=8'b11111110;
				end
			//mode3:abcdg=1
			8'b00100011:
				begin 
					seg<=8'b01001111;
					loc<=8'b11111110;
				end
			//mode4:bcfg=1
			8'b00000011:
				begin 
					seg<=8'b01100110;
					loc<=8'b11111110;
				end
			//music控制模块   无论mode为何值, cnt6的music分频都占一半 
			8'b11111111:
				begin
					//seg<=8'b00000110;
					loc<=8'b11111011;
					case(music)
						1: seg<=8'b00000110;   			//music1
						2: seg<=8'b01011011;     		//music2
						3: seg<=8'b01001111;	 			//music3										
						4: seg<=8'b01100110;  			//music4
						5: seg<=8'b01101101;	 			//music5
					endcase
				end
		endcase
	end
	
always@(posedge clk_1khz)           //数码管执行
	begin       //1	
				if(mode==1)
					begin     //3
						if(counter6==7)
							counter6<=0;
						else
							counter6<=counter6+1;
							
						case(counter6)
							0: cnt6<=8'b01000011;
							1: cnt6<=8'b01000011;
							2: cnt6<=8'b01000011;
							3: cnt6<=8'b01000011;
							4: cnt6<=8'b11111111;
							5: cnt6<=8'b11111111;
							6: cnt6<=8'b11111111;
							7: cnt6<=8'b11111111;
						endcase
					end       //3
					
				else if(mode==2)
					begin     //3
						if(counter6==7)
							counter6<=0;
						else
							counter6<=counter6+1;
							
						case(counter6)
							0: cnt6<=8'b01100011;
							1: cnt6<=8'b01100011;
							2: cnt6<=8'b01100011;
							3: cnt6<=8'b01100011;
							4: cnt6<=8'b11111111;
							5: cnt6<=8'b11111111;
							6: cnt6<=8'b11111111;
							7: cnt6<=8'b11111111;
						endcase
					end      //3
					
				else if(mode==3)
					begin    //3
						if(counter6==7)
							counter6<=0;
						else
							counter6<=counter6+1;
							
						case(counter6)
							0: cnt6<=8'b00100011;
							1: cnt6<=8'b00100011;
							2: cnt6<=8'b00100011;
							3: cnt6<=8'b00100011;
							4: cnt6<=8'b11111111;
							5: cnt6<=8'b11111111;
							6: cnt6<=8'b11111111;
							7: cnt6<=8'b11111111;
						endcase
					end       //3
					
				else if(mode==4)
					begin       //3
						if(counter6==7)
							counter6<=0;
						else
							counter6<=counter6+1;
							
						case(counter6)
							0: cnt6<=8'b00000011;
							1: cnt6<=8'b00000011;
							2: cnt6<=8'b00000011;
							3: cnt6<=8'b00000011;
							4: cnt6<=8'b11111111;
							5: cnt6<=8'b11111111;
							6: cnt6<=8'b11111111;
							7: cnt6<=8'b11111111;
						endcase
					end       //3
//			end       //2
	end       //1
	
	
//----------------------------------液晶模块----------------------------
//——————————————————————————————————————————————————————————————————————
parameter t_20ms=20000;    //1Mhz/50Hz=20000 开机延时准备
parameter t_500hz=2000;    //液晶分频准备
parameter         IDLE=    8'h00  ;  //共40个状态,采用格雷码,一次只有1位发生改变。00 01 03 02                      
parameter SET_FUNCTION=    8'h01  ;  //此处编码与ASCII码对应,液晶可接受ASCII码信息    
parameter     DISP_OFF=    8'h03  ;
parameter   DISP_CLEAR=    8'h02  ;
parameter   ENTRY_MODE=    8'h06  ;
parameter   DISP_ON   =    8'h07  ;
parameter    ROW1_ADDR=    8'h05  ;       
parameter       ROW1_0=    8'h04  ;
parameter       ROW1_1=    8'h0C  ;
parameter       ROW1_2=    8'h0D  ;
parameter       ROW1_3=    8'h0F  ;
parameter       ROW1_4=    8'h0E  ;
parameter       ROW1_5=    8'h0A  ;
parameter       ROW1_6=    8'h0B  ;
parameter       ROW1_7=    8'h09  ;
parameter       ROW1_8=    8'h08  ;
parameter       ROW1_9=    8'h18  ;
parameter       ROW1_A=    8'h19  ;
parameter       ROW1_B=    8'h1B  ;
parameter       ROW1_C=    8'h1A  ;
parameter       ROW1_D=    8'h1E  ;
parameter       ROW1_E=    8'h1F  ;
parameter       ROW1_F=    8'h1D  ;
parameter    ROW2_ADDR=    8'h1C  ;
parameter       ROW2_0=    8'h14  ;
parameter       ROW2_1=    8'h15  ;
parameter       ROW2_2=    8'h17  ;
parameter       ROW2_3=    8'h16  ;
parameter       ROW2_4=    8'h12  ;
parameter       ROW2_5=    8'h13  ;
parameter       ROW2_6=    8'h11  ;
parameter       ROW2_7=    8'h10  ;
parameter       ROW2_8=    8'h30  ;
parameter       ROW2_9=    8'h31  ;
parameter       ROW2_A=    8'h33  ;
parameter       ROW2_B=    8'h32  ;
parameter       ROW2_C=    8'h36  ;
parameter       ROW2_D=    8'h37  ;
parameter       ROW2_E=    8'h35  ;
parameter       ROW2_F=    8'h34  ;

//20ms的计数器，即初始化第一步     //1mhz/500hz = 2000 cnt<[2000/2-1] = 999
reg [19:0] cnt_20ms=0 ;
always  @(posedge clk_1mhz or negedge rst2in)begin
    if(rst2in==1'b0)begin
        cnt_20ms<=0;
    end
    else if(cnt_20ms == t_20ms-1)begin
        cnt_20ms<=cnt_20ms;
    end
    else
        cnt_20ms<=cnt_20ms + 1 ;
end
wire delay_done = (cnt_20ms==t_20ms-1)? 1'b1 : 1'b0 ;   //延时完成信号
//--------------------------------
//500ns  分频，LCD1602的工作频率是500HZ
reg [19:0] cnt_500hz=0;
always  @(posedge clk_1mhz or negedge rst2in)begin
    if(rst2in==1'b0)begin
        cnt_500hz <= 0;
    end
    else if(delay_done==1)begin
        if(cnt_500hz== t_500hz - 1)
            cnt_500hz<=0;
        else
            cnt_500hz<=cnt_500hz + 1 ;
    end
    else
        cnt_500hz<=0;
end
assign lcd_en = (cnt_500hz>(t_500hz-1)/2)? 1'b0 : 1'b1;  //使能下降沿
assign write_flag = (cnt_500hz==t_500hz - 1) ? 1'b1 : 1'b0 ;//写状态信号
                                                         //每500hz写一次
//------------------------------------状态机
always  @(posedge clk_1mhz or negedge rst2in)begin
    if(rst2in==1'b0)begin
        c_state <= IDLE    ;
    end
    else if(write_flag==1) begin
        c_state<= n_state  ;    //把代码里的数据写入液晶(每次只写1个)
    end
    else
        c_state<=c_state   ;
end
always  @(clk_1mhz,rst2in,lcd_en,lcd_rw,lcd_rs,lcd_data)begin
    case (c_state)
        IDLE: n_state = SET_FUNCTION ;
SET_FUNCTION: n_state = DISP_OFF     ;
    DISP_OFF: n_state = DISP_CLEAR   ;
  DISP_CLEAR: n_state = ENTRY_MODE   ;
  ENTRY_MODE: n_state = DISP_ON      ;
  DISP_ON   : n_state = ROW1_ADDR    ;
   ROW1_ADDR: n_state = ROW1_0       ;
      ROW1_0: n_state = ROW1_1       ;
      ROW1_1: n_state = ROW1_2       ;
      ROW1_2: n_state = ROW1_3       ;
      ROW1_3: n_state = ROW1_4       ;
      ROW1_4: n_state = ROW1_5       ;
      ROW1_5: n_state = ROW1_6       ;
      ROW1_6: n_state = ROW1_7       ;
      ROW1_7: n_state = ROW1_8       ;
      ROW1_8: n_state = ROW1_9       ;
      ROW1_9: n_state = ROW1_A       ;
      ROW1_A: n_state = ROW1_B       ;
      ROW1_B: n_state = ROW1_C       ;
      ROW1_C: n_state = ROW1_D       ;
      ROW1_D: n_state = ROW1_E       ;
      ROW1_E: n_state = ROW1_F       ;
      ROW1_F: n_state = ROW2_ADDR    ;
   ROW2_ADDR: n_state = ROW2_0       ;
      ROW2_0: n_state = ROW2_1       ;
      ROW2_1: n_state = ROW2_2       ;
      ROW2_2: n_state = ROW2_3       ;
      ROW2_3: n_state = ROW2_4       ;
      ROW2_4: n_state = ROW2_5       ;
      ROW2_5: n_state = ROW2_6       ;
      ROW2_6: n_state = ROW2_7       ;
      ROW2_7: n_state = ROW2_8       ;
      ROW2_8: n_state = ROW2_9       ;
      ROW2_9: n_state = ROW2_A       ;
      ROW2_A: n_state = ROW2_B       ;
      ROW2_B: n_state = ROW2_C       ;
      ROW2_C: n_state = ROW2_D       ;
      ROW2_D: n_state = ROW2_E       ;
      ROW2_E: n_state = ROW2_F       ;
      ROW2_F: n_state = ROW1_ADDR    ;
     default: n_state = n_state      ;
   endcase 
   end  
   assign lcd_rw = 0;    //不需要读操作
   always  @(posedge clk_1mhz or negedge rst2in)begin
       if(rst2in==1'b0)begin
           lcd_rs <= 0 ;   //order or data  0: order 1:data
       end
       else if(write_flag == 1)begin
           if((n_state==SET_FUNCTION)||(n_state==DISP_OFF)||
              (n_state==DISP_CLEAR)||(n_state==ENTRY_MODE)||
              (n_state==DISP_ON ) ||(n_state==ROW1_ADDR)||
              (n_state==ROW2_ADDR))begin
           lcd_rs<=0 ;
           end 
           else  begin   //当不属于上面任一状态时,执行写操作
           lcd_rs<= 1;   //手册要求,执行写时这个数是1
           end
       end
       else begin
           lcd_rs<=lcd_rs;
       end     
   end                  
   always  @(posedge clk_1mhz or negedge rst2in)begin
       if(rst2in==1'b0)begin
           lcd_data<=0 ;
       end
       else  if(write_flag)begin
           case(n_state)
                 IDLE: lcd_data <= 8'hxx;
         SET_FUNCTION: lcd_data <= 8'h38; //2*16 5*8 8位数据
             DISP_OFF: lcd_data <= 8'h08;
           DISP_CLEAR: lcd_data <= 8'h01;
           ENTRY_MODE: lcd_data <= 8'h06;
           DISP_ON   : lcd_data <= 8'h0c;  //显示功能开，没有光标，且不闪烁，
            ROW1_ADDR: lcd_data <= 8'h80; //00+80   写光标移至第一行
               ROW1_0: lcd_data <= row_1 [127:120]; //把代码里的16个数据拆开
               ROW1_1: lcd_data <= row_1 [119:112];
               ROW1_2: lcd_data <= row_1 [111:104];
               ROW1_3: lcd_data <= row_1 [103: 96];
               ROW1_4: lcd_data <= row_1 [ 95: 88];
               ROW1_5: lcd_data <= row_1 [ 87: 80];
               ROW1_6: lcd_data <= row_1 [ 79: 72];
               ROW1_7: lcd_data <= row_1 [ 71: 64];
               ROW1_8: lcd_data <= row_1 [ 63: 56];
               ROW1_9: lcd_data <= row_1 [ 55: 48];
               ROW1_A: lcd_data <= row_1 [ 47: 40];
               ROW1_B: lcd_data <= row_1 [ 39: 32];
               ROW1_C: lcd_data <= row_1 [ 31: 24];
               ROW1_D: lcd_data <= row_1 [ 23: 16];
               ROW1_E: lcd_data <= row_1 [ 15:  8];
               ROW1_F: lcd_data <= row_1 [  7:  0];
            ROW2_ADDR: lcd_data <= 8'hc0;      //40+80    写光标移至第二行
               ROW2_0: lcd_data <= row_2 [127:120];
               ROW2_1: lcd_data <= row_2 [119:112];
               ROW2_2: lcd_data <= row_2 [111:104];
               ROW2_3: lcd_data <= row_2 [103: 96];
               ROW2_4: lcd_data <= row_2 [ 95: 88];
               ROW2_5: lcd_data <= row_2 [ 87: 80];
               ROW2_6: lcd_data <= row_2 [ 79: 72];
               ROW2_7: lcd_data <= row_2 [ 71: 64];
               ROW2_8: lcd_data <= row_2 [ 63: 56];
               ROW2_9: lcd_data <= row_2 [ 55: 48];
               ROW2_A: lcd_data <= row_2 [ 47: 40];
               ROW2_B: lcd_data <= row_2 [ 39: 32];
               ROW2_C: lcd_data <= row_2 [ 31: 24];
               ROW2_D: lcd_data <= row_2 [ 23: 16];
               ROW2_E: lcd_data <= row_2 [ 15:  8];
               ROW2_F: lcd_data <= row_2 [  7:  0];
           endcase                     
       end
       else
              lcd_data<=lcd_data ;
   end
 
 
 always@(posedge clk_1khz)    //代码里的数据,每行16个,共2行
begin       //1
if(music==1)
begin       //3
	row_1<="1 Happy Birthday" ;  //第一行显示的内容(自动转为ASCII码)
	row_2<="                ";  //第二行显示的内容
end       //3
else if(music==2)
begin     //3
	row_1<="2 Happy Spring  " ; 
	row_2<="Festival !      ";  
end       //3
else if(music==3)
begin     //3
	row_1<="3 heiyewen      " ;  
	row_2<="baitian         "; 
end      //3
else if(music==4)
begin    //3
	row_1<="4 Happy Mid     " ; 
	row_2<="Autumn Festival!"; 
end       //3
else if(music==5)
begin
	row_1<="5 Merry         ";
	row_2<="Christmas!      ";
end
end       //1
endmodule

module key_debounce  //消抖,输入k1,输出k
(    input  clk2,
    input  i_key,
    output  o_key);
reg r_key,  r_key_buf1, r_key_buf2;
 
assign o_key = r_key;
reg[15:0]cnt7;
reg clk_100hz;
always@(posedge clk2)   //1mhz分为100hz
begin
if(cnt7<4999)  //1mhz/100hz=10000,cnt<[10000/2-1=4999]
cnt7=cnt7+1;
else 
begin 
cnt7=0;
clk_100hz=!clk_100hz; 
end
 end
always@(posedge clk_100hz)
begin
   r_key_buf1 <= i_key;
   r_key_buf2 <= r_key_buf1;
   if((r_key_buf1~^r_key_buf2) == 1'b1)    
           r_key <= r_key_buf2;
   else  
           r_key<=0;
end
endmodule
