GHDL		:= ghdl
GTKWAVE	:= gtkwave

SIM_TIME	?= 30us
IDLE_CLKS	?= 2000

BR				?= 150
INTL			?= short
RAND_READY?= false
GENERICS  := -gg_bit_rate=$(BR) -gg_intl_mode=$(INTL) -gg_idle_clks=$(IDLE_CLKS) -gg_rnd_ready=$(RAND_READY)

WORK_DIR	:= work_dir
SRC_DIR		:= src/rtl
TB_DIR		:= tb
LOG_DIR		:= $(TB_DIR)/sim_logs

TOP 			:= tb_hf_mod_interleaver

RTL				:= $(SRC_DIR)/hf_mod_interleaver.vhd
TB				:= $(TB_DIR)/tb_avalon_st_driver_pkg.vhd \
						 $(TB_DIR)/tb_hf_mod_interleaver.vhd
						 

WAVE			:= $(LOG_DIR)/wave.ghw
WAVE_CFG	:= $(LOG_DIR)/wave_config.gtkw

.PHONY: all sim wave clean

all : sim

sim: 
		mkdir -p $(WORK_DIR)
		$(GHDL) -a --workdir=$(WORK_DIR) $(RTL) $(TB)
		$(GHDL) -e --workdir=$(WORK_DIR) $(TOP)
		$(GHDL) -r --workdir=$(WORK_DIR) $(TOP) $(GENERICS) --wave=$(WAVE) # --stop-time=$(SIM_TIME)

wave:
		$(GTKWAVE) $(WAVE) $(WAVE_CFG)

clean:
		rm -rf $(WORK_DIR) $(WAVE)
