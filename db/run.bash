#!/usr/bin/env bash
set -euo pipefail

TESTS="spi_reset_test spi_reg_rw_test spi_main_mode_test spi_secondary_mode_test spi_share_default_test spi_share_range0_main_test spi_share_range1_secondary_test spi_share_default_select_test spi_share_write_safety_test spi_host_switch_test spi_illegal_opcode_test spi_host_contention_test spi_bad_range_test spi_overlap_range_test spi_addr_low_test spi_addr_high_test spi_runtime_cfg_test spi_random_rw_test spi_random_host_mode_test spi_stress_test"
SEEDS="1234 5678"
ITER=1
# For constrained-random tests (random* or stress), override iteration count if desired
CRV_ITER=2
SIMV=simv

# Compile with coverage enabled
# This creates the static coverage model in 'simv.vdb'
vcs -full64 -sverilog -timescale=1ns/1ps \
  -cm line+tgl+cond+fsm+branch+assert \
  -f filelist.f \
  -top testbench \
  -l compile.log

mkdir -p cov_runs
run_list=()
fail_list=()
pass_count=0
fail_count=0

for testname in ${TESTS}; do
  # Decide iteration count (CRV tests get CRV_ITER)
  iter_max=$ITER
  case "$testname" in
    spi_random_rw_test|spi_random_host_mode_test|spi_stress_test)
      iter_max=$CRV_ITER
      ;;
  esac
  iter=1
  while [ $iter -le $iter_max ]; do
    for seed in ${SEEDS}; do
      cm_dir="cov_runs/${testname}_iter${iter}_seed${seed}.vdb"
      run_list+=("$cm_dir")
      echo "===== Running TEST=${testname} ITER=${iter}/${iter_max} SEED=${seed} ====="
      log_file="sim_${testname}_iter${iter}_seed${seed}.log"
      
      # Run simulation with coverage enabled, saving to unique directory
      ./simv +TEST="${testname}" +ntb_random_seed="$seed" +vcs+lic+wait \
        -cm line+tgl+cond+fsm+branch+assert -cm_dir "$cm_dir" \
        -l "$log_file"
        
      if grep -q "==== TEST ${testname} PASSED ====" "$log_file"; then
        pass_count=$((pass_count+1))
      else
        fail_count=$((fail_count+1))
        fail_list+=("${testname} iter${iter} seed${seed}")
      fi
    done
    iter=$((iter+1))
  done
done

# Generate coverage report
# CRITICAL FIX: Include 'simv.vdb' (static model) along with dynamic run data
urg -dir simv.vdb "${run_list[@]}" -report cov_report

echo "Coverage report in cov_report/html/index.html"
if [ -f cov_report/summary.txt ]; then
  echo "---- Coverage Summary ----"
  cat cov_report/summary.txt
fi

echo "---- Test Summary ----"
echo "Passed: ${pass_count}"
echo "Failed: ${fail_count}"
if [ ${fail_count} -ne 0 ]; then
  printf '%s\n' "${fail_list[@]}"
fi