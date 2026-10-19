import argparse
from pathlib import Path

from gem5.components.boards.simple_board import SimpleBoard
from gem5.components.cachehierarchies.classic.no_cache import NoCache
from gem5.components.memory import SingleChannelDDR3_1600
from gem5.components.processors.cpu_types import CPUTypes
from gem5.components.processors.simple_processor import SimpleProcessor
from gem5.isas import ISA
from gem5.resources.resource import BinaryResource
from gem5.simulate.simulator import Simulator
from gem5.utils.requires import requires

PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_BINARY = PROJECT_ROOT / "workload" / "build" / "mips_multicycle.elf"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--binary",
        type=Path,
        default=DEFAULT_BINARY,
        help="MIPS ELF to run (default: workload/build/mips_multicycle.elf)",
    )
    args = parser.parse_args()

    binary = args.binary.expanduser().resolve()
    if not binary.is_file():
        raise SystemExit(
            f"Workload not found: {binary}\n"
            "Build it first with scripts/build_workload.sh"
        )

    # Fail early if this gem5 binary was not compiled for MIPS.
    requires(isa_required=ISA.MIPS)

    # No cache keeps the configuration small and easy to follow.  Instruction
    # fetches and data accesses still go through the memory system, so their
    # latency is visible in the cycle count.
    cache_hierarchy = NoCache()

    # 64 MiB is far more than this small program needs.
    memory = SingleChannelDDR3_1600(size="64MiB")

    # TimingSimpleCPU executes one instruction at a time and models the timing
    # of instruction fetches and data accesses.  It is not a five-stage
    # multicycle state machine.
    processor = SimpleProcessor(
        cpu_type=CPUTypes.TIMING,
        isa=ISA.MIPS,
        num_cores=1,
    )

    board = SimpleBoard(
        clk_freq="1GHz",
        processor=processor,
        memory=memory,
        cache_hierarchy=cache_hierarchy,
    )

    board.set_se_binary_workload(BinaryResource(local_path=str(binary)))

    simulator = Simulator(board=board)
    simulator.run()


if __name__ == "__m5_main__":
    main()
