
#define TESTBENCH_TOP Vverilator_top

#include <iostream>
#include <vector>
#include <memory>
#include <verilated.h>
#include "Vverilator_top.h"
#include "tb_clock.cpp"

using namespace std;

// Legacy function required only so linking works on Cygwin and MSVC++
double sc_time_stamp() { return 0; }

int main(int argc, char** argv) {
    // This is a more complicated example, please also see the simpler examples/make_hello_c.

    // Create logs/ directory in case we have traces to put under it
    Verilated::mkdir("logs");

    // Construct a VerilatedContext to hold simulation time, etc.
    // Multiple modules (made later below with Vtb) may share the same
    // context to share time, or modules may have different contexts if
    // they should be independent from each other.

    // Using unique_ptr is similar to
    // "VerilatedContext* contextp = new VerilatedContext" then deleting at end.
    const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};
    // Do not instead make Vtb as a file-scope static variable, as the
    // "C++ static initialization order fiasco" may cause a crash

    // Set debug level, 0 is off, 9 is highest presently used
    // May be overridden by commandArgs argument parsing
    contextp->debug(0);

    // Randomization reset policy
    // May be overridden by commandArgs argument parsing
    contextp->randReset(2);

    // Verilator must compute traced signals
    contextp->traceEverOn(true);

    // Pass arguments so Verilated code can see them, e.g. $value$plusargs
    // This needs to be called before you create any model
    contextp->commandArgs(argc, argv);

    // Construct the Verilated model, from Vtb.h generated from Verilating "top.v".
    // Using unique_ptr is similar to "Vtb* top = new Vtb" then deleting at end.
    // "TOP" will be the hierarchical name of the module.
    const std::unique_ptr<TESTBENCH_TOP> top{new TESTBENCH_TOP{contextp.get(), "TOP"}};

    vector<tb_clock> clocks;

    for (int i = 0; i < 3; ++i)
        clocks.push_back(tb_clock());

    clocks[0].set_period_ps(12500);
    clocks[1].set_period_ps(40000);
    clocks[2].set_period_ps(8000);

    top->clk = 0;
    top->pixel_clk = 0;
    top->pixel_clk_5x = 0;
    top->eval();

    // Simulate until $finish
    while (!contextp->gotFinish()) {
        // Historical note, before Verilator 4.200 Verilated::gotFinish()
        // was used above in place of contextp->gotFinish().
        // Most of the contextp-> calls can use Verilated:: calls instead;
        // the Verilated:: versions just assume there's a single context
        // being used (per thread).  It's faster and clearer to use the
        // newer contextp-> versions.

        uint64_t next_edge = numeric_limits<uint64_t>::max();
        for (auto clock : clocks) {
            uint64_t current = clock.get_time_to_edge();
            if (current < next_edge) {
                next_edge = current;
            }
        }

        top->clk = clocks[0].advance(next_edge);
        top->pixel_clk = clocks[1].advance(next_edge);
        top->pixel_clk_5x = clocks[2].advance(next_edge);
        contextp->timeInc(next_edge);
        top->eval();
    }

    // Final model cleanup
    top->final();

    // Coverage analysis (calling write only after the test is known to pass)
#if VM_COVERAGE
    Verilated::mkdir("logs");
    contextp->coveragep()->write("logs/coverage.dat");
#endif

    return 0;
}