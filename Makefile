GHDL	:= ghdl
GTKWAVE	:= gtkwave

SIM_TIME	?= 30us
IDLE_CLKS	?= 50000		# longest matrix 1200 long, takes 40X188=11520 clk cycles to steadily write, with ~3clk delay we need X4 clocks to be idle (46080)

BR			?= 150
INTL		?= short
RAND_READY	?= true
RAND_VALID	?= true
GENERICS  	:= -gg_bit_rate=$(BR) -gg_intl_mode=$(INTL) -gg_idle_clks=$(IDLE_CLKS) -gg_rand_ready=$(RAND_READY) -gg_rand_valid=$(RAND_VALID)

WORK_DIR	:= work_dir
SRC_DIR		:= src/rtl
TB_DIR		:= tb
LOG_DIR		:= $(TB_DIR)/sim_logs

TOP_TB 		:= tb_hf_mod_interleaver
TOP_TB_BRIDGE	:= tb_uart_avlnst_bridge

RTL_CORE	:= $(SRC_DIR)/core/hf_mod_interleaver.vhd
RTL_BRIDGE	:= $(SRC_DIR)/uart/uart_trx.vhd \
			   $(SRC_DIR)/fifo/fifo_sync.vhd \
			   $(SRC_DIR)/bridge/uart_avlnst_bridge.vhd

TB			:= $(TB_DIR)/tb_avalon_st_driver_pkg.vhd \
			 	$(TB_DIR)/tb_hf_mod_interleaver.vhd
TB_BRIDGE	:= $(TB_DIR)/tb_uart_avlnst_bridge.vhd

WAVE		:= $(LOG_DIR)/wave.ghw
WAVE_CFG	:= $(TB_DIR)/wave_config.gtkw

.PHONY: all regression sim wave sim_bridge wave_bridge clean

all : regression

regression:
		@for br in 150 300 600 1200; do \
				for intl in short long; do \
						echo "=================================";\
						echo "BR=$$br INTL=$$intl";\
						echo "=================================";\
						for rr in false true; do \
								for rv in false true; do \
										echo "Random ready = $$rr; Random valid = $$rv"; \
										$(MAKE) -s sim \
												BR=$$br	\
												INTL=$$intl \
												RAND_READY=$$rr \
												RAND_VALID=$$rv || exit 1; \
								done \
						done \
				done \
		done
sim: 
		mkdir -p $(WORK_DIR)
		$(GHDL) -a --workdir=$(WORK_DIR) $(RTL_CORE) $(TB)
		$(GHDL) -e --workdir=$(WORK_DIR) $(TOP_TB)
		$(GHDL) -r --workdir=$(WORK_DIR) $(TOP_TB) $(GENERICS) --wave=$(WAVE)

wave:
		$(GTKWAVE) $(WAVE) $(WAVE_CFG)

sim_bridge: $(RTL_BRIDGE) $(TB_BRIDGE)
	mkdir -p $(WORK_DIR)
	$(GHDL) -a --workdir=$(WORK_DIR) $(RTL_BRIDGE) $(TB_BRIDGE)
	$(GHDL) -e --workdir=$(WORK_DIR) $(TOP_TB_BRIDGE)
	$(GHDL) -r --workdir=$(WORK_DIR) $(TOP_TB_BRIDGE) --wave=$(LOG_DIR)/bridge.ghw

wave_bridge: $(LOG_DIR)/bridge.ghw
	$(GTKWAVE) $< $(TB_DIR)/bridge_config.gtkw

clean:
		rm -rf $(WORK_DIR) $(LOG_DIR)/*


