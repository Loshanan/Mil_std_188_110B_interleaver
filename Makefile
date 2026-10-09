GHDL		:= ghdl
GTKWAVE	:= gtkwave

SIM_TIME	?= 30us
IDLE_CLKS	?= 50000		# longest matrix 1200 long, takes 40X188=11520 clk cycles to steadily write, with ~3clk delay we need X4 clocks to be idle (46080)

BR				?= 150
INTL			?= short
RAND_READY?= true
RAND_VALID?= true
GENERICS  := -gg_bit_rate=$(BR) -gg_intl_mode=$(INTL) -gg_idle_clks=$(IDLE_CLKS) -gg_rand_ready=$(RAND_READY) -gg_rand_valid=$(RAND_VALID)

WORK_DIR	:= work_dir
SRC_DIR		:= src/rtl
TB_DIR		:= tb
LOG_DIR		:= $(TB_DIR)/sim_logs

TOP 			:= tb_hf_mod_interleaver

RTL				:= $(SRC_DIR)/hf_mod_interleaver.vhd
TB				:= $(TB_DIR)/tb_avalon_st_driver_pkg.vhd \
						 $(TB_DIR)/tb_hf_mod_interleaver.vhd
						 

WAVE			:= $(LOG_DIR)/wave.ghw
WAVE_CFG	:= $(TB_DIR)/wave_config.gtkw

.PHONY: all regression sim wave clean

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
		$(GHDL) -a --workdir=$(WORK_DIR) $(RTL) $(TB)
		$(GHDL) -e --workdir=$(WORK_DIR) $(TOP)
		$(GHDL) -r --workdir=$(WORK_DIR) $(TOP) $(GENERICS) --wave=$(WAVE)

wave:
		$(GTKWAVE) $(WAVE) $(WAVE_CFG)

clean:
		rm -rf $(WORK_DIR) $(LOG_DIR)/*


