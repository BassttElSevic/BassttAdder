PROJECT := BassttAdder
QBIN := $(HOME)/altera_lite/25.1std/quartus/bin
SOF := output_files/$(PROJECT).sof
JIC := output_files/$(PROJECT).jic
SFL := $(HOME)/altera_lite/25.1std/quartus/common/devinfo/programmer/sfl_ep4ce10.sof
CABLE ?= USB-Blaster [1-2]

.PHONY: check build report program jic flash-jtag

check:
	$(QBIN)/quartus_map --analysis_and_elaboration $(PROJECT)

build:
	$(QBIN)/quartus_sh --flow compile $(PROJECT)

report:
	@cat output_files/$(PROJECT).fit.summary
	@cat output_files/$(PROJECT).sta.summary

program:
	@test -f $(SOF) || { echo "找不到 .sof，请先运行 make build"; exit 1; }
	$(QBIN)/quartus_pgm -c "$(CABLE)" -m jtag -o "p;$(abspath $(SOF))"

# 后面跟一个build，这样就不会忘记打build了
jic: build
	@test -f $(SOF) || { echo "找不到 .sof，请先运行 make build"; exit 1; }
	$(QBIN)/quartus_cpf -c -d EPCS16 -s EP4CE10 $(SOF) $(JIC)

# 将配置写入板载 Flash（断电后仍保留）。排线必须插 JTAG 座。
flash-jtag: jic
	@test -f $(SFL) || { echo "找不到 SFL: $(SFL)"; exit 1; }
	$(QBIN)/quartus_pgm -c "$(CABLE)" -m jtag -o "p;$(SFL)"
	$(QBIN)/quartus_pgm -c "$(CABLE)" -m jtag -o "p;$(abspath $(JIC))"
