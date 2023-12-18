const std = @import("std");
const linux = std.os.linux;
const bpf = linux.BPF;

const ebpf_obj = @embedFile("../zig-out/bin/probes.o");

comptime {
    @setEvalBranchQuota(5000);
}

pub fn main() !noreturn {
    // Create perf_event attributes to profile at a frequency of 1Hz
    var perf_attr = linux.perf_event_attr{
        .type = linux.PERF.TYPE.HARDWARE,
        .config = @intFromEnum(linux.PERF.COUNT.HW.CPU_CYCLES),
        .size = @sizeOf(linux.perf_event_attr),
        .sample_period_or_freq = 1,
    };

    // TODO: start with only CPU 0, but we should have a for loop here
    const popen = linux.perf_event_open(&perf_attr, -1, 0, -1, linux.PERF.FLAG.FD_CLOEXEC);
    if (popen < 0) {
        std.debug.print("perf_event_open failed: error code {d}\n", .{popen});
        return ExecutionError.PerEventOpenFailed;
    } else {
        std.debug.print("perf_event_open fd: {d}\n", .{popen});
    }

    // Keep reading the perf event ring buffer until we get an error
    while (true) {}
}

const ExecutionError = error{
    PerEventOpenFailed,
};
